#ifndef __AQF_TRADE_ENGINE_MQH__
#define __AQF_TRADE_ENGINE_MQH__

#include "../Core/FrameworkModule.mqh"
#include "../Logger/Logger.mqh"

#include "../Common/TradeSignal.mqh"
#include "../Common/MarketSnapshot.mqh"
#include "../Common/RiskDecision.mqh"

#include "../Common/TradeRequest.mqh"
#include "../Common/TradeBuildResult.mqh"
#include "../Common/TradePreflightResult.mqh"
#include "../Common/ExecutionResult.mqh"

#include "OrderBuilder.mqh"
#include "ExecutionPreflight.mqh"
#include "ExecutionGateway.mqh"

class CAQFTradeEngine : public CAQFFrameworkModule
{
private:

   CAQFOrderBuilder       m_orderBuilder;
   CAQFExecutionPreflight m_preflight;
   CAQFExecutionGateway   m_gateway;

public:

   CAQFTradeEngine()
   {
      m_name    = "TradeEngine";
      m_version = "0.6.2";
   }

   bool Initialize(
      CAQFLogger &logger)
   {
      m_status =
         AQF_MODULE_INITIALIZING;

      //------------------------------------------------------------
      // HARD LOCK
      //------------------------------------------------------------

      m_gateway.SetExecutionEnabled(
         false
      );

      m_preflight.SetMaxSpreadPoints(
         100.0
      );

      m_status =
         AQF_MODULE_READY;

      logger.Info(
         "TradeEngine initialized with ExecutionGateway."
      );

      logger.Info(
         "Native request construction enabled."
      );

      logger.Info(
         "TRADE EXECUTION IS PHYSICALLY DISABLED."
      );

      return true;
   }

   bool BuildDryRunRequest(
      const CAQFTradeSignal &signal,
      const CAQFMarketSnapshot &market,
      const CAQFRiskDecision &risk,

      CAQFTradeRequest &request,
      CAQFTradeBuildResult &buildResult,
      CAQFTradePreflightResult &preflightResult,
      CAQFExecutionResult &executionResult,
      MqlTradeRequest &nativeRequest,

      CAQFLogger &logger)
   {
      //------------------------------------------------------------
      // 1. Internal request
      //------------------------------------------------------------

      if(!m_orderBuilder.Build(
            signal,
            market,
            risk,
            request,
            buildResult))
      {
         logger.Error(
            "OrderBuilder execution failed."
         );

         return false;
      }

      if(!buildResult.Ready)
         return true;

      //------------------------------------------------------------
      // 2. Broker preflight
      //------------------------------------------------------------

      if(!m_preflight.Validate(
            request,
            preflightResult))
      {
         logger.Error(
            "ExecutionPreflight internal execution failed."
         );

         return false;
      }

      if(!preflightResult.Passed)
         return true;

      //------------------------------------------------------------
      // 3. Execution gateway
      //
      // Builds native MqlTradeRequest.
      // Does NOT send it.
      //------------------------------------------------------------

      if(!m_gateway.Prepare(
            request,
            preflightResult,
            executionResult,
            nativeRequest))
      {
         logger.Error(
            "ExecutionGateway internal execution failed."
         );

         return false;
      }

      //------------------------------------------------------------
      // The expected Package C result is BLOCKED because the
      // native request is ready while execution remains disabled.
      //------------------------------------------------------------

      if(executionResult.Ready &&
         m_status == AQF_MODULE_READY)
      {
         m_status =
            AQF_MODULE_RUNNING;
      }

      return true;
   }

   bool ExecutionEnabled()
   {
      return
         m_gateway.ExecutionEnabled();
   }

   virtual void Shutdown()
   {
      m_gateway.SetExecutionEnabled(
         false
      );

      m_status =
         AQF_MODULE_STOPPED;
   }
};

#endif