#ifndef __AQF_RANDOM_DIRECTION_BENCHMARK_SIMULATOR_MQH__
#define __AQF_RANDOM_DIRECTION_BENCHMARK_SIMULATOR_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"
#include "ValidationSplit.mqh"
#include "DeterministicRNG.mqh"

//+------------------------------------------------------------------+
//| Random Direction Matched-Opportunity Benchmark                   |
//| Sprint 11 - Methodological Validation Layer                      |
//|                                                                  |
//| Controlled benchmark:                                            |
//| - same executable-quality opportunity stream                     |
//| - same broad H2 regime gate: ATRPercent>=0.075, ADX>=25<40      |
//| - random 50/50 BUY/SELL                                          |
//| - same request.StopDistance                                      |
//| - BUY enters Ask, SELL enters Bid                                |
//| - TP=+1.50R, SL=-1.00R                                          |
//| - one independent virtual position per split segment             |
//|                                                                  |
//| This randomizes DIRECTION while controlling timing/regime/risk.  |
//| It is NOT a fully random clock-time entry benchmark.             |
//+------------------------------------------------------------------+

struct SAQFRandomBenchmarkPosition
{
   bool Active;
   string Symbol;
   ENUM_AQF_SIGNAL_DIRECTION Direction;
   double EntryPrice;
   double StopLoss;
   double StopDistance;
   double TakeProfit;
};

struct SAQFRandomBenchmarkStats
{
   long SignalsSeen;
   long Eligible;
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

class CAQFRandomDirectionBenchmarkSimulator
{
private:
   CAQFDeterministicRNG m_rng;

   SAQFRandomBenchmarkPosition m_isPosition;
   SAQFRandomBenchmarkPosition m_oosPosition;

   SAQFRandomBenchmarkStats m_isStats;
   SAQFRandomBenchmarkStats m_oosStats;

   double m_targetR;
   double m_minATRPercent;
   double m_minADX;
   double m_maxADX;

   uint m_initialSeedIS;
   uint m_initialSeedOOS;

   uint m_rngIS;
   uint m_rngOOS;

   bool m_initialized;

public:
   CAQFRandomDirectionBenchmarkSimulator()
   {
      m_targetR       = 1.50;
      m_minATRPercent = 0.075;
      m_minADX        = 25.0;
      m_maxADX        = 40.0;

      m_initialSeedIS  = 26082022;
      m_initialSeedOOS = 26082025;

      m_initialized = false;

      ResetAll();
   }

   bool Initialize(CAQFLogger &logger)
   {
      ResetAll();
      m_initialized = true;

      logger.Info(
         "RandomDirectionBenchmarkSimulator initialized."
      );

      logger.Info(
         "RandomBenchmark | matched executable-quality timing | H2 gate ATRPercent>=0.075 ADX>=25<40 | random BUY/SELL 50/50 | same StopDistance | TP=1.50R | SL=1.00R"
      );

      logger.Info(
         "RandomBenchmark fixed seeds | IS=26082022 | OOS_RETROSPECTIVE=26082025"
      );

      logger.Warning(
         "RandomBenchmark is a RANDOM-DIRECTION matched-opportunity control, not a fully random clock-time benchmark."
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

      if(segment != AQF_VALIDATION_IN_SAMPLE &&
         segment != AQF_VALIDATION_OOS_RETROSPECTIVE)
      {
         return true;
      }

      if(!request.Valid ||
         !market.Valid ||
         request.Symbol == "" ||
         request.Symbol != market.Symbol ||
         request.StopDistance <= 0.0 ||
         market.Bid <= 0.0 ||
         market.Ask <= 0.0)
      {
         return false;
      }

      if(segment == AQF_VALIDATION_IN_SAMPLE)
      {
         return RegisterSegment(
            m_isPosition,
            m_isStats,
            m_rngIS,
            "IN_SAMPLE",
            request,
            market,
            logger
         );
      }

      return RegisterSegment(
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

   void Shutdown(CAQFLogger &logger)
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

      m_initialized = false;
   }

   long Resolved(const ENUM_AQF_VALIDATION_SEGMENT segment)
   {
      if(segment == AQF_VALIDATION_IN_SAMPLE)
         return m_isStats.Wins + m_isStats.Losses;

      return m_oosStats.Wins + m_oosStats.Losses;
   }

   double Expectancy(const ENUM_AQF_VALIDATION_SEGMENT segment)
   {
      long resolved = 0;
      double cumulativeR = 0.0;

      if(segment == AQF_VALIDATION_IN_SAMPLE)
      {
         resolved =
            m_isStats.Wins +
            m_isStats.Losses;

         cumulativeR =
            m_isStats.CumulativeR;
      }
      else
      {
         resolved =
            m_oosStats.Wins +
            m_oosStats.Losses;

         cumulativeR =
            m_oosStats.CumulativeR;
      }

      if(resolved <= 0)
         return 0.0;

      return cumulativeR / (double)resolved;
   }

   double MaxDD(const ENUM_AQF_VALIDATION_SEGMENT segment)
   {
      if(segment == AQF_VALIDATION_IN_SAMPLE)
         return m_isStats.MaxDrawdownR;

      return m_oosStats.MaxDrawdownR;
   }

private:
   bool RegisterSegment(
      SAQFRandomBenchmarkPosition &position,
      SAQFRandomBenchmarkStats &stats,
      uint &rngState,
      const string segmentText,
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      stats.SignalsSeen++;

      bool eligible =
         (
            market.ATRPercent >= m_minATRPercent &&
            market.ADX >= m_minADX &&
            market.ADX <  m_maxADX
         );

      if(!eligible)
         return true;

      stats.Eligible++;

      if(position.Active)
      {
         stats.SkippedActive++;
         return true;
      }

      ENUM_AQF_SIGNAL_DIRECTION direction =
         RandomDirection(rngState);

      OpenPosition(
         position,
         direction,
         request.StopDistance,
         market
      );

      stats.Opened++;

      if(direction == AQF_SIGNAL_BUY)
         stats.BuyEntries++;
      else
         stats.SellEntries++;

      logger.Debug(
         "RandomBenchmarkOpen" +
         " | Segment=" + segmentText +
         " | Direction=" + AQFSignalDirectionToString(direction) +
         " | StopDistance=" + DoubleToString(request.StopDistance, 5)
      );

      return true;
   }

   void OpenPosition(
      SAQFRandomBenchmarkPosition &position,
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const double stopDistance,
      const CAQFMarketSnapshot &market)
   {
      ResetPosition(position);

      position.Active       = true;
      position.Symbol       = market.Symbol;
      position.Direction    = direction;
      position.StopDistance = stopDistance;

      if(direction == AQF_SIGNAL_BUY)
      {
         position.EntryPrice =
            market.Ask;

         position.StopLoss =
            position.EntryPrice -
            stopDistance;

         position.TakeProfit =
            position.EntryPrice +
            stopDistance * m_targetR;
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
            stopDistance * m_targetR;
      }
   }

   void UpdatePosition(
      SAQFRandomBenchmarkPosition &position,
      SAQFRandomBenchmarkStats &stats,
      const string segmentText,
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!position.Active ||
         position.Symbol != market.Symbol)
      {
         return;
      }

      bool targetReached = false;
      bool stopReached   = false;

      if(position.Direction == AQF_SIGNAL_BUY)
      {
         targetReached = (market.Bid >= position.TakeProfit);
         stopReached   = (market.Bid <= position.StopLoss);
      }
      else
      {
         targetReached = (market.Ask <= position.TakeProfit);
         stopReached   = (market.Ask >= position.StopLoss);
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
      SAQFRandomBenchmarkPosition &position,
      SAQFRandomBenchmarkStats &stats,
      const string segmentText,
      const double resultR,
      CAQFLogger &logger)
   {
      if(resultR > 0.0)
      {
         stats.Wins++;
         stats.GrossProfitR += resultR;
      }
      else
      {
         stats.Losses++;
         stats.GrossLossR += -resultR;
      }

      stats.CumulativeR += resultR;

      if(stats.CumulativeR > stats.PeakR)
         stats.PeakR = stats.CumulativeR;

      double dd =
         stats.PeakR -
         stats.CumulativeR;

      if(dd > stats.MaxDrawdownR)
         stats.MaxDrawdownR = dd;

      logger.Debug(
         "RandomBenchmarkClose" +
         " | Segment=" + segmentText +
         " | ResultR=" + DoubleToString(resultR, 2) + "R"
      );

      ResetPosition(position);
   }

   ENUM_AQF_SIGNAL_DIRECTION RandomDirection(uint &state)
   {
      if(m_rng.NextBool(state))
         return AQF_SIGNAL_BUY;

      return AQF_SIGNAL_SELL;
   }

   void Report(
      const string segmentText,
      const SAQFRandomBenchmarkPosition &position,
      const SAQFRandomBenchmarkStats &stats,
      CAQFLogger &logger)
   {
      long resolved =
         stats.Wins +
         stats.Losses;

      double winRate    = 0.0;
      double expectancy = 0.0;

      if(resolved > 0)
      {
         winRate =
            100.0 *
            (double)stats.Wins /
            (double)resolved;

         expectancy =
            stats.CumulativeR /
            (double)resolved;
      }

      logger.Info(
         "RandomBenchmarkStats" +
         " | Segment=" + segmentText +
         " | Benchmark=MATCHED_OPPORTUNITY_RANDOM_DIRECTION_50_50" +
         " | Signals=" + IntegerToString((int)stats.SignalsSeen) +
         " | Eligible=" + IntegerToString((int)stats.Eligible) +
         " | Opened=" + IntegerToString((int)stats.Opened) +
         " | SkippedActive=" + IntegerToString((int)stats.SkippedActive) +
         " | Resolved=" + IntegerToString((int)resolved) +
         " | Wins=" + IntegerToString((int)stats.Wins) +
         " | Losses=" + IntegerToString((int)stats.Losses) +
         " | BuyEntries=" + IntegerToString((int)stats.BuyEntries) +
         " | SellEntries=" + IntegerToString((int)stats.SellEntries) +
         " | Open=" + (position.Active ? "1" : "0") +
         " | WinRate=" + DoubleToString(winRate, 2) + "%" +
         " | Expectancy=" + DoubleToString(expectancy, 3) + "R" +
         " | PF=" + ProfitFactorText(stats) +
         " | CumR=" + DoubleToString(stats.CumulativeR, 2) + "R" +
         " | MaxDD=" + DoubleToString(stats.MaxDrawdownR, 2) + "R"
      );
   }

   string ProfitFactorText(const SAQFRandomBenchmarkStats &stats)
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

   void ResetPosition(SAQFRandomBenchmarkPosition &position)
   {
      position.Active       = false;
      position.Symbol       = "";
      position.Direction    = AQF_SIGNAL_NONE;
      position.EntryPrice   = 0.0;
      position.StopLoss     = 0.0;
      position.StopDistance = 0.0;
      position.TakeProfit   = 0.0;
   }

   void ResetStats(SAQFRandomBenchmarkStats &stats)
   {
      stats.SignalsSeen     = 0;
      stats.Eligible        = 0;
      stats.Opened          = 0;
      stats.SkippedActive   = 0;
      stats.BuyEntries      = 0;
      stats.SellEntries     = 0;
      stats.Wins            = 0;
      stats.Losses          = 0;
      stats.GrossProfitR    = 0.0;
      stats.GrossLossR      = 0.0;
      stats.CumulativeR     = 0.0;
      stats.PeakR           = 0.0;
      stats.MaxDrawdownR    = 0.0;
   }

   void ResetAll()
   {
      ResetPosition(m_isPosition);
      ResetPosition(m_oosPosition);
      ResetStats(m_isStats);
      ResetStats(m_oosStats);

      m_rngIS  = m_initialSeedIS;
      m_rngOOS = m_initialSeedOOS;
   }
};

#endif
