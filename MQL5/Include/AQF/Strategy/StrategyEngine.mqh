#ifndef __AQF_STRATEGY_ENGINE_MQH__
#define __AQF_STRATEGY_ENGINE_MQH__

#include "../Core/FrameworkModule.mqh"

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Common/StrategyType.mqh"
#include "../Common/StrategyDiagnostics.mqh"

#include "../Logger/Logger.mqh"

#include "NewBarGate.mqh"
#include "StrategySelector.mqh"
#include "TrendFollowingStrategy.mqh"

//+------------------------------------------------------------------+
//| Strategy orchestration engine                                    |
//|                                                                  |
//| Sprint 7 B2:                                                     |
//| Strategy decisions are evaluated once per candle, not per tick.  |
//+------------------------------------------------------------------+
class CAQFStrategyEngine : public CAQFFrameworkModule
{
private:

   CAQFStrategySelector       m_selector;
   CAQFTrendFollowingStrategy m_trendStrategy;

   //---------------------------------------------------------------
   // New-Bar Gate
   //---------------------------------------------------------------

   CAQFNewBarGate m_barGate;

   //---------------------------------------------------------------
   // Strategy Diagnostics
   //---------------------------------------------------------------

   CAQFStrategyDiagnostics m_diagnostics;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFStrategyEngine()
   {
      m_name =
         "StrategyEngine";

      m_version =
         "0.7.2";
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(
      CAQFLogger &logger)
   {
      m_status =
         AQF_MODULE_INITIALIZING;

      //------------------------------------------------------------
      // Strategy activation
      //------------------------------------------------------------

      m_trendStrategy.SetEnabled(
         true
      );

      //------------------------------------------------------------
      // Diagnostics
      //------------------------------------------------------------

      m_diagnostics.Reset();

      //------------------------------------------------------------
      // Report every 100 STRATEGY EVALUATIONS.
      //
      // After B2 this means approximately every 100 candles,
      // not every 100 ticks.
      //------------------------------------------------------------

      m_diagnostics.SetReportInterval(
         100
      );

      //------------------------------------------------------------
      // BarGate will be initialized lazily from the first valid
      // MarketSnapshot because StrategyEngine currently receives
      // symbol/timeframe through the snapshot.
      //------------------------------------------------------------

      m_status =
         AQF_MODULE_READY;

      logger.Info(
         "StrategyEngine initialized."
      );

      logger.Info(
         "Strategy available: " +
         m_trendStrategy.Name()
      );

      logger.Info(
         "Strategy diagnostics enabled."
      );

      logger.Info(
         "New-bar strategy evaluation enabled."
      );

      return true;
   }

   //==============================================================
   // Evaluate
   //==============================================================
   bool Evaluate(
      const CAQFMarketSnapshot &snapshot,
      CAQFTradeSignal &signal,
      CAQFLogger &logger)
   {
      signal.Reset();

      //------------------------------------------------------------
      // Snapshot validity
      //------------------------------------------------------------

      if(!snapshot.Valid)
      {
         logger.Debug(
            "StrategyEngine received invalid snapshot."
         );

         return false;
      }

      //------------------------------------------------------------
      // Initialize BarGate when necessary
      //------------------------------------------------------------

      if(m_barGate.LastProcessedBar() == 0)
      {
         if(!m_barGate.Initialize(
               snapshot.Symbol,
               snapshot.Timeframe))
         {
            logger.Error(
               "Unable to initialize NewBarGate."
            );

            return false;
         }
      }

      //------------------------------------------------------------
      // NEW BAR GATE
      //------------------------------------------------------------

      datetime currentBarTime =
         0;

      if(!m_barGate.IsNewBar(
            currentBarTime))
      {
         //---------------------------------------------------------
         // IMPORTANT:
         //
         // This is NOT an invalid trading signal.
         // It simply means StrategyEngine already evaluated
         // this candle.
         //---------------------------------------------------------

         signal.Time =
            snapshot.Time;

         signal.Symbol =
            snapshot.Symbol;

         signal.Strategy =
            AQF_STRATEGY_NONE;

         signal.Direction =
            AQF_SIGNAL_NONE;

         signal.Confidence =
            0.0;

         signal.Quality =
            AQF_SIGNAL_QUALITY_LOW;

         signal.Valid =
            false;

         signal.Reason =
            "Waiting for new candle";

         //---------------------------------------------------------
         // Do NOT increment StrategyDiagnostics here.
         //
         // We want diagnostics per candle, not per tick.
         //---------------------------------------------------------

         return true;
      }

      //------------------------------------------------------------
      // From this point forward:
      //
      // ONE evaluation = ONE new candle.
      //------------------------------------------------------------

      m_diagnostics.RecordEvaluation();

      //------------------------------------------------------------
      // New-Bar Diagnostics
      //------------------------------------------------------------

      logger.Debug(
         "NewBar | " +
         snapshot.Symbol +
         " | Time=" +
         TimeToString(
            currentBarTime,
            TIME_DATE |
            TIME_MINUTES) +
         " | " +
         m_barGate.Summary()
      );

      //------------------------------------------------------------
      // Strategy selection
      //------------------------------------------------------------

      ENUM_AQF_STRATEGY_TYPE
         selectedStrategy =
            m_selector.Select(
               snapshot
            );

      //------------------------------------------------------------
      // No suitable strategy
      //------------------------------------------------------------

      if(selectedStrategy ==
         AQF_STRATEGY_NONE)
      {
         m_diagnostics.RecordNoStrategy();

         signal.Time =
            snapshot.Time;

         signal.Symbol =
            snapshot.Symbol;

         signal.Strategy =
            AQF_STRATEGY_NONE;

         signal.Direction =
            AQF_SIGNAL_NONE;

         signal.Confidence =
            0.0;

         signal.Quality =
            AQF_SIGNAL_QUALITY_LOW;

         signal.Valid =
            false;

         signal.Trend =
            snapshot.Trend;

         signal.TrendStrength =
            snapshot.TrendStrength;

         signal.Volatility =
            snapshot.Volatility;

         signal.Momentum =
            snapshot.Momentum;

         signal.Reason =
            "No strategy suitable for current market regime";

         m_diagnostics.RecordSignal(
            signal
         );

         if(m_status ==
            AQF_MODULE_READY)
         {
            m_status =
               AQF_MODULE_RUNNING;
         }

         MaybeReportDiagnostics(
            logger
         );

         return true;
      }

      //------------------------------------------------------------
      // Strategy selected
      //------------------------------------------------------------

      m_diagnostics.RecordStrategySelected(
         selectedStrategy
      );

      //------------------------------------------------------------
      // Trend Following
      //------------------------------------------------------------

      if(selectedStrategy ==
         AQF_STRATEGY_TREND_FOLLOWING)
      {
         bool result =
            m_trendStrategy.Evaluate(
               snapshot,
               signal
            );

         if(!result)
         {
            m_diagnostics.RecordEvaluationFailure();

            MaybeReportDiagnostics(
               logger
            );

            return false;
         }

         //---------------------------------------------------------
         // Record resulting signal
         //---------------------------------------------------------

         m_diagnostics.RecordSignal(
            signal
         );

         if(m_status ==
            AQF_MODULE_READY)
         {
            m_status =
               AQF_MODULE_RUNNING;
         }

         MaybeReportDiagnostics(
            logger
         );

         return true;
      }

      //------------------------------------------------------------
      // Unknown / future strategy
      //------------------------------------------------------------

      logger.Warning(
         "Selected strategy is not implemented: " +
         AQFStrategyTypeToString(
            selectedStrategy
         )
      );

      m_diagnostics.RecordEvaluationFailure();

      MaybeReportDiagnostics(
         logger
      );

      return false;
   }

   //==============================================================
   // Diagnostics Summary
   //==============================================================
   string DiagnosticsSummary()
   {
      return
         m_diagnostics.Summary();
   }

   //==============================================================
   // Bar Gate Summary
   //==============================================================
   string BarGateSummary()
   {
      return
         m_barGate.Summary();
   }

   //==============================================================
   // Shutdown
   //==============================================================
   virtual void Shutdown()
   {
      m_status =
         AQF_MODULE_STOPPED;
   }

private:

   //==============================================================
   // Periodic diagnostics
   //==============================================================
   void MaybeReportDiagnostics(
      CAQFLogger &logger)
   {
      if(!m_diagnostics.ShouldReport())
         return;

      logger.Info(
         m_diagnostics.Summary()
      );

      logger.Info(
         m_barGate.Summary()
      );
   }
};

#endif