#ifndef __AQF_TRADE_BUILD_RESULT_MQH__
#define __AQF_TRADE_BUILD_RESULT_MQH__

//+------------------------------------------------------------------+
//| Trade request build status                                       |
//+------------------------------------------------------------------+
enum ENUM_AQF_TRADE_BUILD_STATUS
{
   AQF_TRADE_BUILD_UNKNOWN = 0,
   AQF_TRADE_BUILD_READY,
   AQF_TRADE_BUILD_REJECTED
};

//+------------------------------------------------------------------+
//| Trade request build rejection reason                             |
//+------------------------------------------------------------------+
enum ENUM_AQF_TRADE_BUILD_REJECTION
{
   AQF_TRADE_BUILD_REJECTION_NONE = 0,

   AQF_TRADE_BUILD_INVALID_SIGNAL,
   AQF_TRADE_BUILD_RISK_NOT_AUTHORIZED,

   AQF_TRADE_BUILD_INVALID_SYMBOL,
   AQF_TRADE_BUILD_INVALID_DIRECTION,
   AQF_TRADE_BUILD_INVALID_VOLUME,
   AQF_TRADE_BUILD_INVALID_ENTRY_PRICE,

   AQF_TRADE_BUILD_INVALID_STOP,
   AQF_TRADE_BUILD_INVALID_TAKE_PROFIT,

   AQF_TRADE_BUILD_BROKER_STOP_DISTANCE
};

//+------------------------------------------------------------------+
//| Result                                                           |
//+------------------------------------------------------------------+
class CAQFTradeBuildResult
{
public:

   ENUM_AQF_TRADE_BUILD_STATUS    Status;
   ENUM_AQF_TRADE_BUILD_REJECTION RejectionReason;

   bool Ready;

   string Message;

   CAQFTradeBuildResult()
   {
      Reset();
   }

   void Reset()
   {
      Status          = AQF_TRADE_BUILD_UNKNOWN;
      RejectionReason = AQF_TRADE_BUILD_REJECTION_NONE;

      Ready = false;

      Message = "";
   }
};

//+------------------------------------------------------------------+
//| Status text                                                      |
//+------------------------------------------------------------------+
string AQFTradeBuildStatusToString(
   const ENUM_AQF_TRADE_BUILD_STATUS status)
{
   switch(status)
   {
      case AQF_TRADE_BUILD_READY:
         return "READY";

      case AQF_TRADE_BUILD_REJECTED:
         return "REJECTED";

      default:
         return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Rejection text                                                   |
//+------------------------------------------------------------------+
string AQFTradeBuildRejectionToString(
   const ENUM_AQF_TRADE_BUILD_REJECTION reason)
{
   switch(reason)
   {
      case AQF_TRADE_BUILD_INVALID_SIGNAL:
         return "INVALID_SIGNAL";

      case AQF_TRADE_BUILD_RISK_NOT_AUTHORIZED:
         return "RISK_NOT_AUTHORIZED";

      case AQF_TRADE_BUILD_INVALID_SYMBOL:
         return "INVALID_SYMBOL";

      case AQF_TRADE_BUILD_INVALID_DIRECTION:
         return "INVALID_DIRECTION";

      case AQF_TRADE_BUILD_INVALID_VOLUME:
         return "INVALID_VOLUME";

      case AQF_TRADE_BUILD_INVALID_ENTRY_PRICE:
         return "INVALID_ENTRY_PRICE";

      case AQF_TRADE_BUILD_INVALID_STOP:
         return "INVALID_STOP";

      case AQF_TRADE_BUILD_INVALID_TAKE_PROFIT:
         return "INVALID_TAKE_PROFIT";

      case AQF_TRADE_BUILD_BROKER_STOP_DISTANCE:
         return "BROKER_STOP_DISTANCE";

      default:
         return "NONE";
   }
}

#endif