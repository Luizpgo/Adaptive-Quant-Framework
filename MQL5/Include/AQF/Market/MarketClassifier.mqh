#ifndef __AQF_MARKET_CLASSIFIER_MQH__
#define __AQF_MARKET_CLASSIFIER_MQH__

#include "../Common/MarketSnapshot.mqh"

class CAQFMarketClassifier
{
private:

   // Initial heuristic thresholds.
   // These are classification parameters, NOT trading signals.

   double m_adxWeakThreshold;
   double m_adxStrongThreshold;

   double m_lowVolatilityPercent;
   double m_highVolatilityPercent;

public:

   CAQFMarketClassifier()
   {
      m_adxWeakThreshold      = 20.0;
      m_adxStrongThreshold    = 30.0;

      m_lowVolatilityPercent  = 0.025;
      m_highVolatilityPercent = 0.075;
   }

   //===================================================
   // Classify
   //===================================================

   void Classify(CAQFMarketSnapshot &snapshot)
   {
      CalculateNormalizedMetrics(snapshot);

      ClassifyTrend(snapshot);
      ClassifyTrendStrength(snapshot);
      ClassifyVolatility(snapshot);
      ClassifyMomentum(snapshot);
   }

private:

   //===================================================
   // Normalized Metrics
   //===================================================

   void CalculateNormalizedMetrics(CAQFMarketSnapshot &snapshot)
   {
      if(snapshot.Close > 0.0)
      {
         snapshot.ATRPercent =
            (snapshot.ATR / snapshot.Close) * 100.0;

         snapshot.EMASeparationPercent =
            (MathAbs(snapshot.EMAFast - snapshot.EMASlow)
             / snapshot.Close) * 100.0;
      }
      else
      {
         snapshot.ATRPercent           = 0.0;
         snapshot.EMASeparationPercent = 0.0;
      }
   }

   //===================================================
   // Trend
   //===================================================

   void ClassifyTrend(CAQFMarketSnapshot &snapshot)
   {
      bool bullishAlignment =
         snapshot.Close   > snapshot.EMAFast &&
         snapshot.EMAFast > snapshot.EMASlow &&
         snapshot.EMASlow > snapshot.EMA200;

      bool bearishAlignment =
         snapshot.Close   < snapshot.EMAFast &&
         snapshot.EMAFast < snapshot.EMASlow &&
         snapshot.EMASlow < snapshot.EMA200;

      if(bullishAlignment)
      {
         snapshot.Trend = AQF_TREND_UP;
      }
      else if(bearishAlignment)
      {
         snapshot.Trend = AQF_TREND_DOWN;
      }
      else
      {
         snapshot.Trend = AQF_TREND_RANGE;
      }
   }

   //===================================================
   // Trend Strength
   //===================================================

   void ClassifyTrendStrength(CAQFMarketSnapshot &snapshot)
   {
      if(snapshot.ADX < m_adxWeakThreshold)
      {
         snapshot.TrendStrength = AQF_STRENGTH_WEAK;
      }
      else if(snapshot.ADX < m_adxStrongThreshold)
      {
         snapshot.TrendStrength = AQF_STRENGTH_MODERATE;
      }
      else
      {
         snapshot.TrendStrength = AQF_STRENGTH_STRONG;
      }
   }

   //===================================================
   // Volatility
   //===================================================

   void ClassifyVolatility(CAQFMarketSnapshot &snapshot)
   {
      if(snapshot.ATRPercent < m_lowVolatilityPercent)
      {
         snapshot.Volatility = AQF_VOLATILITY_LOW;
      }
      else if(snapshot.ATRPercent > m_highVolatilityPercent)
      {
         snapshot.Volatility = AQF_VOLATILITY_HIGH;
      }
      else
      {
         snapshot.Volatility = AQF_VOLATILITY_NORMAL;
      }
   }

   //===================================================
   // Momentum
   //===================================================

   void ClassifyMomentum(CAQFMarketSnapshot &snapshot)
   {
      if(snapshot.RSI >= 55.0)
      {
         snapshot.Momentum = AQF_MOMENTUM_BULLISH;
      }
      else if(snapshot.RSI <= 45.0)
      {
         snapshot.Momentum = AQF_MOMENTUM_BEARISH;
      }
      else
      {
         snapshot.Momentum = AQF_MOMENTUM_NEUTRAL;
      }
   }
};

#endif