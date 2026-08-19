#ifndef __AQF_NEW_BAR_GATE_MQH__
#define __AQF_NEW_BAR_GATE_MQH__

//+------------------------------------------------------------------+
//| New-bar evaluation gate                                          |
//|                                                                  |
//| Allows the StrategyEngine to evaluate only once per candle.      |
//+------------------------------------------------------------------+
class CAQFNewBarGate
{
private:

   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;

   datetime m_lastProcessedBar;

   long m_ticksObserved;
   long m_ticksSkipped;
   long m_barsAccepted;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFNewBarGate()
   {
      m_symbol =
         "";

      m_timeframe =
         PERIOD_CURRENT;

      Reset();
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe)
   {
      if(symbol == "")
         return false;

      m_symbol =
         symbol;

      m_timeframe =
         timeframe;

      Reset();

      return true;
   }

   //==============================================================
   // Reset
   //==============================================================
   void Reset()
   {
      m_lastProcessedBar =
         0;

      m_ticksObserved =
         0;

      m_ticksSkipped =
         0;

      m_barsAccepted =
         0;
   }

   //==============================================================
   // Is New Bar?
   //==============================================================
   bool IsNewBar(
      datetime &barTime)
   {
      m_ticksObserved++;

      barTime =
         iTime(
            m_symbol,
            m_timeframe,
            0
         );

      if(barTime <= 0)
         return false;

      //------------------------------------------------------------
      // First valid bar after initialization
      //------------------------------------------------------------

      if(m_lastProcessedBar == 0)
      {
         m_lastProcessedBar =
            barTime;

         m_barsAccepted++;

         return true;
      }

      //------------------------------------------------------------
      // Same candle
      //------------------------------------------------------------

      if(barTime ==
         m_lastProcessedBar)
      {
         m_ticksSkipped++;

         return false;
      }

      //------------------------------------------------------------
      // New candle
      //------------------------------------------------------------

      m_lastProcessedBar =
         barTime;

      m_barsAccepted++;

      return true;
   }

   //==============================================================
   // Diagnostics
   //==============================================================
   datetime LastProcessedBar()
   {
      return m_lastProcessedBar;
   }

   long TicksObserved()
   {
      return m_ticksObserved;
   }

   long TicksSkipped()
   {
      return m_ticksSkipped;
   }

   long BarsAccepted()
   {
      return m_barsAccepted;
   }

   string Summary()
   {
      return
         "BarGate" +
         " | Ticks=" +
         IntegerToString(
            (int)m_ticksObserved) +
         " | Skipped=" +
         IntegerToString(
            (int)m_ticksSkipped) +
         " | Bars=" +
         IntegerToString(
            (int)m_barsAccepted);
   }
};

#endif