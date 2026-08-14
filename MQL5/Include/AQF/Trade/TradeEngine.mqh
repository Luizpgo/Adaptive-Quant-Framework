#ifndef __AQF_TRADE_ENGINE_MQH__
#define __AQF_TRADE_ENGINE_MQH__

#include "../Core/FrameworkModule.mqh"
#include "../Logger/Logger.mqh"

#include "../Common/TradeSignal.mqh"
#include "../Common/MarketSnapshot.mqh"
#include "../Common/RiskDecision.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeBuildResult.mqh"

#include "OrderBuilder.mqh"

//+------------------------------------------------------------------+
//| AQF Trade Engine                                                 |
//|                                                                  |
//| Sprint 6 Package A: DRY RUN ONLY                                 |
//+------------------------------------------------------------------+
class CAQFTradeEngine : public CAQFFrameworkModule
{
private:

   CAQFOrderBuilder m_orderBuilder;

   bool m_executionEnabled;

public:

   CAQFTradeEngine()
   {
      m_name    = "TradeEngine";
      m_version = "0.6.0";

      //------------------------------------------------------------
      // HARD DISABLED.
      //
      // There is intentionally no execution code in Package A.
      //------------------------------------------------------------

      m_executionEnabled = false;
   }

   bool Initialize(CAQFLogger &logger)
   {
      m_status =
         AQF_MODULE_INITIALIZING;

      m_executionEnabled = false;

      m_status =
         AQF_MODULE_READY;

      logger.Info(
         "TradeEngine initialized in DRY-RUN mode."
      );

      logger.Info(
         "Trade execution is DISABLED."
      );

      return true;
   }

   bool BuildDryRunRequest(
      const CAQFTradeSignal &signal,
      const CAQFMarketSnapshot &market,
      const CAQFRiskDecision &risk,
      CAQFTradeRequest &request,
      CAQFTradeBuildResult &result,
      CAQFLogger &logger)
   {
      //------------------------------------------------------------
      // Package A has NO execution path.
      //------------------------------------------------------------

      bool buildResult =
         m_orderBuilder.Build(
            signal,
            market,
            risk,
            request,
            result
         );

      if(!buildResult)
      {
         logger.Error(
            "OrderBuilder execution failed."
         );

         return false;
      }

      if(result.Ready)
      {
         if(m_status == AQF_MODULE_READY)
            m_status = AQF_MODULE_RUNNING;
      }

      return true;
   }

   bool ExecutionEnabled()
   {
      return m_executionEnabled;
   }

   virtual void Shutdown()
   {
      m_executionEnabled = false;

      m_status =
         AQF_MODULE_STOPPED;
   }
};

#endif