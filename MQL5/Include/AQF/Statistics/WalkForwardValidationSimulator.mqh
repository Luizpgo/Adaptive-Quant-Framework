#ifndef __AQF_WALK_FORWARD_VALIDATION_SIMULATOR_MQH__
#define __AQF_WALK_FORWARD_VALIDATION_SIMULATOR_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"
#include "ValidationGate.mqh"

#define AQF_WF_FOLD_COUNT   3
#define AQF_WF_PHASE_COUNT  2
#define AQF_WF_POLICY_COUNT 4
#define AQF_WF_SLOT_COUNT   6

//+------------------------------------------------------------------+
//| Anchored Walk-Forward Validation                                 |
//| AQF v0.12.1 - Sprint 12B                                        |
//|                                                                  |
//| PURPOSE                                                          |
//| Evaluate temporal stability of the FROZEN policy chain without   |
//| changing any strategy thresholds.                               |
//|                                                                  |
//| Folds                                                            |
//| WF1: TRAIN 2022       -> TEST 2023                              |
//| WF2: TRAIN 2022-2023  -> TEST 2024                              |
//| WF3: TRAIN 2022-2024  -> TEST 2025                              |
//|                                                                  |
//| Policies                                                         |
//| BASELINE                                                         |
//| H1 = ATRPercent >= 0.075                                         |
//| H2 = H1 + ADX >= 25 and ADX < 40                               |
//| H3 = H2 + DirER10 >= 0.50 + VolZ20 >= 0.25 and < 1.00          |
//|                                                                  |
//| TP=+1.50R | SL=-1.00R                                           |
//| Every fold/phase/policy owns an INDEPENDENT one-position virtual |
//| account. Test accounts therefore start fresh at each annual      |
//| test boundary.                                                   |
//|                                                                  |
//| BOUNDARY RULE                                                    |
//| A position still active when its phase boundary is reached is    |
//| right-censored and excluded from W/L and expectancy. This avoids |
//| using future TEST ticks to resolve a TRAIN trade.                |
//|                                                                  |
//| METHODOLOGY                                                      |
//| All 2022-2025 data have already been inspected during AQF        |
//| research. These folds are RETROSPECTIVE diagnostics only.        |
//| They cannot create a pristine OOS claim.                         |
//|                                                                  |
//| VIRTUAL ONLY. NO OrderSend.                                      |
//+------------------------------------------------------------------+

enum ENUM_AQF_WF_PHASE
{
   AQF_WF_TRAIN = 0,
   AQF_WF_TEST  = 1
};

enum ENUM_AQF_WF_POLICY
{
   AQF_WF_BASELINE = 0,
   AQF_WF_H1,
   AQF_WF_H2,
   AQF_WF_H3
};

struct SAQFWalkForwardPosition
{
   bool Active;

   string Symbol;
   ENUM_AQF_SIGNAL_DIRECTION Direction;

   double EntryPrice;
   double StopLoss;
   double StopDistance;
   double TakeProfit;
};

struct SAQFWalkForwardStats
{
   long SignalsSeen;
   long Eligible;
   long Opened;
   long SkippedActive;
   long FeatureFailures;
   long BoundaryCensored;

   long Wins;
   long Losses;

   double GrossProfitR;
   double GrossLossR;

   double CumulativeR;
   double PeakR;
   double MaxDrawdownR;
};

class CAQFWalkForwardValidationSimulator
{
private:

   CAQFValidationGate m_validationGate;

   SAQFWalkForwardPosition m_positions[AQF_WF_SLOT_COUNT][AQF_WF_POLICY_COUNT];
   SAQFWalkForwardStats    m_stats[AQF_WF_SLOT_COUNT][AQF_WF_POLICY_COUNT];

   datetime m_slotStart[AQF_WF_SLOT_COUNT];
   datetime m_slotEnd[AQF_WF_SLOT_COUNT];

   int m_slotFold[AQF_WF_SLOT_COUNT];
   ENUM_AQF_WF_PHASE m_slotPhase[AQF_WF_SLOT_COUNT];

   double m_targetR;

   double m_minATRPercent;
   double m_minADX;
   double m_maxADX;

   double m_minDirectionalER10;
   double m_minVolumeZ20;
   double m_maxVolumeZ20;

   bool m_initialized;

public:

   CAQFWalkForwardValidationSimulator()
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

      ConfigureSlots();
      ResetAll();
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(
      CAQFLogger &logger)
   {
      ConfigureSlots();
      ResetAll();

      m_initialized =
         true;

      logger.Info(
         "WalkForwardFramework | Version=v0.12.1 | Mode=ANCHORED_EXPANDING_RETROSPECTIVE | Folds=3 | TP=1.50R | SL=1.00R"
      );

      logger.Info(
         "WalkForwardFold | Fold=WF1 | Train=[2022.01.01,2023.01.01) | Test=[2023.01.01,2024.01.01)"
      );

      logger.Info(
         "WalkForwardFold | Fold=WF2 | Train=[2022.01.01,2024.01.01) | Test=[2024.01.01,2025.01.01)"
      );

      logger.Info(
         "WalkForwardFold | Fold=WF3 | Train=[2022.01.01,2025.01.01) | Test=[2025.01.01,2026.01.01)"
      );

      logger.Info(
         "WalkForwardPolicies | BASELINE | H1=ATRPercent>=0.075 | H2=H1+ADX>=25<40 | H3_FROZEN=H2+DirER10>=0.50+VolZ20>=0.25<1.00"
      );

      logger.Info(
         "WalkForwardBoundaryRule | active positions are right-censored at phase end; future TEST ticks never resolve TRAIN trades."
      );

      logger.Warning(
         "METHODOLOGY: WF1-WF3 are retrospective diagnostics because 2022-2025 were already inspected. Do not label these folds pristine OOS."
      );

      logger.Warning(
         "METHODOLOGY: v0.12.1 does not tune or select thresholds. It measures temporal stability and applies a frozen rejection gate."
      );

      logger.Info(
         "ValidationGateCriteria | Stage=WALK_FORWARD | RequiredTestFolds=3 | PositiveTestFoldsRequired=3 | AggregateExpectancy_GT_0=YES | AggregatePF_GT_1=YES | AggregateCumR_GT_0=YES | WorstFoldExpectancy_GE_0=YES | MinResolvedTradesPerTestFold=30"
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
         request.Symbol != market.Symbol ||
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

      datetime eventTime =
         request.SignalTime;

      if(eventTime <= 0)
         eventTime = market.Time;

      if(eventTime <= 0)
         return false;

      //------------------------------------------------------------
      // Frozen policy eligibility - computed once per opportunity.
      //------------------------------------------------------------

      bool h1Eligible =
         (
            market.ATRPercent >=
            m_minATRPercent
         );

      bool h2Eligible =
         (
            h1Eligible &&
            market.ADX >=
            m_minADX &&
            market.ADX <
            m_maxADX
         );

      bool h3Eligible =
         false;

      bool h3FeatureFailure =
         false;

      if(h2Eligible)
      {
         double relativeVolume20 =
            0.0;

         double volumeZScore20 =
            0.0;

         double directionalER10 =
            0.0;

         if(!CaptureH3Features(
               request,
               market,
               relativeVolume20,
               volumeZScore20,
               directionalER10))
         {
            h3FeatureFailure =
               true;
         }
         else
         {
            h3Eligible =
               (
                  directionalER10 >=
                  m_minDirectionalER10
                  &&
                  volumeZScore20 >=
                  m_minVolumeZ20
                  &&
                  volumeZScore20 <
                  m_maxVolumeZ20
               );
         }
      }

      //------------------------------------------------------------
      // One historical event may belong to TRAIN in several anchored
      // folds. Each slot is an independent virtual account.
      //------------------------------------------------------------

      for(int slot = 0;
          slot < AQF_WF_SLOT_COUNT;
          slot++)
      {
         if(eventTime <
               m_slotStart[slot] ||
            eventTime >=
               m_slotEnd[slot])
         {
            continue;
         }

         RegisterPolicy(
            slot,
            AQF_WF_BASELINE,
            true,
            false,
            request,
            logger
         );

         RegisterPolicy(
            slot,
            AQF_WF_H1,
            h1Eligible,
            false,
            request,
            logger
         );

         RegisterPolicy(
            slot,
            AQF_WF_H2,
            h2Eligible,
            false,
            request,
            logger
         );

         RegisterPolicy(
            slot,
            AQF_WF_H3,
            h3Eligible,
            h3FeatureFailure,
            request,
            logger
         );
      }

      return true;
   }

   //==============================================================
   // Every-tick update
   //==============================================================
   void Update(
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!m_initialized ||
         !market.Valid ||
         market.Time <= 0 ||
         market.Bid <= 0.0 ||
         market.Ask <= 0.0)
      {
         return;
      }

      for(int slot = 0;
          slot < AQF_WF_SLOT_COUNT;
          slot++)
      {
         for(int policy = 0;
             policy < AQF_WF_POLICY_COUNT;
             policy++)
         {
            UpdatePosition(
               slot,
               (ENUM_AQF_WF_POLICY)policy,
               market,
               logger
            );
         }
      }
   }

   //==============================================================
   // Shutdown reports
   //==============================================================
   void Shutdown(
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return;

      ReportAllStats(
         logger
      );

      ReportAllDegradation(
         logger
      );

      ReportTestAggregate(
         logger
      );

      ReportValidationGate(
         logger
      );

      m_initialized =
         false;
   }

private:

   //==============================================================
   // Slot map
   //==============================================================
   void ConfigureSlots()
   {
      //------------------------------------------------------------
      // WF1
      //------------------------------------------------------------
      ConfigureSlot(
         SlotIndex(
            0,
            AQF_WF_TRAIN),
         0,
         AQF_WF_TRAIN,
         D'2022.01.01 00:00',
         D'2023.01.01 00:00'
      );

      ConfigureSlot(
         SlotIndex(
            0,
            AQF_WF_TEST),
         0,
         AQF_WF_TEST,
         D'2023.01.01 00:00',
         D'2024.01.01 00:00'
      );

      //------------------------------------------------------------
      // WF2
      //------------------------------------------------------------
      ConfigureSlot(
         SlotIndex(
            1,
            AQF_WF_TRAIN),
         1,
         AQF_WF_TRAIN,
         D'2022.01.01 00:00',
         D'2024.01.01 00:00'
      );

      ConfigureSlot(
         SlotIndex(
            1,
            AQF_WF_TEST),
         1,
         AQF_WF_TEST,
         D'2024.01.01 00:00',
         D'2025.01.01 00:00'
      );

      //------------------------------------------------------------
      // WF3
      //------------------------------------------------------------
      ConfigureSlot(
         SlotIndex(
            2,
            AQF_WF_TRAIN),
         2,
         AQF_WF_TRAIN,
         D'2022.01.01 00:00',
         D'2025.01.01 00:00'
      );

      ConfigureSlot(
         SlotIndex(
            2,
            AQF_WF_TEST),
         2,
         AQF_WF_TEST,
         D'2025.01.01 00:00',
         D'2026.01.01 00:00'
      );
   }

   void ConfigureSlot(
      const int slot,
      const int fold,
      const ENUM_AQF_WF_PHASE phase,
      const datetime startTime,
      const datetime endTime)
   {
      if(slot < 0 ||
         slot >= AQF_WF_SLOT_COUNT)
      {
         return;
      }

      m_slotFold[slot] =
         fold;

      m_slotPhase[slot] =
         phase;

      m_slotStart[slot] =
         startTime;

      m_slotEnd[slot] =
         endTime;
   }

   int SlotIndex(
      const int fold,
      const ENUM_AQF_WF_PHASE phase)
   {
      return
         fold *
         AQF_WF_PHASE_COUNT +
         (int)phase;
   }

   //==============================================================
   // Registration
   //==============================================================
   void RegisterPolicy(
      const int slot,
      const ENUM_AQF_WF_POLICY policy,
      const bool eligible,
      const bool featureFailure,
      const CAQFTradeRequest &request,
      CAQFLogger &logger)
   {
      int policyIndex =
         (int)policy;

      m_stats[slot][policyIndex].SignalsSeen++;

      if(featureFailure)
      {
         m_stats[slot][policyIndex].FeatureFailures++;
      }

      if(!eligible)
         return;

      m_stats[slot][policyIndex].Eligible++;

      if(m_positions[slot][policyIndex].Active)
      {
         m_stats[slot][policyIndex].SkippedActive++;
         return;
      }

      OpenPosition(
         m_positions[slot][policyIndex],
         request
      );

      m_stats[slot][policyIndex].Opened++;

      logger.Debug(
         "WalkForwardOpen" +
         " | Fold=" +
         FoldText(
            m_slotFold[slot]) +
         " | Phase=" +
         PhaseText(
            m_slotPhase[slot]) +
         " | Policy=" +
         PolicyText(
            policy) +
         " | Direction=" +
         AQFSignalDirectionToString(
            request.Direction)
      );
   }

   void OpenPosition(
      SAQFWalkForwardPosition &position,
      const CAQFTradeRequest &request)
   {
      ResetPosition(
         position
      );

      position.Active =
         true;

      position.Symbol =
         request.Symbol;

      position.Direction =
         request.Direction;

      position.EntryPrice =
         request.EntryPrice;

      position.StopLoss =
         request.StopLoss;

      position.StopDistance =
         request.StopDistance;

      double targetDistance =
         request.StopDistance *
         m_targetR;

      if(request.Direction ==
         AQF_SIGNAL_BUY)
      {
         position.TakeProfit =
            request.EntryPrice +
            targetDistance;
      }
      else
      {
         position.TakeProfit =
            request.EntryPrice -
            targetDistance;
      }
   }

   //==============================================================
   // Tick update + strict phase boundary censoring
   //==============================================================
   void UpdatePosition(
      const int slot,
      const ENUM_AQF_WF_POLICY policy,
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      int policyIndex =
         (int)policy;

      if(!m_positions[slot][policyIndex].Active)
         return;

      //------------------------------------------------------------
      // Critical anti-leakage rule:
      // do not let a future phase tick resolve a prior phase trade.
      //------------------------------------------------------------

      if(market.Time >=
         m_slotEnd[slot])
      {
         m_stats[slot][policyIndex].BoundaryCensored++;

         logger.Debug(
            "WalkForwardBoundaryCensor" +
            " | Fold=" +
            FoldText(
               m_slotFold[slot]) +
            " | Phase=" +
            PhaseText(
               m_slotPhase[slot]) +
            " | Policy=" +
            PolicyText(
               policy)
         );

         ResetPosition(
            m_positions[slot][policyIndex]
         );

         return;
      }

      if(market.Time <
         m_slotStart[slot])
      {
         return;
      }

      if(m_positions[slot][policyIndex].Symbol !=
         market.Symbol)
      {
         return;
      }

      bool targetReached =
         false;

      bool stopReached =
         false;

      if(m_positions[slot][policyIndex].Direction ==
         AQF_SIGNAL_BUY)
      {
         targetReached =
            (
               market.Bid >=
               m_positions[slot][policyIndex].TakeProfit
            );

         stopReached =
            (
               market.Bid <=
               m_positions[slot][policyIndex].StopLoss
            );
      }
      else
      {
         targetReached =
            (
               market.Ask <=
               m_positions[slot][policyIndex].TakeProfit
            );

         stopReached =
            (
               market.Ask >=
               m_positions[slot][policyIndex].StopLoss
            );
      }

      if(targetReached)
      {
         Resolve(
            slot,
            policy,
            m_targetR,
            logger
         );

         return;
      }

      if(stopReached)
      {
         Resolve(
            slot,
            policy,
            -1.0,
            logger
         );

         return;
      }
   }

   void Resolve(
      const int slot,
      const ENUM_AQF_WF_POLICY policy,
      const double resultR,
      CAQFLogger &logger)
   {
      int policyIndex =
         (int)policy;

      if(resultR > 0.0)
      {
         m_stats[slot][policyIndex].Wins++;

         m_stats[slot][policyIndex].GrossProfitR +=
            resultR;
      }
      else
      {
         m_stats[slot][policyIndex].Losses++;

         m_stats[slot][policyIndex].GrossLossR +=
            -resultR;
      }

      m_stats[slot][policyIndex].CumulativeR +=
         resultR;

      if(m_stats[slot][policyIndex].CumulativeR >
         m_stats[slot][policyIndex].PeakR)
      {
         m_stats[slot][policyIndex].PeakR =
            m_stats[slot][policyIndex].CumulativeR;
      }

      double drawdown =
         m_stats[slot][policyIndex].PeakR -
         m_stats[slot][policyIndex].CumulativeR;

      if(drawdown >
         m_stats[slot][policyIndex].MaxDrawdownR)
      {
         m_stats[slot][policyIndex].MaxDrawdownR =
            drawdown;
      }

      logger.Debug(
         "WalkForwardClose" +
         " | Fold=" +
         FoldText(
            m_slotFold[slot]) +
         " | Phase=" +
         PhaseText(
            m_slotPhase[slot]) +
         " | Policy=" +
         PolicyText(
            policy) +
         " | ResultR=" +
         DoubleToString(
            resultR,
            2) +
         "R"
      );

      ResetPosition(
         m_positions[slot][policyIndex]
      );
   }

   //==============================================================
   // Frozen H3 feature capture
   //==============================================================
   bool CaptureH3Features(
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

      return
         efficiency;
   }

   //==============================================================
   // Reports
   //==============================================================
   void ReportAllStats(
      CAQFLogger &logger)
   {
      for(int fold = 0;
          fold < AQF_WF_FOLD_COUNT;
          fold++)
      {
         for(int phase = 0;
             phase < AQF_WF_PHASE_COUNT;
             phase++)
         {
            int slot =
               SlotIndex(
                  fold,
                  (ENUM_AQF_WF_PHASE)phase
               );

            for(int policy = 0;
                policy < AQF_WF_POLICY_COUNT;
                policy++)
            {
               ReportStats(
                  slot,
                  (ENUM_AQF_WF_POLICY)policy,
                  logger
               );
            }
         }
      }
   }

   void ReportStats(
      const int slot,
      const ENUM_AQF_WF_POLICY policy,
      CAQFLogger &logger)
   {
      int policyIndex =
         (int)policy;

      long resolved =
         Resolved(
            m_stats[slot][policyIndex]
         );

      double winRate =
         0.0;

      double expectancy =
         0.0;

      if(resolved > 0)
      {
         winRate =
            100.0 *
            (double)m_stats[slot][policyIndex].Wins /
            (double)resolved;

         expectancy =
            m_stats[slot][policyIndex].CumulativeR /
            (double)resolved;
      }

      logger.Info(
         "WalkForwardStats" +
         " | Fold=" +
         FoldText(
            m_slotFold[slot]) +
         " | Phase=" +
         PhaseText(
            m_slotPhase[slot]) +
         " | Period=" +
         PeriodText(
            m_slotFold[slot],
            m_slotPhase[slot]) +
         " | Policy=" +
         PolicyText(
            policy) +
         " | Signals=" +
         IntegerToString(
            (int)m_stats[slot][policyIndex].SignalsSeen) +
         " | Eligible=" +
         IntegerToString(
            (int)m_stats[slot][policyIndex].Eligible) +
         " | Opened=" +
         IntegerToString(
            (int)m_stats[slot][policyIndex].Opened) +
         " | SkippedActive=" +
         IntegerToString(
            (int)m_stats[slot][policyIndex].SkippedActive) +
         " | BoundaryCensored=" +
         IntegerToString(
            (int)m_stats[slot][policyIndex].BoundaryCensored) +
         " | Resolved=" +
         IntegerToString(
            (int)resolved) +
         " | Wins=" +
         IntegerToString(
            (int)m_stats[slot][policyIndex].Wins) +
         " | Losses=" +
         IntegerToString(
            (int)m_stats[slot][policyIndex].Losses) +
         " | Open=" +
         (
            m_positions[slot][policyIndex].Active
            ? "1"
            : "0"
         ) +
         " | FeatureFailures=" +
         IntegerToString(
            (int)m_stats[slot][policyIndex].FeatureFailures) +
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
            m_stats[slot][policyIndex]) +
         " | CumR=" +
         DoubleToString(
            m_stats[slot][policyIndex].CumulativeR,
            2) +
         "R" +
         " | MaxDD=" +
         DoubleToString(
            m_stats[slot][policyIndex].MaxDrawdownR,
            2) +
         "R"
      );
   }

   void ReportAllDegradation(
      CAQFLogger &logger)
   {
      for(int fold = 0;
          fold < AQF_WF_FOLD_COUNT;
          fold++)
      {
         int trainSlot =
            SlotIndex(
               fold,
               AQF_WF_TRAIN
            );

         int testSlot =
            SlotIndex(
               fold,
               AQF_WF_TEST
            );

         for(int policy = 0;
             policy < AQF_WF_POLICY_COUNT;
             policy++)
         {
            SAQFWalkForwardStats trainStats =
               m_stats[trainSlot][policy];

            SAQFWalkForwardStats testStats =
               m_stats[testSlot][policy];

            long trainN =
               Resolved(
                  trainStats
               );

            long testN =
               Resolved(
                  testStats
               );

            double trainExp =
               Expectancy(
                  trainStats
               );

            double testExp =
               Expectancy(
                  testStats
               );

            logger.Info(
               "WalkForwardDegradation" +
               " | Fold=" +
               FoldText(
                  fold) +
               " | Policy=" +
               PolicyText(
                  (ENUM_AQF_WF_POLICY)policy) +
               " | Train_N=" +
               IntegerToString(
                  (int)trainN) +
               " | Train_Expectancy=" +
               DoubleToString(
                  trainExp,
                  3) +
               "R" +
               " | Train_PF=" +
               ProfitFactorText(
                  trainStats) +
               " | Test_N=" +
               IntegerToString(
                  (int)testN) +
               " | Test_Expectancy=" +
               DoubleToString(
                  testExp,
                  3) +
               "R" +
               " | Test_PF=" +
               ProfitFactorText(
                  testStats) +
               " | DeltaExp_TestMinusTrain=" +
               DoubleToString(
                  testExp -
                  trainExp,
                  3) +
               "R" +
               " | TrainPositive=" +
               (
                  trainExp > 0.0
                  ? "YES"
                  : "NO"
               ) +
               " | TestPositive=" +
               (
                  testExp > 0.0
                  ? "YES"
                  : "NO"
               )
            );
         }
      }
   }

   void ReportTestAggregate(
      CAQFLogger &logger)
   {
      for(int policy = 0;
          policy < AQF_WF_POLICY_COUNT;
          policy++)
      {
         long totalResolved =
            0;

         long totalWins =
            0;

         long totalLosses =
            0;

         double totalR =
            0.0;

         double totalGrossProfit =
            0.0;

         double totalGrossLoss =
            0.0;

         double worstFoldExp =
            0.0;

         double bestFoldExp =
            0.0;

         double worstFoldDD =
            0.0;

         int positiveFolds =
            0;

         int foldsWithTrades =
            0;

         bool firstFoldWithTrades =
            true;

         for(int fold = 0;
             fold < AQF_WF_FOLD_COUNT;
             fold++)
         {
            int testSlot =
               SlotIndex(
                  fold,
                  AQF_WF_TEST
               );

            SAQFWalkForwardStats testStats =
               m_stats[testSlot][policy];

            long resolved =
               Resolved(
                  testStats
               );

            if(resolved <= 0)
               continue;

            double exp =
               Expectancy(
                  testStats
               );

            foldsWithTrades++;

            if(exp > 0.0)
               positiveFolds++;

            totalResolved +=
               resolved;

            totalWins +=
               testStats.Wins;

            totalLosses +=
               testStats.Losses;

            totalR +=
               testStats.CumulativeR;

            totalGrossProfit +=
               testStats.GrossProfitR;

            totalGrossLoss +=
               testStats.GrossLossR;

            if(firstFoldWithTrades)
            {
               worstFoldExp =
                  exp;

               bestFoldExp =
                  exp;

               worstFoldDD =
                  testStats.MaxDrawdownR;

               firstFoldWithTrades =
                  false;
            }
            else
            {
               if(exp <
                  worstFoldExp)
               {
                  worstFoldExp =
                     exp;
               }

               if(exp >
                  bestFoldExp)
               {
                  bestFoldExp =
                     exp;
               }

               if(testStats.MaxDrawdownR >
                  worstFoldDD)
               {
                  worstFoldDD =
                     testStats.MaxDrawdownR;
               }
            }
         }

         double aggregateWinRate =
            0.0;

         double aggregateExp =
            0.0;

         if(totalResolved > 0)
         {
            aggregateWinRate =
               100.0 *
               (double)totalWins /
               (double)totalResolved;

            aggregateExp =
               totalR /
               (double)totalResolved;
         }

         string aggregatePF =
            "0.000";

         if(totalGrossLoss <= 0.0)
         {
            if(totalGrossProfit > 0.0)
               aggregatePF = "INF";
         }
         else
         {
            aggregatePF =
               DoubleToString(
                  totalGrossProfit /
                  totalGrossLoss,
                  3
               );
         }

         logger.Info(
            "WalkForwardTestAggregate" +
            " | Policy=" +
            PolicyText(
               (ENUM_AQF_WF_POLICY)policy) +
            " | TestFoldsWithTrades=" +
            IntegerToString(
               foldsWithTrades) +
            " | PositiveTestFolds=" +
            IntegerToString(
               positiveFolds) +
            " | AllTestFoldsPositive=" +
            (
               foldsWithTrades ==
                  AQF_WF_FOLD_COUNT &&
               positiveFolds ==
                  AQF_WF_FOLD_COUNT
               ? "YES"
               : "NO"
            ) +
            " | Resolved=" +
            IntegerToString(
               (int)totalResolved) +
            " | Wins=" +
            IntegerToString(
               (int)totalWins) +
            " | Losses=" +
            IntegerToString(
               (int)totalLosses) +
            " | WinRate=" +
            DoubleToString(
               aggregateWinRate,
               2) +
            "%" +
            " | AggregateExpectancy=" +
            DoubleToString(
               aggregateExp,
               3) +
            "R" +
            " | AggregatePF=" +
            aggregatePF +
            " | AggregateCumR=" +
            DoubleToString(
               totalR,
               2) +
            "R" +
            " | WorstFoldExpectancy=" +
            DoubleToString(
               worstFoldExp,
               3) +
            "R" +
            " | BestFoldExpectancy=" +
            DoubleToString(
               bestFoldExp,
               3) +
            "R" +
            " | WorstFoldMaxDD=" +
            DoubleToString(
               worstFoldDD,
               2) +
            "R"
         );
      }
   }


   //==============================================================
   // Frozen walk-forward promotion gate
   //==============================================================
   void ReportValidationGate(
      CAQFLogger &logger)
   {
      for(int policy=0; policy<AQF_WF_POLICY_COUNT; policy++)
      {
         int foldsWithTrades=0;
         int positiveFolds=0;
         int minResolvedTrades=0;
         long totalResolved=0;
         double totalR=0.0;
         double totalGrossProfit=0.0;
         double totalGrossLoss=0.0;
         double worstFoldExp=0.0;
         bool first=true;

         for(int fold=0; fold<AQF_WF_FOLD_COUNT; fold++)
         {
            int slot=SlotIndex(fold,AQF_WF_TEST);
            SAQFWalkForwardStats s=m_stats[slot][policy];
            long n=Resolved(s);
            if(n<=0) continue;

            double exp=Expectancy(s);
            foldsWithTrades++;
            if(exp>0.0) positiveFolds++;
            totalResolved+=n;
            totalR+=s.CumulativeR;
            totalGrossProfit+=s.GrossProfitR;
            totalGrossLoss+=s.GrossLossR;

            if(first)
            {
               minResolvedTrades=(int)n;
               worstFoldExp=exp;
               first=false;
            }
            else
            {
               if(n<minResolvedTrades) minResolvedTrades=(int)n;
               if(exp<worstFoldExp) worstFoldExp=exp;
            }
         }

         double aggregateExp=(totalResolved>0 ? totalR/(double)totalResolved : 0.0);
         double aggregatePF=0.0;
         string aggregatePFText="0.000";

         if(totalGrossLoss<=0.0)
         {
            if(totalGrossProfit>0.0)
            {
               aggregatePF=DBL_MAX;
               aggregatePFText="INF";
            }
         }
         else
         {
            aggregatePF=totalGrossProfit/totalGrossLoss;
            aggregatePFText=DoubleToString(aggregatePF,3);
         }

         SAQFValidationGateResult r=m_validationGate.EvaluateWalkForward(
            foldsWithTrades,
            positiveFolds,
            minResolvedTrades,
            aggregateExp,
            aggregatePF,
            totalR,
            worstFoldExp
         );

         logger.Info(
            "ValidationGate"+
            " | Stage=WALK_FORWARD"+
            " | Policy="+PolicyText((ENUM_AQF_WF_POLICY)policy)+
            " | Result="+m_validationGate.ResultText(r)+
            " | Promotion="+m_validationGate.PromotionText(r)+
            " | PassedRules="+IntegerToString(r.PassedRules)+"/7"+
            " | FailedRules="+IntegerToString(r.FailedRules)+
            " | TestFoldsWithTrades="+IntegerToString(foldsWithTrades)+"/3"+
            " | PositiveTestFolds="+IntegerToString(positiveFolds)+"/3"+
            " | MinResolvedTradesAnyTestFold="+IntegerToString(minResolvedTrades)+
            " | AggregateExpectancy="+DoubleToString(aggregateExp,3)+"R"+
            " | AggregatePF="+aggregatePFText+
            " | AggregateCumR="+DoubleToString(totalR,2)+"R"+
            " | WorstFoldExpectancy="+DoubleToString(worstFoldExp,3)+"R"+
            " | FailReasons="+m_validationGate.FailReasons(r)
         );
      }
   }

   //==============================================================
   // Metrics helpers
   //==============================================================
   long Resolved(
      const SAQFWalkForwardStats &stats)
   {
      return
         stats.Wins +
         stats.Losses;
   }

   double Expectancy(
      const SAQFWalkForwardStats &stats)
   {
      long resolved =
         Resolved(
            stats
         );

      if(resolved <= 0)
         return 0.0;

      return
         stats.CumulativeR /
         (double)resolved;
   }

   string ProfitFactorText(
      const SAQFWalkForwardStats &stats)
   {
      if(stats.GrossLossR <= 0.0)
      {
         if(stats.GrossProfitR > 0.0)
            return "INF";

         return "0.000";
      }

      return
         DoubleToString(
            stats.GrossProfitR /
            stats.GrossLossR,
            3
         );
   }

   //==============================================================
   // Text helpers
   //==============================================================
   string FoldText(
      const int fold)
   {
      if(fold == 0)
         return "WF1";

      if(fold == 1)
         return "WF2";

      if(fold == 2)
         return "WF3";

      return "WF_UNKNOWN";
   }

   string PhaseText(
      const ENUM_AQF_WF_PHASE phase)
   {
      if(phase ==
         AQF_WF_TRAIN)
      {
         return "TRAIN";
      }

      if(phase ==
         AQF_WF_TEST)
      {
         return "TEST";
      }

      return "UNKNOWN";
   }

   string PeriodText(
      const int fold,
      const ENUM_AQF_WF_PHASE phase)
   {
      if(fold == 0 &&
         phase == AQF_WF_TRAIN)
      {
         return "2022";
      }

      if(fold == 0 &&
         phase == AQF_WF_TEST)
      {
         return "2023";
      }

      if(fold == 1 &&
         phase == AQF_WF_TRAIN)
      {
         return "2022-2023";
      }

      if(fold == 1 &&
         phase == AQF_WF_TEST)
      {
         return "2024";
      }

      if(fold == 2 &&
         phase == AQF_WF_TRAIN)
      {
         return "2022-2024";
      }

      if(fold == 2 &&
         phase == AQF_WF_TEST)
      {
         return "2025";
      }

      return "UNKNOWN";
   }

   string PolicyText(
      const ENUM_AQF_WF_POLICY policy)
   {
      if(policy ==
         AQF_WF_BASELINE)
      {
         return "BASELINE";
      }

      if(policy ==
         AQF_WF_H1)
      {
         return "H1_ATR_GE_0.075";
      }

      if(policy ==
         AQF_WF_H2)
      {
         return "H2_ATR_GE_0.075_ADX_25_TO_LT_40";
      }

      if(policy ==
         AQF_WF_H3)
      {
         return "H3_FROZEN";
      }

      return "UNKNOWN";
   }

   //==============================================================
   // Reset helpers
   //==============================================================
   void ResetPosition(
      SAQFWalkForwardPosition &position)
   {
      position.Active =
         false;

      position.Symbol =
         "";

      position.Direction =
         AQF_SIGNAL_NONE;

      position.EntryPrice =
         0.0;

      position.StopLoss =
         0.0;

      position.StopDistance =
         0.0;

      position.TakeProfit =
         0.0;
   }

   void ResetStats(
      SAQFWalkForwardStats &stats)
   {
      stats.SignalsSeen =
         0;

      stats.Eligible =
         0;

      stats.Opened =
         0;

      stats.SkippedActive =
         0;

      stats.FeatureFailures =
         0;

      stats.BoundaryCensored =
         0;

      stats.Wins =
         0;

      stats.Losses =
         0;

      stats.GrossProfitR =
         0.0;

      stats.GrossLossR =
         0.0;

      stats.CumulativeR =
         0.0;

      stats.PeakR =
         0.0;

      stats.MaxDrawdownR =
         0.0;
   }

   void ResetAll()
   {
      for(int slot = 0;
          slot < AQF_WF_SLOT_COUNT;
          slot++)
      {
         for(int policy = 0;
             policy < AQF_WF_POLICY_COUNT;
             policy++)
         {
            ResetPosition(
               m_positions[slot][policy]
            );

            ResetStats(
               m_stats[slot][policy]
            );
         }
      }
   }
};

#endif
