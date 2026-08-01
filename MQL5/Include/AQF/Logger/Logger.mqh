#ifndef __LOGGER_MQH__
#define __LOGGER_MQH__

enum ENUM_LOG_LEVEL
{
   LOG_INFO = 0,
   LOG_WARNING,
   LOG_ERROR,
   LOG_DEBUG
};

class CLogger
{
private:

   bool m_debugEnabled;

public:

   //====================================================
   // Constructor
   //====================================================

   CLogger()
   {
      m_debugEnabled = true;
   }

   //====================================================
   // Enable Debug
   //====================================================

   void EnableDebug(bool enable)
   {
      m_debugEnabled = enable;
   }

   //====================================================
   // Info
   //====================================================

   void Info(string message)
   {
      Print("[INFO] ", message);
   }

   //====================================================
   // Warning
   //====================================================

   void Warning(string message)
   {
      Print("[WARNING] ", message);
   }

   //====================================================
   // Error
   //====================================================

   void Error(string message)
   {
      Print("[ERROR] ", message);
   }

   //====================================================
   // Debug
   //====================================================

   void Debug(string message)
   {
      if(m_debugEnabled)
         Print("[DEBUG] ", message);
   }

};

#endif