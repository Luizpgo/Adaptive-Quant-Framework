#ifndef __CORE_MQH__
#define __CORE_MQH__

#include "../Logger/Logger.mqh"

class CCore
{
private:

   CLogger Logger;

public:

   //====================================================
   // Constructor
   //====================================================

   CCore()
   {
   }

   //====================================================
   // Initialize
   //====================================================

   bool Initialize()
   {
      Logger.Info("========================================");
      Logger.Info("Initializing AQF Core...");
      Logger.Info("Loading Framework Modules...");
      Logger.Info("Core initialized successfully.");
      Logger.Info("========================================");

      return true;
   }

   //====================================================
   // Main Update
   //====================================================

   void Update()
   {
      Logger.Debug("Tick received.");
   }

   //====================================================
   // Timer Event
   //====================================================

   void OnTimer()
   {
      Logger.Debug("Timer event.");
   }

   //====================================================
   // Trade Event
   //====================================================

   void OnTrade()
   {
      Logger.Debug("Trade event.");
   }

   //====================================================
   // Shutdown
   //====================================================

   void Shutdown()
   {
      Logger.Info("AQF Core stopped.");
   }

};

#endif