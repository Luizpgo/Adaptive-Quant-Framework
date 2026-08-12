#ifndef __AQF_CORE_MQH__
#define __AQF_CORE_MQH__

#include "../Config/Configuration.mqh"
#include "../Logger/Logger.mqh"
#include "../Market/MarketEngine.mqh"
#include "../Common/MarketSnapshot.mqh"

//+------------------------------------------------------------------+
//| Adaptive Quant Framework Core Controller                         |
//+------------------------------------------------------------------+
class CAQFCore
{
private:

   CAQFConfiguration  m_configuration;
   CAQFLogger         m_logger;
   CAQFMarketEngine   m_marketEngine;
   CAQFMarketSnapshot m_snapshot;

   bool               m_initialized;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFCore()
   {
      m_initialized = false;
   }

   //==============================================================
   // Initialize framework
   //==============================================================
   bool Initialize(string symbol,
                   ENUM_TIMEFRAMES timeframe,
                   bool debugEnabled,
                   int timerSeconds)
   {
      if(!m_configuration.Configure(symbol,
                                    timeframe,
                                    debugEnabled,
                                    timerSeconds))
      {
         Print("[AQF][ERROR] Configuration initialization failed.");

         return false;
      }

      if(!m_logger.Initialize(m_configuration.DebugEnabled()))
      {
         Print("[AQF][ERROR] Logger initialization failed.");

         return false;
      }

      m_logger.Info("==============================================");
      m_logger.Info("Adaptive Quant Framework v0.2.0");
      m_logger.Info("Initializing framework...");
      m_logger.Info("==============================================");

      m_logger.Info("Configuration ........ " +
                    m_configuration.StatusText());

      m_logger.Info("Logger ............... " +
                    m_logger.StatusText());

      if(!m_marketEngine.Initialize(m_configuration.Symbol(),
                                    m_configuration.Timeframe(),
                                    m_logger))
      {
         m_logger.Error("MarketEngine initialization failed.");

         return false;
      }

      m_logger.Info("MarketEngine ......... " +
                    m_marketEngine.StatusText());

      m_initialized = true;

      m_logger.Info("----------------------------------------------");
      m_logger.Info("AQF INITIALIZATION SUCCESSFUL");
      m_logger.Info("----------------------------------------------");

      return true;
   }

   //==============================================================
   // Main tick update
   //==============================================================
   void Update()
   {
      if(!m_initialized)
         return;

      if(!m_marketEngine.BuildSnapshot(m_snapshot, m_logger))
         return;

      if(!m_snapshot.Valid)
         return;

      m_logger.Debug(
         "Snapshot | " +
         m_snapshot.Symbol +
         " | Bid=" +
         DoubleToString(m_snapshot.Bid, _Digits) +
         " | Ask=" +
         DoubleToString(m_snapshot.Ask, _Digits) +
         " | Spread=" +
         DoubleToString(m_snapshot.SpreadPoints, 1)
      );
   }

   //==============================================================
   // Timer event
   //==============================================================
   void OnTimer()
   {
      if(!m_initialized)
         return;

      m_logger.Debug(
         "Heartbeat | MarketEngine=" +
         m_marketEngine.StatusText()
      );
   }

   //==============================================================
   // Trade event
   //==============================================================
   void OnTrade()
   {
      if(!m_initialized)
         return;

      m_logger.Debug("Trade event received.");
   }

   //==============================================================
   // Shutdown
   //==============================================================
   void Shutdown()
   {
      if(!m_initialized)
         return;

      m_logger.Info("Stopping Adaptive Quant Framework...");

      m_marketEngine.Shutdown();

      m_logger.Info("MarketEngine ......... " +
                    m_marketEngine.StatusText());

      m_configuration.Shutdown();

      m_logger.Info("Configuration ........ " +
                    m_configuration.StatusText());

      m_logger.Shutdown();

      m_initialized = false;
   }

   //==============================================================
   // Timer configuration
   //==============================================================
   int TimerSeconds()
   {
      return m_configuration.TimerSeconds();
   }

   //==============================================================
   // Framework status
   //==============================================================
   bool IsInitialized()
   {
      return m_initialized;
   }
};

#endif