#ifndef __AQF_ACCOUNT_SNAPSHOT_MQH__
#define __AQF_ACCOUNT_SNAPSHOT_MQH__

//+------------------------------------------------------------------+
//| Current account state used by the AQF risk layer                 |
//+------------------------------------------------------------------+
class CAQFAccountSnapshot
{
public:

   double Balance;
   double Equity;

   double Margin;
   double FreeMargin;
   double MarginLevel;

   double FloatingProfit;

   double DrawdownMoney;
   double DrawdownPercent;

   bool Valid;

   //==============================================================
   // Constructor
   //==============================================================
   CAQFAccountSnapshot()
   {
      Reset();
   }

   //==============================================================
   // Reset
   //==============================================================
   void Reset()
   {
      Balance         = 0.0;
      Equity          = 0.0;

      Margin          = 0.0;
      FreeMargin      = 0.0;
      MarginLevel     = 0.0;

      FloatingProfit  = 0.0;

      DrawdownMoney   = 0.0;
      DrawdownPercent = 0.0;

      Valid = false;
   }
};

#endif