#ifndef __AQF_STALLED10_EXIT_SIMULATOR_MQH__
#define __AQF_STALLED10_EXIT_SIMULATOR_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"

//+------------------------------------------------------------------+
//| H3 Stalled10 Independent Exit Simulator                          |
//|                                                                  |
//| Sprint 10 - Package B                                            |
//|                                                                  |
//| PURPOSE                                                          |
//| - Simulate the FROZEN H3 entry policy independently.             |
//| - Add exactly ONE predeclared post-entry management rule:        |
//|                                                                  |
//|   D1 - Stalled10                                                 |
//|   If ActualBarsElapsed > 10 AND the trade has NEVER reached      |
//|   +0.50R, close at the first available executable tick.          |
//|                                                                  |
//| - BUY closes at Bid.                                             |
//| - SELL closes at Ask.                                            |
//| - TP/SL barrier checks have priority on the trigger tick.         |
//| - If neither barrier is crossed, Stalled10 exits at the actual   |
//|   executable Bid/Ask of that first tick.                         |
//|                                                                  |
//| FROZEN H3 ENTRY                                                  |
//|   ATRPercent >= 0.075                                            |
//|   ADX >= 25 and ADX < 40                                        |
//|   DirER10 >= 0.50                                                |
//|   VolZ20 >= 0.25 and VolZ20 < 1.00                              |
//|   TP = +1.50R                                                    |
//|   SL = -1.00R                                                    |
//|                                                                  |
//| IMPORTANT                                                        |
//| - ONE independent active virtual position at a time.             |
//| - Early Stalled10 exits can unlock later H3 opportunities.       |
//| - This is why Opened/SkippedActive may differ from frozen H3.    |
//| - Entry filters/counters MUST remain synchronized with H3.       |
//| - COMPLETED candles only for H3 research entry features.         |
//| - VIRTUAL ONLY. NO OrderSend. NO real position management.       |
//+------------------------------------------------------------------+

struct SAQFStalled10Position
{
   bool Active;

   string Symbol;
   ENUM_AQF_SIGNAL_DIRECTION Direction;

   double EntryPrice;
   double StopLoss;
   double StopDistance;
   double TakeProfit;

   ENUM_TIMEFRAMES Timeframe;

   datetime LastObservedBarTime;
   int ActualBarsElapsed;

   bool HitPos050;
};

class CAQFStalled10ExitSimulator
{
private:

   SAQFStalled10Position m_position;

   //---------------------------------------------------------------
   // Frozen H3 parameters
   //---------------------------------------------------------------

   double m_targetR;
   double m_stopR;
   double m_progressR;

   double m_minATRPercent;
   double m_minADX;
   double m_maxADX;

   double m_minDirectionalER10;

   double m_minVolumeZ20;
   double m_maxVolumeZ20;

   //---------------------------------------------------------------
   // Frozen Stalled10 timing
   //---------------------------------------------------------------

   int m_stallBars;

   //---------------------------------------------------------------
   // Opportunity diagnostics
   //---------------------------------------------------------------

   long m_signalsSeen;

   long m_h2Rejected;
   long m_featureFailures;
   long m_c1Rejected;
   long m_c3Rejected;

   long m_eligible;
   long m_opened;
   long m_skippedActive;

   //---------------------------------------------------------------
   // Exit / outcome diagnostics
   //---------------------------------------------------------------

   long m_resolved;

   long m_tpHits;
   long m_slHits;
   long m_stalledExits;

   long m_profitable;
   long m_losing;
   long m_flat;

   long m_stalledPositive;
   long m_stalledNegative;
   long m_stalledFlat;

   double m_stalledExitCumR;
   double m_stalledExitBars;

   //---------------------------------------------------------------
   // Sequential R accounting
   //---------------------------------------------------------------

   double m_cumulativeR;

   double m_grossProfitR;
   double m_grossLossR;

   double m_peakR;
   double m_maxDrawdownR;

   long m_currentLosingStreak;
   long m_maxLosingStreak;

   double m_totalActualBars;

   bool m_initialized;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFStalled10ExitSimulator()
   {
      m_targetR =
         1.50;

      m_stopR =
         -1.00;

      m_progressR =
         0.50;

      m_minATRPercent =
         0.075;

      m_minADX =
         25.0;

      m_maxADX =
         40.0;

      m_minDirectionalER10 =
         0.50;

      m_minVolumeZ20 =
         0.25;

      m_maxVolumeZ20 =
         1.00;

      m_stallBars =
         10;

      m_initialized =
         false;

      ResetPosition();
      ResetStatistics();
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(
      CAQFLogger &logger)
   {
      ResetPosition();
      ResetStatistics();

      m_initialized =
         true;

      logger.Info(
         "Stalled10ExitSimulator initialized."
      );

      logger.Info(
         "D1 FROZEN BEFORE SPRINT10B RESULTS | ActualBarsElapsed>10 AND NeverHit+0.50R | exit at first executable tick | BUY=Bid SELL=Ask"
      );

      logger.Info(
         "D1 EVENT ORDER FROZEN | TP/SL barrier priority on trigger tick; otherwise Stalled10 exits at actual executable price"
      );

      logger.Info(
         "D1 sequential model: ONE ACTIVE VIRTUAL POSITION INDEPENDENT OF H3 - early exits may unlock later H3 opportunities"
      );

      logger.Info(
         "D1 entry policy remains frozen H3: ATR%>=0.075 | ADX>=25<40 | DirER10>=0.50 | VolZ20>=0.25<1.00 | TP=1.50R | SL=-1.00R"
      );

      logger.Info(
         "Stalled10ExitSimulator is VIRTUAL ONLY - NO ORDER EXECUTION"
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

      m_signalsSeen++;

      //------------------------------------------------------------
      // Frozen H2 base
      //------------------------------------------------------------

      if(
         market.ATRPercent <
         m_minATRPercent
         ||
         market.ADX <
         m_minADX
         ||
         market.ADX >=
         m_maxADX
      )
      {
         m_h2Rejected++;
         return true;
      }

      //------------------------------------------------------------
      // Capture frozen H3 entry features from COMPLETED bars only
      //------------------------------------------------------------

      double relativeVolume20 =
         0.0;

      double volumeZScore20 =
         0.0;

      double directionalER10 =
         0.0;

      if(!CaptureResearchFeatures(
            request,
            market,
            relativeVolume20,
            volumeZScore20,
            directionalER10))
      {
         m_featureFailures++;
         return true;
      }

      //------------------------------------------------------------
      // Frozen C1
      //------------------------------------------------------------

      if(directionalER10 <
         m_minDirectionalER10)
      {
         m_c1Rejected++;
         return true;
      }

      //------------------------------------------------------------
      // Frozen C3
      //------------------------------------------------------------

      if(volumeZScore20 <
         m_minVolumeZ20
         ||
         volumeZScore20 >=
         m_maxVolumeZ20)
      {
         m_c3Rejected++;
         return true;
      }

      m_eligible++;

      //------------------------------------------------------------
      // Independent sequential gate
      //------------------------------------------------------------

      if(m_position.Active)
      {
         m_skippedActive++;
         return true;
      }

      OpenPosition(
         request,
         market
      );

      m_opened++;

      logger.Debug(
         "Stalled10Open" +
         " | Policy=H3_PLUS_D1_STALLED10" +
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
            m_position.TakeProfit,
            (int)SymbolInfoInteger(
               request.Symbol,
               SYMBOL_DIGITS))
      );

      return true;
   }

   //==============================================================
   // Tick-by-tick virtual position management
   //==============================================================
   void Update(
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!m_initialized ||
         !m_position.Active)
      {
         return;
      }

      if(!market.Valid ||
         market.Bid <= 0.0 ||
         market.Ask <= 0.0 ||
         m_position.Symbol != market.Symbol)
      {
         return;
      }

      UpdateActualBarCounter();

      double executablePrice =
         (
            m_position.Direction ==
            AQF_SIGNAL_BUY
         )
         ? market.Bid
         : market.Ask;

      bool targetReached =
         false;

      bool stopReached =
         false;

      //------------------------------------------------------------
      // Existing TP/SL barriers have priority on every tick,
      // including the first tick that activates D1.
      //------------------------------------------------------------

      if(m_position.Direction ==
         AQF_SIGNAL_BUY)
      {
         targetReached =
            (
               market.Bid >=
               m_position.TakeProfit
            );

         stopReached =
            (
               market.Bid <=
               m_position.StopLoss
            );
      }
      else
      {
         targetReached =
            (
               market.Ask <=
               m_position.TakeProfit
            );

         stopReached =
            (
               market.Ask >=
               m_position.StopLoss
            );
      }

      if(targetReached)
      {
         m_tpHits++;

         Resolve(
            m_targetR,
            "TP",
            executablePrice,
            logger
         );

         return;
      }

      if(stopReached)
      {
         m_slHits++;

         Resolve(
            m_stopR,
            "SL",
            executablePrice,
            logger
         );

         return;
      }

      //------------------------------------------------------------
      // D1 must be evaluated BEFORE allowing a newly observed
      // +0.50R on bar 11+ to rescue a trade.
      //
      // This preserves the predeclared definition:
      // no +0.50R during ActualBarsElapsed <= 10.
      //------------------------------------------------------------

      if(
         m_position.ActualBarsElapsed >
         m_stallBars
         &&
         !m_position.HitPos050
      )
      {
         double resultR =
            CurrentR(
               executablePrice
            );

         m_stalledExits++;

         m_stalledExitCumR +=
            resultR;

         m_stalledExitBars +=
            (double)m_position.ActualBarsElapsed;

         if(resultR > 0.0000001)
            m_stalledPositive++;
         else if(resultR < -0.0000001)
            m_stalledNegative++;
         else
            m_stalledFlat++;

         Resolve(
            resultR,
            "STALLED10",
            executablePrice,
            logger
         );

         return;
      }

      //------------------------------------------------------------
      // Progress milestone is observed tick-by-tick only while
      // the trade is still inside its first 10 allowed bars.
      //------------------------------------------------------------

      double currentR =
         CurrentR(
            executablePrice
         );

      if(!m_position.HitPos050 &&
         currentR >=
         m_progressR)
      {
         m_position.HitPos050 =
            true;
      }
   }

   //==============================================================
   // Final report
   //==============================================================
   void ReportAll(
      CAQFLogger &logger)
   {
      double expectancyR =
         0.0;

      double winRate =
         0.0;

      double avgActualBars =
         0.0;

      double avgStalledExitR =
         0.0;

      double avgStalledExitBars =
         0.0;

      if(m_resolved > 0)
      {
         expectancyR =
            m_cumulativeR /
            (double)m_resolved;

         winRate =
            (
               (double)m_profitable /
               (double)m_resolved
            ) *
            100.0;

         avgActualBars =
            m_totalActualBars /
            (double)m_resolved;
      }

      if(m_stalledExits > 0)
      {
         avgStalledExitR =
            m_stalledExitCumR /
            (double)m_stalledExits;

         avgStalledExitBars =
            m_stalledExitBars /
            (double)m_stalledExits;
      }

      long totalRejected =
         m_h2Rejected +
         m_featureFailures +
         m_c1Rejected +
         m_c3Rejected;

      logger.Info(
         "Stalled10PolicyStats" +
         " | Policy=H3_PLUS_D1_STALLED10" +
         " | Trigger=ActualBarsGT10_AND_NeverHit+0.50R" +
         " | Signals=" +
         IntegerToString(
            (int)m_signalsSeen) +
         " | FilterRejected=" +
         IntegerToString(
            (int)totalRejected) +
         " | H2Rejected=" +
         IntegerToString(
            (int)m_h2Rejected) +
         " | FeatureFailures=" +
         IntegerToString(
            (int)m_featureFailures) +
         " | C1Rejected=" +
         IntegerToString(
            (int)m_c1Rejected) +
         " | C3Rejected=" +
         IntegerToString(
            (int)m_c3Rejected) +
         " | Eligible=" +
         IntegerToString(
            (int)m_eligible) +
         " | Opened=" +
         IntegerToString(
            (int)m_opened) +
         " | SkippedActive=" +
         IntegerToString(
            (int)m_skippedActive) +
         " | Resolved=" +
         IntegerToString(
            (int)m_resolved) +
         " | TP=" +
         IntegerToString(
            (int)m_tpHits) +
         " | SL=" +
         IntegerToString(
            (int)m_slHits) +
         " | StalledExit=" +
         IntegerToString(
            (int)m_stalledExits) +
         " | Profitable=" +
         IntegerToString(
            (int)m_profitable) +
         " | Losing=" +
         IntegerToString(
            (int)m_losing) +
         " | Flat=" +
         IntegerToString(
            (int)m_flat) +
         " | Open=" +
         (
            m_position.Active
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
         " | PF=" +
         ProfitFactorText() +
         " | CumR=" +
         DoubleToString(
            m_cumulativeR,
            2) +
         "R" +
         " | MaxDD=" +
         DoubleToString(
            m_maxDrawdownR,
            2) +
         "R" +
         " | MaxLossStreak=" +
         IntegerToString(
            (int)m_maxLosingStreak) +
         " | AvgActualBars=" +
         DoubleToString(
            avgActualBars,
            1)
      );

      logger.Info(
         "Stalled10ExitStats" +
         " | Exits=" +
         IntegerToString(
            (int)m_stalledExits) +
         " | Positive=" +
         IntegerToString(
            (int)m_stalledPositive) +
         " | Negative=" +
         IntegerToString(
            (int)m_stalledNegative) +
         " | Flat=" +
         IntegerToString(
            (int)m_stalledFlat) +
         " | CumExitR=" +
         DoubleToString(
            m_stalledExitCumR,
            2) +
         "R" +
         " | AvgExitR=" +
         DoubleToString(
            avgStalledExitR,
            3) +
         "R" +
         " | AvgTriggerActualBars=" +
         DoubleToString(
            avgStalledExitBars,
            1)
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
   // Capture frozen H3 research features
   //==============================================================
   bool CaptureResearchFeatures(
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market,
      double &relativeVolume20,
      double &volumeZScore20,
      double &directionalER10)
   {
      relativeVolume20 =
         0.0;

      volumeZScore20 =
         0.0;

      directionalER10 =
         0.0;

      MqlRates rates[];

      ArraySetAsSeries(
         rates,
         true
      );

      int copied =
         CopyRates(
            request.Symbol,
            market.Timeframe,
            1,
            21,
            rates
         );

      if(copied != 21)
         return false;

      double volumeSum =
         0.0;

      for(int i = 1;
          i <= 20;
          i++)
      {
         volumeSum +=
            (double)rates[i].tick_volume;
      }

      double volumeMean =
         volumeSum /
         20.0;

      if(volumeMean <= 0.0)
         return false;

      relativeVolume20 =
         (double)rates[0].tick_volume /
         volumeMean;

      double squaredDiffSum =
         0.0;

      for(int i = 1;
          i <= 20;
          i++)
      {
         double difference =
            (double)rates[i].tick_volume -
            volumeMean;

         squaredDiffSum +=
            difference *
            difference;
      }

      double volumeStd =
         MathSqrt(
            squaredDiffSum /
            20.0
         );

      if(volumeStd <= 0.0)
         return false;

      volumeZScore20 =
         (
            (double)rates[0].tick_volume -
            volumeMean
         )
         /
         volumeStd;

      directionalER10 =
         DirectionalEfficiency(
            request.Direction,
            rates,
            10
         );

      return true;
   }

   //==============================================================
   // Signed Kaufman-style efficiency ratio
   //==============================================================
   double DirectionalEfficiency(
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const MqlRates &rates[],
      const int window)
   {
      if(window <= 0 ||
         ArraySize(rates) <
         window + 1)
      {
         return 0.0;
      }

      double netDisplacement =
         rates[0].close -
         rates[window].close;

      if(direction ==
         AQF_SIGNAL_SELL)
      {
         netDisplacement =
            -netDisplacement;
      }

      double pathLength =
         0.0;

      for(int i = 0;
          i < window;
          i++)
      {
         pathLength +=
            MathAbs(
               rates[i].close -
               rates[i + 1].close
            );
      }

      if(pathLength <= 0.0)
         return 0.0;

      double efficiency =
         netDisplacement /
         pathLength;

      if(efficiency > 1.0)
         efficiency = 1.0;

      if(efficiency < -1.0)
         efficiency = -1.0;

      return efficiency;
   }

   //==============================================================
   // Open independent virtual position
   //==============================================================
   void OpenPosition(
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market)
   {
      ResetPosition();

      m_position.Active =
         true;

      m_position.Symbol =
         request.Symbol;

      m_position.Direction =
         request.Direction;

      m_position.EntryPrice =
         request.EntryPrice;

      m_position.StopLoss =
         request.StopLoss;

      m_position.StopDistance =
         request.StopDistance;

      m_position.Timeframe =
         market.Timeframe;

      m_position.LastObservedBarTime =
         iTime(
            request.Symbol,
            market.Timeframe,
            0
         );

      m_position.ActualBarsElapsed =
         0;

      m_position.HitPos050 =
         false;

      double targetDistance =
         request.StopDistance *
         m_targetR;

      if(request.Direction ==
         AQF_SIGNAL_BUY)
      {
         m_position.TakeProfit =
            request.EntryPrice +
            targetDistance;
      }
      else
      {
         m_position.TakeProfit =
            request.EntryPrice -
            targetDistance;
      }
   }

   //==============================================================
   // Actual observed-candle counter
   //==============================================================
   void UpdateActualBarCounter()
   {
      datetime currentBarTime =
         iTime(
            m_position.Symbol,
            m_position.Timeframe,
            0
         );

      if(currentBarTime <= 0)
         return;

      if(m_position.LastObservedBarTime <= 0)
      {
         m_position.LastObservedBarTime =
            currentBarTime;

         return;
      }

      if(currentBarTime !=
         m_position.LastObservedBarTime)
      {
         m_position.ActualBarsElapsed++;

         m_position.LastObservedBarTime =
            currentBarTime;
      }
   }

   //==============================================================
   // Current executable R
   //==============================================================
   double CurrentR(
      const double executablePrice)
   {
      if(m_position.StopDistance <= 0.0)
         return 0.0;

      if(m_position.Direction ==
         AQF_SIGNAL_BUY)
      {
         return
            (
               executablePrice -
               m_position.EntryPrice
            )
            /
            m_position.StopDistance;
      }

      return
         (
            m_position.EntryPrice -
            executablePrice
         )
         /
         m_position.StopDistance;
   }

   //==============================================================
   // Resolve independent virtual position
   //==============================================================
   void Resolve(
      const double resultR,
      const string exitType,
      const double executablePrice,
      CAQFLogger &logger)
   {
      m_resolved++;

      m_totalActualBars +=
         (double)m_position.ActualBarsElapsed;

      if(resultR > 0.0000001)
      {
         m_profitable++;

         m_grossProfitR +=
            resultR;

         m_currentLosingStreak =
            0;
      }
      else if(resultR < -0.0000001)
      {
         m_losing++;

         m_grossLossR +=
            -resultR;

         m_currentLosingStreak++;

         if(m_currentLosingStreak >
            m_maxLosingStreak)
         {
            m_maxLosingStreak =
               m_currentLosingStreak;
         }
      }
      else
      {
         m_flat++;

         m_currentLosingStreak =
            0;
      }

      m_cumulativeR +=
         resultR;

      if(m_cumulativeR >
         m_peakR)
      {
         m_peakR =
            m_cumulativeR;
      }

      double currentDrawdown =
         m_peakR -
         m_cumulativeR;

      if(currentDrawdown >
         m_maxDrawdownR)
      {
         m_maxDrawdownR =
            currentDrawdown;
      }

      logger.Debug(
         "Stalled10Close" +
         " | Policy=H3_PLUS_D1_STALLED10" +
         " | " +
         m_position.Symbol +
         " | ExitType=" +
         exitType +
         " | ResultR=" +
         DoubleToString(
            resultR,
            3) +
         "R" +
         " | CumR=" +
         DoubleToString(
            m_cumulativeR,
            3) +
         "R" +
         " | ActualBars=" +
         IntegerToString(
            m_position.ActualBarsElapsed) +
         " | Hit+0.50BeforeTrigger=" +
         (
            m_position.HitPos050
            ? "YES"
            : "NO"
         ) +
         " | ExecutablePrice=" +
         DoubleToString(
            executablePrice,
            (int)SymbolInfoInteger(
               m_position.Symbol,
               SYMBOL_DIGITS))
      );

      ResetPosition();
   }

   //==============================================================
   // Profit factor
   //==============================================================
   string ProfitFactorText()
   {
      if(m_grossLossR <= 0.0)
      {
         if(m_grossProfitR > 0.0)
            return "INF";

         return "0.000";
      }

      return
         DoubleToString(
            m_grossProfitR /
            m_grossLossR,
            3
         );
   }

   //==============================================================
   // Reset position
   //==============================================================
   void ResetPosition()
   {
      m_position.Active =
         false;

      m_position.Symbol =
         "";

      m_position.Direction =
         AQF_SIGNAL_NONE;

      m_position.EntryPrice =
         0.0;

      m_position.StopLoss =
         0.0;

      m_position.StopDistance =
         0.0;

      m_position.TakeProfit =
         0.0;

      m_position.Timeframe =
         PERIOD_CURRENT;

      m_position.LastObservedBarTime =
         0;

      m_position.ActualBarsElapsed =
         0;

      m_position.HitPos050 =
         false;
   }

   //==============================================================
   // Reset statistics
   //==============================================================
   void ResetStatistics()
   {
      m_signalsSeen =
         0;

      m_h2Rejected =
         0;

      m_featureFailures =
         0;

      m_c1Rejected =
         0;

      m_c3Rejected =
         0;

      m_eligible =
         0;

      m_opened =
         0;

      m_skippedActive =
         0;

      m_resolved =
         0;

      m_tpHits =
         0;

      m_slHits =
         0;

      m_stalledExits =
         0;

      m_profitable =
         0;

      m_losing =
         0;

      m_flat =
         0;

      m_stalledPositive =
         0;

      m_stalledNegative =
         0;

      m_stalledFlat =
         0;

      m_stalledExitCumR =
         0.0;

      m_stalledExitBars =
         0.0;

      m_cumulativeR =
         0.0;

      m_grossProfitR =
         0.0;

      m_grossLossR =
         0.0;

      m_peakR =
         0.0;

      m_maxDrawdownR =
         0.0;

      m_currentLosingStreak =
         0;

      m_maxLosingStreak =
         0;

      m_totalActualBars =
         0.0;
   }
};

#endif
