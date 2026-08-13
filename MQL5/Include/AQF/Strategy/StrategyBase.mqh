#ifndef __AQF_STRATEGY_BASE_MQH__
#define __AQF_STRATEGY_BASE_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Common/StrategyType.mqh"

//+------------------------------------------------------------------+
//| Abstract strategy contract                                       |
//+------------------------------------------------------------------+
class CAQFStrategyBase
{
protected:

   string                 m_name;
   ENUM_AQF_STRATEGY_TYPE m_type;
   bool                   m_enabled;

public:

   CAQFStrategyBase()
   {
      m_name    = "AQF Strategy";
      m_type    = AQF_STRATEGY_NONE;
      m_enabled = true;
   }

   virtual ~CAQFStrategyBase()
   {
   }

   //==============================================================
   // Identity
   //==============================================================
   string Name()
   {
      return m_name;
   }

   ENUM_AQF_STRATEGY_TYPE Type()
   {
      return m_type;
   }

   //==============================================================
   // Enable / Disable
   //==============================================================
   void SetEnabled(const bool enabled)
   {
      m_enabled = enabled;
   }

   bool IsEnabled()
   {
      return m_enabled;
   }

   //==============================================================
   // Strategy contract
   //==============================================================
   virtual bool Evaluate(
      const CAQFMarketSnapshot &snapshot,
      CAQFTradeSignal &signal
   ) = 0;
};

#endif