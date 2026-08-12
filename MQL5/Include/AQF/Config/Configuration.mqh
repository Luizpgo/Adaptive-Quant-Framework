#ifndef __AQF_CONFIGURATION_MQH__
#define __AQF_CONFIGURATION_MQH__

#include "../Core/FrameworkModule.mqh"

//+------------------------------------------------------------------+
//| Central configuration module                                    |
//+------------------------------------------------------------------+
class CAQFConfiguration : public CAQFFrameworkModule
{
private:

   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   bool            m_debugEnabled;
   int             m_timerSeconds;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFConfiguration()
   {
      m_name         = "Configuration";
      m_version      = "0.2.0";

      m_symbol       = "";
      m_timeframe    = PERIOD_M1;
      m_debugEnabled = true;
      m_timerSeconds = 1;
   }

   //==============================================================
   // Configure
   //==============================================================
   bool Configure(string symbol,
                  ENUM_TIMEFRAMES timeframe,
                  bool debugEnabled,
                  int timerSeconds)
   {
      m_status = AQF_MODULE_INITIALIZING;

      if(symbol == "")
         symbol = _Symbol;

      if(timerSeconds < 1)
         timerSeconds = 1;

      m_symbol       = symbol;
      m_timeframe    = timeframe;
      m_debugEnabled = debugEnabled;
      m_timerSeconds = timerSeconds;

      m_status = AQF_MODULE_READY;

      return true;
   }

   //==============================================================
   // Symbol
   //==============================================================
   string Symbol()
   {
      return m_symbol;
   }

   //==============================================================
   // Timeframe
   //==============================================================
   ENUM_TIMEFRAMES Timeframe()
   {
      return m_timeframe;
   }

   //==============================================================
   // Debug
   //==============================================================
   bool DebugEnabled()
   {
      return m_debugEnabled;
   }

   //==============================================================
   // Timer interval
   //==============================================================
   int TimerSeconds()
   {
      return m_timerSeconds;
   }
};

#endif