#ifndef __AQF_TRADE_SIGNAL_MQH__
#define __AQF_TRADE_SIGNAL_MQH__

#include "MarketRegime.mqh"
#include "StrategyType.mqh"

//+------------------------------------------------------------------+
//| Signal Direction                                                 |
//+------------------------------------------------------------------+
enum ENUM_AQF_SIGNAL_DIRECTION
{
   AQF_SIGNAL_NONE = 0,
   AQF_SIGNAL_BUY,
   AQF_SIGNAL_SELL
};

//+------------------------------------------------------------------+
//| Signal Quality                                                   |
//+------------------------------------------------------------------+
enum ENUM_AQF_SIGNAL_QUALITY
{
   AQF_SIGNAL_QUALITY_UNKNOWN = 0,
   AQF_SIGNAL_QUALITY_LOW,
   AQF_SIGNAL_QUALITY_MEDIUM,
   AQF_SIGNAL_QUALITY_HIGH
};

//+------------------------------------------------------------------+
//| Trade Signal                                                     |
//+------------------------------------------------------------------+
class CAQFTradeSignal
{
public:

   ENUM_AQF_SIGNAL_DIRECTION Direction;
   ENUM_AQF_SIGNAL_QUALITY   Quality;
   ENUM_AQF_STRATEGY_TYPE    Strategy;

   double Confidence;

   datetime Time;
   string   Symbol;
   string   Reason;

   ENUM_AQF_TREND_REGIME      Trend;
   ENUM_AQF_TREND_STRENGTH    TrendStrength;
   ENUM_AQF_VOLATILITY_REGIME Volatility;
   ENUM_AQF_MOMENTUM_REGIME   Momentum;

   bool Valid;

   CAQFTradeSignal()
   {
      Reset();
   }

   void Reset()
   {
      Direction  = AQF_SIGNAL_NONE;
      Quality    = AQF_SIGNAL_QUALITY_UNKNOWN;
      Strategy   = AQF_STRATEGY_NONE;

      Confidence = 0.0;

      Time   = 0;
      Symbol = "";
      Reason = "";

      Trend         = AQF_TREND_UNKNOWN;
      TrendStrength = AQF_STRENGTH_UNKNOWN;
      Volatility    = AQF_VOLATILITY_UNKNOWN;
      Momentum      = AQF_MOMENTUM_UNKNOWN;

      Valid = false;
   }
};

//+------------------------------------------------------------------+
//| Direction text                                                   |
//+------------------------------------------------------------------+
string AQFSignalDirectionToString(
   const ENUM_AQF_SIGNAL_DIRECTION direction)
{
   switch(direction)
   {
      case AQF_SIGNAL_BUY:
         return "BUY";

      case AQF_SIGNAL_SELL:
         return "SELL";

      default:
         return "NONE";
   }
}

//+------------------------------------------------------------------+
//| Quality text                                                     |
//+------------------------------------------------------------------+
string AQFSignalQualityToString(
   const ENUM_AQF_SIGNAL_QUALITY quality)
{
   switch(quality)
   {
      case AQF_SIGNAL_QUALITY_LOW:
         return "LOW";

      case AQF_SIGNAL_QUALITY_MEDIUM:
         return "MEDIUM";

      case AQF_SIGNAL_QUALITY_HIGH:
         return "HIGH";

      default:
         return "UNKNOWN";
   }
}

#endif