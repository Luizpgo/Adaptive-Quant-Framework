#ifndef __AQF_CAPITAL_LIMITS_MQH__
#define __AQF_CAPITAL_LIMITS_MQH__

//+------------------------------------------------------------------+
//| Capital protection policy                                        |
//+------------------------------------------------------------------+
class CAQFCapitalLimits
{
private:

   double m_maxRiskPercentPerTrade;
   double m_maxMarginUsePercent;
   double m_maxSymbolExposurePercent;

public:

   CAQFCapitalLimits()
   {
      m_maxRiskPercentPerTrade = 0.50;
      m_maxMarginUsePercent    = 20.0;
      m_maxSymbolExposurePercent = 150.0;
   }

   //==============================================================
   // Setters
   //==============================================================
   void SetMaxRiskPercentPerTrade(const double value)
   {
      if(value > 0.0)
         m_maxRiskPercentPerTrade = value;
   }

   void SetMaxMarginUsePercent(const double value)
   {
      if(value > 0.0)
         m_maxMarginUsePercent = value;
   }

   void SetMaxSymbolExposurePercent(const double value)
   {
      if(value > 0.0)
         m_maxSymbolExposurePercent = value;
   }

   //==============================================================
   // Getters
   //==============================================================
   double MaxRiskPercentPerTrade()
   {
      return m_maxRiskPercentPerTrade;
   }

   double MaxMarginUsePercent()
   {
      return m_maxMarginUsePercent;
   }

   double MaxSymbolExposurePercent()
   {
      return m_maxSymbolExposurePercent;
   }
};

#endif