#ifndef __AQF_MARKET_SNAPSHOT_MQH__
#define __AQF_MARKET_SNAPSHOT_MQH__

//+------------------------------------------------------------------+
//| Immutable-style market state container for one AQF update cycle  |
//+------------------------------------------------------------------+
class CAQFMarketSnapshot
{
public:

   //==============================================================
   // Identity
   //==============================================================
   string          Symbol;
   ENUM_TIMEFRAMES Timeframe;
   datetime        Time;

   //==============================================================
   // Tick
   //==============================================================
   double Bid;
   double Ask;
   double Last;

   double Point;
   double SpreadPoints;

   //==============================================================
   // Current bar
   //==============================================================
   double Open;
   double High;
   double Low;
   double Close;

   long TickVolume;

   //==============================================================
   // Indicators - populated in future versions
   //==============================================================
   double EMAFast;
   double EMASlow;
   double EMA200;

   double ATR;
   double RSI;
   double ADX;

   //==============================================================
   // Market classification - future versions
   //==============================================================
   bool UpTrend;
   bool DownTrend;

   bool IsSpreadAcceptable;
   bool IsSessionAllowed;
   bool IsNewsAllowed;
   bool IsVolatilityAcceptable;
   bool IsLiquidityAcceptable;

   //==============================================================
   // Snapshot validity
   //==============================================================
   bool Valid;

   //==============================================================
   // Constructor
   //==============================================================
   CAQFMarketSnapshot()
   {
      Reset();
   }

   //==============================================================
   // Reset snapshot
   //==============================================================
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

      UpTrend   = false;
      DownTrend = false;

      IsSpreadAcceptable     = false;
      IsSessionAllowed       = false;
      IsNewsAllowed          = false;
      IsVolatilityAcceptable = false;
      IsLiquidityAcceptable  = false;

      Valid = false;
   }
};

#endif