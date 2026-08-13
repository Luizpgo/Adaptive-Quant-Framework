#ifndef __AQF_RISK_DECISION_MQH__
#define __AQF_RISK_DECISION_MQH__

enum ENUM_AQF_RISK_STATUS
{
   AQF_RISK_UNKNOWN = 0,
   AQF_RISK_AUTHORIZED,
   AQF_RISK_REJECTED
};

enum ENUM_AQF_RISK_REJECTION_REASON
{
   AQF_RISK_REJECTION_NONE = 0,

   AQF_RISK_REJECTION_INVALID_SIGNAL,
   AQF_RISK_REJECTION_INVALID_ACCOUNT,

   AQF_RISK_REJECTION_MAX_DRAWDOWN,
   AQF_RISK_REJECTION_LOW_FREE_MARGIN,
   AQF_RISK_REJECTION_MARGIN_REQUIREMENT,

   AQF_RISK_REJECTION_INVALID_VOLUME,
   AQF_RISK_REJECTION_INVALID_PRICE,

   AQF_RISK_REJECTION_POSITION_SIZING,
   AQF_RISK_REJECTION_EXPOSURE_LIMIT,

   AQF_RISK_REJECTION_RISK_BUDGET,
   AQF_RISK_REJECTION_MARGIN_BUDGET,
   AQF_RISK_REJECTION_CAPITAL_EXPOSURE
};

class CAQFRiskDecision
{
public:

   ENUM_AQF_RISK_STATUS           Status;
   ENUM_AQF_RISK_REJECTION_REASON RejectionReason;

   bool Authorized;

   double RiskPercent;
   double RiskMoney;

   double StopPrice;
   double StopDistance;

   double RequestedVolume;
   double NormalizedVolume;

   double EstimatedMargin;
   double EstimatedMarginPercent;

   double CurrentSymbolExposure;
   double CurrentSymbolNotional;
   double ProposedNotional;
   double TotalProjectedNotional;
   double ProjectedNotionalPercent;

   string Message;

   CAQFRiskDecision()
   {
      Reset();
   }

   void Reset()
   {
      Status          = AQF_RISK_UNKNOWN;
      RejectionReason = AQF_RISK_REJECTION_NONE;

      Authorized = false;

      RiskPercent = 0.0;
      RiskMoney   = 0.0;

      StopPrice    = 0.0;
      StopDistance = 0.0;

      RequestedVolume  = 0.0;
      NormalizedVolume = 0.0;

      EstimatedMargin        = 0.0;
      EstimatedMarginPercent = 0.0;

      CurrentSymbolExposure = 0.0;

      CurrentSymbolNotional  = 0.0;
      ProposedNotional       = 0.0;
      TotalProjectedNotional = 0.0;
      ProjectedNotionalPercent = 0.0;

      Message = "";
   }
};

string AQFRiskStatusToString(
   const ENUM_AQF_RISK_STATUS status)
{
   switch(status)
   {
      case AQF_RISK_AUTHORIZED:
         return "AUTHORIZED";

      case AQF_RISK_REJECTED:
         return "REJECTED";

      default:
         return "UNKNOWN";
   }
}

string AQFRiskRejectionReasonToString(
   const ENUM_AQF_RISK_REJECTION_REASON reason)
{
   switch(reason)
   {
      case AQF_RISK_REJECTION_INVALID_SIGNAL:
         return "INVALID_SIGNAL";

      case AQF_RISK_REJECTION_INVALID_ACCOUNT:
         return "INVALID_ACCOUNT";

      case AQF_RISK_REJECTION_MAX_DRAWDOWN:
         return "MAX_DRAWDOWN";

      case AQF_RISK_REJECTION_LOW_FREE_MARGIN:
         return "LOW_FREE_MARGIN";

      case AQF_RISK_REJECTION_MARGIN_REQUIREMENT:
         return "MARGIN_REQUIREMENT";

      case AQF_RISK_REJECTION_INVALID_VOLUME:
         return "INVALID_VOLUME";

      case AQF_RISK_REJECTION_INVALID_PRICE:
         return "INVALID_PRICE";

      case AQF_RISK_REJECTION_POSITION_SIZING:
         return "POSITION_SIZING";

      case AQF_RISK_REJECTION_EXPOSURE_LIMIT:
         return "EXPOSURE_LIMIT";

      case AQF_RISK_REJECTION_RISK_BUDGET:
         return "RISK_BUDGET";

      case AQF_RISK_REJECTION_MARGIN_BUDGET:
         return "MARGIN_BUDGET";

      case AQF_RISK_REJECTION_CAPITAL_EXPOSURE:
         return "CAPITAL_EXPOSURE";

      default:
         return "NONE";
   }
}

#endif