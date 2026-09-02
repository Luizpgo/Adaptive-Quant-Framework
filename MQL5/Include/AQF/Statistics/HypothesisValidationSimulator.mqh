#ifndef __AQF_HYPOTHESIS_VALIDATION_SIMULATOR_MQH__
#define __AQF_HYPOTHESIS_VALIDATION_SIMULATOR_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"
#include "ValidationSplit.mqh"
#include "BootstrapMonteCarlo.mqh"

#define AQF_VALIDATION_POLICY_COUNT 4

//+------------------------------------------------------------------+
//| Sequential Hypothesis Validation                                 |
//| Sprint 11 - Methodological Validation Layer                      |
//|                                                                  |
//| Existing simulators are NOT modified. This module independently  |
//| re-simulates the historical hypothesis chain:                    |
//|                                                                  |
//| BASELINE: upstream executable-quality strategy opportunity       |
//| H1:       BASELINE + ATRPercent >= 0.075                         |
//| H2:       H1 + ADX >= 25 and ADX < 40                            |
//| H3:       H2 + DirER10 >= 0.50 + VolZ20 >= 0.25 and < 1.00     |
//|                                                                  |
//| TP=+1.50R | SL=-1.00R                                           |
//| One virtual position per policy PER split segment.               |
//| OOS therefore starts with a fresh independent account.           |
//+------------------------------------------------------------------+

enum ENUM_AQF_VALIDATION_POLICY
{
   AQF_VALIDATION_BASELINE = 0,
   AQF_VALIDATION_H1,
   AQF_VALIDATION_H2,
   AQF_VALIDATION_H3
};

struct SAQFValidationPosition
{
   bool Active;
   string Symbol;
   ENUM_AQF_SIGNAL_DIRECTION Direction;
   double EntryPrice;
   double StopLoss;
   double StopDistance;
   double TakeProfit;
};

struct SAQFValidationStats
{
   long SignalsSeen;
   long Eligible;
   long Opened;
   long SkippedActive;
   long FeatureFailures;

   long Wins;
   long Losses;

   double GrossProfitR;
   double GrossLossR;
   double CumulativeR;
   double PeakR;
   double MaxDrawdownR;
};

class CAQFHypothesisValidationSimulator
{
private:
   SAQFValidationPosition m_isPositions[AQF_VALIDATION_POLICY_COUNT];
   SAQFValidationPosition m_oosPositions[AQF_VALIDATION_POLICY_COUNT];

   SAQFValidationStats m_isStats[AQF_VALIDATION_POLICY_COUNT];
   SAQFValidationStats m_oosStats[AQF_VALIDATION_POLICY_COUNT];

   CAQFBootstrapMonteCarlo m_h3BootstrapIS;
   CAQFBootstrapMonteCarlo m_h3BootstrapOOS;

   double m_targetR;
   double m_minATRPercent;
   double m_minADX;
   double m_maxADX;
   double m_minDirectionalER10;
   double m_minVolumeZ20;
   double m_maxVolumeZ20;

   int  m_bootstrapRuns;
   uint m_bootstrapSeedIS;
   uint m_bootstrapSeedOOS;

   bool m_initialized;

public:
   CAQFHypothesisValidationSimulator()
   {
      m_targetR            = 1.50;
      m_minATRPercent      = 0.075;
      m_minADX             = 25.0;
      m_maxADX             = 40.0;
      m_minDirectionalER10 = 0.50;
      m_minVolumeZ20       = 0.25;
      m_maxVolumeZ20       = 1.00;

      m_bootstrapRuns    = 5000;
      m_bootstrapSeedIS  = 11032022;
      m_bootstrapSeedOOS = 11032025;

      m_initialized = false;

      ResetAll();
   }

   bool Initialize(CAQFLogger &logger)
   {
      ResetAll();
      m_initialized = true;

      logger.Info(
         "HypothesisValidationSimulator initialized."
      );

      logger.Info(
         "ValidationPolicies | BASELINE | H1=ATRPercent>=0.075 | H2=H1+ADX>=25<40 | H3=H2+DirER10>=0.50+VolZ20>=0.25<1.00 | TP=1.50R | SL=1.00R"
      );

      logger.Info(
         "Validation split uses independent one-position accounts per policy and per segment."
      );

      logger.Info(
         "H3 BootstrapMC | 5000 IID resamples WITH replacement | report TotalR P10 and MaxDD P90 pessimistic tail."
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

      bool h1Eligible =
         (market.ATRPercent >= m_minATRPercent);

      bool h2Eligible =
         (
            h1Eligible &&
            market.ADX >= m_minADX &&
            market.ADX <  m_maxADX
         );

      bool h3Eligible       = false;
      bool h3FeatureFailure = false;

      if(h2Eligible)
      {
         double relativeVolume20 = 0.0;
         double volumeZScore20   = 0.0;
         double directionalER10  = 0.0;

         if(!CaptureH3Features(
               request,
               market,
               relativeVolume20,
               volumeZScore20,
               directionalER10))
         {
            h3FeatureFailure = true;
         }
         else
         {
            h3Eligible =
               (
                  directionalER10 >= m_minDirectionalER10 &&
                  volumeZScore20   >= m_minVolumeZ20 &&
                  volumeZScore20   <  m_maxVolumeZ20
               );
         }
      }

      RegisterPolicy(segment, AQF_VALIDATION_BASELINE, true,       false,            request, logger);
      RegisterPolicy(segment, AQF_VALIDATION_H1,       h1Eligible, false,            request, logger);
      RegisterPolicy(segment, AQF_VALIDATION_H2,       h2Eligible, false,            request, logger);
      RegisterPolicy(segment, AQF_VALIDATION_H3,       h3Eligible, h3FeatureFailure, request, logger);

      return true;
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

      for(int policy = 0;
          policy < AQF_VALIDATION_POLICY_COUNT;
          policy++)
      {
         UpdatePosition(
            m_isPositions[policy],
            m_isStats[policy],
            AQF_VALIDATION_IN_SAMPLE,
            (ENUM_AQF_VALIDATION_POLICY)policy,
            market,
            logger
         );

         UpdatePosition(
            m_oosPositions[policy],
            m_oosStats[policy],
            AQF_VALIDATION_OOS_RETROSPECTIVE,
            (ENUM_AQF_VALIDATION_POLICY)policy,
            market,
            logger
         );
      }
   }

   void Shutdown(CAQFLogger &logger)
   {
      if(!m_initialized)
         return;

      ReportSegment(AQF_VALIDATION_IN_SAMPLE,         logger);
      ReportSegment(AQF_VALIDATION_OOS_RETROSPECTIVE, logger);

      m_h3BootstrapIS.Report(
         "IN_SAMPLE",
         m_bootstrapRuns,
         m_bootstrapSeedIS,
         logger
      );

      m_h3BootstrapOOS.Report(
         "OOS_RETROSPECTIVE",
         m_bootstrapRuns,
         m_bootstrapSeedOOS,
         logger
      );

      m_initialized = false;
   }

   long H3Resolved(const ENUM_AQF_VALIDATION_SEGMENT segment)
   {
      int index = (int)AQF_VALIDATION_H3;

      if(segment == AQF_VALIDATION_IN_SAMPLE)
         return m_isStats[index].Wins + m_isStats[index].Losses;

      return m_oosStats[index].Wins + m_oosStats[index].Losses;
   }

   double H3Expectancy(const ENUM_AQF_VALIDATION_SEGMENT segment)
   {
      int index = (int)AQF_VALIDATION_H3;

      long resolved = 0;
      double cumulativeR = 0.0;

      if(segment == AQF_VALIDATION_IN_SAMPLE)
      {
         resolved =
            m_isStats[index].Wins +
            m_isStats[index].Losses;

         cumulativeR =
            m_isStats[index].CumulativeR;
      }
      else
      {
         resolved =
            m_oosStats[index].Wins +
            m_oosStats[index].Losses;

         cumulativeR =
            m_oosStats[index].CumulativeR;
      }

      if(resolved <= 0)
         return 0.0;

      return cumulativeR / (double)resolved;
   }

   double H3MaxDD(const ENUM_AQF_VALIDATION_SEGMENT segment)
   {
      int index = (int)AQF_VALIDATION_H3;

      if(segment == AQF_VALIDATION_IN_SAMPLE)
         return m_isStats[index].MaxDrawdownR;

      return m_oosStats[index].MaxDrawdownR;
   }

private:
   void RegisterPolicy(
      const ENUM_AQF_VALIDATION_SEGMENT segment,
      const ENUM_AQF_VALIDATION_POLICY policy,
      const bool eligible,
      const bool featureFailure,
      const CAQFTradeRequest &request,
      CAQFLogger &logger)
   {
      int index = (int)policy;

      if(segment == AQF_VALIDATION_IN_SAMPLE)
      {
         m_isStats[index].SignalsSeen++;

         if(featureFailure)
            m_isStats[index].FeatureFailures++;

         if(!eligible)
            return;

         m_isStats[index].Eligible++;

         if(m_isPositions[index].Active)
         {
            m_isStats[index].SkippedActive++;
            return;
         }

         OpenPosition(m_isPositions[index], request);
         m_isStats[index].Opened++;
      }
      else
      {
         m_oosStats[index].SignalsSeen++;

         if(featureFailure)
            m_oosStats[index].FeatureFailures++;

         if(!eligible)
            return;

         m_oosStats[index].Eligible++;

         if(m_oosPositions[index].Active)
         {
            m_oosStats[index].SkippedActive++;
            return;
         }

         OpenPosition(m_oosPositions[index], request);
         m_oosStats[index].Opened++;
      }

      logger.Debug(
         "ValidationOpen" +
         " | Segment=" + SegmentText(segment) +
         " | Policy=" + PolicyText(policy) +
         " | Direction=" + AQFSignalDirectionToString(request.Direction)
      );
   }

   void OpenPosition(
      SAQFValidationPosition &position,
      const CAQFTradeRequest &request)
   {
      ResetPosition(position);

      position.Active       = true;
      position.Symbol       = request.Symbol;
      position.Direction    = request.Direction;
      position.EntryPrice   = request.EntryPrice;
      position.StopLoss     = request.StopLoss;
      position.StopDistance = request.StopDistance;

      double targetDistance =
         request.StopDistance * m_targetR;

      if(request.Direction == AQF_SIGNAL_BUY)
         position.TakeProfit = request.EntryPrice + targetDistance;
      else
         position.TakeProfit = request.EntryPrice - targetDistance;
   }

   void UpdatePosition(
      SAQFValidationPosition &position,
      SAQFValidationStats &stats,
      const ENUM_AQF_VALIDATION_SEGMENT segment,
      const ENUM_AQF_VALIDATION_POLICY policy,
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
            segment,
            policy,
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
            segment,
            policy,
            -1.0,
            logger
         );
         return;
      }
   }

   void Resolve(
      SAQFValidationPosition &position,
      SAQFValidationStats &stats,
      const ENUM_AQF_VALIDATION_SEGMENT segment,
      const ENUM_AQF_VALIDATION_POLICY policy,
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

      double dd = stats.PeakR - stats.CumulativeR;

      if(dd > stats.MaxDrawdownR)
         stats.MaxDrawdownR = dd;

      if(policy == AQF_VALIDATION_H3)
      {
         if(segment == AQF_VALIDATION_IN_SAMPLE)
            m_h3BootstrapIS.AddResult(resultR);
         else
            m_h3BootstrapOOS.AddResult(resultR);
      }

      logger.Debug(
         "ValidationClose" +
         " | Segment=" + SegmentText(segment) +
         " | Policy=" + PolicyText(policy) +
         " | ResultR=" + DoubleToString(resultR, 2) + "R"
      );

      ResetPosition(position);
   }

   bool CaptureH3Features(
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market,
      double &relativeVolume20,
      double &volumeZScore20,
      double &directionalER10)
   {
      relativeVolume20 = 0.0;
      volumeZScore20   = 0.0;
      directionalER10  = 0.0;

      MqlRates rates[];
      ArraySetAsSeries(rates, true);

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

      double volumeSum = 0.0;

      for(int i = 1; i <= 20; i++)
         volumeSum += (double)rates[i].tick_volume;

      double volumeMean = volumeSum / 20.0;

      if(volumeMean <= 0.0)
         return false;

      relativeVolume20 =
         (double)rates[0].tick_volume /
         volumeMean;

      double squaredDiffSum = 0.0;

      for(int i = 1; i <= 20; i++)
      {
         double difference =
            (double)rates[i].tick_volume -
            volumeMean;

         squaredDiffSum += difference * difference;
      }

      double volumeStd =
         MathSqrt(squaredDiffSum / 20.0);

      if(volumeStd <= 0.0)
         return false;

      volumeZScore20 =
         (
            (double)rates[0].tick_volume -
            volumeMean
         ) /
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
         ArraySize(rates) < window + 1)
      {
         return 0.0;
      }

      double netDisplacement =
         rates[0].close -
         rates[window].close;

      if(direction == AQF_SIGNAL_SELL)
         netDisplacement = -netDisplacement;

      double pathLength = 0.0;

      for(int i = 0; i < window; i++)
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

   void ReportSegment(
      const ENUM_AQF_VALIDATION_SEGMENT segment,
      CAQFLogger &logger)
   {
      for(int policy = 0;
          policy < AQF_VALIDATION_POLICY_COUNT;
          policy++)
      {
         SAQFValidationStats stats;

         if(segment == AQF_VALIDATION_IN_SAMPLE)
            stats = m_isStats[policy];
         else
            stats = m_oosStats[policy];

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

         bool active =
            (
               segment == AQF_VALIDATION_IN_SAMPLE
               ? m_isPositions[policy].Active
               : m_oosPositions[policy].Active
            );

         logger.Info(
            "HypothesisValidationStats" +
            " | Segment=" + SegmentText(segment) +
            " | Policy=" + PolicyText((ENUM_AQF_VALIDATION_POLICY)policy) +
            " | Signals=" + IntegerToString((int)stats.SignalsSeen) +
            " | Eligible=" + IntegerToString((int)stats.Eligible) +
            " | Opened=" + IntegerToString((int)stats.Opened) +
            " | SkippedActive=" + IntegerToString((int)stats.SkippedActive) +
            " | Resolved=" + IntegerToString((int)resolved) +
            " | Wins=" + IntegerToString((int)stats.Wins) +
            " | Losses=" + IntegerToString((int)stats.Losses) +
            " | Open=" + (active ? "1" : "0") +
            " | FeatureFailures=" + IntegerToString((int)stats.FeatureFailures) +
            " | WinRate=" + DoubleToString(winRate, 2) + "%" +
            " | Expectancy=" + DoubleToString(expectancy, 3) + "R" +
            " | PF=" + ProfitFactorText(stats) +
            " | CumR=" + DoubleToString(stats.CumulativeR, 2) + "R" +
            " | MaxDD=" + DoubleToString(stats.MaxDrawdownR, 2) + "R"
         );
      }
   }

   string ProfitFactorText(const SAQFValidationStats &stats)
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

   string PolicyText(const ENUM_AQF_VALIDATION_POLICY policy)
   {
      if(policy == AQF_VALIDATION_BASELINE)
         return "BASELINE";

      if(policy == AQF_VALIDATION_H1)
         return "H1_ATR_GE_0.075";

      if(policy == AQF_VALIDATION_H2)
         return "H2_ATR_GE_0.075_ADX_25_TO_LT_40";

      if(policy == AQF_VALIDATION_H3)
         return "H3_FROZEN";

      return "UNKNOWN";
   }

   string SegmentText(const ENUM_AQF_VALIDATION_SEGMENT segment)
   {
      if(segment == AQF_VALIDATION_IN_SAMPLE)
         return "IN_SAMPLE";

      if(segment == AQF_VALIDATION_OOS_RETROSPECTIVE)
         return "OOS_RETROSPECTIVE";

      return "OUTSIDE";
   }

   void ResetPosition(SAQFValidationPosition &position)
   {
      position.Active       = false;
      position.Symbol       = "";
      position.Direction    = AQF_SIGNAL_NONE;
      position.EntryPrice   = 0.0;
      position.StopLoss     = 0.0;
      position.StopDistance = 0.0;
      position.TakeProfit   = 0.0;
   }

   void ResetStats(SAQFValidationStats &stats)
   {
      stats.SignalsSeen      = 0;
      stats.Eligible         = 0;
      stats.Opened           = 0;
      stats.SkippedActive    = 0;
      stats.FeatureFailures  = 0;
      stats.Wins             = 0;
      stats.Losses           = 0;
      stats.GrossProfitR     = 0.0;
      stats.GrossLossR       = 0.0;
      stats.CumulativeR      = 0.0;
      stats.PeakR            = 0.0;
      stats.MaxDrawdownR     = 0.0;
   }

   void ResetAll()
   {
      for(int i = 0;
          i < AQF_VALIDATION_POLICY_COUNT;
          i++)
      {
         ResetPosition(m_isPositions[i]);
         ResetPosition(m_oosPositions[i]);

         ResetStats(m_isStats[i]);
         ResetStats(m_oosStats[i]);
      }

      m_h3BootstrapIS.Reset();
      m_h3BootstrapOOS.Reset();
   }
};

#endif
