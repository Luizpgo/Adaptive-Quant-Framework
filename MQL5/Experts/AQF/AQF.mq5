//+------------------------------------------------------------------+
//|                     Adaptive Quant Framework                     |
//|                             AQF v0.1                             |
//|                    Copyright (c) 2026                            |
//+------------------------------------------------------------------+
#property copyright "AQF Project"
#property version   "0.1"
#property strict

//======================================================
// Includes
//======================================================

#include "../Include/Core/Core.mqh"

//======================================================
// Global Objects
//======================================================

CCore Core;

//======================================================
// Expert Initialization
//======================================================

int OnInit()
{
   Print("==========================================");
   Print(" Adaptive Quant Framework");
   Print(" Version 0.1");
   Print(" Initializing...");
   Print("==========================================");

   if(!Core.Initialize())
   {
      Print("Framework initialization failed.");
      return(INIT_FAILED);
   }

   Print("Framework initialized successfully.");

   return(INIT_SUCCEEDED);
}

//======================================================
// Expert Deinitialization
//======================================================

void OnDeinit(const int reason)
{
   Core.Shutdown();

   Print("AQF stopped.");
}

//======================================================
// Main Tick
//======================================================

void OnTick()
{
   Core.Update();
}

//======================================================
// Timer
//======================================================

void OnTimer()
{
   Core.OnTimer();
}

//======================================================
// Trade Event
//======================================================

void OnTrade()
{
   Core.OnTrade();
}