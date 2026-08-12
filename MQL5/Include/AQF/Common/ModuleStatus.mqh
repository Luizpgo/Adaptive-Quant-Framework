#ifndef __AQF_MODULE_STATUS_MQH__
#define __AQF_MODULE_STATUS_MQH__

//+------------------------------------------------------------------+
//| Lifecycle states shared by AQF framework modules                 |
//+------------------------------------------------------------------+
enum ENUM_AQF_MODULE_STATUS
{
   AQF_MODULE_CREATED = 0,
   AQF_MODULE_INITIALIZING,
   AQF_MODULE_READY,
   AQF_MODULE_RUNNING,
   AQF_MODULE_STOPPED,
   AQF_MODULE_ERROR
};

//+------------------------------------------------------------------+
//| Convert module status to readable text                           |
//+------------------------------------------------------------------+
string AQFModuleStatusToString(const ENUM_AQF_MODULE_STATUS status)
{
   switch(status)
   {
      case AQF_MODULE_CREATED:
         return "CREATED";

      case AQF_MODULE_INITIALIZING:
         return "INITIALIZING";

      case AQF_MODULE_READY:
         return "READY";

      case AQF_MODULE_RUNNING:
         return "RUNNING";

      case AQF_MODULE_STOPPED:
         return "STOPPED";

      case AQF_MODULE_ERROR:
         return "ERROR";
   }

   return "UNKNOWN";
}

#endif