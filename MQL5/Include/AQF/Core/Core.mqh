#ifndef __AQF_CORE_MQH__
#define __AQF_CORE_MQH__

#include "../Config/Configuration.mqh"
#include "../Logger/Logger.mqh"
#include "../Market/MarketEngine.mqh"
#include "../Common/MarketSnapshot.mqh"
#include "../Common/MarketRegime.mqh"

class CAQFCore
{
private:

   CAQFConfiguration  m_configuration;
   CAQFLogger         m_logger;
   CAQFMarketEngine   m_marketEngine;
   CAQFMarketSnapshot m_snapshot;

   bool m_initialized;

public:

   CAQFCore()
   {
      m_initialized = false;
   }

   //===================================================
   // Initialize
   //===================================================

   bool Initialize(string symbol,
                   ENUM_TIMEFRAMES timeframe,
                   bool debugEnabled,
                   int timerSeconds)
   {
      if(!m_configuration.Configure(
            symbol,
            timeframe,
            debugEnabled,
            timerSeconds))
      {
         Print("[AQF][ERROR] Configuration initialization failed.");
         return false;
      }

      if(!m_logger.Initialize(
            m_configuration.DebugEnabled()))
      {
         Print("[AQF][ERROR] Logger initialization failed.");
         return false;
      }

      m_logger.Info("==============================================");
      m_logger.Info("Adaptive Quant Framework v0.3.0");
      m_logger.Info("Market Intelligence Layer");
      m_logger.Info("==============================================");

      if(!m_marketEngine.Initialize(
            m_configuration.Symbol(),
            m_configuration.Timeframe(),
            m_logger))
      {
         m_logger.Error("MarketEngine initialization failed.");
         return false;
      }

      m_initialized = true;

      m_logger.Info("AQF INITIALIZATION SUCCESSFUL");

      return true;
   }

   //===================================================
   // Update
   //===================================================

   void Update()
   {
      if(!m_initialized)
         return;

      if(!m_marketEngine.BuildSnapshot(
            m_snapshot,
            m_logger))
         return;

      if(!m_snapshot.Valid)
         return;

      m_logger.Debug(
         "Market | " +
         m_snapshot.Symbol +
         " | Trend=" +
         AQFTrendToString(m_snapshot.Trend) +
         " | Strength=" +
         AQFStrengthToString(m_snapshot.TrendStrength) +
         " | Volatility=" +
         AQFVolatilityToString(m_snapshot.Volatility) +
         " | Momentum=" +
         AQFMomentumToString(m_snapshot.Momentum) +
         " | ADX=" +
         DoubleToString(m_snapshot.ADX, 2) +
         " | RSI=" +
         DoubleToString(m_snapshot.RSI, 2) +
         " | ATR%=" +
         DoubleToString(m_snapshot.ATRPercent, 4)
      );
   }

   //===================================================
   // Timer
   //===================================================

   void OnTimer()
   {
      if(!m_initialized)
         return;

      m_logger.Debug(
         "Heartbeat | MarketEngine=" +
         m_marketEngine.StatusText()
      );
   }

   //===================================================
   // Trade Event
   //===================================================

   void OnTrade()
   {
      if(!m_initialized)
         return;

      m_logger.Debug("Trade event received.");
   }

   //===================================================
   // Shutdown
   //===================================================

   void Shutdown()
   {
      if(!m_initialized)
         return;

      m_logger.Info("Stopping AQF...");

      m_marketEngine.Shutdown();
      m_configuration.Shutdown();
      m_logger.Shutdown();

      m_initialized = false;
   }

   //===================================================
   // Accessors
   //===================================================

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