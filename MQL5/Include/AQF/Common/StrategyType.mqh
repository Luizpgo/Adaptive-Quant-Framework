#ifndef __AQF_STRATEGY_TYPE_MQH__
#define __AQF_STRATEGY_TYPE_MQH__

//+------------------------------------------------------------------+
//| Strategy identifiers                                             |
//+------------------------------------------------------------------+
enum ENUM_AQF_STRATEGY_TYPE
{
   AQF_STRATEGY_NONE = 0,
   AQF_STRATEGY_TREND_FOLLOWING,
   AQF_STRATEGY_MEAN_REVERSION,
   AQF_STRATEGY_BREAKOUT,
   AQF_STRATEGY_XAU_SCALPER
};

//+------------------------------------------------------------------+
//| Convert strategy type to readable text                           |
//+------------------------------------------------------------------+
string AQFStrategyTypeToString(
   const ENUM_AQF_STRATEGY_TYPE strategy)
{
   switch(strategy)
   {
      case AQF_STRATEGY_TREND_FOLLOWING:
         return "TREND_FOLLOWING";

      case AQF_STRATEGY_MEAN_REVERSION:
         return "MEAN_REVERSION";

      case AQF_STRATEGY_BREAKOUT:
         return "BREAKOUT";

      case AQF_STRATEGY_XAU_SCALPER:
         return "XAU_SCALPER";

      default:
         return "NONE";
   }
}

#endif