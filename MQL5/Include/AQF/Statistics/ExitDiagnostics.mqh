#ifndef __AQF_EXIT_DIAGNOSTICS_MQH__
#define __AQF_EXIT_DIAGNOSTICS_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Logger/Logger.mqh"

#define AQF_EXIT_TARGET_COUNT 6

//+------------------------------------------------------------------+
//| Virtual exit trade                                               |
//|                                                                  |
//| Diagnostic only.                                                 |
//| This structure NEVER sends an order.                             |
//+------------------------------------------------------------------+
struct SAQFVirtualExitTrade
{
   bool Active;

   string Symbol;

   ENUM_AQF_SIGNAL_DIRECTION Direction;
   ENUM_AQF_STRATEGY_TYPE    Strategy;

   double EntryPrice;
   double StopLoss;
   double StopDistance;

   double TargetR;
   double TargetPrice;

   datetime EntryTime;

   ENUM_TIMEFRAMES Timeframe;

   int TargetIndex;
};

//+------------------------------------------------------------------+
//| Exit / Take-Profit Diagnostics                                   |
//|                                                                  |
//| Compares multiple R targets using virtual trades only.            |
//|                                                                  |
//| Targets:                                                         |
//| 0.50R / 0.75R / 1.00R / 1.25R / 1.50R / 2.00R                  |
//|                                                                  |
//| NO TRADE EXECUTION EXISTS IN THIS CLASS.                         |
//+------------------------------------------------------------------+
class CAQFExitDiagnostics
{
private:

   //---------------------------------------------------------------
   // Virtual trade storage
   //---------------------------------------------------------------

   SAQFVirtualExitTrade m_slots[];

   int m_capacity;

   //---------------------------------------------------------------
   // Targets
   //---------------------------------------------------------------

   double m_targetR[AQF_EXIT_TARGET_COUNT];

   //---------------------------------------------------------------
   // Statistics
   //---------------------------------------------------------------

   long m_created[AQF_EXIT_TARGET_COUNT];

   long m_wins[AQF_EXIT_TARGET_COUNT];

   long m_losses[AQF_EXIT_TARGET_COUNT];

   long m_expired[AQF_EXIT_TARGET_COUNT];

   double m_totalResolvedBars[AQF_EXIT_TARGET_COUNT];

   //---------------------------------------------------------------
   // Global diagnostics
   //---------------------------------------------------------------

   long m_totalClosed;
   long m_totalResolved;
   long m_droppedOpportunities;

   long m_lastReportedClosed;

   int m_reportEveryClosed;

   //---------------------------------------------------------------
   // Maximum virtual holding period
   //---------------------------------------------------------------

   int m_maxHoldingBars;

   //---------------------------------------------------------------
   // Duplicate registration protection
   //---------------------------------------------------------------

   string m_lastRegistrationKey;

   bool m_initialized;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFExitDiagnostics()
   {
      m_initialized =
         false;

      m_capacity =
         2048;

      //------------------------------------------------------------
      // Temporary diagnostic holding horizon.
      //
      // For M1 this represents approximately 120 minutes.
      //------------------------------------------------------------

      m_maxHoldingBars =
         120;

      //------------------------------------------------------------
      // Print full statistics every 25 closed virtual scenarios.
      //------------------------------------------------------------

      m_reportEveryClosed =
         25;

      ResetStatistics();
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(
      CAQFLogger &logger)
   {
      //------------------------------------------------------------
      // Experimental R targets
      //------------------------------------------------------------

      m_targetR[0] = 0.50;
      m_targetR[1] = 0.75;
      m_targetR[2] = 1.00;
      m_targetR[3] = 1.25;
      m_targetR[4] = 1.50;
      m_targetR[5] = 2.00;

      //------------------------------------------------------------
      // Allocate virtual trade pool
      //------------------------------------------------------------

      if(ArrayResize(
            m_slots,
            m_capacity) != m_capacity)
      {
         logger.Error(
            "ExitDiagnostics unable to allocate virtual trade pool."
         );

         return false;
      }

      for(int i = 0;
          i < m_capacity;
          i++)
      {
         ResetSlot(
            m_slots[i]
         );
      }

      ResetStatistics();

      m_initialized =
         true;

      logger.Info(
         "ExitDiagnostics initialized."
      );

      logger.Info(
         "Exit targets: 0.50R | 0.75R | 1.00R | 1.25R | 1.50R | 2.00R"
      );

      logger.Info(
         "ExitDiagnostics mode: VIRTUAL ONLY - NO ORDER EXECUTION"
      );

      return true;
   }

   //==============================================================
   // Register Opportunity
   //==============================================================
   bool Register(
      const CAQFTradeRequest &request,
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return false;

      //------------------------------------------------------------
      // Request validation
      //------------------------------------------------------------

      if(!request.Valid ||
         request.Symbol == "" ||
         request.EntryPrice <= 0.0 ||
         request.StopLoss <= 0.0 ||
         request.StopDistance <= 0.0)
      {
         return false;
      }

      if(request.Direction != AQF_SIGNAL_BUY &&
         request.Direction != AQF_SIGNAL_SELL)
      {
         return false;
      }

      //------------------------------------------------------------
      // Duplicate registration key
      //
      // B2 already limits strategy evaluation to one per candle.
      // This is a second defensive layer.
      //------------------------------------------------------------

      string registrationKey =
         request.Symbol +
         "|" +
         IntegerToString(
            (int)request.SignalTime) +
         "|" +
         IntegerToString(
            (int)request.Strategy) +
         "|" +
         IntegerToString(
            (int)request.Direction);

      if(registrationKey ==
         m_lastRegistrationKey)
      {
         logger.Debug(
            "ExitDiagnostics duplicate opportunity ignored."
         );

         return true;
      }

      //------------------------------------------------------------
      // Verify that six free slots exist before registering.
      //------------------------------------------------------------

      int freeSlots =
         CountFreeSlots();

      if(freeSlots <
         AQF_EXIT_TARGET_COUNT)
      {
         m_droppedOpportunities++;

         logger.Warning(
            "ExitDiagnostics virtual trade pool is full."
         );

         return false;
      }

      //------------------------------------------------------------
      // Create one independent virtual trade for every R target.
      //------------------------------------------------------------

      for(int targetIndex = 0;
          targetIndex < AQF_EXIT_TARGET_COUNT;
          targetIndex++)
      {
         int slotIndex =
            FindFreeSlot();

         if(slotIndex < 0)
         {
            m_droppedOpportunities++;

            logger.Warning(
               "ExitDiagnostics unable to obtain virtual trade slot."
            );

            return false;
         }

        m_slots[slotIndex].Active =
   true;

m_slots[slotIndex].Symbol =
   request.Symbol;

m_slots[slotIndex].Direction =
   request.Direction;

m_slots[slotIndex].Strategy =
   request.Strategy;

m_slots[slotIndex].EntryPrice =
   request.EntryPrice;

m_slots[slotIndex].StopLoss =
   request.StopLoss;

m_slots[slotIndex].StopDistance =
   request.StopDistance;

m_slots[slotIndex].TargetIndex =
   targetIndex;

m_slots[slotIndex].TargetR =
   m_targetR[targetIndex];

m_slots[slotIndex].EntryTime =
   request.SignalTime;

//---------------------------------------------------------
// The timeframe will be inferred from the market snapshot
// during Update if necessary.
//---------------------------------------------------------

m_slots[slotIndex].Timeframe =
   PERIOD_CURRENT;

//---------------------------------------------------------
// Target Price
//---------------------------------------------------------

double targetDistance =
   request.StopDistance *
   m_slots[slotIndex].TargetR;

if(request.Direction ==
   AQF_SIGNAL_BUY)
{
   m_slots[slotIndex].TargetPrice =
      request.EntryPrice +
      targetDistance;
}
else
{
   m_slots[slotIndex].TargetPrice =
      request.EntryPrice -
      targetDistance;
}

m_created[targetIndex]++;
         
      }

      m_lastRegistrationKey =
         registrationKey;

      logger.Debug(
         "ExitTrack | " +
         request.Symbol +
         " | Direction=" +
         AQFSignalDirectionToString(
            request.Direction) +
         " | Entry=" +
         DoubleToString(
            request.EntryPrice,
            (int)SymbolInfoInteger(
               request.Symbol,
               SYMBOL_DIGITS)) +
         " | SL=" +
         DoubleToString(
            request.StopLoss,
            (int)SymbolInfoInteger(
               request.Symbol,
               SYMBOL_DIGITS)) +
         " | Scenarios=6" +
         " | Active=" +
         IntegerToString(
            ActiveCount())
      );

      return true;
   }

   //==============================================================
   // Update
   //
   // Must be called on EVERY market tick.
   //==============================================================
   void Update(
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return;

      if(!market.Valid)
         return;

      if(market.Bid <= 0.0 ||
         market.Ask <= 0.0)
      {
         return;
      }

      for(int i = 0;
          i < m_capacity;
          i++)
      {
         if(!m_slots[i].Active)
            continue;

         if(m_slots[i].Symbol !=
            market.Symbol)
         {
            continue;
         }

         //---------------------------------------------------------
         // Store timeframe when first observed.
         //---------------------------------------------------------

         if(m_slots[i].Timeframe ==
            PERIOD_CURRENT)
         {
            m_slots[i].Timeframe =
               market.Timeframe;
         }

         //---------------------------------------------------------
         // Closing side of market.
         //
         // BUY closes at Bid.
         // SELL closes at Ask.
         //---------------------------------------------------------

         double exitPrice =
            0.0;

         bool targetReached =
            false;

         bool stopReached =
            false;

         if(m_slots[i].Direction ==
            AQF_SIGNAL_BUY)
         {
            exitPrice =
               market.Bid;

            targetReached =
               (market.Bid >=
                m_slots[i].TargetPrice);

            stopReached =
               (market.Bid <=
                m_slots[i].StopLoss);
         }
         else
         {
            exitPrice =
               market.Ask;

            targetReached =
               (market.Ask <=
                m_slots[i].TargetPrice);

            stopReached =
               (market.Ask >=
                m_slots[i].StopLoss);
         }

         //---------------------------------------------------------
         // Bars elapsed
         //---------------------------------------------------------

         int barsElapsed =
            CalculateBarsElapsed(
               m_slots[i],
               market.Time
            );

         //---------------------------------------------------------
         // Target reached first
         //---------------------------------------------------------

         if(targetReached)
         {
            ResolveWin(
               m_slots[i],
               exitPrice,
               barsElapsed,
               logger
            );

            continue;
         }

         //---------------------------------------------------------
         // Stop reached first
         //---------------------------------------------------------

         if(stopReached)
         {
            ResolveLoss(
               m_slots[i],
               exitPrice,
               barsElapsed,
               logger
            );

            continue;
         }

         //---------------------------------------------------------
         // Expiration
         //---------------------------------------------------------

         if(barsElapsed >=
            m_maxHoldingBars)
         {
            ResolveExpired(
               m_slots[i],
               exitPrice,
               barsElapsed,
               logger
            );

            continue;
         }
      }
   }

   //==============================================================
   // Active Count
   //==============================================================
   int ActiveCount()
   {
      int active =
         0;

      for(int i = 0;
          i < m_capacity;
          i++)
      {
         if(m_slots[i].Active)
            active++;
      }

      return active;
   }

   //==============================================================
   // Report All
   //==============================================================
   void ReportAll(
      CAQFLogger &logger)
   {
      logger.Info(
         "ExitStats =============================================="
      );

      for(int i = 0;
          i < AQF_EXIT_TARGET_COUNT;
          i++)
      {
         logger.Info(
            BuildTargetSummary(
               i
            )
         );
      }

      logger.Info(
         "ExitStats | Active=" +
         IntegerToString(
            ActiveCount()) +
         " | Closed=" +
         IntegerToString(
            (int)m_totalClosed) +
         " | Resolved=" +
         IntegerToString(
            (int)m_totalResolved) +
         " | Dropped=" +
         IntegerToString(
            (int)m_droppedOpportunities)
      );

      logger.Info(
         "ExitStats =============================================="
      );
   }

   //==============================================================
   // Shutdown
   //==============================================================
   void Shutdown(
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return;

      ReportAll(
         logger
      );

      m_initialized =
         false;
   }

private:

   //==============================================================
   // Reset Statistics
   //==============================================================
   void ResetStatistics()
   {
      for(int i = 0;
          i < AQF_EXIT_TARGET_COUNT;
          i++)
      {
         m_created[i] =
            0;

         m_wins[i] =
            0;

         m_losses[i] =
            0;

         m_expired[i] =
            0;

         m_totalResolvedBars[i] =
            0.0;
      }

      m_totalClosed =
         0;

      m_totalResolved =
         0;

      m_droppedOpportunities =
         0;

      m_lastReportedClosed =
         0;

      m_lastRegistrationKey =
         "";
   }

   //==============================================================
   // Reset Slot
   //==============================================================
   void ResetSlot(
      SAQFVirtualExitTrade &trade)
   {
      trade.Active =
         false;

      trade.Symbol =
         "";

      trade.Direction =
         AQF_SIGNAL_NONE;

      trade.Strategy =
         AQF_STRATEGY_NONE;

      trade.EntryPrice =
         0.0;

      trade.StopLoss =
         0.0;

      trade.StopDistance =
         0.0;

      trade.TargetR =
         0.0;

      trade.TargetPrice =
         0.0;

      trade.EntryTime =
         0;

      trade.Timeframe =
         PERIOD_CURRENT;

      trade.TargetIndex =
         -1;
   }

   //==============================================================
   // Count Free Slots
   //==============================================================
   int CountFreeSlots()
   {
      int freeSlots =
         0;

      for(int i = 0;
          i < m_capacity;
          i++)
      {
         if(!m_slots[i].Active)
            freeSlots++;
      }

      return freeSlots;
   }

   //==============================================================
   // Find Free Slot
   //==============================================================
   int FindFreeSlot()
   {
      for(int i = 0;
          i < m_capacity;
          i++)
      {
         if(!m_slots[i].Active)
            return i;
      }

      return -1;
   }

   //==============================================================
   // Bars Elapsed
   //==============================================================
   int CalculateBarsElapsed(
      const SAQFVirtualExitTrade &trade,
      const datetime currentTime)
   {
      int secondsPerBar =
         PeriodSeconds(
            trade.Timeframe
         );

      if(secondsPerBar <= 0)
         return 0;

      long secondsElapsed =
         (long)(
            currentTime -
            trade.EntryTime
         );

      if(secondsElapsed <= 0)
         return 0;

      return
         (int)(
            secondsElapsed /
            secondsPerBar
         );
   }

   //==============================================================
   // Resolve Win
   //==============================================================
   void ResolveWin(
      SAQFVirtualExitTrade &trade,
      const double exitPrice,
      const int barsElapsed,
      CAQFLogger &logger)
   {
      int index =
         trade.TargetIndex;

      if(index < 0 ||
         index >= AQF_EXIT_TARGET_COUNT)
      {
         ResetSlot(
            trade
         );

         return;
      }

      m_wins[index]++;

      m_totalResolvedBars[index] +=
         (double)barsElapsed;

      m_totalClosed++;

      m_totalResolved++;

      logger.Debug(
         "ExitResult | " +
         trade.Symbol +
         " | Target=" +
         DoubleToString(
            trade.TargetR,
            2) +
         "R | Result=WIN" +
         " | Bars=" +
         IntegerToString(
            barsElapsed) +
         " | Exit=" +
         DoubleToString(
            exitPrice,
            (int)SymbolInfoInteger(
               trade.Symbol,
               SYMBOL_DIGITS))
      );

      ResetSlot(
         trade
      );

      MaybeReport(
         logger
      );
   }

   //==============================================================
   // Resolve Loss
   //==============================================================
   void ResolveLoss(
      SAQFVirtualExitTrade &trade,
      const double exitPrice,
      const int barsElapsed,
      CAQFLogger &logger)
   {
      int index =
         trade.TargetIndex;

      if(index < 0 ||
         index >= AQF_EXIT_TARGET_COUNT)
      {
         ResetSlot(
            trade
         );

         return;
      }

      m_losses[index]++;

      m_totalResolvedBars[index] +=
         (double)barsElapsed;

      m_totalClosed++;

      m_totalResolved++;

      logger.Debug(
         "ExitResult | " +
         trade.Symbol +
         " | Target=" +
         DoubleToString(
            trade.TargetR,
            2) +
         "R | Result=LOSS" +
         " | Bars=" +
         IntegerToString(
            barsElapsed) +
         " | Exit=" +
         DoubleToString(
            exitPrice,
            (int)SymbolInfoInteger(
               trade.Symbol,
               SYMBOL_DIGITS))
      );

      ResetSlot(
         trade
      );

      MaybeReport(
         logger
      );
   }

   //==============================================================
   // Resolve Expired
   //==============================================================
   void ResolveExpired(
      SAQFVirtualExitTrade &trade,
      const double exitPrice,
      const int barsElapsed,
      CAQFLogger &logger)
   {
      int index =
         trade.TargetIndex;

      if(index < 0 ||
         index >= AQF_EXIT_TARGET_COUNT)
      {
         ResetSlot(
            trade
         );

         return;
      }

      m_expired[index]++;

      m_totalClosed++;

      logger.Debug(
         "ExitResult | " +
         trade.Symbol +
         " | Target=" +
         DoubleToString(
            trade.TargetR,
            2) +
         "R | Result=EXPIRED" +
         " | Bars=" +
         IntegerToString(
            barsElapsed) +
         " | Exit=" +
         DoubleToString(
            exitPrice,
            (int)SymbolInfoInteger(
               trade.Symbol,
               SYMBOL_DIGITS))
      );

      ResetSlot(
         trade
      );

      MaybeReport(
         logger
      );
   }

   //==============================================================
   // Periodic Report
   //==============================================================
   void MaybeReport(
      CAQFLogger &logger)
   {
      if(
         (m_totalClosed -
          m_lastReportedClosed) <
         m_reportEveryClosed)
      {
         return;
      }

      m_lastReportedClosed =
         m_totalClosed;

      ReportAll(
         logger
      );
   }

   //==============================================================
   // Open Count For Target
   //==============================================================
   int OpenCountForTarget(
      const int targetIndex)
   {
      int count =
         0;

      for(int i = 0;
          i < m_capacity;
          i++)
      {
         if(!m_slots[i].Active)
            continue;

         if(m_slots[i].TargetIndex ==
            targetIndex)
         {
            count++;
         }
      }

      return count;
   }

   //==============================================================
   // Target Summary
   //==============================================================
   string BuildTargetSummary(
      const int index)
   {
      long resolved =
         m_wins[index] +
         m_losses[index];

      double winRate =
         0.0;

      double expectancyR =
         0.0;

      double averageBars =
         0.0;

      if(resolved > 0)
      {
         winRate =
            (
               (double)m_wins[index] /
               (double)resolved
            ) * 100.0;

         //---------------------------------------------------------
         // R expectancy:
         //
         // WIN  = +TargetR
         // LOSS = -1R
         //---------------------------------------------------------

         expectancyR =
            (
               (
                  (double)m_wins[index] *
                  m_targetR[index]
               )
               -
               (double)m_losses[index]
            )
            /
            (double)resolved;

         averageBars =
            m_totalResolvedBars[index] /
            (double)resolved;
      }

      return
         "ExitStats" +
         " | Target=" +
         DoubleToString(
            m_targetR[index],
            2) +
         "R" +
         " | Created=" +
         IntegerToString(
            (int)m_created[index]) +
         " | Resolved=" +
         IntegerToString(
            (int)resolved) +
         " | Wins=" +
         IntegerToString(
            (int)m_wins[index]) +
         " | Losses=" +
         IntegerToString(
            (int)m_losses[index]) +
         " | Expired=" +
         IntegerToString(
            (int)m_expired[index]) +
         " | Open=" +
         IntegerToString(
            OpenCountForTarget(
               index)) +
         " | WinRate=" +
         DoubleToString(
            winRate,
            2) +
         "%" +
         " | Expectancy=" +
         DoubleToString(
            expectancyR,
            3) +
         "R" +
         " | AvgBars=" +
         DoubleToString(
            averageBars,
            1);
   }
};

#endif