#ifndef __AQF_H3_PAIRED_DIRECTIONAL_RANDOMIZATION_SIMULATOR_MQH__
#define __AQF_H3_PAIRED_DIRECTIONAL_RANDOMIZATION_SIMULATOR_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"
#include "ValidationSplit.mqh"
#include "DeterministicRNG.mqh"

//+------------------------------------------------------------------+
//| H3 Paired Directional Randomization                              |
//| Sprint 11B - Validation Layer v0.11.2                            |
//|                                                                  |
//| PURPOSE                                                          |
//| - Reproduce the FROZEN H3 sequential entry stream independently. |
//| - For every H3 OPENED event, create a paired counterfactual:     |
//|     BUY from the same event                                      |
//|     SELL from the same event                                     |
//| - Same StopDistance, SL=1.00R, TP=1.50R.                        |
//| - Original H3 side uses request.EntryPrice exactly.              |
//| - Opposite side uses executable market quote at the same event.  |
//| - Paired legs are allowed to overlap after the original H3 trade |
//|   closes; this is intentional because the statistical unit is    |
//|   the H3 ENTRY EVENT, not a sequential random account.            |
//|                                                                  |
//| RANDOMIZATION TEST                                               |
//| - Uses only COMPLETE pairs.                                      |
//| - Each Monte Carlo run selects BUY or SELL 50/50 for every pair. |
//| - N is therefore exactly the number of complete H3 entry events. |
//| - Reports empirical P(random total >= observed H3 total).        |
//| - MaxDD is computed in H3 ENTRY-EVENT ORDER.                     |
//|                                                                  |
//| IMPORTANT LIMITATION                                             |
//| H3 eligibility itself contains a direction-conditioned feature  |
//| (DirectionalER10). Therefore this test asks:                     |
//| "conditional on the exact H3-qualified event set, does executing |
//|  H3's chosen direction outperform a 50/50 direction assignment?" |
//| It does NOT remove the historical data-snooping that selected H3.|
//|                                                                  |
//| VIRTUAL ONLY. NO OrderSend.                                      |
//+------------------------------------------------------------------+

struct SAQFPairedReplayPosition
{
   bool Active;

   string Symbol;
   ENUM_AQF_SIGNAL_DIRECTION Direction;

   double EntryPrice;
   double StopLoss;
   double StopDistance;
   double TakeProfit;

   int PairIndex;
};

struct SAQFPairedTrade
{
   bool Valid;

   string Symbol;
   ENUM_AQF_SIGNAL_DIRECTION OriginalDirection;

   double StopDistance;

   double BuyEntry;
   double BuyStop;
   double BuyTarget;

   double SellEntry;
   double SellStop;
   double SellTarget;

   bool BuyActive;
   bool SellActive;

   bool BuyResolved;
   bool SellResolved;

   double BuyResultR;
   double SellResultR;

   bool ReplayResolved;
   double ReplayResultR;
};

struct SAQFPairedValidationStats
{
   long SignalsSeen;

   long H2Rejected;
   long FeatureFailures;
   long C1Rejected;
   long C3Rejected;

   long Eligible;
   long Opened;
   long SkippedActive;

   long Resolved;
   long Wins;
   long Losses;

   double GrossProfitR;
   double GrossLossR;

   double CumulativeR;
   double PeakR;
   double MaxDrawdownR;

   long PairCreated;
   long PairComplete;
   long PairReplayMismatch;
};

class CAQFH3PairedDirectionalRandomizationSimulator
{
private:

   CAQFDeterministicRNG m_rng;

   SAQFPairedReplayPosition m_isReplay;
   SAQFPairedReplayPosition m_oosReplay;

   SAQFPairedValidationStats m_isStats;
   SAQFPairedValidationStats m_oosStats;

   SAQFPairedTrade m_isPairs[];
   SAQFPairedTrade m_oosPairs[];

   double m_targetR;

   double m_minATRPercent;
   double m_minADX;
   double m_maxADX;

   double m_minDirectionalER10;
   double m_minVolumeZ20;
   double m_maxVolumeZ20;

   int m_randomizationRuns;

   uint m_seedIS;
   uint m_seedOOS;

   bool m_initialized;

public:

   CAQFH3PairedDirectionalRandomizationSimulator()
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

      m_randomizationRuns =
         5000;

      m_seedIS =
         11122022;

      m_seedOOS =
         11122025;

      m_initialized =
         false;

      ResetAll();
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(
      CAQFLogger &logger)
   {
      ResetAll();

      m_initialized =
         true;

      logger.Info(
         "H3PairedDirectionalRandomizationSimulator initialized."
      );

      logger.Info(
         "PairedDirectionalTest | FROZEN H3 eligibility | every H3 OPENED event spawns BUY+SELL counterfactual legs | same StopDistance | TP=1.50R | SL=1.00R"
      );

      logger.Info(
         "PairedDirectionalTest | 5000 fixed-seed 50/50 direction randomizations | RNG=xorshift32-high-bit-v0.11.3 | constant N per complete pair set | empirical P=random total >= observed H3 total"
      );

      logger.Warning(
         "METHODOLOGY: H3 eligibility includes direction-conditioned DirER10. This test is conditional on the already-selected H3 event set and does not erase prior data snooping."
      );

      return true;
   }

   //==============================================================
   // Register executable-quality opportunity
   //==============================================================
   bool Register(
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market,
      const ENUM_AQF_VALIDATION_SEGMENT segment,
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return false;

      if(segment !=
            AQF_VALIDATION_IN_SAMPLE &&
         segment !=
            AQF_VALIDATION_OOS_RETROSPECTIVE)
      {
         return true;
      }

      if(!request.Valid ||
         !market.Valid ||
         request.Symbol == "" ||
         request.Symbol !=
         market.Symbol ||
         request.EntryPrice <= 0.0 ||
         request.StopLoss <= 0.0 ||
         request.StopDistance <= 0.0 ||
         market.Bid <= 0.0 ||
         market.Ask <= 0.0)
      {
         return false;
      }

      if(request.Direction !=
            AQF_SIGNAL_BUY &&
         request.Direction !=
            AQF_SIGNAL_SELL)
      {
         return false;
      }

      if(segment ==
         AQF_VALIDATION_IN_SAMPLE)
      {
         return
            RegisterSegment(
               m_isReplay,
               m_isStats,
               m_isPairs,
               "IN_SAMPLE",
               request,
               market,
               logger
            );
      }

      return
         RegisterSegment(
            m_oosReplay,
            m_oosStats,
            m_oosPairs,
            "OOS_RETROSPECTIVE",
            request,
            market,
            logger
         );
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
         market.Bid <= 0.0 ||
         market.Ask <= 0.0)
      {
         return;
      }

      UpdateReplay(
         m_isReplay,
         m_isStats,
         m_isPairs,
         "IN_SAMPLE",
         market,
         logger
      );

      UpdateReplay(
         m_oosReplay,
         m_oosStats,
         m_oosPairs,
         "OOS_RETROSPECTIVE",
         market,
         logger
      );

      UpdatePairs(
         m_isPairs,
         m_isStats,
         "IN_SAMPLE",
         market,
         logger
      );

      UpdatePairs(
         m_oosPairs,
         m_oosStats,
         "OOS_RETROSPECTIVE",
         market,
         logger
      );
   }

   //==============================================================
   // Shutdown reports
   //==============================================================
   void Shutdown(
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return;

      ReportReplay(
         "IN_SAMPLE",
         m_isReplay,
         m_isStats,
         logger
      );

      ReportReplay(
         "OOS_RETROSPECTIVE",
         m_oosReplay,
         m_oosStats,
         logger
      );

      ReportPairsAndRandomization(
         "IN_SAMPLE",
         m_isPairs,
         m_isStats,
         m_randomizationRuns,
         m_seedIS,
         logger
      );

      ReportPairsAndRandomization(
         "OOS_RETROSPECTIVE",
         m_oosPairs,
         m_oosStats,
         m_randomizationRuns,
         m_seedOOS,
         logger
      );

      m_initialized =
         false;
   }

private:

   //==============================================================
   // Segment registration - exact frozen H3 gate
   //==============================================================
   bool RegisterSegment(
      SAQFPairedReplayPosition &replay,
      SAQFPairedValidationStats &stats,
      SAQFPairedTrade &pairs[],
      const string segmentText,
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      stats.SignalsSeen++;

      //------------------------------------------------------------
      // Frozen H2 gate
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
         stats.H2Rejected++;
         return true;
      }

      //------------------------------------------------------------
      // Frozen H3 features from completed bars
      //------------------------------------------------------------

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
         stats.FeatureFailures++;
         return true;
      }

      if(directionalER10 <
         m_minDirectionalER10)
      {
         stats.C1Rejected++;
         return true;
      }

      if(
         volumeZScore20 <
         m_minVolumeZ20
         ||
         volumeZScore20 >=
         m_maxVolumeZ20
      )
      {
         stats.C3Rejected++;
         return true;
      }

      stats.Eligible++;

      //------------------------------------------------------------
      // Exact H3 one-position sequential gate
      //------------------------------------------------------------

      if(replay.Active)
      {
         stats.SkippedActive++;
         return true;
      }

      int pairIndex =
         CreatePair(
            pairs,
            request,
            market
         );

      if(pairIndex < 0)
      {
         logger.Error(
            "PairedDirectionalTest pair allocation failed."
         );

         return false;
      }

      OpenReplay(
         replay,
         request,
         pairIndex
      );

      stats.Opened++;
      stats.PairCreated++;

      logger.Debug(
         "PairedH3Open" +
         " | Segment=" +
         segmentText +
         " | PairIndex=" +
         IntegerToString(
            pairIndex) +
         " | OriginalDirection=" +
         AQFSignalDirectionToString(
            request.Direction)
      );

      return true;
   }

   //==============================================================
   // Create BUY/SELL counterfactual pair
   //==============================================================
   int CreatePair(
      SAQFPairedTrade &pairs[],
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market)
   {
      int index =
         ArraySize(
            pairs
         );

      if(ArrayResize(
            pairs,
            index + 1) !=
         index + 1)
      {
         return -1;
      }

      ResetPair(
         pairs[index]
      );

      pairs[index].Valid =
         true;

      pairs[index].Symbol =
         request.Symbol;

      pairs[index].OriginalDirection =
         request.Direction;

      pairs[index].StopDistance =
         request.StopDistance;

      //------------------------------------------------------------
      // Preserve request.EntryPrice EXACTLY for the original side.
      // The counterfactual side enters at the executable quote from
      // the same event.
      //------------------------------------------------------------

      if(request.Direction ==
         AQF_SIGNAL_BUY)
      {
         pairs[index].BuyEntry =
            request.EntryPrice;

         pairs[index].SellEntry =
            market.Bid;
      }
      else
      {
         pairs[index].SellEntry =
            request.EntryPrice;

         pairs[index].BuyEntry =
            market.Ask;
      }

      pairs[index].BuyStop =
         pairs[index].BuyEntry -
         request.StopDistance;

      pairs[index].BuyTarget =
         pairs[index].BuyEntry +
         request.StopDistance *
         m_targetR;

      pairs[index].SellStop =
         pairs[index].SellEntry +
         request.StopDistance;

      pairs[index].SellTarget =
         pairs[index].SellEntry -
         request.StopDistance *
         m_targetR;

      pairs[index].BuyActive =
         true;

      pairs[index].SellActive =
         true;

      return
         index;
   }

   //==============================================================
   // Open exact H3 replay position
   //==============================================================
   void OpenReplay(
      SAQFPairedReplayPosition &replay,
      const CAQFTradeRequest &request,
      const int pairIndex)
   {
      ResetReplay(
         replay
      );

      replay.Active =
         true;

      replay.Symbol =
         request.Symbol;

      replay.Direction =
         request.Direction;

      replay.EntryPrice =
         request.EntryPrice;

      replay.StopLoss =
         request.StopLoss;

      replay.StopDistance =
         request.StopDistance;

      replay.PairIndex =
         pairIndex;

      double targetDistance =
         request.StopDistance *
         m_targetR;

      if(request.Direction ==
         AQF_SIGNAL_BUY)
      {
         replay.TakeProfit =
            request.EntryPrice +
            targetDistance;
      }
      else
      {
         replay.TakeProfit =
            request.EntryPrice -
            targetDistance;
      }
   }

   //==============================================================
   // Exact H3 replay tick update
   //==============================================================
   void UpdateReplay(
      SAQFPairedReplayPosition &replay,
      SAQFPairedValidationStats &stats,
      SAQFPairedTrade &pairs[],
      const string segmentText,
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!replay.Active ||
         replay.Symbol !=
         market.Symbol)
      {
         return;
      }

      bool targetReached =
         false;

      bool stopReached =
         false;

      if(replay.Direction ==
         AQF_SIGNAL_BUY)
      {
         targetReached =
            (
               market.Bid >=
               replay.TakeProfit
            );

         stopReached =
            (
               market.Bid <=
               replay.StopLoss
            );
      }
      else
      {
         targetReached =
            (
               market.Ask <=
               replay.TakeProfit
            );

         stopReached =
            (
               market.Ask >=
               replay.StopLoss
            );
      }

      if(targetReached)
      {
         ResolveReplay(
            replay,
            stats,
            pairs,
            segmentText,
            m_targetR,
            logger
         );

         return;
      }

      if(stopReached)
      {
         ResolveReplay(
            replay,
            stats,
            pairs,
            segmentText,
            -1.0,
            logger
         );

         return;
      }
   }

   //==============================================================
   // Resolve H3 replay
   //==============================================================
   void ResolveReplay(
      SAQFPairedReplayPosition &replay,
      SAQFPairedValidationStats &stats,
      SAQFPairedTrade &pairs[],
      const string segmentText,
      const double resultR,
      CAQFLogger &logger)
   {
      stats.Resolved++;

      if(resultR > 0.0)
      {
         stats.Wins++;
         stats.GrossProfitR +=
            resultR;
      }
      else
      {
         stats.Losses++;
         stats.GrossLossR +=
            -resultR;
      }

      stats.CumulativeR +=
         resultR;

      if(stats.CumulativeR >
         stats.PeakR)
      {
         stats.PeakR =
            stats.CumulativeR;
      }

      double drawdown =
         stats.PeakR -
         stats.CumulativeR;

      if(drawdown >
         stats.MaxDrawdownR)
      {
         stats.MaxDrawdownR =
            drawdown;
      }

      if(replay.PairIndex >= 0 &&
         replay.PairIndex <
         ArraySize(pairs))
      {
         pairs[replay.PairIndex].ReplayResolved =
            true;

         pairs[replay.PairIndex].ReplayResultR =
            resultR;
      }

      logger.Debug(
         "PairedH3ReplayClose" +
         " | Segment=" +
         segmentText +
         " | ResultR=" +
         DoubleToString(
            resultR,
            2) +
         "R"
      );

      ResetReplay(
         replay
      );
   }

   //==============================================================
   // Update all counterfactual legs
   //==============================================================
   void UpdatePairs(
      SAQFPairedTrade &pairs[],
      SAQFPairedValidationStats &stats,
      const string segmentText,
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      int count =
         ArraySize(
            pairs
         );

      for(int i = 0;
          i < count;
          i++)
      {
         if(!pairs[i].Valid ||
            pairs[i].Symbol !=
            market.Symbol)
         {
            continue;
         }

         bool wasComplete =
            (
               pairs[i].BuyResolved &&
               pairs[i].SellResolved
            );

         //---------------------------------------------------------
         // BUY leg exits on Bid
         //---------------------------------------------------------

         if(pairs[i].BuyActive)
         {
            if(market.Bid >=
               pairs[i].BuyTarget)
            {
               pairs[i].BuyActive =
                  false;

               pairs[i].BuyResolved =
                  true;

               pairs[i].BuyResultR =
                  m_targetR;
            }
            else if(market.Bid <=
                    pairs[i].BuyStop)
            {
               pairs[i].BuyActive =
                  false;

               pairs[i].BuyResolved =
                  true;

               pairs[i].BuyResultR =
                  -1.0;
            }
         }

         //---------------------------------------------------------
         // SELL leg exits on Ask
         //---------------------------------------------------------

         if(pairs[i].SellActive)
         {
            if(market.Ask <=
               pairs[i].SellTarget)
            {
               pairs[i].SellActive =
                  false;

               pairs[i].SellResolved =
                  true;

               pairs[i].SellResultR =
                  m_targetR;
            }
            else if(market.Ask >=
                    pairs[i].SellStop)
            {
               pairs[i].SellActive =
                  false;

               pairs[i].SellResolved =
                  true;

               pairs[i].SellResultR =
                  -1.0;
            }
         }

         bool isComplete =
            (
               pairs[i].BuyResolved &&
               pairs[i].SellResolved
            );

         if(!wasComplete &&
            isComplete)
         {
            stats.PairComplete++;

            if(pairs[i].ReplayResolved)
            {
               double pairedOriginal =
                  OriginalResult(
                     pairs[i]
                  );

               if(MathAbs(
                     pairedOriginal -
                     pairs[i].ReplayResultR) >
                  0.0000001)
               {
                  stats.PairReplayMismatch++;

                  logger.Warning(
                     "PairedDirectional replay mismatch" +
                     " | Segment=" +
                     segmentText +
                     " | PairIndex=" +
                     IntegerToString(
                        i) +
                     " | Replay=" +
                     DoubleToString(
                        pairs[i].ReplayResultR,
                        2) +
                     "R" +
                     " | PairOriginal=" +
                     DoubleToString(
                        pairedOriginal,
                        2) +
                     "R"
                  );
               }
            }
         }
      }
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

   //==============================================================
   // Directional efficiency - exact frozen H3 definition
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

      return
         efficiency;
   }

   //==============================================================
   // Replay report
   //==============================================================
   void ReportReplay(
      const string segmentText,
      const SAQFPairedReplayPosition &replay,
      const SAQFPairedValidationStats &stats,
      CAQFLogger &logger)
   {
      double winRate =
         0.0;

      double expectancy =
         0.0;

      if(stats.Resolved > 0)
      {
         winRate =
            100.0 *
            (double)stats.Wins /
            (double)stats.Resolved;

         expectancy =
            stats.CumulativeR /
            (double)stats.Resolved;
      }

      long filterRejected =
         stats.H2Rejected +
         stats.FeatureFailures +
         stats.C1Rejected +
         stats.C3Rejected;

      logger.Info(
         "PairedH3ReplayStats" +
         " | Segment=" +
         segmentText +
         " | Signals=" +
         IntegerToString(
            (int)stats.SignalsSeen) +
         " | FilterRejected=" +
         IntegerToString(
            (int)filterRejected) +
         " | H2Rejected=" +
         IntegerToString(
            (int)stats.H2Rejected) +
         " | FeatureFailures=" +
         IntegerToString(
            (int)stats.FeatureFailures) +
         " | C1Rejected=" +
         IntegerToString(
            (int)stats.C1Rejected) +
         " | C3Rejected=" +
         IntegerToString(
            (int)stats.C3Rejected) +
         " | Eligible=" +
         IntegerToString(
            (int)stats.Eligible) +
         " | Opened=" +
         IntegerToString(
            (int)stats.Opened) +
         " | SkippedActive=" +
         IntegerToString(
            (int)stats.SkippedActive) +
         " | Resolved=" +
         IntegerToString(
            (int)stats.Resolved) +
         " | Wins=" +
         IntegerToString(
            (int)stats.Wins) +
         " | Losses=" +
         IntegerToString(
            (int)stats.Losses) +
         " | Open=" +
         (
            replay.Active
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
            stats) +
         " | CumR=" +
         DoubleToString(
            stats.CumulativeR,
            2) +
         "R" +
         " | MaxDD=" +
         DoubleToString(
            stats.MaxDrawdownR,
            2) +
         "R" +
         " | PairCreated=" +
         IntegerToString(
            (int)stats.PairCreated) +
         " | PairComplete=" +
         IntegerToString(
            (int)stats.PairComplete) +
         " | PairReplayMismatch=" +
         IntegerToString(
            (int)stats.PairReplayMismatch)
      );
   }

   //==============================================================
   // Pair diagnostics + Monte Carlo randomization
   //==============================================================
   void ReportPairsAndRandomization(
      const string segmentText,
      SAQFPairedTrade &pairs[],
      const SAQFPairedValidationStats &stats,
      const int requestedRuns,
      const uint seed,
      CAQFLogger &logger)
   {
      int pairCount =
         ArraySize(
            pairs
         );

      long complete =
         0;

      long unresolved =
         0;

      long originalWins =
         0;

      long originalLosses =
         0;

      long oppositeWins =
         0;

      long oppositeLosses =
         0;

      long bothWin =
         0;

      long bothLoss =
         0;

      long originalOnlyWin =
         0;

      long oppositeOnlyWin =
         0;

      double observedTotalR =
         0.0;

      double oppositeTotalR =
         0.0;

      for(int i = 0;
          i < pairCount;
          i++)
      {
         if(!pairs[i].Valid)
            continue;

         if(!pairs[i].BuyResolved ||
            !pairs[i].SellResolved ||
            !pairs[i].ReplayResolved)
         {
            unresolved++;
            continue;
         }

         complete++;

         double originalR =
            OriginalResult(
               pairs[i]
            );

         double oppositeR =
            OppositeResult(
               pairs[i]
            );

         observedTotalR +=
            originalR;

         oppositeTotalR +=
            oppositeR;

         bool originalWin =
            (
               originalR >
               0.0
            );

         bool oppositeWin =
            (
               oppositeR >
               0.0
            );

         if(originalWin)
            originalWins++;
         else
            originalLosses++;

         if(oppositeWin)
            oppositeWins++;
         else
            oppositeLosses++;

         if(originalWin &&
            oppositeWin)
         {
            bothWin++;
         }
         else if(!originalWin &&
                 !oppositeWin)
         {
            bothLoss++;
         }
         else if(originalWin)
         {
            originalOnlyWin++;
         }
         else
         {
            oppositeOnlyWin++;
         }
      }

      double avgDirectionalAdvantageR =
         0.0;

      if(complete > 0)
      {
         avgDirectionalAdvantageR =
            (
               observedTotalR -
               oppositeTotalR
            )
            /
            (double)complete;
      }

      logger.Info(
         "PairedDirectionalStats" +
         " | Segment=" +
         segmentText +
         " | PairCreated=" +
         IntegerToString(
            pairCount) +
         " | PairComplete=" +
         IntegerToString(
            (int)complete) +
         " | PairUnresolved=" +
         IntegerToString(
            (int)unresolved) +
         " | ReplayMismatch=" +
         IntegerToString(
            (int)stats.PairReplayMismatch) +
         " | OriginalWins=" +
         IntegerToString(
            (int)originalWins) +
         " | OriginalLosses=" +
         IntegerToString(
            (int)originalLosses) +
         " | OppositeWins=" +
         IntegerToString(
            (int)oppositeWins) +
         " | OppositeLosses=" +
         IntegerToString(
            (int)oppositeLosses) +
         " | BothWin=" +
         IntegerToString(
            (int)bothWin) +
         " | BothLoss=" +
         IntegerToString(
            (int)bothLoss) +
         " | OriginalOnlyWin=" +
         IntegerToString(
            (int)originalOnlyWin) +
         " | OppositeOnlyWin=" +
         IntegerToString(
            (int)oppositeOnlyWin) +
         " | ObservedH3Total=" +
         DoubleToString(
            observedTotalR,
            2) +
         "R" +
         " | OppositeTotal=" +
         DoubleToString(
            oppositeTotalR,
            2) +
         "R" +
         " | AvgDirectionalAdvantage=" +
         DoubleToString(
            avgDirectionalAdvantageR,
            3) +
         "R"
      );

      //------------------------------------------------------------
      // Statistical integrity: do NOT silently drop unresolved pairs.
      //------------------------------------------------------------

      if(complete <= 0)
      {
         logger.Info(
            "PairedRandomizationMC" +
            " | Segment=" +
            segmentText +
            " | Status=NO_COMPLETE_PAIRS"
         );

         return;
      }

      if(unresolved > 0 ||
         complete !=
         stats.Resolved ||
         stats.PairReplayMismatch > 0)
      {
         logger.Warning(
            "PairedRandomizationMC skipped" +
            " | Segment=" +
            segmentText +
            " | Reason=INCOMPLETE_OR_UNSYNCED_PAIRS" +
            " | H3Resolved=" +
            IntegerToString(
               (int)stats.Resolved) +
            " | CompletePairs=" +
            IntegerToString(
               (int)complete) +
            " | UnresolvedPairs=" +
            IntegerToString(
               (int)unresolved) +
            " | ReplayMismatch=" +
            IntegerToString(
               (int)stats.PairReplayMismatch)
         );

         return;
      }

      int runs =
         requestedRuns;

      if(runs < 100)
         runs = 100;

      double totalDistribution[];
      double ddDistribution[];

      if(ArrayResize(
            totalDistribution,
            runs) != runs ||
         ArrayResize(
            ddDistribution,
            runs) != runs)
      {
         logger.Error(
            "PairedRandomizationMC allocation failed."
         );

         return;
      }

      uint rngState =
         seed;

      if(rngState == 0)
         rngState = 1;

      long randomGEObserved =
         0;

      for(int run = 0;
          run < runs;
          run++)
      {
         double cumulativeR =
            0.0;

         double peakR =
            0.0;

         double maxDD =
            0.0;

         for(int i = 0;
             i < pairCount;
             i++)
         {
            if(!pairs[i].Valid ||
               !pairs[i].BuyResolved ||
               !pairs[i].SellResolved ||
               !pairs[i].ReplayResolved)
            {
               continue;
            }

            bool chooseBuy =
               m_rng.NextBool(
                  rngState
               );

            double selectedR =
               chooseBuy
               ? pairs[i].BuyResultR
               : pairs[i].SellResultR;

            cumulativeR +=
               selectedR;

            if(cumulativeR >
               peakR)
            {
               peakR =
                  cumulativeR;
            }

            double drawdown =
               peakR -
               cumulativeR;

            if(drawdown >
               maxDD)
            {
               maxDD =
                  drawdown;
            }
         }

         totalDistribution[run] =
            cumulativeR;

         ddDistribution[run] =
            maxDD;

         if(cumulativeR >=
            observedTotalR -
            0.0000001)
         {
            randomGEObserved++;
         }
      }

      ArraySort(
         totalDistribution
      );

      ArraySort(
         ddDistribution
      );

      double empiricalP =
         (
            (double)randomGEObserved +
            1.0
         )
         /
         (
            (double)runs +
            1.0
         );

      double totalP10 =
         PercentileSorted(
            totalDistribution,
            0.10
         );

      double totalP50 =
         PercentileSorted(
            totalDistribution,
            0.50
         );

      double totalP90 =
         PercentileSorted(
            totalDistribution,
            0.90
         );

      logger.Info(
         "PairedRandomizationMC" +
         " | Segment=" +
         segmentText +
         " | Status=COMPLETE" +
         " | Pairs=" +
         IntegerToString(
            (int)complete) +
         " | Runs=" +
         IntegerToString(
            runs) +
         " | Seed=" +
         IntegerToString(
            (int)seed) +
         " | ObservedH3Total=" +
         DoubleToString(
            observedTotalR,
            2) +
         "R" +
         " | RandomTotal_P10=" +
         DoubleToString(
            totalP10,
            2) +
         "R" +
         " | RandomTotal_P50=" +
         DoubleToString(
            totalP50,
            2) +
         "R" +
         " | RandomTotal_P90=" +
         DoubleToString(
            totalP90,
            2) +
         "R" +
         " | RandomExp_P10=" +
         DoubleToString(
            totalP10 /
            (double)complete,
            3) +
         "R" +
         " | RandomExp_P50=" +
         DoubleToString(
            totalP50 /
            (double)complete,
            3) +
         "R" +
         " | RandomExp_P90=" +
         DoubleToString(
            totalP90 /
            (double)complete,
            3) +
         "R" +
         " | RandomGEObserved=" +
         IntegerToString(
            (int)randomGEObserved) +
         " | EmpiricalP=" +
         DoubleToString(
            empiricalP,
            4)
      );

      logger.Info(
         "PairedRandomizationDD" +
         " | Segment=" +
         segmentText +
         " | Ordering=H3_ENTRY_EVENT_ORDER" +
         " | Pairs=" +
         IntegerToString(
            (int)complete) +
         " | MaxDD_P10=" +
         DoubleToString(
            PercentileSorted(
               ddDistribution,
               0.10),
            2) +
         "R" +
         " | MaxDD_P50=" +
         DoubleToString(
            PercentileSorted(
               ddDistribution,
               0.50),
            2) +
         "R" +
         " | MaxDD_P90_PESSIMISTIC=" +
         DoubleToString(
            PercentileSorted(
               ddDistribution,
               0.90),
            2) +
         "R"
      );
   }

   //==============================================================
   // Pair result helpers
   //==============================================================
   double OriginalResult(
      const SAQFPairedTrade &pair)
   {
      if(pair.OriginalDirection ==
         AQF_SIGNAL_BUY)
      {
         return
            pair.BuyResultR;
      }

      return
         pair.SellResultR;
   }

   double OppositeResult(
      const SAQFPairedTrade &pair)
   {
      if(pair.OriginalDirection ==
         AQF_SIGNAL_BUY)
      {
         return
            pair.SellResultR;
      }

      return
         pair.BuyResultR;
   }

   //==============================================================
   // Percentile helper
   //==============================================================
   double PercentileSorted(
      double &values[],
      const double percentile)
   {
      int size =
         ArraySize(
            values
         );

      if(size <= 0)
         return 0.0;

      double bounded =
         percentile;

      if(bounded < 0.0)
         bounded = 0.0;

      if(bounded > 1.0)
         bounded = 1.0;

      int index =
         (int)MathRound(
            bounded *
            (double)(size - 1)
         );

      if(index < 0)
         index = 0;

      if(index >= size)
         index = size - 1;

      return
         values[index];
   }

   //==============================================================
   // Profit factor
   //==============================================================
   string ProfitFactorText(
      const SAQFPairedValidationStats &stats)
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
   // Reset helpers
   //==============================================================
   void ResetReplay(
      SAQFPairedReplayPosition &replay)
   {
      replay.Active =
         false;

      replay.Symbol =
         "";

      replay.Direction =
         AQF_SIGNAL_NONE;

      replay.EntryPrice =
         0.0;

      replay.StopLoss =
         0.0;

      replay.StopDistance =
         0.0;

      replay.TakeProfit =
         0.0;

      replay.PairIndex =
         -1;
   }

   void ResetPair(
      SAQFPairedTrade &pair)
   {
      pair.Valid =
         false;

      pair.Symbol =
         "";

      pair.OriginalDirection =
         AQF_SIGNAL_NONE;

      pair.StopDistance =
         0.0;

      pair.BuyEntry =
         0.0;

      pair.BuyStop =
         0.0;

      pair.BuyTarget =
         0.0;

      pair.SellEntry =
         0.0;

      pair.SellStop =
         0.0;

      pair.SellTarget =
         0.0;

      pair.BuyActive =
         false;

      pair.SellActive =
         false;

      pair.BuyResolved =
         false;

      pair.SellResolved =
         false;

      pair.BuyResultR =
         0.0;

      pair.SellResultR =
         0.0;

      pair.ReplayResolved =
         false;

      pair.ReplayResultR =
         0.0;
   }

   void ResetStats(
      SAQFPairedValidationStats &stats)
   {
      stats.SignalsSeen =
         0;

      stats.H2Rejected =
         0;

      stats.FeatureFailures =
         0;

      stats.C1Rejected =
         0;

      stats.C3Rejected =
         0;

      stats.Eligible =
         0;

      stats.Opened =
         0;

      stats.SkippedActive =
         0;

      stats.Resolved =
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

      stats.PairCreated =
         0;

      stats.PairComplete =
         0;

      stats.PairReplayMismatch =
         0;
   }

   void ResetAll()
   {
      ResetReplay(
         m_isReplay
      );

      ResetReplay(
         m_oosReplay
      );

      ResetStats(
         m_isStats
      );

      ResetStats(
         m_oosStats
      );

      ArrayResize(
         m_isPairs,
         0
      );

      ArrayResize(
         m_oosPairs,
         0
      );
   }
};

#endif
