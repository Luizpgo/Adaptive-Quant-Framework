#ifndef __AQF_SIGNAL_VALIDATION_MQH__
#define __AQF_SIGNAL_VALIDATION_MQH__

//+------------------------------------------------------------------+
//| Signal validation status                                         |
//+------------------------------------------------------------------+
enum ENUM_AQF_SIGNAL_VALIDATION_STATUS
{
   AQF_VALIDATION_UNKNOWN = 0,
   AQF_VALIDATION_ACCEPTED,
   AQF_VALIDATION_REJECTED
};

//+------------------------------------------------------------------+
//| Signal rejection reason                                          |
//+------------------------------------------------------------------+
enum ENUM_AQF_SIGNAL_REJECTION_REASON
{
   AQF_REJECTION_NONE = 0,
   AQF_REJECTION_INVALID_SIGNAL,
   AQF_REJECTION_NO_STRATEGY,
   AQF_REJECTION_NO_DIRECTION,
   AQF_REJECTION_LOW_CONFIDENCE,
   AQF_REJECTION_LOW_QUALITY,
   AQF_REJECTION_INVALID_SYMBOL,
   AQF_REJECTION_INVALID_TIME
};

//+------------------------------------------------------------------+
//| Signal validation result                                         |
//+------------------------------------------------------------------+
class CAQFSignalValidationResult
{
public:

   ENUM_AQF_SIGNAL_VALIDATION_STATUS Status;
   ENUM_AQF_SIGNAL_REJECTION_REASON  RejectionReason;

   string Message;

   bool Accepted;

   //==============================================================
   // Constructor
   //==============================================================
   CAQFSignalValidationResult()
   {
      Reset();
   }

   //==============================================================
   // Reset
   //==============================================================
   void Reset()
   {
      Status          = AQF_VALIDATION_UNKNOWN;
      RejectionReason = AQF_REJECTION_NONE;

      Message  = "";
      Accepted = false;
   }
};

//+------------------------------------------------------------------+
//| Validation status text                                           |
//+------------------------------------------------------------------+
string AQFValidationStatusToString(
   const ENUM_AQF_SIGNAL_VALIDATION_STATUS status)
{
   switch(status)
   {
      case AQF_VALIDATION_ACCEPTED:
         return "ACCEPTED";

      case AQF_VALIDATION_REJECTED:
         return "REJECTED";

      default:
         return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Rejection reason text                                            |
//+------------------------------------------------------------------+
string AQFRejectionReasonToString(
   const ENUM_AQF_SIGNAL_REJECTION_REASON reason)
{
   switch(reason)
   {
      case AQF_REJECTION_INVALID_SIGNAL:
         return "INVALID_SIGNAL";

      case AQF_REJECTION_NO_STRATEGY:
         return "NO_STRATEGY";

      case AQF_REJECTION_NO_DIRECTION:
         return "NO_DIRECTION";

      case AQF_REJECTION_LOW_CONFIDENCE:
         return "LOW_CONFIDENCE";

      case AQF_REJECTION_LOW_QUALITY:
         return "LOW_QUALITY";

      case AQF_REJECTION_INVALID_SYMBOL:
         return "INVALID_SYMBOL";

      case AQF_REJECTION_INVALID_TIME:
         return "INVALID_TIME";

      default:
         return "NONE";
   }
}

#endif