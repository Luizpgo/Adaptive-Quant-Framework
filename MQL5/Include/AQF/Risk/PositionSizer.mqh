#ifndef __AQF_POSITION_SIZER_MQH__
#define __AQF_POSITION_SIZER_MQH__

//+------------------------------------------------------------------+
//| Dynamic risk-based position sizing                               |
//+------------------------------------------------------------------+
class CAQFPositionSizer
{
private:

   double m_riskPercent;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFPositionSizer()
   {
      // Engineering default for development/testing.
      m_riskPercent = 0.50;
   }

   //==============================================================
   // Risk Percent
   //==============================================================
   void SetRiskPercent(const double riskPercent)
   {
      if(riskPercent < 0.01)
         m_riskPercent = 0.01;
      else if(riskPercent > 5.0)
         m_riskPercent = 5.0;
      else
         m_riskPercent = riskPercent;
   }

   double RiskPercent()
   {
      return m_riskPercent;
   }

   //==============================================================
   // Calculate Position Size
   //==============================================================
   bool Calculate(
      const string symbol,
      const double equity,
      const double entryPrice,
      const double stopPrice,
      double &riskMoney,
      double &rawVolume,
      double &normalizedVolume)
   {
      riskMoney        = 0.0;
      rawVolume        = 0.0;
      normalizedVolume = 0.0;

      if(symbol == "" ||
         equity <= 0.0 ||
         entryPrice <= 0.0 ||
         stopPrice <= 0.0)
      {
         return false;
      }

      //------------------------------------------------------------
      // Stop distance
      //------------------------------------------------------------

      double stopDistance =
         MathAbs(entryPrice - stopPrice);

      if(stopDistance <= 0.0)
         return false;

      //------------------------------------------------------------
      // Symbol contract information
      //------------------------------------------------------------

      double tickSize =
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_TICK_SIZE
         );

      double tickValue =
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_TICK_VALUE
         );

      double minVolume =
         SymbolInfoDouble(
            symbol,
            SYMBOL_VOLUME_MIN
         );

      double maxVolume =
         SymbolInfoDouble(
            symbol,
            SYMBOL_VOLUME_MAX
         );

      double volumeStep =
         SymbolInfoDouble(
            symbol,
            SYMBOL_VOLUME_STEP
         );

      if(tickSize <= 0.0 ||
         tickValue <= 0.0 ||
         minVolume <= 0.0 ||
         maxVolume <= 0.0 ||
         volumeStep <= 0.0)
      {
         return false;
      }

      //------------------------------------------------------------
      // Maximum money allocated to this trade
      //------------------------------------------------------------

      riskMoney =
         equity * (m_riskPercent / 100.0);

      if(riskMoney <= 0.0)
         return false;

      //------------------------------------------------------------
      // Estimated loss for 1 lot at the proposed stop
      //
      // number of ticks = price distance / tick size
      // money per lot   = ticks * tick value
      //------------------------------------------------------------

      double ticksToStop =
         stopDistance / tickSize;

      double lossPerLot =
         ticksToStop * tickValue;

      if(lossPerLot <= 0.0)
         return false;

      //------------------------------------------------------------
      // Raw volume
      //------------------------------------------------------------

      rawVolume =
         riskMoney / lossPerLot;

      if(rawVolume <= 0.0)
         return false;

      //------------------------------------------------------------
      // IMPORTANT:
      //
      // Round DOWN, never up.
      // Risk sizing must not increase the requested risk.
      //------------------------------------------------------------

      normalizedVolume =
         MathFloor(rawVolume / volumeStep)
         * volumeStep;

      //------------------------------------------------------------
      // If even broker minimum volume exceeds our risk budget,
      // reject instead of forcing minimum volume.
      //------------------------------------------------------------

      if(normalizedVolume < minVolume)
      {
         normalizedVolume = 0.0;
         return false;
      }

      if(normalizedVolume > maxVolume)
         normalizedVolume = maxVolume;

      return true;
   }
};

#endif