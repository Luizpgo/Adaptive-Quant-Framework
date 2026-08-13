#ifndef __AQF_MARKET_SNAPSHOT_MQH__
#define __AQF_MARKET_SNAPSHOT_MQH__

#include "MarketRegime.mqh"

class CAQFMarketSnapshot
{
public:

   //===================================================
   // Identification
   //===================================================

   string          Symbol;
   ENUM_TIMEFRAMES Timeframe;
   datetime        Time;

   //===================================================
   // Prices
   //===================================================

   double Bid;
   double Ask;
   double Last;

   double Point;
   double SpreadPoints;

   //===================================================
   // OHLC
   //===================================================

   double Open;
   double High;
   double Low;
   double Close;

   long TickVolume;

   //===================================================
   // Indicators
   //===================================================

   double EMAFast;
   double EMASlow;
   double EMA200;

   double ATR;
   double RSI;
   double ADX;

   //===================================================
   // Normalized Market Metrics
   //===================================================

   double ATRPercent;
   double EMASeparationPercent;

   //===================================================
   // Market Intelligence
   //===================================================

   ENUM_AQF_TREND_REGIME      Trend;
   ENUM_AQF_TREND_STRENGTH    TrendStrength;
   ENUM_AQF_VOLATILITY_REGIME Volatility;
   ENUM_AQF_MOMENTUM_REGIME   Momentum;

   //===================================================
   // State
   //===================================================

   bool Valid;

   //===================================================
   // Constructor
   //===================================================

   CAQFMarketSnapshot()
   {
      Reset();
   }

   //===================================================
   // Reset
   //===================================================

   void Reset()
   {
      Symbol    = "";
      Timeframe = PERIOD_CURRENT;
      Time      = 0;

      Bid  = 0.0;
      Ask  = 0.0;
      Last = 0.0;

      Point        = 0.0;
      SpreadPoints = 0.0;

      Open  = 0.0;
      High  = 0.0;
      Low   = 0.0;
      Close = 0.0;

      TickVolume = 0;

      EMAFast = 0.0;
      EMASlow = 0.0;
      EMA200  = 0.0;

      ATR = 0.0;
      RSI = 0.0;
      ADX = 0.0;

      ATRPercent           = 0.0;
      EMASeparationPercent = 0.0;

      Trend         = AQF_TREND_UNKNOWN;
      TrendStrength = AQF_STRENGTH_UNKNOWN;
      Volatility    = AQF_VOLATILITY_UNKNOWN;
      Momentum      = AQF_MOMENTUM_UNKNOWN;

      Valid = false;
   }
};

#endif