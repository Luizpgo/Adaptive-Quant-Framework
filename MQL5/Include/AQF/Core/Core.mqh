#ifndef __AQF_CORE_MQH__
#define __AQF_CORE_MQH__

#include "../Config/Configuration.mqh"
#include "../Logger/Logger.mqh"
#include "../Market/MarketEngine.mqh"
#include "../Strategy/StrategyEngine.mqh"
#include "../Strategy/SignalValidator.mqh"

#include "../Common/MarketSnapshot.mqh"
#include "../Common/MarketRegime.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Common/StrategyType.mqh"
#include "../Common/SignalValidation.mqh"

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

   CAQFMarketSnapshot         m_snapshot;
   CAQFTradeSignal            m_signal;
   CAQFSignalValidationResult m_validation;

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
         "Adaptive Quant Framework v0.4.0"
      );

      m_logger.Info(
         "Signal Validation Layer"
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

      if(!m_strategyEngine.Initialize(m_logger))
      {
         m_logger.Error(
            "StrategyEngine initialization failed."
         );

         return false;
      }

      //------------------------------------------------------------
      // Signal Validator
      //------------------------------------------------------------

      m_signalValidator.SetMinimumConfidence(60.0);

      //------------------------------------------------------------
      // Complete
      //------------------------------------------------------------

      m_initialized = true;

      m_logger.Info(
         "SignalValidator initialized."
      );

      m_logger.Info(
         "AQF INITIALIZATION SUCCESSFUL"
      );

      return true;
   }

   //==============================================================
   // Main Update
   //==============================================================
   void Update()
   {
      if(!m_initialized)
         return;

      //------------------------------------------------------------
      // Market Snapshot
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
      // Strategy Evaluation
      //------------------------------------------------------------

      if(!m_strategyEngine.Evaluate(
            m_snapshot,
            m_signal,
            m_logger))
      {
         return;
      }

      //------------------------------------------------------------
      // Strategy diagnostics
      //------------------------------------------------------------

      m_logger.Debug(
         "Signal | " +
         m_snapshot.Symbol +
         " | Strategy=" +
         AQFStrategyTypeToString(
            m_signal.Strategy) +
         " | Direction=" +
         AQFSignalDirectionToString(
            m_signal.Direction) +
         " | Confidence=" +
         DoubleToString(
            m_signal.Confidence,
            1) +
         " | Quality=" +
         AQFSignalQualityToString(
            m_signal.Quality) +
         " | Valid=" +
         (m_signal.Valid ? "YES" : "NO") +
         " | Reason=" +
         m_signal.Reason
      );

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
      // Validation diagnostics
      //------------------------------------------------------------

      m_logger.Debug(
         "Validation | " +
         m_snapshot.Symbol +
         " | Status=" +
         AQFValidationStatusToString(
            m_validation.Status) +
         " | Rejection=" +
         AQFRejectionReasonToString(
            m_validation.RejectionReason) +
         " | Message=" +
         m_validation.Message
      );

      //------------------------------------------------------------
      // IMPORTANT:
      //
      // Accepted signals STOP HERE.
      //
      // RiskManager integration will be implemented in Sprint 5.
      //------------------------------------------------------------

      if(m_validation.Accepted)
      {
         m_logger.Debug(
            "Pipeline | Signal accepted and ready for RiskManager"
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
         m_strategyEngine.StatusText()
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