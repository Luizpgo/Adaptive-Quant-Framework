#ifndef __AQF_H3_CANDIDATE_SIMULATOR_MQH__
#define __AQF_H3_CANDIDATE_SIMULATOR_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"

//+------------------------------------------------------------------+
//| H3 Candidate Sequential Simulator                                |
//|                                                                  |
//| Sprint 9 - Package C                                             |
//|                                                                  |
//| Purpose                                                          |
//| - Simulate the FROZEN H3 candidate as an INDEPENDENT policy.     |
//| - Use its own one-position-at-a-time virtual account.            |
//| - Prevent subset/gating bias from the observational H2 reports.  |
//|                                                                  |
//| FROZEN H3                                                        |
//|   Base H2:                                                       |
//|     ATRPercent >= 0.075                                          |
//|     ADX >= 25 and ADX < 40                                      |
//|   C1: DirectionalER10 >= 0.50                                   |
//|   C3: VolumeZScore20 >= 0.25 and < 1.00                         |
//|   TP = 1.50R                                                     |
//|                                                                  |
//| Research features use COMPLETED candles only:                    |
//|   CopyRates shift 1..21                                         |
//|   VolZ20 compares shift 1 against shifts 2..21                  |
//|   DirER10 uses closes from shifts 1..11                          |
//|                                                                  |
//| IMPORTANT                                                        |
//| - Virtual simulation only.                                      |
//| - NO OrderSend.                                                  |
//| - NO real position management.                                  |
//| - H3 has ONE independent active virtual position at a time.     |
//+------------------------------------------------------------------+

struct SAQFH3Position
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

   double RelativeVolume20;
   double VolumeZScore20;
   double DirectionalER10;
};

class CAQFH3CandidateSimulator
{
private:

   SAQFH3Position m_position;

   //---------------------------------------------------------------
   // Frozen H3 parameters
   //---------------------------------------------------------------

   double m_targetR;

   double m_minATRPercent;
   double m_minADX;
   double m_maxADX;

   double m_minDirectionalER10;

   double m_minVolumeZ20;
   double m_maxVolumeZ20;

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
   // Resolved trade statistics
   //---------------------------------------------------------------

   long m_wins;
   long m_losses;

   double m_totalBars;

   double m_sumRelVol20;
   double m_sumVolZ20;
   double m_sumDirER10;

   //---------------------------------------------------------------
   // R equity curve
   //---------------------------------------------------------------

   double m_cumulativeR;
   double m_peakR;
   double m_maxDrawdownR;

   //---------------------------------------------------------------
   // Losing streak
   //---------------------------------------------------------------

   long m_currentLosingStreak;
   long m_maxLosingStreak;

   bool m_initialized;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFH3CandidateSimulator()
   {
      m_targetR =
         1.50;

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
         "H3CandidateSimulator initialized."
      );

      logger.Info(
         "H3 FROZEN BEFORE 2024 VALIDATION | Base=H2 ATRPercent>=0.075 ADX>=25 ADX<40 | C1 DirER10>=0.50 | C3 VolZ20>=0.25 VolZ20<1.00 | TP=1.50R"
      );

      logger.Info(
         "H3 sequential model: ONE ACTIVE VIRTUAL POSITION INDEPENDENT OF H2 - FILTERED SIGNALS DO NOT BLOCK LATER H3 OPPORTUNITIES"
      );

      logger.Info(
         "H3 research features use COMPLETED candles only: VolZ20 shift1 vs shifts2..21 | DirER10 shifts1..11"
      );

      logger.Info(
         "H3CandidateSimulator is VIRTUAL ONLY - NO ORDER EXECUTION"
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
      // Capture H3 research features from COMPLETED bars only
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
      // C1 - strong 10-bar directional efficiency
      //------------------------------------------------------------

      if(directionalER10 <
         m_minDirectionalER10)
      {
         m_c1Rejected++;
         return true;
      }

      //------------------------------------------------------------
      // C3 - moderately abnormal volume
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
      // Independent sequential-position gate.
      //
      // IMPORTANT:
      // This is why H3 must be simulated independently instead of
      // treating C1_AND_C3 merely as a subset of H2-opened trades.
      //------------------------------------------------------------

      if(m_position.Active)
      {
         m_skippedActive++;
         return true;
      }

      OpenPosition(
         request,
         market,
         relativeVolume20,
         volumeZScore20,
         directionalER10
      );

      m_opened++;

      logger.Debug(
         "H3Open" +
         " | Policy=H3_H2_C1_C3" +
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
               SYMBOL_DIGITS)) +
         " | ATR%=" +
         DoubleToString(
            market.ATRPercent,
            4) +
         " | ADX=" +
         DoubleToString(
            market.ADX,
            2) +
         " | RelVol20=" +
         DoubleToString(
            relativeVolume20,
            3) +
         " | VolZ20=" +
         DoubleToString(
            volumeZScore20,
            3) +
         " | DirER10=" +
         DoubleToString(
            directionalER10,
            3)
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

      double crossingPrice =
         0.0;

      bool targetReached =
         false;

      bool stopReached =
         false;

      //------------------------------------------------------------
      // BUY exits at Bid.
      // SELL exits at Ask.
      //------------------------------------------------------------

      if(m_position.Direction ==
         AQF_SIGNAL_BUY)
      {
         crossingPrice =
            market.Bid;

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
         crossingPrice =
            market.Ask;

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

      int barsElapsed =
         CalculateBarsElapsed(
            market.Time
         );

      //------------------------------------------------------------
      // Same event ordering as CandidatePolicySimulator / H2.
      //------------------------------------------------------------

      if(targetReached)
      {
         Resolve(
            true,
            crossingPrice,
            barsElapsed,
            logger
         );

         return;
      }

      if(stopReached)
      {
         Resolve(
            false,
            crossingPrice,
            barsElapsed,
            logger
         );

         return;
      }
   }

   //==============================================================
   // Final Report
   //==============================================================
   void ReportAll(
      CAQFLogger &logger)
   {
      long resolved =
         m_wins +
         m_losses;

      double winRate =
         0.0;

      double expectancyR =
         0.0;

      double avgBars =
         0.0;

      double avgRelVol20 =
         0.0;

      double avgVolZ20 =
         0.0;

      double avgDirER10 =
         0.0;

      if(resolved > 0)
      {
         winRate =
            (
               (double)m_wins /
               (double)resolved
            ) *
            100.0;

         expectancyR =
            m_cumulativeR /
            (double)resolved;

         avgBars =
            m_totalBars /
            (double)resolved;

         avgRelVol20 =
            m_sumRelVol20 /
            (double)resolved;

         avgVolZ20 =
            m_sumVolZ20 /
            (double)resolved;

         avgDirER10 =
            m_sumDirER10 /
            (double)resolved;
      }

      long totalRejected =
         m_h2Rejected +
         m_featureFailures +
         m_c1Rejected +
         m_c3Rejected;

      logger.Info(
         "H3PolicyStats" +
         " | Policy=H3_H2_DIRER10_GE_0.50_VOLZ20_0.25_TO_LT_1.00" +
         " | TP=" +
         DoubleToString(
            m_targetR,
            2) +
         "R" +
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
            (int)resolved) +
         " | Wins=" +
         IntegerToString(
            (int)m_wins) +
         " | Losses=" +
         IntegerToString(
            (int)m_losses) +
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
         " | ProfitFactor=" +
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
         " | AvgRelVol20=" +
         DoubleToString(
            avgRelVol20,
            3) +
         " | AvgVolZ20=" +
         DoubleToString(
            avgVolZ20,
            3) +
         " | AvgDirER10=" +
         DoubleToString(
            avgDirER10,
            3) +
         " | AvgBars=" +
         DoubleToString(
            avgBars,
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
   // Capture research features
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

      //------------------------------------------------------------
      // Volume of shift 1 versus baseline shifts 2..21
      //------------------------------------------------------------

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
   // Open virtual position
   //==============================================================
   void OpenPosition(
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market,
      const double relativeVolume20,
      const double volumeZScore20,
      const double directionalER10)
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

      m_position.EntryTime =
         request.SignalTime;

      m_position.Timeframe =
         market.Timeframe;

      m_position.RelativeVolume20 =
         relativeVolume20;

      m_position.VolumeZScore20 =
         volumeZScore20;

      m_position.DirectionalER10 =
         directionalER10;

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
   // Resolve virtual position
   //==============================================================
   void Resolve(
      const bool win,
      const double crossingPrice,
      const int barsElapsed,
      CAQFLogger &logger)
   {
      double resultR =
         -1.0;

      if(win)
      {
         m_wins++;

         resultR =
            m_targetR;

         m_currentLosingStreak =
            0;
      }
      else
      {
         m_losses++;

         m_currentLosingStreak++;

         if(m_currentLosingStreak >
            m_maxLosingStreak)
         {
            m_maxLosingStreak =
               m_currentLosingStreak;
         }
      }

      m_totalBars +=
         (double)barsElapsed;

      m_sumRelVol20 +=
         m_position.RelativeVolume20;

      m_sumVolZ20 +=
         m_position.VolumeZScore20;

      m_sumDirER10 +=
         m_position.DirectionalER10;

      //------------------------------------------------------------
      // R equity curve
      //------------------------------------------------------------

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
         "H3Close" +
         " | Policy=H3_H2_C1_C3" +
         " | " +
         m_position.Symbol +
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
            m_cumulativeR,
            2) +
         "R" +
         " | Bars=" +
         IntegerToString(
            barsElapsed) +
         " | CrossingPrice=" +
         DoubleToString(
            crossingPrice,
            (int)SymbolInfoInteger(
               m_position.Symbol,
               SYMBOL_DIGITS))
      );

      ResetPosition();
   }

   //==============================================================
   // Bars elapsed
   //==============================================================
   int CalculateBarsElapsed(
      const datetime currentTime)
   {
      int secondsPerBar =
         PeriodSeconds(
            m_position.Timeframe
         );

      if(secondsPerBar <= 0)
         return 0;

      long secondsElapsed =
         (long)(
            currentTime -
            m_position.EntryTime
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
   // Profit factor
   //==============================================================
   string ProfitFactorText()
   {
      double grossProfitR =
         (double)m_wins *
         m_targetR;

      double grossLossR =
         (double)m_losses;

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

      m_position.EntryTime =
         0;

      m_position.Timeframe =
         PERIOD_CURRENT;

      m_position.RelativeVolume20 =
         0.0;

      m_position.VolumeZScore20 =
         0.0;

      m_position.DirectionalER10 =
         0.0;
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

      m_wins =
         0;

      m_losses =
         0;

      m_totalBars =
         0.0;

      m_sumRelVol20 =
         0.0;

      m_sumVolZ20 =
         0.0;

      m_sumDirER10 =
         0.0;

      m_cumulativeR =
         0.0;

      m_peakR =
         0.0;

      m_maxDrawdownR =
         0.0;

      m_currentLosingStreak =
         0;

      m_maxLosingStreak =
         0;
   }
};

#endif
