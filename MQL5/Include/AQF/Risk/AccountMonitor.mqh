#ifndef __AQF_ACCOUNT_MONITOR_MQH__
#define __AQF_ACCOUNT_MONITOR_MQH__

#include "../Common/AccountSnapshot.mqh"

//+------------------------------------------------------------------+
//| Account state acquisition                                        |
//+------------------------------------------------------------------+
class CAQFAccountMonitor
{
public:

   CAQFAccountMonitor()
   {
   }

   //==============================================================
   // Build Snapshot
   //==============================================================
   bool BuildSnapshot(
      CAQFAccountSnapshot &snapshot)
   {
      snapshot.Reset();

      snapshot.Balance =
         AccountInfoDouble(ACCOUNT_BALANCE);

      snapshot.Equity =
         AccountInfoDouble(ACCOUNT_EQUITY);

      snapshot.Margin =
         AccountInfoDouble(ACCOUNT_MARGIN);

      snapshot.FreeMargin =
         AccountInfoDouble(ACCOUNT_MARGIN_FREE);

      snapshot.MarginLevel =
         AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

      snapshot.FloatingProfit =
         AccountInfoDouble(ACCOUNT_PROFIT);

      //------------------------------------------------------------
      // Basic account validity
      //------------------------------------------------------------

      if(snapshot.Balance < 0.0 ||
         snapshot.Equity < 0.0 ||
         snapshot.FreeMargin < 0.0)
      {
         return false;
      }

      //------------------------------------------------------------
      // Drawdown relative to current balance
      //------------------------------------------------------------

      if(snapshot.Equity < snapshot.Balance)
      {
         snapshot.DrawdownMoney =
            snapshot.Balance - snapshot.Equity;

         if(snapshot.Balance > 0.0)
         {
            snapshot.DrawdownPercent =
               (snapshot.DrawdownMoney /
                snapshot.Balance) * 100.0;
         }
      }

      snapshot.Valid = true;

      return true;
   }
};

#endif