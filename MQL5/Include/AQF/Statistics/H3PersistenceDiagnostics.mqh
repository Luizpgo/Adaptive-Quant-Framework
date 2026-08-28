#ifndef __AQF_H3_PERSISTENCE_DIAGNOSTICS_MQH__
#define __AQF_H3_PERSISTENCE_DIAGNOSTICS_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"

//+------------------------------------------------------------------+
//| H3 Trade Persistence & Failure Dynamics Diagnostics              |
//|                                                                  |
//| Sprint 10 - Package A1                                           |
//|                                                                  |
//| Purpose                                                          |
//| - Re-simulate the FROZEN H3 policy independently.                |
//| - Verify exact synchronization with H3CandidateSimulator.         |
//| - Observe POST-ENTRY path dynamics without changing entries,      |
//|   stops, targets, risk, or execution.                             |
//|                                                                  |
//| FROZEN H3                                                        |
//|   Base H2: ATRPercent >= 0.075, ADX >= 25, ADX < 40              |
//|   C1: DirER10 >= 0.50                                            |
//|   C3: VolZ20 >= 0.25 and < 1.00                                  |
//|   TP = 1.50R, SL = 1.00R                                        |
//|                                                                  |
//| Diagnostics                                                      |
//| - MFE / MAE                                                      |
//| - time to first +0.50R in ACTUAL observed candles              |
//| - first passage: +0.50R versus -0.50R                            |
//| - milestone excursion frequencies                               |
//| - checkpoints at 5 / 10 / 20 ACTUAL candles for survivors      |
//|   using COMPLETED candles only for DirER10 / VolZ20              |
//|                                                                  |
//| IMPORTANT                                                        |
//| - OBSERVATIONAL ONLY.                                            |
//| - Post-entry variables MUST NOT be interpreted as entry filters.  |
//| - NO OrderSend.                                                   |
//| - NO real position management.                                   |
//| - H3CandidateSimulator.mqh remains unchanged/frozen.              |
//+------------------------------------------------------------------+

struct SAQFPersistencePosition
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

   // Sprint 10A1: actual observed-candle counter.
   datetime LastObservedBarTime;
   int ActualBarsElapsed;

   double EntryRelativeVolume20;
   double EntryVolumeZScore20;
   double EntryDirectionalER10;

   double MFE;
   double MAE;

   bool HitPos025;
   bool HitPos050;
   bool HitPos075;
   bool HitPos100;

   bool HitNeg025;
   bool HitNeg050;
   bool HitNeg075;

   int BarsToPos050;

   // 0 = NONE / NEITHER
   // 1 = +0.50R reached first
   // 2 = -0.50R reached first
   int FirstHalfEvent;

   bool Checkpoint5Captured;
   bool Checkpoint10Captured;
   bool Checkpoint20Captured;

   double Checkpoint5CurrentR;
   double Checkpoint5MFE;
   double Checkpoint5MAE;
   double Checkpoint5DirER10;
   double Checkpoint5ERDelta;
   double Checkpoint5VolZ20;

   double Checkpoint10CurrentR;
   double Checkpoint10MFE;
   double Checkpoint10MAE;
   double Checkpoint10DirER10;
   double Checkpoint10ERDelta;
   double Checkpoint10VolZ20;

   double Checkpoint20CurrentR;
   double Checkpoint20MFE;
   double Checkpoint20MAE;
   double Checkpoint20DirER10;
   double Checkpoint20ERDelta;
   double Checkpoint20VolZ20;
};

struct SAQFPersistenceStats
{
   long Trades;
   long Wins;
   long Losses;

   double CumR;
   double TotalBars;
};

struct SAQFPersistenceCheckpointStats
{
   long Trades;
   long Wins;
   long Losses;

   double CumR;

   double SumCurrentR;
   double SumMFE;
   double SumMAE;

   double SumDirER10;
   double SumERDelta;
   double SumVolZ20;
};

class CAQFH3PersistenceDiagnostics
{
private:

   SAQFPersistencePosition m_position;

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
   // Synchronization counters
   //---------------------------------------------------------------

   long m_signalsSeen;

   long m_h2Rejected;
   long m_featureFailures;
   long m_c1Rejected;
   long m_c3Rejected;

   long m_eligible;
   long m_opened;
   long m_skippedActive;

   long m_wins;
   long m_losses;

   double m_cumulativeR;

   //---------------------------------------------------------------
   // Overall persistence metrics
   //---------------------------------------------------------------

   double m_totalBars;
   double m_winBars;
   double m_lossBars;

   double m_sumMFE;
   double m_sumMAE;

   double m_sumWinMFE;
   double m_sumWinMAE;

   double m_sumLossMFE;
   double m_sumLossMAE;

   //---------------------------------------------------------------
   // Milestone diagnostics
   //---------------------------------------------------------------

   long m_hitPos025;
   long m_hitPos050;
   long m_hitPos075;
   long m_hitPos100;

   long m_lossHitPos025;
   long m_lossHitPos050;
   long m_lossHitPos075;
   long m_lossHitPos100;

   long m_winHitNeg025;
   long m_winHitNeg050;
   long m_winHitNeg075;

   long m_pos050HitCount;
   double m_totalBarsToPos050;

   //---------------------------------------------------------------
   // Outcome buckets
   //---------------------------------------------------------------

   // Time to first +0.50R:
   // 0 = 0-5 bars
   // 1 = 6-10 bars
   // 2 = 11-20 bars
   // 3 = 21+ bars
   // 4 = NEVER
   SAQFPersistenceStats m_timeToPos050[5];

   // First half-R event:
   // 0 = POS_FIRST
   // 1 = NEG_FIRST
   // 2 = NEITHER
   SAQFPersistenceStats m_firstHalfEvent[3];

   //---------------------------------------------------------------
   // Surviving-trade checkpoints
   //---------------------------------------------------------------

   SAQFPersistenceCheckpointStats m_checkpoint5;
   SAQFPersistenceCheckpointStats m_checkpoint10;
   SAQFPersistenceCheckpointStats m_checkpoint20;

   bool m_initialized;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFH3PersistenceDiagnostics()
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
         "H3PersistenceDiagnostics initialized."
      );

      logger.Info(
         "Sprint 10A OBSERVATIONAL ONLY | FROZEN H3 unchanged | Base H2 ATR%>=0.075 ADX>=25 ADX<40 | DirER10>=0.50 | VolZ20>=0.25 VolZ20<1.00 | TP=1.50R"
      );

      logger.Info(
         "Persistence diagnostics A1: MFE/MAE | first +0.50R timing | +/-0.50R first passage | 5/10/20 ACTUAL-candle surviving-trade checkpoints"
      );

      logger.Info(
         "Checkpoint DirER10/VolZ20 use COMPLETED candles only. Post-entry data are NOT entry filters."
      );

      logger.Info(
         "Sprint 10A1 bar counter FIXED: bars are counted from observed timeframe candle changes, NOT wall-clock seconds / PeriodSeconds."
      );

      logger.Info(
         "H3PersistenceDiagnostics is VIRTUAL ONLY - NO ORDER EXECUTION"
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
      // Exact frozen H3 base filter
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

      double relativeVolume20 =
         0.0;

      double volumeZScore20 =
         0.0;

      double directionalER10 =
         0.0;

      if(!CaptureResearchFeatures(
            request.Symbol,
            market.Timeframe,
            request.Direction,
            relativeVolume20,
            volumeZScore20,
            directionalER10))
      {
         m_featureFailures++;
         return true;
      }

      if(directionalER10 <
         m_minDirectionalER10)
      {
         m_c1Rejected++;
         return true;
      }

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
         "PersistenceOpen" +
         " | Policy=H3_H2_C1_C3" +
         " | " +
         request.Symbol +
         " | DirER10=" +
         DoubleToString(
            directionalER10,
            3) +
         " | VolZ20=" +
         DoubleToString(
            volumeZScore20,
            3)
      );

      return true;
   }

   //==============================================================
   // Tick-by-tick post-entry observation
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
         market.Symbol != m_position.Symbol)
      {
         return;
      }

      UpdateActualBarCounter();

      double exitPrice =
         (
            m_position.Direction ==
            AQF_SIGNAL_BUY
         )
         ? market.Bid
         : market.Ask;

      double currentR =
         CurrentR(
            exitPrice
         );

      if(currentR >
         m_position.MFE)
      {
         m_position.MFE =
            currentR;
      }

      if(currentR < 0.0)
      {
         double adverseR =
            -currentR;

         if(adverseR >
            m_position.MAE)
         {
            m_position.MAE =
               adverseR;
         }
      }

      int barsElapsed =
         m_position.ActualBarsElapsed;

      UpdateMilestones(
         currentR,
         barsElapsed
      );

      CaptureCheckpointIfNeeded(
         5,
         barsElapsed
      );

      CaptureCheckpointIfNeeded(
         10,
         barsElapsed
      );

      CaptureCheckpointIfNeeded(
         20,
         barsElapsed
      );

      bool targetReached =
         false;

      bool stopReached =
         false;

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
         Resolve(
            true,
            barsElapsed,
            logger
         );

         return;
      }

      if(stopReached)
      {
         Resolve(
            false,
            barsElapsed,
            logger
         );

         return;
      }
   }

   //==============================================================
   // Final report
   //==============================================================
   void ReportAll(
      CAQFLogger &logger)
   {
      long resolved =
         m_wins +
         m_losses;

      double winRate =
         Percent(
            m_wins,
            resolved
         );

      double expectancy =
         0.0;

      double avgBars =
         0.0;

      double avgWinBars =
         0.0;

      double avgLossBars =
         0.0;

      double avgMFE =
         0.0;

      double avgMAE =
         0.0;

      double avgWinMFE =
         0.0;

      double avgWinMAE =
         0.0;

      double avgLossMFE =
         0.0;

      double avgLossMAE =
         0.0;

      if(resolved > 0)
      {
         expectancy =
            m_cumulativeR /
            (double)resolved;

         avgBars =
            m_totalBars /
            (double)resolved;

         avgMFE =
            m_sumMFE /
            (double)resolved;

         avgMAE =
            m_sumMAE /
            (double)resolved;
      }

      if(m_wins > 0)
      {
         avgWinBars =
            m_winBars /
            (double)m_wins;

         avgWinMFE =
            m_sumWinMFE /
            (double)m_wins;

         avgWinMAE =
            m_sumWinMAE /
            (double)m_wins;
      }

      if(m_losses > 0)
      {
         avgLossBars =
            m_lossBars /
            (double)m_losses;

         avgLossMFE =
            m_sumLossMFE /
            (double)m_losses;

         avgLossMAE =
            m_sumLossMAE /
            (double)m_losses;
      }

      logger.Info(
         "PersistenceSync" +
         " | Policy=H3_H2_DIRER10_GE_0.50_VOLZ20_0.25_TO_LT_1.00" +
         " | Signals=" +
         IntegerToString(
            (int)m_signalsSeen) +
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
            expectancy,
            3) +
         "R" +
         " | PF=" +
         ProfitFactorText(
            m_wins,
            m_losses) +
         " | CumR=" +
         DoubleToString(
            m_cumulativeR,
            2) +
         "R"
      );

      logger.Info(
         "PersistenceSummary" +
         " | Trades=" +
         IntegerToString(
            (int)resolved) +
         " | AvgActualBars=" +
         DoubleToString(
            avgBars,
            1) +
         " | AvgWinActualBars=" +
         DoubleToString(
            avgWinBars,
            1) +
         " | AvgLossActualBars=" +
         DoubleToString(
            avgLossBars,
            1) +
         " | AvgMFE=" +
         DoubleToString(
            avgMFE,
            3) +
         "R" +
         " | AvgMAE=" +
         DoubleToString(
            avgMAE,
            3) +
         "R" +
         " | WinMFE=" +
         DoubleToString(
            avgWinMFE,
            3) +
         "R" +
         " | WinMAE=" +
         DoubleToString(
            avgWinMAE,
            3) +
         "R" +
         " | LossMFE=" +
         DoubleToString(
            avgLossMFE,
            3) +
         "R" +
         " | LossMAE=" +
         DoubleToString(
            avgLossMAE,
            3) +
         "R"
      );

      double avgBarsToPos050 =
         0.0;

      if(m_pos050HitCount > 0)
      {
         avgBarsToPos050 =
            m_totalBarsToPos050 /
            (double)m_pos050HitCount;
      }

      logger.Info(
         "PersistenceMilestones" +
         " | Hit+0.25=" +
         IntegerToString(
            (int)m_hitPos025) +
         "/" +
         IntegerToString(
            (int)resolved) +
         " (" +
         DoubleToString(
            Percent(
               m_hitPos025,
               resolved),
            1) +
         "%)" +
         " | Hit+0.50=" +
         IntegerToString(
            (int)m_hitPos050) +
         "/" +
         IntegerToString(
            (int)resolved) +
         " (" +
         DoubleToString(
            Percent(
               m_hitPos050,
               resolved),
            1) +
         "%)" +
         " | Hit+0.75=" +
         IntegerToString(
            (int)m_hitPos075) +
         "/" +
         IntegerToString(
            (int)resolved) +
         " (" +
         DoubleToString(
            Percent(
               m_hitPos075,
               resolved),
            1) +
         "%)" +
         " | Hit+1.00=" +
         IntegerToString(
            (int)m_hitPos100) +
         "/" +
         IntegerToString(
            (int)resolved) +
         " (" +
         DoubleToString(
            Percent(
               m_hitPos100,
               resolved),
            1) +
         "%)" +
         " | AvgActualBarsTo+0.50=" +
         DoubleToString(
            avgBarsToPos050,
            1)
      );

      logger.Info(
         "PersistenceFailurePath" +
         " | Losses=" +
         IntegerToString(
            (int)m_losses) +
         " | LossHit+0.25=" +
         IntegerToString(
            (int)m_lossHitPos025) +
         " (" +
         DoubleToString(
            Percent(
               m_lossHitPos025,
               m_losses),
            1) +
         "%)" +
         " | LossHit+0.50=" +
         IntegerToString(
            (int)m_lossHitPos050) +
         " (" +
         DoubleToString(
            Percent(
               m_lossHitPos050,
               m_losses),
            1) +
         "%)" +
         " | LossHit+0.75=" +
         IntegerToString(
            (int)m_lossHitPos075) +
         " (" +
         DoubleToString(
            Percent(
               m_lossHitPos075,
               m_losses),
            1) +
         "%)" +
         " | LossHit+1.00=" +
         IntegerToString(
            (int)m_lossHitPos100) +
         " (" +
         DoubleToString(
            Percent(
               m_lossHitPos100,
               m_losses),
            1) +
         "%)"
      );

      logger.Info(
         "PersistenceWinnerAdversePath" +
         " | Wins=" +
         IntegerToString(
            (int)m_wins) +
         " | WinHit-0.25=" +
         IntegerToString(
            (int)m_winHitNeg025) +
         " (" +
         DoubleToString(
            Percent(
               m_winHitNeg025,
               m_wins),
            1) +
         "%)" +
         " | WinHit-0.50=" +
         IntegerToString(
            (int)m_winHitNeg050) +
         " (" +
         DoubleToString(
            Percent(
               m_winHitNeg050,
               m_wins),
            1) +
         "%)" +
         " | WinHit-0.75=" +
         IntegerToString(
            (int)m_winHitNeg075) +
         " (" +
         DoubleToString(
            Percent(
               m_winHitNeg075,
               m_wins),
            1) +
         "%)"
      );

      ReportPersistenceStats(
         "TimeTo+0.50R",
         "0-5",
         m_timeToPos050[0],
         logger
      );

      ReportPersistenceStats(
         "TimeTo+0.50R",
         "6-10",
         m_timeToPos050[1],
         logger
      );

      ReportPersistenceStats(
         "TimeTo+0.50R",
         "11-20",
         m_timeToPos050[2],
         logger
      );

      ReportPersistenceStats(
         "TimeTo+0.50R",
         "21+",
         m_timeToPos050[3],
         logger
      );

      ReportPersistenceStats(
         "TimeTo+0.50R",
         "NEVER",
         m_timeToPos050[4],
         logger
      );

      ReportPersistenceStats(
         "FirstHalfR",
         "POS_FIRST",
         m_firstHalfEvent[0],
         logger
      );

      ReportPersistenceStats(
         "FirstHalfR",
         "NEG_FIRST",
         m_firstHalfEvent[1],
         logger
      );

      ReportPersistenceStats(
         "FirstHalfR",
         "NEITHER",
         m_firstHalfEvent[2],
         logger
      );

      ReportCheckpoint(
         5,
         m_checkpoint5,
         logger
      );

      ReportCheckpoint(
         10,
         m_checkpoint10,
         logger
      );

      ReportCheckpoint(
         20,
         m_checkpoint20,
         logger
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
   // Exact H3 entry research features from completed bars
   //==============================================================
   bool CaptureResearchFeatures(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe,
      const ENUM_AQF_SIGNAL_DIRECTION direction,
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
            symbol,
            timeframe,
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
            direction,
            rates,
            10
         );

      return true;
   }

   //==============================================================
   // Signed directional efficiency
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
   // Open diagnostics position
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

      m_position.LastObservedBarTime =
         iTime(
            request.Symbol,
            market.Timeframe,
            0
         );

      m_position.ActualBarsElapsed =
         0;

      m_position.EntryRelativeVolume20 =
         relativeVolume20;

      m_position.EntryVolumeZScore20 =
         volumeZScore20;

      m_position.EntryDirectionalER10 =
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
   // Current R using executable-side price
   //==============================================================
   double CurrentR(
      const double exitPrice)
   {
      if(m_position.StopDistance <= 0.0)
         return 0.0;

      if(m_position.Direction ==
         AQF_SIGNAL_BUY)
      {
         return
            (
               exitPrice -
               m_position.EntryPrice
            )
            /
            m_position.StopDistance;
      }

      return
         (
            m_position.EntryPrice -
            exitPrice
         )
         /
         m_position.StopDistance;
   }

   //==============================================================
   // Update post-entry milestones
   //==============================================================
   void UpdateMilestones(
      const double currentR,
      const int barsElapsed)
   {
      if(currentR >= 0.25)
         m_position.HitPos025 = true;

      if(currentR >= 0.50)
      {
         if(!m_position.HitPos050)
         {
            m_position.BarsToPos050 =
               barsElapsed;
         }

         m_position.HitPos050 =
            true;
      }

      if(currentR >= 0.75)
         m_position.HitPos075 = true;

      if(currentR >= 1.00)
         m_position.HitPos100 = true;

      if(currentR <= -0.25)
         m_position.HitNeg025 = true;

      if(currentR <= -0.50)
         m_position.HitNeg050 = true;

      if(currentR <= -0.75)
         m_position.HitNeg075 = true;

      if(m_position.FirstHalfEvent == 0)
      {
         if(currentR >= 0.50)
         {
            m_position.FirstHalfEvent =
               1;
         }
         else if(currentR <= -0.50)
         {
            m_position.FirstHalfEvent =
               2;
         }
      }
   }

   //==============================================================
   // Capture surviving-trade checkpoint
   //==============================================================
   void CaptureCheckpointIfNeeded(
      const int checkpointBars,
      const int barsElapsed)
   {
      if(barsElapsed <
         checkpointBars)
      {
         return;
      }

      if(
         checkpointBars == 5
         &&
         m_position.Checkpoint5Captured
      )
      {
         return;
      }

      if(
         checkpointBars == 10
         &&
         m_position.Checkpoint10Captured
      )
      {
         return;
      }

      if(
         checkpointBars == 20
         &&
         m_position.Checkpoint20Captured
      )
      {
         return;
      }

      double relativeVolume20 =
         0.0;

      double volumeZScore20 =
         0.0;

      double directionalER10 =
         0.0;

      if(!CaptureResearchFeatures(
            m_position.Symbol,
            m_position.Timeframe,
            m_position.Direction,
            relativeVolume20,
            volumeZScore20,
            directionalER10))
      {
         return;
      }

      double exitPrice =
         (
            m_position.Direction ==
            AQF_SIGNAL_BUY
         )
         ? SymbolInfoDouble(
              m_position.Symbol,
              SYMBOL_BID)
         : SymbolInfoDouble(
              m_position.Symbol,
              SYMBOL_ASK);

      if(exitPrice <= 0.0)
         return;

      double currentR =
         CurrentR(
            exitPrice
         );

      double erDelta =
         directionalER10 -
         m_position.EntryDirectionalER10;

      if(checkpointBars == 5)
      {
         m_position.Checkpoint5Captured =
            true;

         m_position.Checkpoint5CurrentR =
            currentR;

         m_position.Checkpoint5MFE =
            m_position.MFE;

         m_position.Checkpoint5MAE =
            m_position.MAE;

         m_position.Checkpoint5DirER10 =
            directionalER10;

         m_position.Checkpoint5ERDelta =
            erDelta;

         m_position.Checkpoint5VolZ20 =
            volumeZScore20;

         return;
      }

      if(checkpointBars == 10)
      {
         m_position.Checkpoint10Captured =
            true;

         m_position.Checkpoint10CurrentR =
            currentR;

         m_position.Checkpoint10MFE =
            m_position.MFE;

         m_position.Checkpoint10MAE =
            m_position.MAE;

         m_position.Checkpoint10DirER10 =
            directionalER10;

         m_position.Checkpoint10ERDelta =
            erDelta;

         m_position.Checkpoint10VolZ20 =
            volumeZScore20;

         return;
      }

      m_position.Checkpoint20Captured =
         true;

      m_position.Checkpoint20CurrentR =
         currentR;

      m_position.Checkpoint20MFE =
         m_position.MFE;

      m_position.Checkpoint20MAE =
         m_position.MAE;

      m_position.Checkpoint20DirER10 =
         directionalER10;

      m_position.Checkpoint20ERDelta =
         erDelta;

      m_position.Checkpoint20VolZ20 =
         volumeZScore20;
   }

   //==============================================================
   // Resolve
   //==============================================================
   void Resolve(
      const bool win,
      const int barsElapsed,
      CAQFLogger &logger)
   {
      double resultR =
         (
            win
            ? m_targetR
            : -1.0
         );

      if(win)
      {
         m_wins++;

         // Ensure target-crossing milestones are represented even
         // when one tick jumps across multiple levels.
         m_position.HitPos025 =
            true;

         m_position.HitPos050 =
            true;

         m_position.HitPos075 =
            true;

         m_position.HitPos100 =
            true;

         if(m_position.BarsToPos050 < 0)
         {
            m_position.BarsToPos050 =
               barsElapsed;
         }
      }
      else
      {
         m_losses++;
      }

      m_cumulativeR +=
         resultR;

      m_totalBars +=
         (double)barsElapsed;

      m_sumMFE +=
         m_position.MFE;

      m_sumMAE +=
         m_position.MAE;

      if(win)
      {
         m_winBars +=
            (double)barsElapsed;

         m_sumWinMFE +=
            m_position.MFE;

         m_sumWinMAE +=
            m_position.MAE;
      }
      else
      {
         m_lossBars +=
            (double)barsElapsed;

         m_sumLossMFE +=
            m_position.MFE;

         m_sumLossMAE +=
            m_position.MAE;
      }

      //------------------------------------------------------------
      // Milestone aggregates
      //------------------------------------------------------------

      if(m_position.HitPos025)
         m_hitPos025++;

      if(m_position.HitPos050)
      {
         m_hitPos050++;

         m_pos050HitCount++;

         m_totalBarsToPos050 +=
            (double)m_position.BarsToPos050;
      }

      if(m_position.HitPos075)
         m_hitPos075++;

      if(m_position.HitPos100)
         m_hitPos100++;

      if(!win)
      {
         if(m_position.HitPos025)
            m_lossHitPos025++;

         if(m_position.HitPos050)
            m_lossHitPos050++;

         if(m_position.HitPos075)
            m_lossHitPos075++;

         if(m_position.HitPos100)
            m_lossHitPos100++;
      }
      else
      {
         if(m_position.HitNeg025)
            m_winHitNeg025++;

         if(m_position.HitNeg050)
            m_winHitNeg050++;

         if(m_position.HitNeg075)
            m_winHitNeg075++;
      }

      //------------------------------------------------------------
      // Time-to-+0.50R bucket
      //------------------------------------------------------------

      int timeBucket =
         4;

      if(m_position.HitPos050)
      {
         if(m_position.BarsToPos050 <= 5)
            timeBucket = 0;
         else if(m_position.BarsToPos050 <= 10)
            timeBucket = 1;
         else if(m_position.BarsToPos050 <= 20)
            timeBucket = 2;
         else
            timeBucket = 3;
      }

      AddPersistenceStats(
         m_timeToPos050[timeBucket],
         win,
         resultR,
         barsElapsed
      );

      //------------------------------------------------------------
      // First +/-0.50R passage bucket
      //------------------------------------------------------------

      int firstHalfBucket =
         2;

      if(m_position.FirstHalfEvent == 1)
         firstHalfBucket = 0;
      else if(m_position.FirstHalfEvent == 2)
         firstHalfBucket = 1;

      AddPersistenceStats(
         m_firstHalfEvent[firstHalfBucket],
         win,
         resultR,
         barsElapsed
      );

      //------------------------------------------------------------
      // Checkpoint stats use final outcome, but checkpoint values
      // are only captured if the trade was still active then.
      //------------------------------------------------------------

      if(m_position.Checkpoint5Captured)
      {
         AddCheckpointStats(
            m_checkpoint5,
            win,
            resultR,
            m_position.Checkpoint5CurrentR,
            m_position.Checkpoint5MFE,
            m_position.Checkpoint5MAE,
            m_position.Checkpoint5DirER10,
            m_position.Checkpoint5ERDelta,
            m_position.Checkpoint5VolZ20
         );
      }

      if(m_position.Checkpoint10Captured)
      {
         AddCheckpointStats(
            m_checkpoint10,
            win,
            resultR,
            m_position.Checkpoint10CurrentR,
            m_position.Checkpoint10MFE,
            m_position.Checkpoint10MAE,
            m_position.Checkpoint10DirER10,
            m_position.Checkpoint10ERDelta,
            m_position.Checkpoint10VolZ20
         );
      }

      if(m_position.Checkpoint20Captured)
      {
         AddCheckpointStats(
            m_checkpoint20,
            win,
            resultR,
            m_position.Checkpoint20CurrentR,
            m_position.Checkpoint20MFE,
            m_position.Checkpoint20MAE,
            m_position.Checkpoint20DirER10,
            m_position.Checkpoint20ERDelta,
            m_position.Checkpoint20VolZ20
         );
      }

      logger.Debug(
         "PersistenceClose" +
         " | Policy=H3_H2_C1_C3" +
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
         " | MFE=" +
         DoubleToString(
            m_position.MFE,
            3) +
         "R" +
         " | MAE=" +
         DoubleToString(
            m_position.MAE,
            3) +
         "R" +
         " | Bars=" +
         IntegerToString(
            barsElapsed)
      );

      ResetPosition();
   }

   //==============================================================
   // Add simple outcome stats
   //==============================================================
   void AddPersistenceStats(
      SAQFPersistenceStats &stats,
      const bool win,
      const double resultR,
      const int barsElapsed)
   {
      stats.Trades++;

      if(win)
         stats.Wins++;
      else
         stats.Losses++;

      stats.CumR +=
         resultR;

      stats.TotalBars +=
         (double)barsElapsed;
   }

   //==============================================================
   // Add checkpoint stats
   //==============================================================
   void AddCheckpointStats(
      SAQFPersistenceCheckpointStats &stats,
      const bool win,
      const double resultR,
      const double currentR,
      const double mfe,
      const double mae,
      const double directionalER10,
      const double erDelta,
      const double volumeZ20)
   {
      stats.Trades++;

      if(win)
         stats.Wins++;
      else
         stats.Losses++;

      stats.CumR +=
         resultR;

      stats.SumCurrentR +=
         currentR;

      stats.SumMFE +=
         mfe;

      stats.SumMAE +=
         mae;

      stats.SumDirER10 +=
         directionalER10;

      stats.SumERDelta +=
         erDelta;

      stats.SumVolZ20 +=
         volumeZ20;
   }

   //==============================================================
   // Report simple outcome bucket
   //==============================================================
   void ReportPersistenceStats(
      const string dimension,
      const string bucket,
      const SAQFPersistenceStats &stats,
      CAQFLogger &logger)
   {
      double winRate =
         Percent(
            stats.Wins,
            stats.Trades
         );

      double expectancy =
         0.0;

      double avgBars =
         0.0;

      if(stats.Trades > 0)
      {
         expectancy =
            stats.CumR /
            (double)stats.Trades;

         avgBars =
            stats.TotalBars /
            (double)stats.Trades;
      }

      logger.Info(
         "PersistenceBucket" +
         " | Dimension=" +
         dimension +
         " | Bucket=" +
         bucket +
         " | Trades=" +
         IntegerToString(
            (int)stats.Trades) +
         " | Wins=" +
         IntegerToString(
            (int)stats.Wins) +
         " | Losses=" +
         IntegerToString(
            (int)stats.Losses) +
         " | WinRate=" +
         DoubleToString(
            winRate,
            2) +
         "%" +
         " | Expectancy=" +
         DoubleToString(
            expectancy,
            3) +
         "R" +
         " | PF=" +
         ProfitFactorText(
            stats.Wins,
            stats.Losses) +
         " | CumR=" +
         DoubleToString(
            stats.CumR,
            2) +
         "R" +
         " | AvgActualBars=" +
         DoubleToString(
            avgBars,
            1)
      );
   }

   //==============================================================
   // Report surviving-trade checkpoint
   //==============================================================
   void ReportCheckpoint(
      const int bars,
      const SAQFPersistenceCheckpointStats &stats,
      CAQFLogger &logger)
   {
      double winRate =
         Percent(
            stats.Wins,
            stats.Trades
         );

      double expectancy =
         0.0;

      double avgCurrentR =
         0.0;

      double avgMFE =
         0.0;

      double avgMAE =
         0.0;

      double avgDirER10 =
         0.0;

      double avgERDelta =
         0.0;

      double avgVolZ20 =
         0.0;

      if(stats.Trades > 0)
      {
         expectancy =
            stats.CumR /
            (double)stats.Trades;

         avgCurrentR =
            stats.SumCurrentR /
            (double)stats.Trades;

         avgMFE =
            stats.SumMFE /
            (double)stats.Trades;

         avgMAE =
            stats.SumMAE /
            (double)stats.Trades;

         avgDirER10 =
            stats.SumDirER10 /
            (double)stats.Trades;

         avgERDelta =
            stats.SumERDelta /
            (double)stats.Trades;

         avgVolZ20 =
            stats.SumVolZ20 /
            (double)stats.Trades;
      }

      logger.Info(
         "PersistenceCheckpoint" +
         " | ActualBars=" +
         IntegerToString(
            bars) +
         " | SurvivedN=" +
         IntegerToString(
            (int)stats.Trades) +
         " | Wins=" +
         IntegerToString(
            (int)stats.Wins) +
         " | Losses=" +
         IntegerToString(
            (int)stats.Losses) +
         " | FinalWinRate=" +
         DoubleToString(
            winRate,
            2) +
         "%" +
         " | FinalExpectancy=" +
         DoubleToString(
            expectancy,
            3) +
         "R" +
         " | AvgCurrentR=" +
         DoubleToString(
            avgCurrentR,
            3) +
         "R" +
         " | AvgMFE=" +
         DoubleToString(
            avgMFE,
            3) +
         "R" +
         " | AvgMAE=" +
         DoubleToString(
            avgMAE,
            3) +
         "R" +
         " | AvgDirER10=" +
         DoubleToString(
            avgDirER10,
            3) +
         " | AvgERDelta=" +
         DoubleToString(
            avgERDelta,
            3) +
         " | AvgVolZ20=" +
         DoubleToString(
            avgVolZ20,
            3)
      );
   }

   //==============================================================
   // Sprint 10A1 - actual observed candle counter
   //
   // In every-tick real-tick testing, increment exactly once when
   // the current timeframe candle changes. Weekend/session gaps do
   // not create phantom M1 bars.
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
   // Percent helper
   //==============================================================
   double Percent(
      const long numerator,
      const long denominator)
   {
      if(denominator <= 0)
         return 0.0;

      return
         (
            (double)numerator /
            (double)denominator
         )
         *
         100.0;
   }

   //==============================================================
   // PF helper, fixed H3 payoff
   //==============================================================
   string ProfitFactorText(
      const long wins,
      const long losses)
   {
      double grossProfitR =
         (double)wins *
         m_targetR;

      double grossLossR =
         (double)losses;

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

      m_position.LastObservedBarTime =
         0;

      m_position.ActualBarsElapsed =
         0;

      m_position.EntryRelativeVolume20 =
         0.0;

      m_position.EntryVolumeZScore20 =
         0.0;

      m_position.EntryDirectionalER10 =
         0.0;

      m_position.MFE =
         0.0;

      m_position.MAE =
         0.0;

      m_position.HitPos025 =
         false;

      m_position.HitPos050 =
         false;

      m_position.HitPos075 =
         false;

      m_position.HitPos100 =
         false;

      m_position.HitNeg025 =
         false;

      m_position.HitNeg050 =
         false;

      m_position.HitNeg075 =
         false;

      m_position.BarsToPos050 =
         -1;

      m_position.FirstHalfEvent =
         0;

      m_position.Checkpoint5Captured =
         false;

      m_position.Checkpoint10Captured =
         false;

      m_position.Checkpoint20Captured =
         false;

      m_position.Checkpoint5CurrentR =
         0.0;

      m_position.Checkpoint5MFE =
         0.0;

      m_position.Checkpoint5MAE =
         0.0;

      m_position.Checkpoint5DirER10 =
         0.0;

      m_position.Checkpoint5ERDelta =
         0.0;

      m_position.Checkpoint5VolZ20 =
         0.0;

      m_position.Checkpoint10CurrentR =
         0.0;

      m_position.Checkpoint10MFE =
         0.0;

      m_position.Checkpoint10MAE =
         0.0;

      m_position.Checkpoint10DirER10 =
         0.0;

      m_position.Checkpoint10ERDelta =
         0.0;

      m_position.Checkpoint10VolZ20 =
         0.0;

      m_position.Checkpoint20CurrentR =
         0.0;

      m_position.Checkpoint20MFE =
         0.0;

      m_position.Checkpoint20MAE =
         0.0;

      m_position.Checkpoint20DirER10 =
         0.0;

      m_position.Checkpoint20ERDelta =
         0.0;

      m_position.Checkpoint20VolZ20 =
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

      m_cumulativeR =
         0.0;

      m_totalBars =
         0.0;

      m_winBars =
         0.0;

      m_lossBars =
         0.0;

      m_sumMFE =
         0.0;

      m_sumMAE =
         0.0;

      m_sumWinMFE =
         0.0;

      m_sumWinMAE =
         0.0;

      m_sumLossMFE =
         0.0;

      m_sumLossMAE =
         0.0;

      m_hitPos025 =
         0;

      m_hitPos050 =
         0;

      m_hitPos075 =
         0;

      m_hitPos100 =
         0;

      m_lossHitPos025 =
         0;

      m_lossHitPos050 =
         0;

      m_lossHitPos075 =
         0;

      m_lossHitPos100 =
         0;

      m_winHitNeg025 =
         0;

      m_winHitNeg050 =
         0;

      m_winHitNeg075 =
         0;

      m_pos050HitCount =
         0;

      m_totalBarsToPos050 =
         0.0;

      for(int i = 0;
          i < 5;
          i++)
      {
         ResetPersistenceStats(
            m_timeToPos050[i]
         );
      }

      for(int i = 0;
          i < 3;
          i++)
      {
         ResetPersistenceStats(
            m_firstHalfEvent[i]
         );
      }

      ResetCheckpointStats(
         m_checkpoint5
      );

      ResetCheckpointStats(
         m_checkpoint10
      );

      ResetCheckpointStats(
         m_checkpoint20
      );
   }

   //==============================================================
   // Reset simple stats
   //==============================================================
   void ResetPersistenceStats(
      SAQFPersistenceStats &stats)
   {
      stats.Trades =
         0;

      stats.Wins =
         0;

      stats.Losses =
         0;

      stats.CumR =
         0.0;

      stats.TotalBars =
         0.0;
   }

   //==============================================================
   // Reset checkpoint stats
   //==============================================================
   void ResetCheckpointStats(
      SAQFPersistenceCheckpointStats &stats)
   {
      stats.Trades =
         0;

      stats.Wins =
         0;

      stats.Losses =
         0;

      stats.CumR =
         0.0;

      stats.SumCurrentR =
         0.0;

      stats.SumMFE =
         0.0;

      stats.SumMAE =
         0.0;

      stats.SumDirER10 =
         0.0;

      stats.SumERDelta =
         0.0;

      stats.SumVolZ20 =
         0.0;
   }
};

#endif
