#ifndef __AQF_MARKET_REGIME_MQH__
#define __AQF_MARKET_REGIME_MQH__

//======================================================
// Trend Regime
//======================================================

enum ENUM_AQF_TREND_REGIME
{
   AQF_TREND_UNKNOWN = 0,
   AQF_TREND_UP,
   AQF_TREND_DOWN,
   AQF_TREND_RANGE
};

//======================================================
// Trend Strength
//======================================================

enum ENUM_AQF_TREND_STRENGTH
{
   AQF_STRENGTH_UNKNOWN = 0,
   AQF_STRENGTH_WEAK,
   AQF_STRENGTH_MODERATE,
   AQF_STRENGTH_STRONG
};

//======================================================
// Volatility Regime
//======================================================

enum ENUM_AQF_VOLATILITY_REGIME
{
   AQF_VOLATILITY_UNKNOWN = 0,
   AQF_VOLATILITY_LOW,
   AQF_VOLATILITY_NORMAL,
   AQF_VOLATILITY_HIGH
};

//======================================================
// Momentum Regime
//======================================================

enum ENUM_AQF_MOMENTUM_REGIME
{
   AQF_MOMENTUM_UNKNOWN = 0,
   AQF_MOMENTUM_BEARISH,
   AQF_MOMENTUM_NEUTRAL,
   AQF_MOMENTUM_BULLISH
};

//======================================================
// Text Helpers
//======================================================

string AQFTrendToString(ENUM_AQF_TREND_REGIME value)
{
   switch(value)
   {
      case AQF_TREND_UP:
         return "UPTREND";

      case AQF_TREND_DOWN:
         return "DOWNTREND";

      case AQF_TREND_RANGE:
         return "RANGE";

      default:
         return "UNKNOWN";
   }
}

string AQFStrengthToString(ENUM_AQF_TREND_STRENGTH value)
{
   switch(value)
   {
      case AQF_STRENGTH_WEAK:
         return "WEAK";

      case AQF_STRENGTH_MODERATE:
         return "MODERATE";

      case AQF_STRENGTH_STRONG:
         return "STRONG";

      default:
         return "UNKNOWN";
   }
}

string AQFVolatilityToString(ENUM_AQF_VOLATILITY_REGIME value)
{
   switch(value)
   {
      case AQF_VOLATILITY_LOW:
         return "LOW";

      case AQF_VOLATILITY_NORMAL:
         return "NORMAL";

      case AQF_VOLATILITY_HIGH:
         return "HIGH";

      default:
         return "UNKNOWN";
   }
}

string AQFMomentumToString(ENUM_AQF_MOMENTUM_REGIME value)
{
   switch(value)
   {
      case AQF_MOMENTUM_BEARISH:
         return "BEARISH";

      case AQF_MOMENTUM_NEUTRAL:
         return "NEUTRAL";

      case AQF_MOMENTUM_BULLISH:
         return "BULLISH";

      default:
         return "UNKNOWN";
   }
}

#endif