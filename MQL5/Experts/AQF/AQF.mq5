//+------------------------------------------------------------------+
//|                  Adaptive Quant Framework                        |
//|                         AQF v0.6.0                               |
//|                                                                  |
//|   Modular quantitative trading framework for MetaTrader 5        |
//+------------------------------------------------------------------+

#property copyright "Adaptive Quant Framework"
#property version   "1.000"
#property strict

#include <AQF/Core/Core.mqh>

//====================================================================
// User Inputs
//====================================================================

input string          InpSymbol       = "";
input ENUM_TIMEFRAMES InpTimeframe    = PERIOD_M1;
input bool            InpDebugLogs    = true;
input int             InpTimerSeconds = 1;

//--------------------------------------------------------------------
// DEVELOPMENT TEST HOOK
//
// false = normal AQF behavior
// true  = inject one synthetic signal for DRY-RUN pipeline testing
//
// IMPORTANT:
// This DOES NOT enable trade execution.
//--------------------------------------------------------------------

input bool            InpDryRunTest   = false;

//====================================================================
// Framework
//====================================================================

CAQFCore AQFCore;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!AQFCore.Initialize(
         InpSymbol,
         InpTimeframe,
         InpDebugLogs,
         InpTimerSeconds,
         InpDryRunTest))
   {
      Print(
         "[AQF][FATAL] Framework initialization failed."
      );

      return INIT_FAILED;
   }

   if(!EventSetTimer(
         AQFCore.TimerSeconds()))
   {
      Print(
         "[AQF][ERROR] Unable to initialize framework timer."
      );

      AQFCore.Shutdown();

      return INIT_FAILED;
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   AQFCore.Shutdown();

   Print(
      "[AQF] Expert Advisor stopped. Reason=",
      reason
   );
}

//+------------------------------------------------------------------+
//| Tick event                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   AQFCore.Update();
}

//+------------------------------------------------------------------+
//| Timer event                                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   AQFCore.OnTimer();
}

//+------------------------------------------------------------------+
//| Trade event                                                      |
//+------------------------------------------------------------------+
void OnTrade()
{
   AQFCore.OnTrade();
}