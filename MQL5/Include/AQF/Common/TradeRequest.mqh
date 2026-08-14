#ifndef __AQF_TRADE_REQUEST_MQH__
#define __AQF_TRADE_REQUEST_MQH__

#include "TradeSignal.mqh"

//+------------------------------------------------------------------+
//| Internal AQF trade request                                       |
//|                                                                  |
//| IMPORTANT:                                                       |
//| This is NOT MqlTradeRequest and cannot execute trades.           |
//+------------------------------------------------------------------+
class CAQFTradeRequest
{
public:

   string Symbol;

   ENUM_AQF_SIGNAL_DIRECTION Direction;

   double Volume;

   double EntryPrice;
   double StopLoss;
   double TakeProfit;

   double StopDistance;
   double TakeProfitDistance;

   ulong MagicNumber;

   string Comment;

   datetime SignalTime;

   ENUM_AQF_STRATEGY_TYPE Strategy;

   bool Valid;

   CAQFTradeRequest()
   {
      Reset();
   }

   void Reset()
   {
      Symbol = "";

      Direction = AQF_SIGNAL_NONE;

      Volume = 0.0;

      EntryPrice = 0.0;
      StopLoss   = 0.0;
      TakeProfit = 0.0;

      StopDistance       = 0.0;
      TakeProfitDistance = 0.0;

      MagicNumber = 0;

      Comment = "";

      SignalTime = 0;

      Strategy = AQF_STRATEGY_NONE;

      Valid = false;
   }
};

#endif