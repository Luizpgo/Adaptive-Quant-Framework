#ifndef __AQF_FRAMEWORK_MODULE_MQH__
#define __AQF_FRAMEWORK_MODULE_MQH__

#include "../Common/ModuleStatus.mqh"

//+------------------------------------------------------------------+
//| Base class for AQF framework modules                             |
//+------------------------------------------------------------------+
class CAQFFrameworkModule
{
protected:

   string                 m_name;
   string                 m_version;
   ENUM_AQF_MODULE_STATUS m_status;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFFrameworkModule()
   {
      m_name    = "AQF Module";
      m_version = "0.2.0";
      m_status  = AQF_MODULE_CREATED;
   }

   //==============================================================
   // Module name
   //==============================================================
   string Name()
   {
      return m_name;
   }

   //==============================================================
   // Module version
   //==============================================================
   string Version()
   {
      return m_version;
   }

   //==============================================================
   // Current lifecycle status
   //==============================================================
   ENUM_AQF_MODULE_STATUS Status()
   {
      return m_status;
   }

   //==============================================================
   // Human readable status
   //==============================================================
   string StatusText()
   {
      return AQFModuleStatusToString(m_status);
   }

   //==============================================================
   // Ready check
   //==============================================================
   bool IsReady()
   {
      return (m_status == AQF_MODULE_READY ||
              m_status == AQF_MODULE_RUNNING);
   }

   //==============================================================
   // Base initialization
   //==============================================================
   virtual bool Initialize()
   {
      m_status = AQF_MODULE_INITIALIZING;
      m_status = AQF_MODULE_READY;

      return true;
   }

   //==============================================================
   // Base update
   //==============================================================
   virtual void Update()
   {
      if(m_status == AQF_MODULE_READY)
         m_status = AQF_MODULE_RUNNING;
   }

   //==============================================================
   // Base shutdown
   //==============================================================
   virtual void Shutdown()
   {
      m_status = AQF_MODULE_STOPPED;
   }
};

#endif