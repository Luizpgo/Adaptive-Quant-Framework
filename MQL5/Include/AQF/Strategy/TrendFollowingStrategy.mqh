#ifndef __AQF_TREND_FOLLOWING_STRATEGY_MQH__
#define __AQF_TREND_FOLLOWING_STRATEGY_MQH__

#include "StrategyBase.mqh"

//+------------------------------------------------------------------+
//| Trend Following Strategy                                         |
//+------------------------------------------------------------------+
class CAQFTrendFollowingStrategy : public CAQFStrategyBase
{
private:

   double m_minimumConfidence;

public:

   CAQFTrendFollowingStrategy()
   {
      m_name  = "Trend Following";
      m_type  = AQF_STRATEGY_TREND_FOLLOWING;

      m_minimumConfidence = 60.0;
   }

   //==============================================================
   // Evaluate
   //==============================================================
   virtual bool Evaluate(
      const CAQFMarketSnapshot &snapshot,
      CAQFTradeSignal &signal)
   {
      signal.Reset();

      if(!m_enabled)
         return false;

      if(!snapshot.Valid)
         return false;

      //------------------------------------------------------------
      // Context
      //------------------------------------------------------------

      signal.Time     = snapshot.Time;
      signal.Symbol   = snapshot.Symbol;
      signal.Strategy = m_type;

      signal.Trend         = snapshot.Trend;
      signal.TrendStrength = snapshot.TrendStrength;
      signal.Volatility    = snapshot.Volatility;
      signal.Momentum      = snapshot.Momentum;

      double confidence = 0.0;

      //------------------------------------------------------------
      // BUY context
      //------------------------------------------------------------

      if(snapshot.Trend == AQF_TREND_UP)
      {
         signal.Direction = AQF_SIGNAL_BUY;

         confidence += 40.0;

         if(snapshot.TrendStrength ==
            AQF_STRENGTH_MODERATE)
         {
            confidence += 15.0;
         }
         else if(snapshot.TrendStrength ==
                 AQF_STRENGTH_STRONG)
         {
            confidence += 25.0;
         }

         if(snapshot.Momentum ==
            AQF_MOMENTUM_BULLISH)
         {
            confidence += 20.0;
         }

         if(snapshot.Volatility ==
            AQF_VOLATILITY_NORMAL)
         {
            confidence += 15.0;
         }
         else if(snapshot.Volatility ==
                 AQF_VOLATILITY_HIGH)
         {
            confidence -= 10.0;
         }

         signal.Reason =
            "Bullish trend-following alignment";
      }

      //------------------------------------------------------------
      // SELL context
      //------------------------------------------------------------

      else if(snapshot.Trend == AQF_TREND_DOWN)
      {
         signal.Direction = AQF_SIGNAL_SELL;

         confidence += 40.0;

         if(snapshot.TrendStrength ==
            AQF_STRENGTH_MODERATE)
         {
            confidence += 15.0;
         }
         else if(snapshot.TrendStrength ==
                 AQF_STRENGTH_STRONG)
         {
            confidence += 25.0;
         }

         if(snapshot.Momentum ==
            AQF_MOMENTUM_BEARISH)
         {
            confidence += 20.0;
         }

         if(snapshot.Volatility ==
            AQF_VOLATILITY_NORMAL)
         {
            confidence += 15.0;
         }
         else if(snapshot.Volatility ==
                 AQF_VOLATILITY_HIGH)
         {
            confidence -= 10.0;
         }

         signal.Reason =
            "Bearish trend-following alignment";
      }

      //------------------------------------------------------------
      // Trend strategy not applicable
      //------------------------------------------------------------

      else
      {
         signal.Direction  = AQF_SIGNAL_NONE;
         signal.Quality    = AQF_SIGNAL_QUALITY_LOW;
         signal.Confidence = 0.0;

         signal.Reason =
            "Trend strategy not applicable";

         signal.Valid = false;

         return true;
      }

      //------------------------------------------------------------
      // Normalize score
      //------------------------------------------------------------

      if(confidence < 0.0)
         confidence = 0.0;

      if(confidence > 100.0)
         confidence = 100.0;

      signal.Confidence = confidence;

      //------------------------------------------------------------
      // Quality
      //------------------------------------------------------------

      if(confidence >= 80.0)
      {
         signal.Quality =
            AQF_SIGNAL_QUALITY_HIGH;
      }
      else if(confidence >= 60.0)
      {
         signal.Quality =
            AQF_SIGNAL_QUALITY_MEDIUM;
      }
      else
      {
         signal.Quality =
            AQF_SIGNAL_QUALITY_LOW;
      }

      //------------------------------------------------------------
      // Validity
      //------------------------------------------------------------

      signal.Valid =
         (
            signal.Direction != AQF_SIGNAL_NONE &&
            signal.Confidence >= m_minimumConfidence
         );

      return true;
   }
};

#endif