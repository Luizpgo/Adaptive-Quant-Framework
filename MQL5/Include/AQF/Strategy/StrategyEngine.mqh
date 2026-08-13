#ifndef __AQF_STRATEGY_ENGINE_MQH__
#define __AQF_STRATEGY_ENGINE_MQH__

#include "../Core/FrameworkModule.mqh"
#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Common/StrategyType.mqh"
#include "../Logger/Logger.mqh"

#include "StrategySelector.mqh"
#include "TrendFollowingStrategy.mqh"

//+------------------------------------------------------------------+
//| Strategy orchestration engine                                    |
//+------------------------------------------------------------------+
class CAQFStrategyEngine : public CAQFFrameworkModule
{
private:

   CAQFStrategySelector        m_selector;
   CAQFTrendFollowingStrategy  m_trendStrategy;

public:

   CAQFStrategyEngine()
   {
      m_name    = "StrategyEngine";
      m_version = "0.4.0";
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(CAQFLogger &logger)
   {
      m_status = AQF_MODULE_INITIALIZING;

      m_trendStrategy.SetEnabled(true);

      m_status = AQF_MODULE_READY;

      logger.Info(
         "StrategyEngine initialized."
      );

      logger.Info(
         "Strategy available: " +
         m_trendStrategy.Name()
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

      if(!snapshot.Valid)
      {
         logger.Debug(
            "StrategyEngine received invalid snapshot."
         );

         return false;
      }

      ENUM_AQF_STRATEGY_TYPE selectedStrategy =
         m_selector.Select(snapshot);

      //------------------------------------------------------------
      // No applicable strategy
      //------------------------------------------------------------

      if(selectedStrategy == AQF_STRATEGY_NONE)
      {
         signal.Time     = snapshot.Time;
         signal.Symbol   = snapshot.Symbol;
         signal.Strategy = AQF_STRATEGY_NONE;

         signal.Direction  = AQF_SIGNAL_NONE;
         signal.Confidence = 0.0;
         signal.Quality    = AQF_SIGNAL_QUALITY_LOW;
         signal.Valid      = false;

         signal.Trend         = snapshot.Trend;
         signal.TrendStrength = snapshot.TrendStrength;
         signal.Volatility    = snapshot.Volatility;
         signal.Momentum      = snapshot.Momentum;

         signal.Reason =
            "No strategy suitable for current market regime";

         if(m_status == AQF_MODULE_READY)
            m_status = AQF_MODULE_RUNNING;

         return true;
      }

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

         if(result &&
            m_status == AQF_MODULE_READY)
         {
            m_status = AQF_MODULE_RUNNING;
         }

         return result;
      }

      //------------------------------------------------------------
      // Unknown / future strategy
      //------------------------------------------------------------

      logger.Warning(
         "Selected strategy is not implemented: " +
         AQFStrategyTypeToString(selectedStrategy)
      );

      return false;
   }

   //==============================================================
   // Shutdown
   //==============================================================
   virtual void Shutdown()
   {
      m_status = AQF_MODULE_STOPPED;
   }
};

#endif