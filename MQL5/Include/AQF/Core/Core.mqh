#ifndef __AQF_CORE_MQH__
#define __AQF_CORE_MQH__

#include "../Config/Configuration.mqh"
#include "../Logger/Logger.mqh"

#include "../Market/MarketEngine.mqh"

#include "../Strategy/StrategyEngine.mqh"
#include "../Strategy/SignalValidator.mqh"

#include "../Risk/RiskManager.mqh"

#include "../Trade/TradeEngine.mqh"

#include "../Common/MarketSnapshot.mqh"
#include "../Common/MarketRegime.mqh"

#include "../Common/TradeSignal.mqh"
#include "../Common/StrategyType.mqh"
#include "../Common/SignalValidation.mqh"

#include "../Common/AccountSnapshot.mqh"
#include "../Common/RiskDecision.mqh"

#include "../Common/TradeRequest.mqh"
#include "../Common/TradeBuildResult.mqh"

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

   CAQFTradeEngine            m_tradeEngine;

   CAQFMarketSnapshot         m_snapshot;
   CAQFTradeSignal            m_signal;

   CAQFSignalValidationResult m_validation;
   CAQFRiskDecision           m_riskDecision;

   CAQFTradeRequest           m_tradeRequest;
   CAQFTradeBuildResult       m_tradeBuildResult;

   bool m_initialized;

   //---------------------------------------------------------------
   // Development-only DRYRUN test
   //---------------------------------------------------------------

   bool m_dryRunTestEnabled;
   bool m_dryRunTestCompleted;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFCore()
   {
      m_initialized         = false;

      m_dryRunTestEnabled   = false;
      m_dryRunTestCompleted = false;
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(
      string symbol,
      ENUM_TIMEFRAMES timeframe,
      bool debugEnabled,
      int timerSeconds,
      bool dryRunTestEnabled)
   {
      //------------------------------------------------------------
      // Test configuration
      //------------------------------------------------------------

      m_dryRunTestEnabled =
         dryRunTestEnabled;

      m_dryRunTestCompleted =
         false;

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
         "Adaptive Quant Framework v0.6.0"
      );

      m_logger.Info(
         "Trade Execution Layer - DRY RUN"
      );

      m_logger.Info(
         "=============================================="
      );

      //------------------------------------------------------------
      // Market
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
      // Strategy
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
      // Risk
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
      // Trade Engine
      //------------------------------------------------------------

      if(!m_tradeEngine.Initialize(
            m_logger))
      {
         m_logger.Error(
            "TradeEngine initialization failed."
         );

         return false;
      }

      //------------------------------------------------------------
      // Test mode diagnostics
      //------------------------------------------------------------

      if(m_dryRunTestEnabled)
      {
         m_logger.Warning(
            "DRYRUN TEST MODE ENABLED"
         );

         m_logger.Warning(
            "Synthetic signal injection enabled."
         );

         m_logger.Warning(
            "TRADE EXECUTION REMAINS DISABLED."
         );
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
   // Main Update
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
      // Signal generation
      //------------------------------------------------------------

      if(m_dryRunTestEnabled &&
         !m_dryRunTestCompleted)
      {
         BuildSyntheticDryRunSignal();
      }
      else
      {
         if(!m_strategyEngine.Evaluate(
               m_snapshot,
               m_signal,
               m_logger))
         {
            return;
         }
      }

      //------------------------------------------------------------
      // Signal validation
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
      // Validation diagnostics in test mode
      //------------------------------------------------------------

      if(m_dryRunTestEnabled &&
         !m_dryRunTestCompleted)
      {
         m_logger.Debug(
            "TEST Validation | " +
            m_snapshot.Symbol +
            " | Status=" +
            AQFValidationStatusToString(
               m_validation.Status) +
            " | Rejection=" +
            AQFRejectionReasonToString(
               m_validation.RejectionReason)
         );
      }

      if(!m_validation.Accepted)
         return;

      //------------------------------------------------------------
      // Risk
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
      // Risk diagnostics
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
      // Stop if RiskManager rejects
      //------------------------------------------------------------

      if(!m_riskDecision.Authorized)
         return;

      //------------------------------------------------------------
      // Build Trade Request
      //
      // DRY RUN ONLY
      //------------------------------------------------------------

      if(!m_tradeEngine.BuildDryRunRequest(
            m_signal,
            m_snapshot,
            m_riskDecision,
            m_tradeRequest,
            m_tradeBuildResult,
            m_logger))
      {
         return;
      }

      //------------------------------------------------------------
      // TradeBuild diagnostics
      //------------------------------------------------------------

      m_logger.Debug(
         "TradeBuild | " +
         m_snapshot.Symbol +
         " | Status=" +
         AQFTradeBuildStatusToString(
            m_tradeBuildResult.Status) +
         " | Rejection=" +
         AQFTradeBuildRejectionToString(
            m_tradeBuildResult.RejectionReason) +
         " | Message=" +
         m_tradeBuildResult.Message
      );

      //------------------------------------------------------------
      // DRY RUN request
      //------------------------------------------------------------

      if(m_tradeBuildResult.Ready &&
         m_tradeRequest.Valid)
      {
         m_logger.Debug(
            "DRYRUN | " +
            m_tradeRequest.Symbol +
            " | Strategy=" +
            AQFStrategyTypeToString(
               m_tradeRequest.Strategy) +
            " | Direction=" +
            AQFSignalDirectionToString(
               m_tradeRequest.Direction) +
            " | Volume=" +
            DoubleToString(
               m_tradeRequest.Volume,
               2) +
            " | Entry=" +
            DoubleToString(
               m_tradeRequest.EntryPrice,
               _Digits) +
            " | SL=" +
            DoubleToString(
               m_tradeRequest.StopLoss,
               _Digits) +
            " | TP=" +
            DoubleToString(
               m_tradeRequest.TakeProfit,
               _Digits) +
            " | Magic=" +
            IntegerToString(
               (int)m_tradeRequest.MagicNumber) +
            " | EXECUTION=DISABLED"
         );

         //---------------------------------------------------------
         // Complete one-shot synthetic test.
         //---------------------------------------------------------

         if(m_dryRunTestEnabled)
         {
            m_dryRunTestCompleted = true;

            m_logger.Info(
               "=============================================="
            );

            m_logger.Info(
               "DRYRUN TEST COMPLETED SUCCESSFULLY"
            );

            m_logger.Info(
               "NO ORDER WAS SENT"
            );

            m_logger.Info(
               "=============================================="
            );
         }
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
         m_riskManager.StatusText() +
         " | TradeEngine=" +
         m_tradeEngine.StatusText() +
         " | Execution=" +
         (m_tradeEngine.ExecutionEnabled()
          ? "ON"
          : "OFF") +
         " | DryRunTest=" +
         (m_dryRunTestEnabled
          ? "ON"
          : "OFF") +
         " | TestCompleted=" +
         (m_dryRunTestCompleted
          ? "YES"
          : "NO")
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

      m_tradeEngine.Shutdown();
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

private:

   //==============================================================
   // Synthetic DRYRUN Signal
   //
   // DEVELOPMENT TEST ONLY.
   //
   // This creates an internal TradeSignal.
   // It does NOT create or send a broker order.
   //==============================================================
   void BuildSyntheticDryRunSignal()
   {
      m_signal.Reset();

      m_signal.Symbol =
         m_snapshot.Symbol;

      m_signal.Time =
         m_snapshot.Time;

      //------------------------------------------------------------
      // Use market direction if available.
      //
      // If RANGE, default to BUY only for pipeline testing.
      //------------------------------------------------------------

      if(m_snapshot.Trend ==
         AQF_TREND_DOWN)
      {
         m_signal.Direction =
            AQF_SIGNAL_SELL;
      }
      else
      {
         m_signal.Direction =
            AQF_SIGNAL_BUY;
      }

      //------------------------------------------------------------
      // Synthetic strategy metadata
      //------------------------------------------------------------

      m_signal.Strategy =
         AQF_STRATEGY_TREND_FOLLOWING;

      m_signal.Confidence =
         100.0;

      m_signal.Quality =
         AQF_SIGNAL_QUALITY_HIGH;

      m_signal.Trend =
         m_snapshot.Trend;

      m_signal.TrendStrength =
         m_snapshot.TrendStrength;

      m_signal.Volatility =
         m_snapshot.Volatility;

      m_signal.Momentum =
         m_snapshot.Momentum;

      m_signal.Reason =
         "Synthetic DRYRUN pipeline test";

      m_signal.Valid =
         true;
   }
};

#endif