#ifndef __AQF_ADX_MQH__
#define __AQF_ADX_MQH__

class CAQFADX
{
private:
   int             m_handle;
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int             m_period;

public:
   CAQFADX()
   {
      m_handle    = INVALID_HANDLE;
      m_symbol    = "";
      m_timeframe = PERIOD_CURRENT;
      m_period    = 14;
   }

   bool Initialize(const string symbol,
                   const ENUM_TIMEFRAMES timeframe,
                   const int period)
   {
      m_symbol    = symbol;
      m_timeframe = timeframe;
      m_period    = period;

      m_handle = iADX(
         m_symbol,
         m_timeframe,
         m_period
      );

      return (m_handle != INVALID_HANDLE);
   }

   bool GetValue(double &value)
   {
      if(m_handle == INVALID_HANDLE)
         return false;

      double buffer[1];

      if(CopyBuffer(m_handle, 0, 0, 1, buffer) != 1)
         return false;

      if(buffer[0] == EMPTY_VALUE)
         return false;

      value = buffer[0];

      return true;
   }

   void Shutdown()
   {
      if(m_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle);
         m_handle = INVALID_HANDLE;
      }
   }
};

#endif