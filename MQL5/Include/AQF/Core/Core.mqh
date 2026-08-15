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
#include "../Common/TradePreflightResult.mqh"
#include "../Common/ExecutionResult.mqh"

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
   CAQFTradePreflightResult   m_tradePreflightResult;

   CAQFExecutionResult        m_executionResult;
   MqlTradeRequest            m_nativeTradeRequest;

   bool m_initialized;

   //==============================================================
   // Development DRY-RUN Test
   //==============================================================

   bool m_dryRunTestEnabled;
   bool m_dryRunTestCompleted;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFCore()
   {
      m_initialized = false;

      m_dryRunTestEnabled   = false;
      m_dryRunTestCompleted = false;

      ZeroMemory(m_nativeTradeRequest);
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
         "Adaptive Quant Framework v0.6.2"
      );

      m_logger.Info(
         "Execution Gateway - HARD LOCKED"
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
      // Development test warning
      //------------------------------------------------------------

      if(m_dryRunTestEnabled)
      {
         m_logger.Warning(
            "PACKAGE C TEST MODE ENABLED"
         );

         m_logger.Warning(
            "Synthetic signal and isolated synthetic risk decision enabled."
         );

         m_logger.Warning(
            "TRADE EXECUTION REMAINS PHYSICALLY DISABLED."
         );
      }

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
      // Package C test is ONE SHOT.
      //------------------------------------------------------------

      if(m_dryRunTestEnabled &&
         m_dryRunTestCompleted)
      {
         return;
      }

      //------------------------------------------------------------
      // Signal
      //------------------------------------------------------------

      if(m_dryRunTestEnabled)
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

      if(m_dryRunTestEnabled)
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

      if(m_dryRunTestEnabled)
      {
         //---------------------------------------------------------
         // IMPORTANT:
         //
         // Package C test bypasses ONLY RiskManager authorization.
         //
         // This synthetic decision exists exclusively to exercise:
         //
         // OrderBuilder
         // ExecutionPreflight
         // OrderCheck
         // DuplicateGuard
         // ExecutionGateway
         //
         // Normal AQF operation NEVER uses this path.
         //---------------------------------------------------------

         if(!BuildSyntheticDryRunRiskDecision())
         {
            m_logger.Error(
               "Unable to build synthetic Package C risk decision."
            );

            return;
         }

         m_logger.Warning(
            "TEST RiskDecision | SYNTHETIC AUTHORIZATION | Volume=" +
            DoubleToString(
               m_riskDecision.NormalizedVolume,
               2)
         );
      }
      else
      {
         //---------------------------------------------------------
         // REAL RiskManager
         //---------------------------------------------------------

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

         //---------------------------------------------------------
         // Real Risk Diagnostics
         //---------------------------------------------------------

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

         if(!m_riskDecision.Authorized)
            return;
      }

      //------------------------------------------------------------
      // Build + Preflight + Execution Gateway
      //
      // STILL NO ORDER SEND
      //------------------------------------------------------------

      if(!m_tradeEngine.BuildDryRunRequest(
            m_signal,
            m_snapshot,
            m_riskDecision,
            m_tradeRequest,
            m_tradeBuildResult,
            m_tradePreflightResult,
            m_executionResult,
            m_nativeTradeRequest,
            m_logger))
      {
         return;
      }

      //------------------------------------------------------------
      // Trade Build
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
      // Preflight
      //------------------------------------------------------------

      m_logger.Debug(
         "Preflight | " +
         m_snapshot.Symbol +
         " | Status=" +
         AQFPreflightStatusToString(
            m_tradePreflightResult.Status) +
         " | Rejection=" +
         AQFPreflightRejectionToString(
            m_tradePreflightResult.RejectionReason) +
         " | Filling=" +
         AQFFillingModeToString(
            m_tradePreflightResult.FillingMode) +
         " | Spread=" +
         DoubleToString(
            m_tradePreflightResult.SpreadPoints,
            1) +
         " | Retcode=" +
         IntegerToString(
            (int)m_tradePreflightResult.CheckRetcode) +
         " | CheckMargin=" +
         DoubleToString(
            m_tradePreflightResult.CheckMargin,
            2) +
         " | CheckFreeMargin=" +
         DoubleToString(
            m_tradePreflightResult.CheckFreeMargin,
            2) +
         " | Comment=" +
         m_tradePreflightResult.CheckComment +
         " | Message=" +
         m_tradePreflightResult.Message
      );

      //------------------------------------------------------------
      // Execution Gateway
      //------------------------------------------------------------

      m_logger.Debug(
         "ExecutionGateway | " +
         m_snapshot.Symbol +
         " | Status=" +
         AQFExecutionStatusToString(
            m_executionResult.Status) +
         " | Rejection=" +
         AQFExecutionRejectionToString(
            m_executionResult.RejectionReason) +
         " | Ready=" +
         (m_executionResult.Ready
            ? "YES"
            : "NO") +
         " | Sent=" +
         (m_executionResult.Sent
            ? "YES"
            : "NO") +
         " | NativeVolume=" +
         DoubleToString(
            m_nativeTradeRequest.volume,
            2) +
         " | NativePrice=" +
         DoubleToString(
            m_nativeTradeRequest.price,
            _Digits) +
         " | Message=" +
         m_executionResult.Message
      );

      //------------------------------------------------------------
      // DRY-RUN
      //------------------------------------------------------------

      if(m_tradeBuildResult.Ready &&
         m_tradeRequest.Valid &&
         m_tradePreflightResult.Passed &&
         m_executionResult.Ready &&
         !m_executionResult.Sent)
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
            " | Filling=" +
            AQFFillingModeToString(
               m_tradePreflightResult.FillingMode) +
            " | EXECUTION=DISABLED"
         );

         //---------------------------------------------------------
         // Mark test complete ONLY here.
         //---------------------------------------------------------

         if(m_dryRunTestEnabled)
         {
            m_dryRunTestCompleted = true;

            m_logger.Info(
               "=============================================="
            );

            m_logger.Info(
               "PACKAGE C DRYRUN TEST COMPLETED SUCCESSFULLY"
            );

            m_logger.Info(
               "NATIVE REQUEST BUILT"
            );

            m_logger.Info(
               "ORDER CHECK PASSED"
            );

            m_logger.Info(
               "EXECUTION GATEWAY BLOCKED REQUEST"
            );

            m_logger.Info(
               "SENT=NO"
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
      return
         m_configuration.TimerSeconds();
   }

   bool IsInitialized()
   {
      return m_initialized;
   }

private:

   //==============================================================
   // Synthetic Signal
   //==============================================================
   void BuildSyntheticDryRunSignal()
   {
      m_signal.Reset();

      m_signal.Symbol =
         m_snapshot.Symbol;

      m_signal.Time =
         m_snapshot.Time;

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
         "Synthetic Package C pipeline test";

      m_signal.Valid =
         true;
   }

   //==============================================================
   // Synthetic Risk Decision
   //
   // DEVELOPMENT TEST ONLY.
   //
   // This bypasses RiskManager ONLY when InpDryRunTest=true.
   //==============================================================
   bool BuildSyntheticDryRunRiskDecision()
   {
      m_riskDecision.Reset();

      //------------------------------------------------------------
      // Symbol contract
      //------------------------------------------------------------

      double minVolume =
         SymbolInfoDouble(
            m_snapshot.Symbol,
            SYMBOL_VOLUME_MIN
         );

      double volumeStep =
         SymbolInfoDouble(
            m_snapshot.Symbol,
            SYMBOL_VOLUME_STEP
         );

      double point =
         SymbolInfoDouble(
            m_snapshot.Symbol,
            SYMBOL_POINT
         );

      long stopsLevelPoints =
         SymbolInfoInteger(
            m_snapshot.Symbol,
            SYMBOL_TRADE_STOPS_LEVEL
         );

      if(minVolume <= 0.0 ||
         volumeStep <= 0.0 ||
         point <= 0.0)
      {
         return false;
      }

      //------------------------------------------------------------
      // Smallest safe broker-valid test volume
      //------------------------------------------------------------

      double testVolume =
         0.01;

      if(testVolume < minVolume)
         testVolume = minVolume;

      testVolume =
         MathCeil(
            testVolume / volumeStep
         ) * volumeStep;

      //------------------------------------------------------------
      // Entry
      //------------------------------------------------------------

      double entryPrice = 0.0;

      if(m_signal.Direction ==
         AQF_SIGNAL_BUY)
      {
         entryPrice =
            m_snapshot.Ask;
      }
      else
      {
         entryPrice =
            m_snapshot.Bid;
      }

      if(entryPrice <= 0.0)
         return false;

      //------------------------------------------------------------
      // Test stop distance
      //
      // Use real ATR if available, while also respecting broker
      // minimum stop distance with additional room.
      //------------------------------------------------------------

      double atrDistance =
         m_snapshot.ATR * 2.0;

      double brokerMinimumDistance =
         (double)stopsLevelPoints *
         point;

      double stopDistance =
         atrDistance;

      double protectedMinimum =
         brokerMinimumDistance * 2.0;

      if(stopDistance <
         protectedMinimum)
      {
         stopDistance =
            protectedMinimum;
      }

      if(stopDistance <= 0.0)
      {
         //---------------------------------------------------------
         // Last-resort test distance.
         //---------------------------------------------------------

         stopDistance =
            point * 100.0;
      }

      //------------------------------------------------------------
      // Stop Price
      //------------------------------------------------------------

      double stopPrice = 0.0;

      if(m_signal.Direction ==
         AQF_SIGNAL_BUY)
      {
         stopPrice =
            entryPrice - stopDistance;
      }
      else
      {
         stopPrice =
            entryPrice + stopDistance;
      }

      if(stopPrice <= 0.0)
         return false;

      //------------------------------------------------------------
      // Synthetic Authorization
      //------------------------------------------------------------

      m_riskDecision.Status =
         AQF_RISK_AUTHORIZED;

      m_riskDecision.RejectionReason =
         AQF_RISK_REJECTION_NONE;

      m_riskDecision.Authorized =
         true;

      m_riskDecision.RiskPercent =
         0.0;

      m_riskDecision.RiskMoney =
         0.0;

      m_riskDecision.StopPrice =
         stopPrice;

      m_riskDecision.StopDistance =
         stopDistance;

      m_riskDecision.RequestedVolume =
         testVolume;

      m_riskDecision.NormalizedVolume =
         testVolume;

      m_riskDecision.EstimatedMargin =
         0.0;

      m_riskDecision.EstimatedMarginPercent =
         0.0;

      m_riskDecision.CurrentSymbolExposure =
         0.0;

      m_riskDecision.CurrentSymbolNotional =
         0.0;

      m_riskDecision.ProposedNotional =
         0.0;

      m_riskDecision.TotalProjectedNotional =
         0.0;

      m_riskDecision.ProjectedNotionalPercent =
         0.0;

      m_riskDecision.Message =
         "Synthetic Package C test authorization";

      return true;
   }
};

#endif