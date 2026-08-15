#ifndef __AQF_EXECUTION_RESULT_MQH__
#define __AQF_EXECUTION_RESULT_MQH__

enum ENUM_AQF_EXECUTION_STATUS
{
   AQF_EXECUTION_UNKNOWN = 0,
   AQF_EXECUTION_BLOCKED,
   AQF_EXECUTION_READY,
   AQF_EXECUTION_REJECTED,
   AQF_EXECUTION_SENT
};

enum ENUM_AQF_EXECUTION_REJECTION
{
   AQF_EXECUTION_REJECTION_NONE = 0,

   AQF_EXECUTION_INVALID_REQUEST,
   AQF_EXECUTION_PREFLIGHT_NOT_PASSED,
   AQF_EXECUTION_DUPLICATE,
   AQF_EXECUTION_DISABLED,
   AQF_EXECUTION_NATIVE_BUILD_FAILED,
   AQF_EXECUTION_SEND_FAILED
};

class CAQFExecutionResult
{
public:

   ENUM_AQF_EXECUTION_STATUS    Status;
   ENUM_AQF_EXECUTION_REJECTION RejectionReason;

   bool Ready;
   bool Sent;

   uint  Retcode;
   ulong OrderTicket;
   ulong DealTicket;

   string BrokerComment;
   string Message;

   CAQFExecutionResult()
   {
      Reset();
   }

   void Reset()
   {
      Status          = AQF_EXECUTION_UNKNOWN;
      RejectionReason = AQF_EXECUTION_REJECTION_NONE;

      Ready = false;
      Sent  = false;

      Retcode     = 0;
      OrderTicket = 0;
      DealTicket  = 0;

      BrokerComment = "";
      Message       = "";
   }
};

string AQFExecutionStatusToString(
   const ENUM_AQF_EXECUTION_STATUS status)
{
   switch(status)
   {
      case AQF_EXECUTION_BLOCKED:
         return "BLOCKED";

      case AQF_EXECUTION_READY:
         return "READY";

      case AQF_EXECUTION_REJECTED:
         return "REJECTED";

      case AQF_EXECUTION_SENT:
         return "SENT";

      default:
         return "UNKNOWN";
   }
}

string AQFExecutionRejectionToString(
   const ENUM_AQF_EXECUTION_REJECTION reason)
{
   switch(reason)
   {
      case AQF_EXECUTION_INVALID_REQUEST:
         return "INVALID_REQUEST";

      case AQF_EXECUTION_PREFLIGHT_NOT_PASSED:
         return "PREFLIGHT_NOT_PASSED";

      case AQF_EXECUTION_DUPLICATE:
         return "DUPLICATE";

      case AQF_EXECUTION_DISABLED:
         return "EXECUTION_DISABLED";

      case AQF_EXECUTION_NATIVE_BUILD_FAILED:
         return "NATIVE_BUILD_FAILED";

      case AQF_EXECUTION_SEND_FAILED:
         return "SEND_FAILED";

      default:
         return "NONE";
   }
}

#endif