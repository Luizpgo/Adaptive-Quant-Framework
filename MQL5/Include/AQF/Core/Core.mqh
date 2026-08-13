#ifndef __AQF_CORE_MQH__
#define __AQF_CORE_MQH__

#include "../Config/Configuration.mqh"
#include "../Logger/Logger.mqh"

#include "../Market/MarketEngine.mqh"
#include "../Strategy/StrategyEngine.mqh"
#include "../Strategy/SignalValidator.mqh"
#include "../Risk/RiskManager.mqh"

#include "../Common/MarketSnapshot.mqh"
#include "../Common/MarketRegime.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Common/StrategyType.mqh"
#include "../Common/SignalValidation.mqh"
#include "../Common/AccountSnapshot.mqh"
#include "../Common/RiskDecision.mqh"

//+------------------------------------------------------------------+
//| Adaptive Quant Framework Core                                    |
//+------------------------------------------------------------------+
class CAQFCore
{
private:

   CAQFConfiguration          m_configuration;
   CAQFLogger                 m_logger;

   CAQFMarketEngine           m_marketEngine;
   CAQFStrategyEngine         m_strategyEngine;
   CAQFSignalValidator        m_signalValidator;
   CAQFRiskManager            m_riskManager;

   CAQFMarketSnapshot         m_snapshot;
   CAQFTradeSignal            m_signal;

   CAQFSignalValidationResult m_validation;
   CAQFRiskDecision           m_riskDecision;

   bool m_initialized;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFCore()
   {
      m_initialized = false;
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(
      string symbol,
      ENUM_TIMEFRAMES timeframe,
      bool debugEnabled,
      int timerSeconds)
   {
      //------------------------------------------------------------
      // Configuration
      //------------------------------------------------------------

      if(!m_configuration.Configure(
            symbol,
            timeframe,
            debugEnabled,
            timerSeconds))
      {
         Print(
            "[AQF][ERROR] Configuration initialization failed."
         );

         return false;
      }

      //------------------------------------------------------------
      // Logger
      //------------------------------------------------------------

      if(!m_logger.Initialize(
            m_configuration.DebugEnabled()))
      {
         Print(
            "[AQF][ERROR] Logger initialization failed."
         );

         return false;
      }

      m_logger.Info(
         "=============================================="
      );

      m_logger.Info(
         "Adaptive Quant Framework v0.5.0"
      );

      m_logger.Info(
         "Risk Management Layer"
      );

      m_logger.Info(
         "=============================================="
      );

      //------------------------------------------------------------
      // Market Engine
      //------------------------------------------------------------

      if(!m_marketEngine.Initialize(
            m_configuration.Symbol(),
            m_configuration.Timeframe(),
            m_logger))
      {
         m_logger.Error(
            "MarketEngine initialization failed."
         );

         return false;
      }

      //------------------------------------------------------------
      // Strategy Engine
      //------------------------------------------------------------

      if(!m_strategyEngine.Initialize(
            m_logger))
      {
         m_logger.Error(
            "StrategyEngine initialization failed."
         );

         return false;
      }

      //------------------------------------------------------------
      // Risk Manager
      //------------------------------------------------------------

      if(!m_riskManager.Initialize(
            m_logger))
      {
         m_logger.Error(
            "RiskManager initialization failed."
         );

         return false;
      }

      //------------------------------------------------------------
      // Complete
      //------------------------------------------------------------

      m_initialized = true;

      m_logger.Info(
         "AQF INITIALIZATION SUCCESSFUL"
      );

      return true;
   }

   //==============================================================
   // Update
   //==============================================================
   void Update()
   {
      if(!m_initialized)
         return;

      //------------------------------------------------------------
      // Market
      //------------------------------------------------------------

      if(!m_marketEngine.BuildSnapshot(
            m_snapshot,
            m_logger))
      {
         return;
      }

      if(!m_snapshot.Valid)
         return;

      //------------------------------------------------------------
      // Strategy
      //------------------------------------------------------------

      if(!m_strategyEngine.Evaluate(
            m_snapshot,
            m_signal,
            m_logger))
      {
         return;
      }

      //------------------------------------------------------------
      // Signal Validation
      //------------------------------------------------------------

      if(!m_signalValidator.Validate(
            m_signal,
            m_validation))
      {
         m_logger.Error(
            "SignalValidator execution failed."
         );

         return;
      }

      //------------------------------------------------------------
      // Stop invalid signals before RiskManager
      //------------------------------------------------------------

      if(!m_validation.Accepted)
      {
         m_logger.Debug(
            "Validation | " +
            m_snapshot.Symbol +
            " | Status=" +
            AQFValidationStatusToString(
               m_validation.Status) +
            " | Rejection=" +
            AQFRejectionReasonToString(
               m_validation.RejectionReason)
         );

         return;
      }

      //------------------------------------------------------------
      // Risk Evaluation
      //------------------------------------------------------------

     if(!m_riskManager.Evaluate(
      m_signal,
      m_snapshot,
      m_riskDecision,
      m_logger))
      {
         m_logger.Error(
            "RiskManager execution failed."
         );

         return;
      }

      //------------------------------------------------------------
      // Risk Diagnostics
      //------------------------------------------------------------

      m_logger.Debug(
   "Risk | " +
   m_snapshot.Symbol +
   " | Status=" +
   AQFRiskStatusToString(
      m_riskDecision.Status) +
   " | Rejection=" +
   AQFRiskRejectionReasonToString(
      m_riskDecision.RejectionReason) +
   " | Risk%=" +
   DoubleToString(
      m_riskDecision.RiskPercent,
      2) +
   " | RiskMoney=" +
   DoubleToString(
      m_riskDecision.RiskMoney,
      2) +
   " | Volume=" +
   DoubleToString(
      m_riskDecision.NormalizedVolume,
      2) +
   " | Margin%=" +
   DoubleToString(
      m_riskDecision.EstimatedMarginPercent,
      2) +
   " | Notional%=" +
   DoubleToString(
      m_riskDecision.ProjectedNotionalPercent,
      2) +
   " | Message=" +
   m_riskDecision.Message
);

      //------------------------------------------------------------
      // IMPORTANT:
      //
      // Even AUTHORIZED trades stop here.
      //
      // TradeEngine integration will occur later.
      //------------------------------------------------------------

      if(m_riskDecision.Authorized)
      {
         m_logger.Debug(
            "Pipeline | Risk authorized and ready for TradeEngine"
         );
      }
   }

   //==============================================================
   // Timer
   //==============================================================
   void OnTimer()
   {
      if(!m_initialized)
         return;

      m_logger.Debug(
         "Heartbeat | MarketEngine=" +
         m_marketEngine.StatusText() +
         " | StrategyEngine=" +
         m_strategyEngine.StatusText() +
         " | RiskManager=" +
         m_riskManager.StatusText()
      );
   }

   //==============================================================
   // Trade Event
   //==============================================================
   void OnTrade()
   {
      if(!m_initialized)
         return;

      m_logger.Debug(
         "Trade event received."
      );
   }

   //==============================================================
   // Shutdown
   //==============================================================
   void Shutdown()
   {
      if(!m_initialized)
         return;

      m_logger.Info(
         "Stopping AQF..."
      );

      m_riskManager.Shutdown();
      m_strategyEngine.Shutdown();
      m_marketEngine.Shutdown();
      m_configuration.Shutdown();
      m_logger.Shutdown();

      m_initialized = false;
   }

   //==============================================================
   // Accessors
   //==============================================================
   int TimerSeconds()
   {
      return m_configuration.TimerSeconds();
   }

   bool IsInitialized()
   {
      return m_initialized;
   }
};

#endif