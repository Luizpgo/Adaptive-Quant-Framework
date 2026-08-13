#ifndef __AQF_STRATEGY_SELECTOR_MQH__
#define __AQF_STRATEGY_SELECTOR_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/StrategyType.mqh"

//+------------------------------------------------------------------+
//| Strategy selection based on market regime                        |
//+------------------------------------------------------------------+
class CAQFStrategySelector
{
public:

   CAQFStrategySelector()
   {
   }

   ENUM_AQF_STRATEGY_TYPE Select(
      const CAQFMarketSnapshot &snapshot)
   {
      if(!snapshot.Valid)
         return AQF_STRATEGY_NONE;

      //------------------------------------------------------------
      // Trending markets
      //------------------------------------------------------------

      if(snapshot.Trend == AQF_TREND_UP ||
         snapshot.Trend == AQF_TREND_DOWN)
      {
         return AQF_STRATEGY_TREND_FOLLOWING;
      }

      //------------------------------------------------------------
      // RANGE
      //
      // Mean Reversion will be implemented later.
      //------------------------------------------------------------

      if(snapshot.Trend == AQF_TREND_RANGE)
      {
         return AQF_STRATEGY_NONE;
      }

      return AQF_STRATEGY_NONE;
   }
};

#endif