#ifndef __MARKETSNAPSHOT_MQH__
#define __MARKETSNAPSHOT_MQH__

class CMarketSnapshot
{
public:

   //=========================
   // Symbol Information
   //=========================

   string Symbol;
   ENUM_TIMEFRAMES Timeframe;

   datetime Time;

   //=========================
   // Prices
   //=========================

   double Bid;
   double Ask;
   double Last;

   double Spread;

   //=========================
   // OHLC
   //=========================

   double Open;
   double High;
   double Low;
   double Close;

   //=========================
   // Trend
   //=========================

   double EMA20;
   double EMA50;
   double EMA200;

   bool UpTrend;
   bool DownTrend;

   //=========================
   // Volatility
   //=========================

   double ATR;

   //=========================
   // Momentum
   //=========================

   double RSI;

   double ADX;

   //=========================
   // Volume
   //=========================

   long TickVolume;

   //=========================
   // Trading Conditions
   //=========================

   bool IsSpreadAcceptable;

   bool IsSessionAllowed;

   bool IsNewsAllowed;

   bool IsVolatilityAcceptable;

   bool IsLiquidityAcceptable;

   //=========================
   // Strategy Result
   //=========================

   bool BuySignal;

   bool SellSignal;

   //=========================
   // Constructor
   //=========================

   CMarketSnapshot()
   {
      BuySignal = false;
      SellSignal = false;
   };

};

#endif