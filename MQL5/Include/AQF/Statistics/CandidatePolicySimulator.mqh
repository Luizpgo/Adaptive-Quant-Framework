#ifndef __AQF_CANDIDATE_POLICY_SIMULATOR_MQH__
#define __AQF_CANDIDATE_POLICY_SIMULATOR_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"

#define AQF_POLICY_COUNT 3

//+------------------------------------------------------------------+
//| Candidate Policy Simulator                                       |
//|                                                                  |
//| Sprint 8 - Package A                                             |
//|                                                                  |
//| Purpose:                                                         |
//| Compare three frozen candidate policies using a realistic        |
//| one-position-at-a-time virtual account for EACH policy.          |
//|                                                                  |
//| Policy 0 - BASELINE                                               |
//|   TP = 1.50R                                                     |
//|   No additional entry filter                                     |
//|                                                                  |
//| Policy 1 - H1_ATR_HIGH                                           |
//|   TP = 1.50R                                                     |
//|   ATRPercent >= 0.075                                            |
//|                                                                  |
//| Policy 2 - H2_ATR_HIGH_ADX_25_39                                 |
//|   TP = 1.50R                                                     |
//|   ATRPercent >= 0.075                                            |
//|   ADX >= 25 and ADX < 40                                         |
//|                                                                  |
//| IMPORTANT                                                        |
//| - Virtual simulation only.                                       |
//| - NO OrderSend.                                                   |
//| - NO real position management.                                   |
//| - Each policy allows only ONE active virtual position at a time. |
//+------------------------------------------------------------------+

struct SAQFCandidatePolicyPosition
{
   bool Active;

   string Symbol;

   ENUM_AQF_SIGNAL_DIRECTION Direction;

   double EntryPrice;
   double StopLoss;
   double StopDistance;
   double TakeProfit;

   datetime EntryTime;

   ENUM_TIMEFRAMES Timeframe;
};

class CAQFCandidatePolicySimulator
{
private:

   //---------------------------------------------------------------
   // Active virtual position for each independent policy
   //---------------------------------------------------------------

   SAQFCandidatePolicyPosition m_position[AQF_POLICY_COUNT];

   //---------------------------------------------------------------
   // Frozen policy parameters
   //---------------------------------------------------------------

   double m_targetR[AQF_POLICY_COUNT];

   //---------------------------------------------------------------
   // Opportunity statistics
   //---------------------------------------------------------------

   long m_signalsSeen[AQF_POLICY_COUNT];
   long m_filterRejected[AQF_POLICY_COUNT];
   long m_eligible[AQF_POLICY_COUNT];
   long m_opened[AQF_POLICY_COUNT];
   long m_skippedActive[AQF_POLICY_COUNT];

   //---------------------------------------------------------------
   // Resolved trade statistics
   //---------------------------------------------------------------

   long m_wins[AQF_POLICY_COUNT];
   long m_losses[AQF_POLICY_COUNT];

   double m_totalBars[AQF_POLICY_COUNT];

   //---------------------------------------------------------------
   // Equity curve in R
   //---------------------------------------------------------------

   double m_cumulativeR[AQF_POLICY_COUNT];
   double m_peakR[AQF_POLICY_COUNT];
   double m_maxDrawdownR[AQF_POLICY_COUNT];

   //---------------------------------------------------------------
   // Losing streak
   //---------------------------------------------------------------

   long m_currentLosingStreak[AQF_POLICY_COUNT];
   long m_maxLosingStreak[AQF_POLICY_COUNT];

   bool m_initialized;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFCandidatePolicySimulator()
   {
      m_initialized =
         false;

      for(int i = 0;
          i < AQF_POLICY_COUNT;
          i++)
      {
         m_targetR[i] =
            1.50;

         ResetPosition(
            i
         );

         ResetStatistics(
            i
         );
      }
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(
      CAQFLogger &logger)
   {
      for(int i = 0;
          i < AQF_POLICY_COUNT;
          i++)
      {
         ResetPosition(
            i
         );

         ResetStatistics(
            i
         );
      }

      m_initialized =
         true;

      logger.Info(
         "CandidatePolicySimulator initialized."
      );

      logger.Info(
         "Policy BASELINE | TP=1.50R | Filter=NONE"
      );

      logger.Info(
         "Policy H1_ATR_HIGH | TP=1.50R | ATRPercent>=0.075"
      );

      logger.Info(
         "Policy H2_ATR_HIGH_ADX_25_39 | TP=1.50R | ATRPercent>=0.075 | ADX>=25 | ADX<40"
      );

      logger.Info(
         "Candidate policies use ONE ACTIVE VIRTUAL POSITION PER POLICY - NO ORDER EXECUTION"
      );

      return true;
   }

   //==============================================================
   // Register executable-quality opportunity
   //==============================================================
   bool Register(
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return false;

      if(!request.Valid ||
         !market.Valid ||
         request.Symbol == "" ||
         market.Symbol != request.Symbol ||
         request.EntryPrice <= 0.0 ||
         request.StopLoss <= 0.0 ||
         request.StopDistance <= 0.0)
      {
         return false;
      }

      if(request.Direction != AQF_SIGNAL_BUY &&
         request.Direction != AQF_SIGNAL_SELL)
      {
         return false;
      }

      for(int policy = 0;
          policy < AQF_POLICY_COUNT;
          policy++)
      {
         m_signalsSeen[policy]++;

         //---------------------------------------------------------
         // Frozen candidate filter
         //---------------------------------------------------------

         if(!PolicyAccepts(
               policy,
               market))
         {
            m_filterRejected[policy]++;
            continue;
         }

         m_eligible[policy]++;

         //---------------------------------------------------------
         // Realistic sequential-position gate
         //
         // Each policy is treated as its own virtual account.
         // An active position blocks every new eligible signal until
         // that position reaches its original SL or the policy TP.
         //---------------------------------------------------------

         if(m_position[policy].Active)
         {
            m_skippedActive[policy]++;
            continue;
         }

         //---------------------------------------------------------
         // Open virtual policy position
         //---------------------------------------------------------

         OpenPosition(
            policy,
            request,
            market
         );

         m_opened[policy]++;

         logger.Debug(
            "PolicyOpen | Policy=" +
            PolicyName(
               policy) +
            " | " +
            request.Symbol +
            " | Direction=" +
            AQFSignalDirectionToString(
               request.Direction) +
            " | Entry=" +
            DoubleToString(
               request.EntryPrice,
               (int)SymbolInfoInteger(
                  request.Symbol,
                  SYMBOL_DIGITS)) +
            " | SL=" +
            DoubleToString(
               request.StopLoss,
               (int)SymbolInfoInteger(
                  request.Symbol,
                  SYMBOL_DIGITS)) +
            " | TP=" +
            DoubleToString(
               m_position[policy].TakeProfit,
               (int)SymbolInfoInteger(
                  request.Symbol,
                  SYMBOL_DIGITS)) +
            " | ADX=" +
            DoubleToString(
               market.ADX,
               2) +
            " | ATR%=" +
            DoubleToString(
               market.ATRPercent,
               4)
         );
      }

      return true;
   }

   //==============================================================
   // Tick-by-tick virtual position management
   //==============================================================
   void Update(
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return;

      if(!market.Valid ||
         market.Bid <= 0.0 ||
         market.Ask <= 0.0)
      {
         return;
      }

      for(int policy = 0;
          policy < AQF_POLICY_COUNT;
          policy++)
      {
         if(!m_position[policy].Active)
            continue;

         if(m_position[policy].Symbol !=
            market.Symbol)
         {
            continue;
         }

         double exitPrice =
            0.0;

         bool targetReached =
            false;

         bool stopReached =
            false;

         //---------------------------------------------------------
         // BUY exits at Bid.
         // SELL exits at Ask.
         //---------------------------------------------------------

         if(m_position[policy].Direction ==
            AQF_SIGNAL_BUY)
         {
            exitPrice =
               market.Bid;

            targetReached =
               (
                  market.Bid >=
                  m_position[policy].TakeProfit
               );

            stopReached =
               (
                  market.Bid <=
                  m_position[policy].StopLoss
               );
         }
         else
         {
            exitPrice =
               market.Ask;

            targetReached =
               (
                  market.Ask <=
                  m_position[policy].TakeProfit
               );

            stopReached =
               (
                  market.Ask >=
                  m_position[policy].StopLoss
               );
         }

         int barsElapsed =
            CalculateBarsElapsed(
               policy,
               market.Time
            );

         if(targetReached)
         {
            Resolve(
               policy,
               true,
               exitPrice,
               barsElapsed,
               logger
            );

            continue;
         }

         if(stopReached)
         {
            Resolve(
               policy,
               false,
               exitPrice,
               barsElapsed,
               logger
            );

            continue;
         }
      }
   }

   //==============================================================
   // Final Report
   //==============================================================
   void ReportAll(
      CAQFLogger &logger)
   {
      logger.Info(
         "PolicyStats ============================================"
      );

      for(int policy = 0;
          policy < AQF_POLICY_COUNT;
          policy++)
      {
         long resolved =
            m_wins[policy] +
            m_losses[policy];

         double winRate =
            0.0;

         double expectancyR =
            0.0;

         double avgBars =
            0.0;

         if(resolved > 0)
         {
            winRate =
               (
                  (double)m_wins[policy] /
                  (double)resolved
               ) * 100.0;

            expectancyR =
               m_cumulativeR[policy] /
               (double)resolved;

            avgBars =
               m_totalBars[policy] /
               (double)resolved;
         }

         logger.Info(
            "PolicyStats" +
            " | Policy=" +
            PolicyName(
               policy) +
            " | TP=" +
            DoubleToString(
               m_targetR[policy],
               2) +
            "R" +
            " | Signals=" +
            IntegerToString(
               (int)m_signalsSeen[policy]) +
            " | FilterRejected=" +
            IntegerToString(
               (int)m_filterRejected[policy]) +
            " | Eligible=" +
            IntegerToString(
               (int)m_eligible[policy]) +
            " | Opened=" +
            IntegerToString(
               (int)m_opened[policy]) +
            " | SkippedActive=" +
            IntegerToString(
               (int)m_skippedActive[policy]) +
            " | Resolved=" +
            IntegerToString(
               (int)resolved) +
            " | Wins=" +
            IntegerToString(
               (int)m_wins[policy]) +
            " | Losses=" +
            IntegerToString(
               (int)m_losses[policy]) +
            " | Open=" +
            (
               m_position[policy].Active
               ? "1"
               : "0"
            ) +
            " | WinRate=" +
            DoubleToString(
               winRate,
               2) +
            "%" +
            " | Expectancy=" +
            DoubleToString(
               expectancyR,
               3) +
            "R" +
            " | ProfitFactor=" +
            ProfitFactorText(
               policy) +
            " | CumR=" +
            DoubleToString(
               m_cumulativeR[policy],
               2) +
            "R" +
            " | MaxDD=" +
            DoubleToString(
               m_maxDrawdownR[policy],
               2) +
            "R" +
            " | MaxLossStreak=" +
            IntegerToString(
               (int)m_maxLosingStreak[policy]) +
            " | AvgBars=" +
            DoubleToString(
               avgBars,
               1)
         );
      }

      logger.Info(
         "PolicyStats ============================================"
      );
   }

   //==============================================================
   // Shutdown
   //==============================================================
   void Shutdown(
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return;

      ReportAll(
         logger
      );

      m_initialized =
         false;
   }

private:

   //==============================================================
   // Frozen Policy Acceptance
   //==============================================================
   bool PolicyAccepts(
      const int policy,
      const CAQFMarketSnapshot &market)
   {
      //------------------------------------------------------------
      // BASELINE
      //------------------------------------------------------------

      if(policy == 0)
         return true;

      //------------------------------------------------------------
      // H1
      //------------------------------------------------------------

      if(policy == 1)
      {
         return
            (
               market.ATRPercent >=
               0.075
            );
      }

      //------------------------------------------------------------
      // H2
      //------------------------------------------------------------

      if(policy == 2)
      {
         return
            (
               market.ATRPercent >=
               0.075
               &&
               market.ADX >=
               25.0
               &&
               market.ADX <
               40.0
            );
      }

      return false;
   }

   //==============================================================
   // Open Position
   //==============================================================
   void OpenPosition(
      const int policy,
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market)
   {
      ResetPosition(
         policy
      );

      m_position[policy].Active =
         true;

      m_position[policy].Symbol =
         request.Symbol;

      m_position[policy].Direction =
         request.Direction;

      m_position[policy].EntryPrice =
         request.EntryPrice;

      m_position[policy].StopLoss =
         request.StopLoss;

      m_position[policy].StopDistance =
         request.StopDistance;

      m_position[policy].EntryTime =
         request.SignalTime;

      m_position[policy].Timeframe =
         market.Timeframe;

      double targetDistance =
         request.StopDistance *
         m_targetR[policy];

      if(request.Direction ==
         AQF_SIGNAL_BUY)
      {
         m_position[policy].TakeProfit =
            request.EntryPrice +
            targetDistance;
      }
      else
      {
         m_position[policy].TakeProfit =
            request.EntryPrice -
            targetDistance;
      }
   }

   //==============================================================
   // Resolve Position
   //==============================================================
   void Resolve(
      const int policy,
      const bool win,
      const double exitPrice,
      const int barsElapsed,
      CAQFLogger &logger)
   {
      if(policy < 0 ||
         policy >= AQF_POLICY_COUNT)
      {
         return;
      }

      double resultR =
         -1.0;

      if(win)
      {
         m_wins[policy]++;

         resultR =
            m_targetR[policy];

         m_currentLosingStreak[policy] =
            0;
      }
      else
      {
         m_losses[policy]++;

         m_currentLosingStreak[policy]++;

         if(m_currentLosingStreak[policy] >
            m_maxLosingStreak[policy])
         {
            m_maxLosingStreak[policy] =
               m_currentLosingStreak[policy];
         }
      }

      m_totalBars[policy] +=
         (double)barsElapsed;

      //------------------------------------------------------------
      // R equity curve
      //------------------------------------------------------------

      m_cumulativeR[policy] +=
         resultR;

      if(m_cumulativeR[policy] >
         m_peakR[policy])
      {
         m_peakR[policy] =
            m_cumulativeR[policy];
      }

      double currentDrawdown =
         m_peakR[policy] -
         m_cumulativeR[policy];

      if(currentDrawdown >
         m_maxDrawdownR[policy])
      {
         m_maxDrawdownR[policy] =
            currentDrawdown;
      }

      logger.Debug(
         "PolicyClose | Policy=" +
         PolicyName(
            policy) +
         " | " +
         m_position[policy].Symbol +
         " | Result=" +
         (
            win
            ? "WIN"
            : "LOSS"
         ) +
         " | ResultR=" +
         DoubleToString(
            resultR,
            2) +
         "R" +
         " | CumR=" +
         DoubleToString(
            m_cumulativeR[policy],
            2) +
         "R" +
         " | Bars=" +
         IntegerToString(
            barsElapsed) +
         " | Exit=" +
         DoubleToString(
            exitPrice,
            (int)SymbolInfoInteger(
               m_position[policy].Symbol,
               SYMBOL_DIGITS))
      );

      ResetPosition(
         policy
      );
   }

   //==============================================================
   // Bars Elapsed
   //==============================================================
   int CalculateBarsElapsed(
      const int policy,
      const datetime currentTime)
   {
      if(policy < 0 ||
         policy >= AQF_POLICY_COUNT)
      {
         return 0;
      }

      int secondsPerBar =
         PeriodSeconds(
            m_position[policy].Timeframe
         );

      if(secondsPerBar <= 0)
         return 0;

      long secondsElapsed =
         (long)(
            currentTime -
            m_position[policy].EntryTime
         );

      if(secondsElapsed <= 0)
         return 0;

      return
         (int)(
            secondsElapsed /
            secondsPerBar
         );
   }

   //==============================================================
   // Profit Factor
   //==============================================================
   string ProfitFactorText(
      const int policy)
   {
      if(policy < 0 ||
         policy >= AQF_POLICY_COUNT)
      {
         return "0.000";
      }

      double grossProfitR =
         (double)m_wins[policy] *
         m_targetR[policy];

      double grossLossR =
         (double)m_losses[policy];

      if(grossLossR <= 0.0)
      {
         if(grossProfitR > 0.0)
            return "INF";

         return "0.000";
      }

      return
         DoubleToString(
            grossProfitR /
            grossLossR,
            3
         );
   }

   //==============================================================
   // Names
   //==============================================================
   string PolicyName(
      const int policy)
   {
      if(policy == 0)
         return "BASELINE";

      if(policy == 1)
         return "H1_ATR_HIGH";

      if(policy == 2)
         return "H2_ATR_HIGH_ADX_25_39";

      return "UNKNOWN";
   }

   //==============================================================
   // Reset Position
   //==============================================================
   void ResetPosition(
      const int policy)
   {
      if(policy < 0 ||
         policy >= AQF_POLICY_COUNT)
      {
         return;
      }

      m_position[policy].Active =
         false;

      m_position[policy].Symbol =
         "";

      m_position[policy].Direction =
         AQF_SIGNAL_NONE;

      m_position[policy].EntryPrice =
         0.0;

      m_position[policy].StopLoss =
         0.0;

      m_position[policy].StopDistance =
         0.0;

      m_position[policy].TakeProfit =
         0.0;

      m_position[policy].EntryTime =
         0;

      m_position[policy].Timeframe =
         PERIOD_CURRENT;
   }

   //==============================================================
   // Reset Statistics
   //==============================================================
   void ResetStatistics(
      const int policy)
   {
      if(policy < 0 ||
         policy >= AQF_POLICY_COUNT)
      {
         return;
      }

      m_signalsSeen[policy] =
         0;

      m_filterRejected[policy] =
         0;

      m_eligible[policy] =
         0;

      m_opened[policy] =
         0;

      m_skippedActive[policy] =
         0;

      m_wins[policy] =
         0;

      m_losses[policy] =
         0;

      m_totalBars[policy] =
         0.0;

      m_cumulativeR[policy] =
         0.0;

      m_peakR[policy] =
         0.0;

      m_maxDrawdownR[policy] =
         0.0;

      m_currentLosingStreak[policy] =
         0;

      m_maxLosingStreak[policy] =
         0;
   }
};

#endif
