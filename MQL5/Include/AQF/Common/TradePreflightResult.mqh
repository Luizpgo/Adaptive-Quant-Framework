#ifndef __AQF_TRADE_PREFLIGHT_RESULT_MQH__
#define __AQF_TRADE_PREFLIGHT_RESULT_MQH__

enum ENUM_AQF_PREFLIGHT_STATUS
{
   AQF_PREFLIGHT_UNKNOWN = 0,
   AQF_PREFLIGHT_PASSED,
   AQF_PREFLIGHT_REJECTED
};

enum ENUM_AQF_PREFLIGHT_REJECTION
{
   AQF_PREFLIGHT_REJECTION_NONE = 0,

   AQF_PREFLIGHT_INVALID_REQUEST,
   AQF_PREFLIGHT_SYMBOL_DISABLED,
   AQF_PREFLIGHT_DIRECTION_NOT_ALLOWED,

   AQF_PREFLIGHT_INVALID_VOLUME,
   AQF_PREFLIGHT_VOLUME_STEP,

   AQF_PREFLIGHT_INVALID_PRICE,
   AQF_PREFLIGHT_SPREAD_TOO_HIGH,

   AQF_PREFLIGHT_STOP_DISTANCE,
   AQF_PREFLIGHT_FILLING_MODE,

   AQF_PREFLIGHT_ORDER_CHECK_FAILED
};

class CAQFTradePreflightResult
{
public:

   ENUM_AQF_PREFLIGHT_STATUS    Status;
   ENUM_AQF_PREFLIGHT_REJECTION RejectionReason;

   bool Passed;

   ENUM_ORDER_TYPE_FILLING FillingMode;

   double SpreadPoints;

   uint   CheckRetcode;
   string CheckComment;

   double CheckBalance;
   double CheckEquity;
   double CheckMargin;
   double CheckFreeMargin;
   double CheckMarginLevel;

   string Message;

   CAQFTradePreflightResult()
   {
      Reset();
   }

   void Reset()
   {
      Status          = AQF_PREFLIGHT_UNKNOWN;
      RejectionReason = AQF_PREFLIGHT_REJECTION_NONE;

      Passed = false;

      FillingMode = ORDER_FILLING_FOK;

      SpreadPoints = 0.0;

      CheckRetcode = 0;
      CheckComment = "";

      CheckBalance     = 0.0;
      CheckEquity      = 0.0;
      CheckMargin      = 0.0;
      CheckFreeMargin  = 0.0;
      CheckMarginLevel = 0.0;

      Message = "";
   }
};

string AQFPreflightStatusToString(
   const ENUM_AQF_PREFLIGHT_STATUS status)
{
   switch(status)
   {
      case AQF_PREFLIGHT_PASSED:
         return "PASSED";

      case AQF_PREFLIGHT_REJECTED:
         return "REJECTED";

      default:
         return "UNKNOWN";
   }
}

string AQFPreflightRejectionToString(
   const ENUM_AQF_PREFLIGHT_REJECTION reason)
{
   switch(reason)
   {
      case AQF_PREFLIGHT_INVALID_REQUEST:
         return "INVALID_REQUEST";

      case AQF_PREFLIGHT_SYMBOL_DISABLED:
         return "SYMBOL_DISABLED";

      case AQF_PREFLIGHT_DIRECTION_NOT_ALLOWED:
         return "DIRECTION_NOT_ALLOWED";

      case AQF_PREFLIGHT_INVALID_VOLUME:
         return "INVALID_VOLUME";

      case AQF_PREFLIGHT_VOLUME_STEP:
         return "VOLUME_STEP";

      case AQF_PREFLIGHT_INVALID_PRICE:
         return "INVALID_PRICE";

      case AQF_PREFLIGHT_SPREAD_TOO_HIGH:
         return "SPREAD_TOO_HIGH";

      case AQF_PREFLIGHT_STOP_DISTANCE:
         return "STOP_DISTANCE";

      case AQF_PREFLIGHT_FILLING_MODE:
         return "FILLING_MODE";

      case AQF_PREFLIGHT_ORDER_CHECK_FAILED:
         return "ORDER_CHECK_FAILED";

      default:
         return "NONE";
   }
}

string AQFFillingModeToString(
   const ENUM_ORDER_TYPE_FILLING mode)
{
   switch(mode)
   {
      case ORDER_FILLING_FOK:
         return "FOK";

      case ORDER_FILLING_IOC:
         return "IOC";

      case ORDER_FILLING_RETURN:
         return "RETURN";

      default:
         return "UNKNOWN";
   }
}

#endif