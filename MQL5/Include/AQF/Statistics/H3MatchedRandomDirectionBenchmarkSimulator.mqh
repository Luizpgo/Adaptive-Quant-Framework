#ifndef __AQF_H3_MATCHED_RANDOM_DIRECTION_BENCHMARK_SIMULATOR_MQH__
#define __AQF_H3_MATCHED_RANDOM_DIRECTION_BENCHMARK_SIMULATOR_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"
#include "ValidationSplit.mqh"
#include "DeterministicRNG.mqh"

//+------------------------------------------------------------------+
//| H3 Matched Random-Direction Benchmark                            |
//| Sprint 11 - Validation Layer v0.11.1                             |
//|                                                                  |
//| PRIMARY random benchmark for H3 directional value.               |
//|                                                                  |
//| Candidate timing is matched to the FROZEN H3 eligibility gate:   |
//|   ATRPercent >= 0.075                                            |
//|   ADX >= 25 and ADX < 40                                        |
//|   DirectionalER10 >= 0.50                                       |
//|   VolumeZScore20 >= 0.25 and < 1.00                             |
//|                                                                  |
//| IMPORTANT: H3 eligibility is evaluated using the ORIGINAL        |
//| strategy direction, exactly as frozen H3 does. Only AFTER an     |
//| opportunity qualifies H3 is the executed benchmark direction    |
//| randomized 50/50 BUY/SELL.                                      |
//|                                                                  |
//| This isolates the value of H3's chosen DIRECTION conditional     |
//| on the same H3-qualified opportunity stream.                     |
//|                                                                  |
//| Risk/exit conventions:                                           |
//| - same request.StopDistance                                      |
//| - BUY entry at current Ask                                       |
//| - SELL entry at current Bid                                      |
//| - TP = +1.50R                                                    |
//| - SL = -1.00R                                                    |
//| - one independent active virtual position per split segment      |
//|                                                                  |
//| RNG advances once per H3-eligible opportunity, even when the     |
//| benchmark already has an active position. This makes the random  |
//| direction assigned to each candidate ordinal reproducible and   |
//| independent of the benchmark's own holding duration.             |
//|                                                                  |
//| VIRTUAL ONLY. NO OrderSend.                                      |
//+------------------------------------------------------------------+

struct SAQFH3MatchedRandomPosition
{
   bool Active;

   string Symbol;
   ENUM_AQF_SIGNAL_DIRECTION Direction;

   double EntryPrice;
   double StopLoss;
   double StopDistance;
   double TakeProfit;
};

struct SAQFH3MatchedRandomStats
{
   long SignalsSeen;

   long H2Rejected;
   long FeatureFailures;
   long C1Rejected;
   long C3Rejected;

   long Eligible;
   long RandomDrawBuy;
   long RandomDrawSell;

   long Opened;
   long SkippedActive;

   long BuyEntries;
   long SellEntries;

   long Wins;
   long Losses;

   double GrossProfitR;
   double GrossLossR;

   double CumulativeR;
   double PeakR;
   double MaxDrawdownR;
};

class CAQFH3MatchedRandomDirectionBenchmarkSimulator
{
private:

   CAQFDeterministicRNG m_rng;

   SAQFH3MatchedRandomPosition m_isPosition;
   SAQFH3MatchedRandomPosition m_oosPosition;

   SAQFH3MatchedRandomStats m_isStats;
   SAQFH3MatchedRandomStats m_oosStats;

   double m_targetR;

   double m_minATRPercent;
   double m_minADX;
   double m_maxADX;

   double m_minDirectionalER10;
   double m_minVolumeZ20;
   double m_maxVolumeZ20;

   uint m_initialSeedIS;
   uint m_initialSeedOOS;

   uint m_rngIS;
   uint m_rngOOS;

   bool m_initialized;

public:

   CAQFH3MatchedRandomDirectionBenchmarkSimulator()
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

      m_initialSeedIS =
         110112022;

      m_initialSeedOOS =
         110112025;

      m_initialized =
         false;

      ResetAll();
   }

   bool Initialize(
      CAQFLogger &logger)
   {
      ResetAll();

      m_initialized =
         true;

      logger.Info(
         "H3MatchedRandomDirectionBenchmarkSimulator initialized."
      );

      logger.Info(
         "MatchedH3RandomBenchmark | SAME frozen-H3 eligibility stream | ORIGINAL signal direction used only to qualify H3 | benchmark execution direction randomized 50/50 AFTER qualification | same StopDistance | TP=1.50R | SL=1.00R"
      );

      logger.Info(
         "MatchedH3RandomBenchmark fixed seeds | IS=110112022 | OOS_RETROSPECTIVE=110112025 | RNG=xorshift32-high-bit-v0.11.3"
      );

      logger.Warning(
         "MatchedH3RandomBenchmark uses ONE reproducible random realization. Treat it as a control, not as a randomization-test p-value."
      );

      return true;
   }

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
               m_isPosition,
               m_isStats,
               m_rngIS,
               "IN_SAMPLE",
               request,
               market,
               logger
            );
      }

      return
         RegisterSegment(
            m_oosPosition,
            m_oosStats,
            m_rngOOS,
            "OOS_RETROSPECTIVE",
            request,
            market,
            logger
         );
   }

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

      UpdatePosition(
         m_isPosition,
         m_isStats,
         "IN_SAMPLE",
         market,
         logger
      );

      UpdatePosition(
         m_oosPosition,
         m_oosStats,
         "OOS_RETROSPECTIVE",
         market,
         logger
      );
   }

   void Shutdown(
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return;

      Report(
         "IN_SAMPLE",
         m_isPosition,
         m_isStats,
         logger
      );

      Report(
         "OOS_RETROSPECTIVE",
         m_oosPosition,
         m_oosStats,
         logger
      );

      m_initialized =
         false;
   }

   long Resolved(
      const ENUM_AQF_VALIDATION_SEGMENT segment)
   {
      SAQFH3MatchedRandomStats stats =
         StatsCopy(
            segment
         );

      return
         stats.Wins +
         stats.Losses;
   }

   double Expectancy(
      const ENUM_AQF_VALIDATION_SEGMENT segment)
   {
      SAQFH3MatchedRandomStats stats =
         StatsCopy(
            segment
         );

      long resolved =
         stats.Wins +
         stats.Losses;

      if(resolved <= 0)
         return 0.0;

      return
         stats.CumulativeR /
         (double)resolved;
   }

   double MaxDD(
      const ENUM_AQF_VALIDATION_SEGMENT segment)
   {
      SAQFH3MatchedRandomStats stats =
         StatsCopy(
            segment
         );

      return
         stats.MaxDrawdownR;
   }

private:

   bool RegisterSegment(
      SAQFH3MatchedRandomPosition &position,
      SAQFH3MatchedRandomStats &stats,
      uint &rngState,
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
      // Frozen H3 research features. ORIGINAL request direction is
      // intentionally used here to reproduce H3 candidate timing.
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
      // Advance RNG ON EVERY eligible H3 candidate, whether or not
      // this benchmark can open it.
      //------------------------------------------------------------

      ENUM_AQF_SIGNAL_DIRECTION randomDirection =
         RandomDirection(
            rngState
         );

      if(randomDirection ==
         AQF_SIGNAL_BUY)
      {
         stats.RandomDrawBuy++;
      }
      else
      {
         stats.RandomDrawSell++;
      }

      if(position.Active)
      {
         stats.SkippedActive++;
         return true;
      }

      OpenPosition(
         position,
         randomDirection,
         request.StopDistance,
         market
      );

      stats.Opened++;

      if(randomDirection ==
         AQF_SIGNAL_BUY)
      {
         stats.BuyEntries++;
      }
      else
      {
         stats.SellEntries++;
      }

      logger.Debug(
         "MatchedH3RandomOpen" +
         " | Segment=" +
         segmentText +
         " | OriginalH3Direction=" +
         AQFSignalDirectionToString(
            request.Direction) +
         " | RandomDirection=" +
         AQFSignalDirectionToString(
            randomDirection) +
         " | StopDistance=" +
         DoubleToString(
            request.StopDistance,
            5)
      );

      return true;
   }

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

   void OpenPosition(
      SAQFH3MatchedRandomPosition &position,
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const double stopDistance,
      const CAQFMarketSnapshot &market)
   {
      ResetPosition(
         position
      );

      position.Active =
         true;

      position.Symbol =
         market.Symbol;

      position.Direction =
         direction;

      position.StopDistance =
         stopDistance;

      if(direction ==
         AQF_SIGNAL_BUY)
      {
         position.EntryPrice =
            market.Ask;

         position.StopLoss =
            position.EntryPrice -
            stopDistance;

         position.TakeProfit =
            position.EntryPrice +
            stopDistance *
            m_targetR;
      }
      else
      {
         position.EntryPrice =
            market.Bid;

         position.StopLoss =
            position.EntryPrice +
            stopDistance;

         position.TakeProfit =
            position.EntryPrice -
            stopDistance *
            m_targetR;
      }
   }

   void UpdatePosition(
      SAQFH3MatchedRandomPosition &position,
      SAQFH3MatchedRandomStats &stats,
      const string segmentText,
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!position.Active ||
         position.Symbol !=
         market.Symbol)
      {
         return;
      }

      bool targetReached =
         false;

      bool stopReached =
         false;

      if(position.Direction ==
         AQF_SIGNAL_BUY)
      {
         targetReached =
            (
               market.Bid >=
               position.TakeProfit
            );

         stopReached =
            (
               market.Bid <=
               position.StopLoss
            );
      }
      else
      {
         targetReached =
            (
               market.Ask <=
               position.TakeProfit
            );

         stopReached =
            (
               market.Ask >=
               position.StopLoss
            );
      }

      if(targetReached)
      {
         Resolve(
            position,
            stats,
            segmentText,
            m_targetR,
            logger
         );

         return;
      }

      if(stopReached)
      {
         Resolve(
            position,
            stats,
            segmentText,
            -1.0,
            logger
         );

         return;
      }
   }

   void Resolve(
      SAQFH3MatchedRandomPosition &position,
      SAQFH3MatchedRandomStats &stats,
      const string segmentText,
      const double resultR,
      CAQFLogger &logger)
   {
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

      logger.Debug(
         "MatchedH3RandomClose" +
         " | Segment=" +
         segmentText +
         " | ResultR=" +
         DoubleToString(
            resultR,
            2) +
         "R"
      );

      ResetPosition(
         position
      );
   }

   ENUM_AQF_SIGNAL_DIRECTION RandomDirection(
      uint &state)
   {
      if(m_rng.NextBool(
            state))
      {
         return
            AQF_SIGNAL_BUY;
      }

      return
         AQF_SIGNAL_SELL;
   }

   void Report(
      const string segmentText,
      const SAQFH3MatchedRandomPosition &position,
      const SAQFH3MatchedRandomStats &stats,
      CAQFLogger &logger)
   {
      long resolved =
         stats.Wins +
         stats.Losses;

      double winRate =
         0.0;

      double expectancy =
         0.0;

      if(resolved > 0)
      {
         winRate =
            (
               (double)stats.Wins /
               (double)resolved
            ) *
            100.0;

         expectancy =
            stats.CumulativeR /
            (double)resolved;
      }

      long filterRejected =
         stats.H2Rejected +
         stats.FeatureFailures +
         stats.C1Rejected +
         stats.C3Rejected;

      logger.Info(
         "MatchedH3RandomBenchmarkStats" +
         " | Segment=" +
         segmentText +
         " | Benchmark=H3_MATCHED_CANDIDATE_RANDOM_DIRECTION_50_50" +
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
         " | RandomDrawBuy=" +
         IntegerToString(
            (int)stats.RandomDrawBuy) +
         " | RandomDrawSell=" +
         IntegerToString(
            (int)stats.RandomDrawSell) +
         " | Opened=" +
         IntegerToString(
            (int)stats.Opened) +
         " | SkippedActive=" +
         IntegerToString(
            (int)stats.SkippedActive) +
         " | Resolved=" +
         IntegerToString(
            (int)resolved) +
         " | Wins=" +
         IntegerToString(
            (int)stats.Wins) +
         " | Losses=" +
         IntegerToString(
            (int)stats.Losses) +
         " | BuyEntries=" +
         IntegerToString(
            (int)stats.BuyEntries) +
         " | SellEntries=" +
         IntegerToString(
            (int)stats.SellEntries) +
         " | Open=" +
         (
            position.Active
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
         "R"
      );
   }

   SAQFH3MatchedRandomStats StatsCopy(
      const ENUM_AQF_VALIDATION_SEGMENT segment)
   {
      if(segment ==
         AQF_VALIDATION_IN_SAMPLE)
      {
         return
            m_isStats;
      }

      return
         m_oosStats;
   }

   string ProfitFactorText(
      const SAQFH3MatchedRandomStats &stats)
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

   void ResetPosition(
      SAQFH3MatchedRandomPosition &position)
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
      SAQFH3MatchedRandomStats &stats)
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

      stats.RandomDrawBuy =
         0;

      stats.RandomDrawSell =
         0;

      stats.Opened =
         0;

      stats.SkippedActive =
         0;

      stats.BuyEntries =
         0;

      stats.SellEntries =
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
      ResetPosition(
         m_isPosition
      );

      ResetPosition(
         m_oosPosition
      );

      ResetStats(
         m_isStats
      );

      ResetStats(
         m_oosStats
      );

      m_rngIS =
         m_initialSeedIS;

      m_rngOOS =
         m_initialSeedOOS;
   }
};

#endif
