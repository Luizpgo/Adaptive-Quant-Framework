#ifndef __AQF_BREAKOUT_EXPANSION_RESEARCH_SIMULATOR_MQH__
#define __AQF_BREAKOUT_EXPANSION_RESEARCH_SIMULATOR_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"
#include "ValidationGate.mqh"

#define AQF_B1_WF_FOLD_COUNT   3
#define AQF_B1_WF_PHASE_COUNT  2
#define AQF_B1_WF_SLOT_COUNT   6

//+------------------------------------------------------------------+
//| B1 Breakout Expansion Research Simulator                         |
//| AQF v0.13.0 - Sprint 13A Research Reset                         |
//|                                                                  |
//| PREDECLARED HYPOTHESIS - FROZEN BEFORE RESULTS                   |
//| Family: independent breakout / volatility expansion              |
//|                                                                  |
//| SIGNAL EVENT                                                     |
//| - Evaluate once at the first tick of each new M1 candle.         |
//| - Use ONLY completed bars.                                       |
//| - Prior Donchian channel = 20 bars BEFORE the breakout bar.      |
//| - BUY  if last closed bar CLOSE > prior 20-bar highest HIGH.     |
//| - SELL if last closed bar CLOSE < prior 20-bar lowest LOW.       |
//| - Breakout bar TrueRange must be >= 1.25 * prior ATR20.          |
//|                                                                  |
//| EXECUTION MODEL                                                  |
//| - Entry at first executable quote of the new bar:                |
//|     BUY = Ask                                                    |
//|     SELL = Bid                                                   |
//| - StopDistance = 1.00 * prior ATR20.                             |
//| - SL = -1.00R                                                    |
//| - TP = +1.50R                                                    |
//| - One active virtual position per fold/phase.                    |
//|                                                                  |
//| WALK-FORWARD                                                     |
//| WF1: TRAIN 2022       -> TEST 2023                              |
//| WF2: TRAIN 2022-2023  -> TEST 2024                              |
//| WF3: TRAIN 2022-2024  -> TEST 2025                              |
//|                                                                  |
//| IMPORTANT                                                        |
//| - This candidate is INDEPENDENT of the legacy StrategyEngine     |
//|   signal stream and independent of H1/H2/H3 eligibility.         |
//| - No ADX, ER10, VolumeZ, RSI, EMA or hour/day filters.           |
//| - No parameter optimization is performed in this module.         |
//| - 2022-2025 are contaminated retrospective research data.        |
//| - PASS only means eligible for the next validation stage.        |
//| - VIRTUAL ONLY. NO OrderSend.                                    |
//+------------------------------------------------------------------+

enum ENUM_AQF_B1_WF_PHASE
{
   AQF_B1_WF_TRAIN = 0,
   AQF_B1_WF_TEST  = 1
};

struct SAQFB1Position
{
   bool Active;

   string Symbol;
   ENUM_AQF_SIGNAL_DIRECTION Direction;

   double EntryPrice;
   double StopLoss;
   double StopDistance;
   double TakeProfit;
};

struct SAQFB1Stats
{
   long BarsEvaluated;
   long FeatureFailures;

   long RawBreakouts;
   long ExpansionRejected;
   long Eligible;

   long Opened;
   long SkippedActive;
   long BoundaryCensored;

   long Wins;
   long Losses;

   double GrossProfitR;
   double GrossLossR;

   double CumulativeR;
   double PeakR;
   double MaxDrawdownR;
};

class CAQFBreakoutExpansionResearchSimulator
{
private:

   CAQFValidationGate m_validationGate;

   SAQFB1Position m_positions[AQF_B1_WF_SLOT_COUNT];
   SAQFB1Stats    m_stats[AQF_B1_WF_SLOT_COUNT];

   datetime m_slotStart[AQF_B1_WF_SLOT_COUNT];
   datetime m_slotEnd[AQF_B1_WF_SLOT_COUNT];

   int m_slotFold[AQF_B1_WF_SLOT_COUNT];
   ENUM_AQF_B1_WF_PHASE m_slotPhase[AQF_B1_WF_SLOT_COUNT];

   int m_channelLookback;
   int m_atrLookback;

   double m_minExpansionTRToATR;
   double m_stopATRMultiple;
   double m_targetR;

   datetime m_lastObservedBarTime;

   bool m_initialized;

public:

   CAQFBreakoutExpansionResearchSimulator()
   {
      m_channelLookback =
         20;

      m_atrLookback =
         20;

      m_minExpansionTRToATR =
         1.25;

      m_stopATRMultiple =
         1.00;

      m_targetR =
         1.50;

      m_lastObservedBarTime =
         0;

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

      m_lastObservedBarTime =
         0;

      m_initialized =
         true;

      logger.Info(
         "ResearchProtocol | Candidate=B1_BREAKOUT_EXPANSION | Version=v0.13.0 | Status=FROZEN_BEFORE_RESULTS | Family=INDEPENDENT_BREAKOUT_VOLATILITY_EXPANSION"
      );

      logger.Info(
         "ResearchProtocolRules | Candidate=B1_BREAKOUT_EXPANSION | DonchianLookback=20_COMPLETED_PRIOR_BARS | Trigger=LAST_CLOSED_BAR_CLOSE_OUTSIDE_CHANNEL | ExpansionTR_ATR20_GE=1.25 | StopATR20=1.00 | TP=1.50R | SL=1.00R | Entry=FIRST_EXECUTABLE_QUOTE_NEW_BAR"
      );

      logger.Info(
         "ResearchProtocolExclusions | Candidate=B1_BREAKOUT_EXPANSION | ADX=NONE | ER10=NONE | VolumeZ=NONE | RSI=NONE | EMA=NONE | HourFilter=NONE | WeekdayFilter=NONE | LegacyStrategyDirection=NONE"
      );

      logger.Info(
         "ResearchWalkForward | WF1=TRAIN_2022_TEST_2023 | WF2=TRAIN_2022_2023_TEST_2024 | WF3=TRAIN_2022_2024_TEST_2025 | Accounts=INDEPENDENT_PER_FOLD_PHASE"
      );

      logger.Info(
         "ResearchValidationGate | Candidate=B1_BREAKOUT_EXPANSION | RequiredTestFolds=3 | PositiveTestFoldsRequired=3 | AggregateExpectancy_GT_0=YES | AggregatePF_GT_1=YES | AggregateCumR_GT_0=YES | WorstFoldExpectancy_GE_0=YES | MinResolvedTradesPerTestFold=30"
      );

      logger.Warning(
         "METHODOLOGY: B1 rules are frozen before viewing B1 results. If B1 fails, archive it; do not tune its thresholds using TEST folds."
      );

      logger.Warning(
         "METHODOLOGY: 2022-2025 are already inspected AQF research data. B1 walk-forward results are retrospective diagnostics, not pristine OOS proof."
      );

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
         market.Symbol == "" ||
         market.Time <= 0 ||
         market.Bid <= 0.0 ||
         market.Ask <= 0.0)
      {
         return;
      }

      //------------------------------------------------------------
      // Virtual exits and strict phase boundaries are checked on
      // every market tick.
      //------------------------------------------------------------

      for(int slot = 0;
          slot < AQF_B1_WF_SLOT_COUNT;
          slot++)
      {
         UpdatePosition(
            slot,
            market,
            logger
         );
      }

      //------------------------------------------------------------
      // Candidate signal is evaluated only once per NEW candle.
      //------------------------------------------------------------

      datetime currentBarTime =
         iTime(
            market.Symbol,
            market.Timeframe,
            0
         );

      if(currentBarTime <= 0)
         return;

      if(m_lastObservedBarTime == 0)
      {
         m_lastObservedBarTime =
            currentBarTime;

         return;
      }

      if(currentBarTime ==
         m_lastObservedBarTime)
      {
         return;
      }

      m_lastObservedBarTime =
         currentBarTime;

      EvaluateNewBar(
         market,
         currentBarTime,
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

      RightCensorAnyOpenPositions(
         logger
      );

      ReportAllStats(
         logger
      );

      ReportAllDegradation(
         logger
      );

      ReportAggregateAndGate(
         logger
      );

      m_initialized =
         false;
   }

private:

   //==============================================================
   // New-bar hypothesis evaluation
   //==============================================================
   void EvaluateNewBar(
      const CAQFMarketSnapshot &market,
      const datetime eventTime,
      CAQFLogger &logger)
   {
      //------------------------------------------------------------
      // Need:
      // rates[0]     = breakout bar (last completed bar)
      // rates[1..20] = prior channel + prior ATR20 bars
      // rates[21]    = previous close for TR of rates[20]
      //------------------------------------------------------------

      const int requiredBars =
         22;

      MqlRates rates[];

      ArraySetAsSeries(
         rates,
         true
      );

      int copied =
         CopyRates(
            market.Symbol,
            market.Timeframe,
            1,
            requiredBars,
            rates
         );

      bool featureFailure =
         (
            copied !=
            requiredBars
         );

      bool rawBreakout =
         false;

      bool expansionPassed =
         false;

      ENUM_AQF_SIGNAL_DIRECTION direction =
         AQF_SIGNAL_NONE;

      double priorATR20 =
         0.0;

      double breakoutTR =
         0.0;

      double expansionRatio =
         0.0;

      if(!featureFailure)
      {
         double highestHigh =
            rates[1].high;

         double lowestLow =
            rates[1].low;

         for(int i = 2;
             i <= m_channelLookback;
             i++)
         {
            if(rates[i].high >
               highestHigh)
            {
               highestHigh =
                  rates[i].high;
            }

            if(rates[i].low <
               lowestLow)
            {
               lowestLow =
                  rates[i].low;
            }
         }

         if(rates[0].close >
            highestHigh)
         {
            rawBreakout =
               true;

            direction =
               AQF_SIGNAL_BUY;
         }
         else if(rates[0].close <
                 lowestLow)
         {
            rawBreakout =
               true;

            direction =
               AQF_SIGNAL_SELL;
         }

         double trSum =
            0.0;

         for(int i = 1;
             i <= m_atrLookback;
             i++)
         {
            trSum +=
               TrueRange(
                  rates[i],
                  rates[i + 1].close
               );
         }

         priorATR20 =
            trSum /
            (double)m_atrLookback;

         breakoutTR =
            TrueRange(
               rates[0],
               rates[1].close
            );

         if(priorATR20 <= 0.0)
         {
            featureFailure =
               true;
         }
         else
         {
            expansionRatio =
               breakoutTR /
               priorATR20;

            expansionPassed =
               (
                  rawBreakout &&
                  expansionRatio >=
                  m_minExpansionTRToATR
               );
         }
      }

      //------------------------------------------------------------
      // Same historical event can belong to TRAIN in multiple
      // anchored folds. Every slot owns an independent account.
      //------------------------------------------------------------

      for(int slot = 0;
          slot < AQF_B1_WF_SLOT_COUNT;
          slot++)
      {
         if(eventTime <
               m_slotStart[slot] ||
            eventTime >=
               m_slotEnd[slot])
         {
            continue;
         }

         m_stats[slot].BarsEvaluated++;

         if(featureFailure)
         {
            m_stats[slot].FeatureFailures++;
            continue;
         }

         if(!rawBreakout)
            continue;

         m_stats[slot].RawBreakouts++;

         if(!expansionPassed)
         {
            m_stats[slot].ExpansionRejected++;
            continue;
         }

         m_stats[slot].Eligible++;

         if(m_positions[slot].Active)
         {
            m_stats[slot].SkippedActive++;
            continue;
         }

         double stopDistance =
            priorATR20 *
            m_stopATRMultiple;

         if(stopDistance <= 0.0)
         {
            m_stats[slot].FeatureFailures++;
            continue;
         }

         OpenPosition(
            slot,
            market,
            direction,
            stopDistance
         );

         m_stats[slot].Opened++;

         logger.Debug(
            "B1Open" +
            " | Fold=" +
            FoldText(
               m_slotFold[slot]) +
            " | Phase=" +
            PhaseText(
               m_slotPhase[slot]) +
            " | Direction=" +
            AQFSignalDirectionToString(
               direction) +
            " | ATR20=" +
            DoubleToString(
               priorATR20,
               5) +
            " | BreakoutTR=" +
            DoubleToString(
               breakoutTR,
               5) +
            " | ExpansionRatio=" +
            DoubleToString(
               expansionRatio,
               3)
         );
      }
   }

   double TrueRange(
      const MqlRates &bar,
      const double previousClose)
   {
      double rangeHL =
         bar.high -
         bar.low;

      double rangeHC =
         MathAbs(
            bar.high -
            previousClose
         );

      double rangeLC =
         MathAbs(
            bar.low -
            previousClose
         );

      return
         MathMax(
            rangeHL,
            MathMax(
               rangeHC,
               rangeLC
            )
         );
   }

   //==============================================================
   // Virtual position
   //==============================================================
   void OpenPosition(
      const int slot,
      const CAQFMarketSnapshot &market,
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const double stopDistance)
   {
      ResetPosition(
         m_positions[slot]
      );

      m_positions[slot].Active =
         true;

      m_positions[slot].Symbol =
         market.Symbol;

      m_positions[slot].Direction =
         direction;

      m_positions[slot].StopDistance =
         stopDistance;

      if(direction ==
         AQF_SIGNAL_BUY)
      {
         m_positions[slot].EntryPrice =
            market.Ask;

         m_positions[slot].StopLoss =
            market.Ask -
            stopDistance;

         m_positions[slot].TakeProfit =
            market.Ask +
            stopDistance *
            m_targetR;
      }
      else
      {
         m_positions[slot].EntryPrice =
            market.Bid;

         m_positions[slot].StopLoss =
            market.Bid +
            stopDistance;

         m_positions[slot].TakeProfit =
            market.Bid -
            stopDistance *
            m_targetR;
      }
   }

   void UpdatePosition(
      const int slot,
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!m_positions[slot].Active)
         return;

      //------------------------------------------------------------
      // Anti-leakage boundary rule.
      //------------------------------------------------------------

      if(market.Time >=
         m_slotEnd[slot])
      {
         m_stats[slot].BoundaryCensored++;

         logger.Debug(
            "B1BoundaryCensor" +
            " | Fold=" +
            FoldText(
               m_slotFold[slot]) +
            " | Phase=" +
            PhaseText(
               m_slotPhase[slot])
         );

         ResetPosition(
            m_positions[slot]
         );

         return;
      }

      if(market.Time <
         m_slotStart[slot])
      {
         return;
      }

      if(m_positions[slot].Symbol !=
         market.Symbol)
      {
         return;
      }

      bool targetReached =
         false;

      bool stopReached =
         false;

      if(m_positions[slot].Direction ==
         AQF_SIGNAL_BUY)
      {
         targetReached =
            (
               market.Bid >=
               m_positions[slot].TakeProfit
            );

         stopReached =
            (
               market.Bid <=
               m_positions[slot].StopLoss
            );
      }
      else
      {
         targetReached =
            (
               market.Ask <=
               m_positions[slot].TakeProfit
            );

         stopReached =
            (
               market.Ask >=
               m_positions[slot].StopLoss
            );
      }

      //------------------------------------------------------------
      // Same barrier priority used throughout AQF virtual research:
      // TP first, then SL, on the executable side of the market.
      //------------------------------------------------------------

      if(targetReached)
      {
         Resolve(
            slot,
            m_targetR,
            logger
         );

         return;
      }

      if(stopReached)
      {
         Resolve(
            slot,
            -1.0,
            logger
         );

         return;
      }
   }

   void Resolve(
      const int slot,
      const double resultR,
      CAQFLogger &logger)
   {
      if(resultR > 0.0)
      {
         m_stats[slot].Wins++;

         m_stats[slot].GrossProfitR +=
            resultR;
      }
      else
      {
         m_stats[slot].Losses++;

         m_stats[slot].GrossLossR +=
            -resultR;
      }

      m_stats[slot].CumulativeR +=
         resultR;

      if(m_stats[slot].CumulativeR >
         m_stats[slot].PeakR)
      {
         m_stats[slot].PeakR =
            m_stats[slot].CumulativeR;
      }

      double drawdown =
         m_stats[slot].PeakR -
         m_stats[slot].CumulativeR;

      if(drawdown >
         m_stats[slot].MaxDrawdownR)
      {
         m_stats[slot].MaxDrawdownR =
            drawdown;
      }

      logger.Debug(
         "B1Close" +
         " | Fold=" +
         FoldText(
            m_slotFold[slot]) +
         " | Phase=" +
         PhaseText(
            m_slotPhase[slot]) +
         " | ResultR=" +
         DoubleToString(
            resultR,
            2) +
         "R"
      );

      ResetPosition(
         m_positions[slot]
      );
   }

   void RightCensorAnyOpenPositions(
      CAQFLogger &logger)
   {
      for(int slot = 0;
          slot < AQF_B1_WF_SLOT_COUNT;
          slot++)
      {
         if(!m_positions[slot].Active)
            continue;

         m_stats[slot].BoundaryCensored++;

         logger.Debug(
            "B1ShutdownRightCensor" +
            " | Fold=" +
            FoldText(
               m_slotFold[slot]) +
            " | Phase=" +
            PhaseText(
               m_slotPhase[slot])
         );

         ResetPosition(
            m_positions[slot]
         );
      }
   }

   //==============================================================
   // Walk-forward slot configuration
   //==============================================================
   void ConfigureSlots()
   {
      ConfigureSlot(
         SlotIndex(
            0,
            AQF_B1_WF_TRAIN),
         0,
         AQF_B1_WF_TRAIN,
         D'2022.01.01 00:00',
         D'2023.01.01 00:00'
      );

      ConfigureSlot(
         SlotIndex(
            0,
            AQF_B1_WF_TEST),
         0,
         AQF_B1_WF_TEST,
         D'2023.01.01 00:00',
         D'2024.01.01 00:00'
      );

      ConfigureSlot(
         SlotIndex(
            1,
            AQF_B1_WF_TRAIN),
         1,
         AQF_B1_WF_TRAIN,
         D'2022.01.01 00:00',
         D'2024.01.01 00:00'
      );

      ConfigureSlot(
         SlotIndex(
            1,
            AQF_B1_WF_TEST),
         1,
         AQF_B1_WF_TEST,
         D'2024.01.01 00:00',
         D'2025.01.01 00:00'
      );

      ConfigureSlot(
         SlotIndex(
            2,
            AQF_B1_WF_TRAIN),
         2,
         AQF_B1_WF_TRAIN,
         D'2022.01.01 00:00',
         D'2025.01.01 00:00'
      );

      ConfigureSlot(
         SlotIndex(
            2,
            AQF_B1_WF_TEST),
         2,
         AQF_B1_WF_TEST,
         D'2025.01.01 00:00',
         D'2026.01.01 00:00'
      );
   }

   void ConfigureSlot(
      const int slot,
      const int fold,
      const ENUM_AQF_B1_WF_PHASE phase,
      const datetime startTime,
      const datetime endTime)
   {
      if(slot < 0 ||
         slot >= AQF_B1_WF_SLOT_COUNT)
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
      const ENUM_AQF_B1_WF_PHASE phase)
   {
      return
         fold *
         AQF_B1_WF_PHASE_COUNT +
         (int)phase;
   }

   //==============================================================
   // Reports
   //==============================================================
   void ReportAllStats(
      CAQFLogger &logger)
   {
      for(int fold = 0;
          fold < AQF_B1_WF_FOLD_COUNT;
          fold++)
      {
         for(int phase = 0;
             phase < AQF_B1_WF_PHASE_COUNT;
             phase++)
         {
            int slot =
               SlotIndex(
                  fold,
                  (ENUM_AQF_B1_WF_PHASE)phase
               );

            long resolved =
               Resolved(
                  m_stats[slot]
               );

            double winRate =
               0.0;

            if(resolved > 0)
            {
               winRate =
                  100.0 *
                  (double)m_stats[slot].Wins /
                  (double)resolved;
            }

            logger.Info(
               "ResearchCandidateStats" +
               " | Candidate=B1_BREAKOUT_EXPANSION" +
               " | Fold=" +
               FoldText(
                  fold) +
               " | Phase=" +
               PhaseText(
                  (ENUM_AQF_B1_WF_PHASE)phase) +
               " | Period=" +
               PeriodText(
                  fold,
                  (ENUM_AQF_B1_WF_PHASE)phase) +
               " | BarsEvaluated=" +
               IntegerToString(
                  (int)m_stats[slot].BarsEvaluated) +
               " | FeatureFailures=" +
               IntegerToString(
                  (int)m_stats[slot].FeatureFailures) +
               " | RawBreakouts=" +
               IntegerToString(
                  (int)m_stats[slot].RawBreakouts) +
               " | ExpansionRejected=" +
               IntegerToString(
                  (int)m_stats[slot].ExpansionRejected) +
               " | Eligible=" +
               IntegerToString(
                  (int)m_stats[slot].Eligible) +
               " | Opened=" +
               IntegerToString(
                  (int)m_stats[slot].Opened) +
               " | SkippedActive=" +
               IntegerToString(
                  (int)m_stats[slot].SkippedActive) +
               " | BoundaryCensored=" +
               IntegerToString(
                  (int)m_stats[slot].BoundaryCensored) +
               " | Resolved=" +
               IntegerToString(
                  (int)resolved) +
               " | Wins=" +
               IntegerToString(
                  (int)m_stats[slot].Wins) +
               " | Losses=" +
               IntegerToString(
                  (int)m_stats[slot].Losses) +
               " | WinRate=" +
               DoubleToString(
                  winRate,
                  2) +
               "%" +
               " | Expectancy=" +
               DoubleToString(
                  Expectancy(
                     m_stats[slot]),
                  3) +
               "R" +
               " | PF=" +
               ProfitFactorText(
                  m_stats[slot]) +
               " | CumR=" +
               DoubleToString(
                  m_stats[slot].CumulativeR,
                  2) +
               "R" +
               " | MaxDD=" +
               DoubleToString(
                  m_stats[slot].MaxDrawdownR,
                  2) +
               "R"
            );
         }
      }
   }

   void ReportAllDegradation(
      CAQFLogger &logger)
   {
      for(int fold = 0;
          fold < AQF_B1_WF_FOLD_COUNT;
          fold++)
      {
         int trainSlot =
            SlotIndex(
               fold,
               AQF_B1_WF_TRAIN
            );

         int testSlot =
            SlotIndex(
               fold,
               AQF_B1_WF_TEST
            );

         double trainExp =
            Expectancy(
               m_stats[trainSlot]
            );

         double testExp =
            Expectancy(
               m_stats[testSlot]
            );

         logger.Info(
            "ResearchCandidateDegradation" +
            " | Candidate=B1_BREAKOUT_EXPANSION" +
            " | Fold=" +
            FoldText(
               fold) +
            " | Train_N=" +
            IntegerToString(
               (int)Resolved(
                  m_stats[trainSlot])) +
            " | Train_Expectancy=" +
            DoubleToString(
               trainExp,
               3) +
            "R" +
            " | Train_PF=" +
            ProfitFactorText(
               m_stats[trainSlot]) +
            " | Test_N=" +
            IntegerToString(
               (int)Resolved(
                  m_stats[testSlot])) +
            " | Test_Expectancy=" +
            DoubleToString(
               testExp,
               3) +
            "R" +
            " | Test_PF=" +
            ProfitFactorText(
               m_stats[testSlot]) +
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

   void ReportAggregateAndGate(
      CAQFLogger &logger)
   {
      int foldsWithTrades =
         0;

      int positiveTestFolds =
         0;

      int minResolvedTrades =
         0;

      bool firstFoldWithTrades =
         true;

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

      double worstFoldExpectancy =
         0.0;

      double bestFoldExpectancy =
         0.0;

      double worstFoldMaxDD =
         0.0;

      for(int fold = 0;
          fold < AQF_B1_WF_FOLD_COUNT;
          fold++)
      {
         int slot =
            SlotIndex(
               fold,
               AQF_B1_WF_TEST
            );

         long resolved =
            Resolved(
               m_stats[slot]
            );

         if(resolved <= 0)
            continue;

         double foldExp =
            Expectancy(
               m_stats[slot]
            );

         foldsWithTrades++;

         if(foldExp > 0.0)
            positiveTestFolds++;

         totalResolved +=
            resolved;

         totalWins +=
            m_stats[slot].Wins;

         totalLosses +=
            m_stats[slot].Losses;

         totalR +=
            m_stats[slot].CumulativeR;

         totalGrossProfit +=
            m_stats[slot].GrossProfitR;

         totalGrossLoss +=
            m_stats[slot].GrossLossR;

         if(firstFoldWithTrades)
         {
            minResolvedTrades =
               (int)resolved;

            worstFoldExpectancy =
               foldExp;

            bestFoldExpectancy =
               foldExp;

            worstFoldMaxDD =
               m_stats[slot].MaxDrawdownR;

            firstFoldWithTrades =
               false;
         }
         else
         {
            if(resolved <
               minResolvedTrades)
            {
               minResolvedTrades =
                  (int)resolved;
            }

            if(foldExp <
               worstFoldExpectancy)
            {
               worstFoldExpectancy =
                  foldExp;
            }

            if(foldExp >
               bestFoldExpectancy)
            {
               bestFoldExpectancy =
                  foldExp;
            }

            if(m_stats[slot].MaxDrawdownR >
               worstFoldMaxDD)
            {
               worstFoldMaxDD =
                  m_stats[slot].MaxDrawdownR;
            }
         }
      }

      double aggregateWinRate =
         0.0;

      double aggregateExpectancy =
         0.0;

      if(totalResolved > 0)
      {
         aggregateWinRate =
            100.0 *
            (double)totalWins /
            (double)totalResolved;

         aggregateExpectancy =
            totalR /
            (double)totalResolved;
      }

      double aggregatePF =
         0.0;

      string aggregatePFText =
         "0.000";

      if(totalGrossLoss <= 0.0)
      {
         if(totalGrossProfit > 0.0)
         {
            aggregatePF =
               DBL_MAX;

            aggregatePFText =
               "INF";
         }
      }
      else
      {
         aggregatePF =
            totalGrossProfit /
            totalGrossLoss;

         aggregatePFText =
            DoubleToString(
               aggregatePF,
               3
            );
      }

      logger.Info(
         "ResearchCandidateTestAggregate" +
         " | Candidate=B1_BREAKOUT_EXPANSION" +
         " | TestFoldsWithTrades=" +
         IntegerToString(
            foldsWithTrades) +
         " | PositiveTestFolds=" +
         IntegerToString(
            positiveTestFolds) +
         " | MinResolvedTradesAnyTestFold=" +
         IntegerToString(
            minResolvedTrades) +
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
            aggregateExpectancy,
            3) +
         "R" +
         " | AggregatePF=" +
         aggregatePFText +
         " | AggregateCumR=" +
         DoubleToString(
            totalR,
            2) +
         "R" +
         " | WorstFoldExpectancy=" +
         DoubleToString(
            worstFoldExpectancy,
            3) +
         "R" +
         " | BestFoldExpectancy=" +
         DoubleToString(
            bestFoldExpectancy,
            3) +
         "R" +
         " | WorstFoldMaxDD=" +
         DoubleToString(
            worstFoldMaxDD,
            2) +
         "R"
      );

      SAQFValidationGateResult gateResult =
         m_validationGate.EvaluateWalkForward(
            foldsWithTrades,
            positiveTestFolds,
            minResolvedTrades,
            aggregateExpectancy,
            aggregatePF,
            totalR,
            worstFoldExpectancy
         );

      logger.Info(
         "ResearchCandidateGate" +
         " | Candidate=B1_BREAKOUT_EXPANSION" +
         " | Stage=WALK_FORWARD" +
         " | Result=" +
         m_validationGate.ResultText(
            gateResult) +
         " | Promotion=" +
         m_validationGate.PromotionText(
            gateResult) +
         " | PassedRules=" +
         IntegerToString(
            gateResult.PassedRules) +
         "/7" +
         " | FailedRules=" +
         IntegerToString(
            gateResult.FailedRules) +
         " | TestFoldsWithTrades=" +
         IntegerToString(
            foldsWithTrades) +
         "/3" +
         " | PositiveTestFolds=" +
         IntegerToString(
            positiveTestFolds) +
         "/3" +
         " | MinResolvedTradesAnyTestFold=" +
         IntegerToString(
            minResolvedTrades) +
         " | AggregateExpectancy=" +
         DoubleToString(
            aggregateExpectancy,
            3) +
         "R" +
         " | AggregatePF=" +
         aggregatePFText +
         " | AggregateCumR=" +
         DoubleToString(
            totalR,
            2) +
         "R" +
         " | WorstFoldExpectancy=" +
         DoubleToString(
            worstFoldExpectancy,
            3) +
         "R" +
         " | FailReasons=" +
         m_validationGate.FailReasons(
            gateResult)
      );
   }

   //==============================================================
   // Metric helpers
   //==============================================================
   long Resolved(
      const SAQFB1Stats &stats)
   {
      return
         stats.Wins +
         stats.Losses;
   }

   double Expectancy(
      const SAQFB1Stats &stats)
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
      const SAQFB1Stats &stats)
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
      const ENUM_AQF_B1_WF_PHASE phase)
   {
      if(phase ==
         AQF_B1_WF_TRAIN)
      {
         return "TRAIN";
      }

      if(phase ==
         AQF_B1_WF_TEST)
      {
         return "TEST";
      }

      return "UNKNOWN";
   }

   string PeriodText(
      const int fold,
      const ENUM_AQF_B1_WF_PHASE phase)
   {
      if(fold == 0 &&
         phase == AQF_B1_WF_TRAIN)
      {
         return "2022";
      }

      if(fold == 0 &&
         phase == AQF_B1_WF_TEST)
      {
         return "2023";
      }

      if(fold == 1 &&
         phase == AQF_B1_WF_TRAIN)
      {
         return "2022-2023";
      }

      if(fold == 1 &&
         phase == AQF_B1_WF_TEST)
      {
         return "2024";
      }

      if(fold == 2 &&
         phase == AQF_B1_WF_TRAIN)
      {
         return "2022-2024";
      }

      if(fold == 2 &&
         phase == AQF_B1_WF_TEST)
      {
         return "2025";
      }

      return "UNKNOWN";
   }

   //==============================================================
   // Reset helpers
   //==============================================================
   void ResetPosition(
      SAQFB1Position &position)
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
      SAQFB1Stats &stats)
   {
      stats.BarsEvaluated =
         0;

      stats.FeatureFailures =
         0;

      stats.RawBreakouts =
         0;

      stats.ExpansionRejected =
         0;

      stats.Eligible =
         0;

      stats.Opened =
         0;

      stats.SkippedActive =
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
          slot < AQF_B1_WF_SLOT_COUNT;
          slot++)
      {
         ResetPosition(
            m_positions[slot]
         );

         ResetStats(
            m_stats[slot]
         );
      }
   }
};

#endif
