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

#include "OrderBuilder.mqh"
#include "ExecutionPreflight.mqh"

class CAQFTradeEngine : public CAQFFrameworkModule
{
private:

   CAQFOrderBuilder       m_orderBuilder;
   CAQFExecutionPreflight m_preflight;

   bool m_executionEnabled;

public:

   CAQFTradeEngine()
   {
      m_name    = "TradeEngine";
      m_version = "0.6.1";

      //------------------------------------------------------------
      // Package B remains HARD DISABLED for execution.
      //------------------------------------------------------------

      m_executionEnabled = false;
   }

   bool Initialize(
      CAQFLogger &logger)
   {
      m_status =
         AQF_MODULE_INITIALIZING;

      m_executionEnabled =
         false;

      //------------------------------------------------------------
      // Initial spread policy.
      //------------------------------------------------------------

      m_preflight.SetMaxSpreadPoints(
         100.0
      );

      m_status =
         AQF_MODULE_READY;

      logger.Info(
         "TradeEngine initialized in PREFLIGHT DRY-RUN mode."
      );

      logger.Info(
         "OrderCheck enabled. Trade execution remains DISABLED."
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
      CAQFLogger &logger)
   {
      //------------------------------------------------------------
      // Build internal AQF request
      //------------------------------------------------------------

      bool builderOk =
         m_orderBuilder.Build(
            signal,
            market,
            risk,
            request,
            buildResult
         );

      if(!builderOk)
      {
         logger.Error(
            "OrderBuilder execution failed."
         );

         return false;
      }

      //------------------------------------------------------------
      // Stop if builder rejected
      //------------------------------------------------------------

      if(!buildResult.Ready)
         return true;

      //------------------------------------------------------------
      // Broker preflight
      //------------------------------------------------------------

      bool preflightOk =
         m_preflight.Validate(
            request,
            preflightResult
         );

      if(!preflightOk)
      {
         logger.Error(
            "ExecutionPreflight internal execution failed."
         );

         return false;
      }

      //------------------------------------------------------------
      // Module only reaches RUNNING after passing preflight.
      //------------------------------------------------------------

      if(preflightResult.Passed &&
         m_status == AQF_MODULE_READY)
      {
         m_status =
            AQF_MODULE_RUNNING;
      }

      return true;
   }

   bool ExecutionEnabled()
   {
      return m_executionEnabled;
   }

   virtual void Shutdown()
   {
      m_executionEnabled =
         false;

      m_status =
         AQF_MODULE_STOPPED;
   }
};

#endif