#ifndef __AQF_EXIT_DIAGNOSTICS_MQH__
#define __AQF_EXIT_DIAGNOSTICS_MQH__
#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"
#include "RawEntryDiagnostics.mqh"
#define AQF_EXIT_TARGET_COUNT 6
#define AQF_DIRECTION_BUCKETS 2
#define AQF_QUALITY_BUCKETS 3
#define AQF_STRENGTH_BUCKETS 3
#define AQF_MOMENTUM_BUCKETS 3
#define AQF_VOLATILITY_BUCKETS 3
#define AQF_CONFIDENCE_BUCKETS 4
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
   //---------------------------------------------------------------
   // Entry-quality context
   //---------------------------------------------------------------
   ENUM_AQF_SIGNAL_QUALITY    Quality;
   double                     Confidence;
   ENUM_AQF_TREND_REGIME      Trend;
   ENUM_AQF_TREND_STRENGTH    TrendStrength;
   ENUM_AQF_VOLATILITY_REGIME Volatility;
   ENUM_AQF_MOMENTUM_REGIME   Momentum;

   //---------------------------------------------------------------
   // Sprint 7 B5 raw market context
   //---------------------------------------------------------------
   double ADX;
   double RSI;
   double ATRPercent;
   double EMASeparationPercent;
};
//+------------------------------------------------------------------+
//| Exit / Take-Profit Diagnostics                                   |
//|                                                                  |
//| Sprint 7 B5:                                                     |
//| Preserves categorized entry context from B4 and adds raw ADX,     |
//| RSI, ATR%, EMA separation%, and momentum-alignment diagnostics.   |
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
   // Baseline statistics
   //---------------------------------------------------------------
   long m_created[AQF_EXIT_TARGET_COUNT];
   long m_wins[AQF_EXIT_TARGET_COUNT];
   long m_losses[AQF_EXIT_TARGET_COUNT];
   long m_expired[AQF_EXIT_TARGET_COUNT];
   double m_totalResolvedBars[AQF_EXIT_TARGET_COUNT];
   //---------------------------------------------------------------
   // Direction statistics
   //
   // 0 = BUY
   // 1 = SELL
   //---------------------------------------------------------------
   long m_directionWins
      [AQF_EXIT_TARGET_COUNT]
      [AQF_DIRECTION_BUCKETS];
   long m_directionLosses
      [AQF_EXIT_TARGET_COUNT]
      [AQF_DIRECTION_BUCKETS];
   //---------------------------------------------------------------
   // Quality statistics
   //
   // 0 = LOW
   // 1 = MEDIUM
   // 2 = HIGH
   //---------------------------------------------------------------
   long m_qualityWins
      [AQF_EXIT_TARGET_COUNT]
      [AQF_QUALITY_BUCKETS];
   long m_qualityLosses
      [AQF_EXIT_TARGET_COUNT]
      [AQF_QUALITY_BUCKETS];
   //---------------------------------------------------------------
   // Strength statistics
   //
   // 0 = WEAK
   // 1 = MODERATE
   // 2 = STRONG
   //---------------------------------------------------------------
   long m_strengthWins
      [AQF_EXIT_TARGET_COUNT]
      [AQF_STRENGTH_BUCKETS];
   long m_strengthLosses
      [AQF_EXIT_TARGET_COUNT]
      [AQF_STRENGTH_BUCKETS];
   //---------------------------------------------------------------
   // Momentum statistics
   //
   // 0 = BEARISH
   // 1 = NEUTRAL
   // 2 = BULLISH
   //---------------------------------------------------------------
   long m_momentumWins
      [AQF_EXIT_TARGET_COUNT]
      [AQF_MOMENTUM_BUCKETS];
   long m_momentumLosses
      [AQF_EXIT_TARGET_COUNT]
      [AQF_MOMENTUM_BUCKETS];
   //---------------------------------------------------------------
   // Volatility statistics
   //
   // 0 = LOW
   // 1 = NORMAL
   // 2 = HIGH
   //---------------------------------------------------------------
   long m_volatilityWins
      [AQF_EXIT_TARGET_COUNT]
      [AQF_VOLATILITY_BUCKETS];
   long m_volatilityLosses
      [AQF_EXIT_TARGET_COUNT]
      [AQF_VOLATILITY_BUCKETS];
   //---------------------------------------------------------------
   // Confidence statistics
   //
   // 0 = 60-69
   // 1 = 70-79
   // 2 = 80-89
   // 3 = 90-100
   //---------------------------------------------------------------
   long m_confidenceWins
      [AQF_EXIT_TARGET_COUNT]
      [AQF_CONFIDENCE_BUCKETS];
   long m_confidenceLosses
      [AQF_EXIT_TARGET_COUNT]
      [AQF_CONFIDENCE_BUCKETS];

   //---------------------------------------------------------------
   // Sprint 7 B5 raw diagnostics
   //---------------------------------------------------------------
   CAQFRawEntryDiagnostics m_rawEntryDiagnostics;

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
      // Baseline ExitStats report frequency.
      //
      // Entry-quality detail is printed at Shutdown so that long
      // Strategy Tester runs do not flood the Journal.
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

      if(!m_rawEntryDiagnostics.Initialize(
            logger))
      {
         logger.Error(
            "RawEntryDiagnostics initialization failed."
         );
         return false;
      }

      for(int i = 0;
          i < AQF_EXIT_TARGET_COUNT;
          i++)
      {
         m_rawEntryDiagnostics.SetTargetR(
            i,
            m_targetR[i]
         );
      }

      m_initialized =
         true;
      logger.Info(
         "ExitDiagnostics initialized."
      );
      logger.Info(
         "Exit targets: 0.50R | 0.75R | 1.00R | 1.25R | 1.50R | 2.00R"
      );
      logger.Info(
         "Entry-quality outcome diagnostics enabled."
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
      const CAQFTradeSignal &signal,
      const CAQFMarketSnapshot &market,
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
      // Signal validation
      //------------------------------------------------------------
      if(!signal.Valid)
         return false;

      //------------------------------------------------------------
      // Raw market context validation
      //------------------------------------------------------------
      if(!market.Valid ||
         market.Symbol != request.Symbol)
      {
         return false;
      }

      //------------------------------------------------------------
      // Duplicate registration key
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
      // Verify that six free slots exist.
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
         m_slots[slotIndex].Timeframe =
            PERIOD_CURRENT;
         //---------------------------------------------------------
         // Preserve original entry context
         //---------------------------------------------------------
         m_slots[slotIndex].Quality =
            signal.Quality;
         m_slots[slotIndex].Confidence =
            signal.Confidence;
         m_slots[slotIndex].Trend =
            signal.Trend;
         m_slots[slotIndex].TrendStrength =
            signal.TrendStrength;
         m_slots[slotIndex].Volatility =
            signal.Volatility;
         m_slots[slotIndex].Momentum =
            signal.Momentum;

         //---------------------------------------------------------
         // Sprint 7 B5 raw market context
         //---------------------------------------------------------
         m_slots[slotIndex].ADX =
            market.ADX;
         m_slots[slotIndex].RSI =
            market.RSI;
         m_slots[slotIndex].ATRPercent =
            market.ATRPercent;
         m_slots[slotIndex].EMASeparationPercent =
            market.EMASeparationPercent;

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
         " | Quality=" +
         AQFSignalQualityToString(
            signal.Quality) +
         " | Confidence=" +
         DoubleToString(
            signal.Confidence,
            1) +
         " | Strength=" +
         AQFStrengthToString(
            signal.TrendStrength) +
         " | Momentum=" +
         AQFMomentumToString(
            signal.Momentum) +
         " | Volatility=" +
         AQFVolatilityToString(
            signal.Volatility) +
         " | MomAlign=" +
         m_rawEntryDiagnostics.MomentumAlignmentText(
            request.Direction,
            signal.Momentum) +
         " | ADX=" +
         DoubleToString(
            market.ADX,
            2) +
         " | RSI=" +
         DoubleToString(
            market.RSI,
            2) +
         " | ATR%=" +
         DoubleToString(
            market.ATRPercent,
            4) +
         " | EMAsep%=" +
         DoubleToString(
            market.EMASeparationPercent,
            4) +
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
         double exitPrice =
            0.0;
         bool targetReached =
            false;
         bool stopReached =
            false;
         //---------------------------------------------------------
         // BUY closes at Bid.
         // SELL closes at Ask.
         //---------------------------------------------------------
         if(m_slots[i].Direction ==
            AQF_SIGNAL_BUY)
         {
            exitPrice =
               market.Bid;
            targetReached =
               (
                  market.Bid >=
                  m_slots[i].TargetPrice
               );
            stopReached =
               (
                  market.Bid <=
                  m_slots[i].StopLoss
               );
         }
         else
         {
            exitPrice =
               market.Ask;
            targetReached =
               (
                  market.Ask <=
                  m_slots[i].TargetPrice
               );
            stopReached =
               (
                  market.Ask >=
                  m_slots[i].StopLoss
               );
         }
         int barsElapsed =
            CalculateBarsElapsed(
               m_slots[i],
               market.Time
            );
         //---------------------------------------------------------
         // Target reached
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
         // Stop reached
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
   // Baseline Report
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
   // Entry Quality Report
   //==============================================================
   void ReportEntryQuality(
      CAQFLogger &logger)
   {
      logger.Info(
         "EntryStats ============================================="
      );
      for(int target = 0;
          target < AQF_EXIT_TARGET_COUNT;
          target++)
      {
         //---------------------------------------------------------
         // Direction
         //---------------------------------------------------------
         for(int bucket = 0;
             bucket < AQF_DIRECTION_BUCKETS;
             bucket++)
         {
            ReportSegment(
               logger,
               target,
               "DIRECTION",
               DirectionBucketText(
                  bucket),
               m_directionWins[target][bucket],
               m_directionLosses[target][bucket]
            );
         }
         //---------------------------------------------------------
         // Signal Quality
         //---------------------------------------------------------
         for(int bucket = 0;
             bucket < AQF_QUALITY_BUCKETS;
             bucket++)
         {
            ReportSegment(
               logger,
               target,
               "QUALITY",
               QualityBucketText(
                  bucket),
               m_qualityWins[target][bucket],
               m_qualityLosses[target][bucket]
            );
         }
         //---------------------------------------------------------
         // Trend Strength
         //---------------------------------------------------------
         for(int bucket = 0;
             bucket < AQF_STRENGTH_BUCKETS;
             bucket++)
         {
            ReportSegment(
               logger,
               target,
               "STRENGTH",
               StrengthBucketText(
                  bucket),
               m_strengthWins[target][bucket],
               m_strengthLosses[target][bucket]
            );
         }
         //---------------------------------------------------------
         // Momentum
         //---------------------------------------------------------
         for(int bucket = 0;
             bucket < AQF_MOMENTUM_BUCKETS;
             bucket++)
         {
            ReportSegment(
               logger,
               target,
               "MOMENTUM",
               MomentumBucketText(
                  bucket),
               m_momentumWins[target][bucket],
               m_momentumLosses[target][bucket]
            );
         }
         //---------------------------------------------------------
         // Volatility
         //---------------------------------------------------------
         for(int bucket = 0;
             bucket < AQF_VOLATILITY_BUCKETS;
             bucket++)
         {
            ReportSegment(
               logger,
               target,
               "VOLATILITY",
               VolatilityBucketText(
                  bucket),
               m_volatilityWins[target][bucket],
               m_volatilityLosses[target][bucket]
            );
         }
         //---------------------------------------------------------
         // Confidence
         //---------------------------------------------------------
         for(int bucket = 0;
             bucket < AQF_CONFIDENCE_BUCKETS;
             bucket++)
         {
            ReportSegment(
               logger,
               target,
               "CONFIDENCE",
               ConfidenceBucketText(
                  bucket),
               m_confidenceWins[target][bucket],
               m_confidenceLosses[target][bucket]
            );
         }
      }
      logger.Info(
         "EntryStats ============================================="
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
      //------------------------------------------------------------
      // Baseline first
      //------------------------------------------------------------
      ReportAll(
         logger
      );
      //------------------------------------------------------------
      // Detailed entry-quality attribution second
      //------------------------------------------------------------
      ReportEntryQuality(
         logger
      );

      //------------------------------------------------------------
      // Sprint 7 B5 raw-entry attribution third
      //------------------------------------------------------------
      m_rawEntryDiagnostics.ReportAll(
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
      for(int target = 0;
          target < AQF_EXIT_TARGET_COUNT;
          target++)
      {
         m_created[target] =
            0;
         m_wins[target] =
            0;
         m_losses[target] =
            0;
         m_expired[target] =
            0;
         m_totalResolvedBars[target] =
            0.0;
         for(int bucket = 0;
             bucket < AQF_DIRECTION_BUCKETS;
             bucket++)
         {
            m_directionWins[target][bucket] =
               0;
            m_directionLosses[target][bucket] =
               0;
         }
         for(int bucket = 0;
             bucket < AQF_QUALITY_BUCKETS;
             bucket++)
         {
            m_qualityWins[target][bucket] =
               0;
            m_qualityLosses[target][bucket] =
               0;
         }
         for(int bucket = 0;
             bucket < AQF_STRENGTH_BUCKETS;
             bucket++)
         {
            m_strengthWins[target][bucket] =
               0;
            m_strengthLosses[target][bucket] =
               0;
         }
         for(int bucket = 0;
             bucket < AQF_MOMENTUM_BUCKETS;
             bucket++)
         {
            m_momentumWins[target][bucket] =
               0;
            m_momentumLosses[target][bucket] =
               0;
         }
         for(int bucket = 0;
             bucket < AQF_VOLATILITY_BUCKETS;
             bucket++)
         {
            m_volatilityWins[target][bucket] =
               0;
            m_volatilityLosses[target][bucket] =
               0;
         }
         for(int bucket = 0;
             bucket < AQF_CONFIDENCE_BUCKETS;
             bucket++)
         {
            m_confidenceWins[target][bucket] =
               0;
            m_confidenceLosses[target][bucket] =
               0;
         }
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
      trade.Quality =
         AQF_SIGNAL_QUALITY_UNKNOWN;
      trade.Confidence =
         0.0;
      trade.Trend =
         AQF_TREND_UNKNOWN;
      trade.TrendStrength =
         AQF_STRENGTH_UNKNOWN;
      trade.Volatility =
         AQF_VOLATILITY_UNKNOWN;
      trade.Momentum =
         AQF_MOMENTUM_UNKNOWN;
      trade.ADX =
         0.0;
      trade.RSI =
         0.0;
      trade.ATRPercent =
         0.0;
      trade.EMASeparationPercent =
         0.0;
   }
   //==============================================================
   // Free Slot Helpers
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
      //------------------------------------------------------------
      // B4 attribution
      //------------------------------------------------------------
      RecordEntryOutcome(
         trade,
         true
      );
      m_rawEntryDiagnostics.Record(
         trade.TargetIndex,
         trade.Direction,
         trade.Momentum,
         trade.ADX,
         trade.RSI,
         trade.ATRPercent,
         trade.EMASeparationPercent,
         true
      );
      logger.Debug(
         "ExitResult | " +
         trade.Symbol +
         " | Target=" +
         DoubleToString(
            trade.TargetR,
            2) +
         "R | Result=WIN" +
         " | Quality=" +
         AQFSignalQualityToString(
            trade.Quality) +
         " | Confidence=" +
         DoubleToString(
            trade.Confidence,
            1) +
         " | Strength=" +
         AQFStrengthToString(
            trade.TrendStrength) +
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
      //------------------------------------------------------------
      // B4 attribution
      //------------------------------------------------------------
      RecordEntryOutcome(
         trade,
         false
      );
      m_rawEntryDiagnostics.Record(
         trade.TargetIndex,
         trade.Direction,
         trade.Momentum,
         trade.ADX,
         trade.RSI,
         trade.ATRPercent,
         trade.EMASeparationPercent,
         false
      );
      logger.Debug(
         "ExitResult | " +
         trade.Symbol +
         " | Target=" +
         DoubleToString(
            trade.TargetR,
            2) +
         "R | Result=LOSS" +
         " | Quality=" +
         AQFSignalQualityToString(
            trade.Quality) +
         " | Confidence=" +
         DoubleToString(
            trade.Confidence,
            1) +
         " | Strength=" +
         AQFStrengthToString(
            trade.TrendStrength) +
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
      //------------------------------------------------------------
      // Expired trades are intentionally NOT classified as WIN or
      // LOSS in EntryStats.
      //------------------------------------------------------------
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
   // Entry Outcome Attribution
   //==============================================================
   void RecordEntryOutcome(
      const SAQFVirtualExitTrade &trade,
      const bool win)
   {
      int target =
         trade.TargetIndex;
      if(target < 0 ||
         target >= AQF_EXIT_TARGET_COUNT)
      {
         return;
      }
      //------------------------------------------------------------
      // Direction
      //------------------------------------------------------------
      int directionBucket =
         DirectionBucket(
            trade.Direction
         );
      if(directionBucket >= 0)
      {
         if(win)
            m_directionWins[target][directionBucket]++;
         else
            m_directionLosses[target][directionBucket]++;
      }
      //------------------------------------------------------------
      // Quality
      //------------------------------------------------------------
      int qualityBucket =
         QualityBucket(
            trade.Quality
         );
      if(qualityBucket >= 0)
      {
         if(win)
            m_qualityWins[target][qualityBucket]++;
         else
            m_qualityLosses[target][qualityBucket]++;
      }
      //------------------------------------------------------------
      // Strength
      //------------------------------------------------------------
      int strengthBucket =
         StrengthBucket(
            trade.TrendStrength
         );
      if(strengthBucket >= 0)
      {
         if(win)
            m_strengthWins[target][strengthBucket]++;
         else
            m_strengthLosses[target][strengthBucket]++;
      }
      //------------------------------------------------------------
      // Momentum
      //------------------------------------------------------------
      int momentumBucket =
         MomentumBucket(
            trade.Momentum
         );
      if(momentumBucket >= 0)
      {
         if(win)
            m_momentumWins[target][momentumBucket]++;
         else
            m_momentumLosses[target][momentumBucket]++;
      }
      //------------------------------------------------------------
      // Volatility
      //------------------------------------------------------------
      int volatilityBucket =
         VolatilityBucket(
            trade.Volatility
         );
      if(volatilityBucket >= 0)
      {
         if(win)
            m_volatilityWins[target][volatilityBucket]++;
         else
            m_volatilityLosses[target][volatilityBucket]++;
      }
      //------------------------------------------------------------
      // Confidence
      //------------------------------------------------------------
      int confidenceBucket =
         ConfidenceBucket(
            trade.Confidence
         );
      if(confidenceBucket >= 0)
      {
         if(win)
            m_confidenceWins[target][confidenceBucket]++;
         else
            m_confidenceLosses[target][confidenceBucket]++;
      }
   }
   //==============================================================
   // Bucket Mapping
   //==============================================================
   int DirectionBucket(
      const ENUM_AQF_SIGNAL_DIRECTION direction)
   {
      if(direction ==
         AQF_SIGNAL_BUY)
      {
         return 0;
      }
      if(direction ==
         AQF_SIGNAL_SELL)
      {
         return 1;
      }
      return -1;
   }
   int QualityBucket(
      const ENUM_AQF_SIGNAL_QUALITY quality)
   {
      if(quality ==
         AQF_SIGNAL_QUALITY_LOW)
      {
         return 0;
      }
      if(quality ==
         AQF_SIGNAL_QUALITY_MEDIUM)
      {
         return 1;
      }
      if(quality ==
         AQF_SIGNAL_QUALITY_HIGH)
      {
         return 2;
      }
      return -1;
   }
   int StrengthBucket(
      const ENUM_AQF_TREND_STRENGTH strength)
   {
      if(strength ==
         AQF_STRENGTH_WEAK)
      {
         return 0;
      }
      if(strength ==
         AQF_STRENGTH_MODERATE)
      {
         return 1;
      }
      if(strength ==
         AQF_STRENGTH_STRONG)
      {
         return 2;
      }
      return -1;
   }
   int MomentumBucket(
      const ENUM_AQF_MOMENTUM_REGIME momentum)
   {
      if(momentum ==
         AQF_MOMENTUM_BEARISH)
      {
         return 0;
      }
      if(momentum ==
         AQF_MOMENTUM_NEUTRAL)
      {
         return 1;
      }
      if(momentum ==
         AQF_MOMENTUM_BULLISH)
      {
         return 2;
      }
      return -1;
   }
   int VolatilityBucket(
      const ENUM_AQF_VOLATILITY_REGIME volatility)
   {
      if(volatility ==
         AQF_VOLATILITY_LOW)
      {
         return 0;
      }
      if(volatility ==
         AQF_VOLATILITY_NORMAL)
      {
         return 1;
      }
      if(volatility ==
         AQF_VOLATILITY_HIGH)
      {
         return 2;
      }
      return -1;
   }
   int ConfidenceBucket(
      const double confidence)
   {
      if(confidence < 60.0)
         return -1;
      if(confidence < 70.0)
         return 0;
      if(confidence < 80.0)
         return 1;
      if(confidence < 90.0)
         return 2;
      return 3;
   }
   //==============================================================
   // Bucket Text
   //==============================================================
   string DirectionBucketText(
      const int bucket)
   {
      if(bucket == 0)
         return "BUY";
      if(bucket == 1)
         return "SELL";
      return "UNKNOWN";
   }
   string QualityBucketText(
      const int bucket)
   {
      if(bucket == 0)
         return "LOW";
      if(bucket == 1)
         return "MEDIUM";
      if(bucket == 2)
         return "HIGH";
      return "UNKNOWN";
   }
   string StrengthBucketText(
      const int bucket)
   {
      if(bucket == 0)
         return "WEAK";
      if(bucket == 1)
         return "MODERATE";
      if(bucket == 2)
         return "STRONG";
      return "UNKNOWN";
   }
   string MomentumBucketText(
      const int bucket)
   {
      if(bucket == 0)
         return "BEARISH";
      if(bucket == 1)
         return "NEUTRAL";
      if(bucket == 2)
         return "BULLISH";
      return "UNKNOWN";
   }
   string VolatilityBucketText(
      const int bucket)
   {
      if(bucket == 0)
         return "LOW";
      if(bucket == 1)
         return "NORMAL";
      if(bucket == 2)
         return "HIGH";
      return "UNKNOWN";
   }
   string ConfidenceBucketText(
      const int bucket)
   {
      if(bucket == 0)
         return "60-69";
      if(bucket == 1)
         return "70-79";
      if(bucket == 2)
         return "80-89";
      if(bucket == 3)
         return "90-100";
      return "UNKNOWN";
   }
   //==============================================================
   // Segment Reporter
   //==============================================================
   void ReportSegment(
      CAQFLogger &logger,
      const int targetIndex,
      const string dimension,
      const string bucket,
      const long wins,
      const long losses)
   {
      long resolved =
         wins +
         losses;
      //------------------------------------------------------------
      // Avoid printing empty combinations.
      //------------------------------------------------------------
      if(resolved <= 0)
         return;
      double winRate =
         (
            (double)wins /
            (double)resolved
         ) * 100.0;
      double expectancyR =
         (
            (
               (double)wins *
               m_targetR[targetIndex]
            )
            -
            (double)losses
         )
         /
         (double)resolved;
      logger.Info(
         "EntryStats" +
         " | Target=" +
         DoubleToString(
            m_targetR[targetIndex],
            2) +
         "R" +
         " | Dimension=" +
         dimension +
         " | Bucket=" +
         bucket +
         " | Resolved=" +
         IntegerToString(
            (int)resolved) +
         " | Wins=" +
         IntegerToString(
            (int)wins) +
         " | Losses=" +
         IntegerToString(
            (int)losses) +
         " | WinRate=" +
         DoubleToString(
            winRate,
            2) +
         "%" +
         " | Expectancy=" +
         DoubleToString(
            expectancyR,
            3) +
         "R"
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
      //------------------------------------------------------------
      // Keep periodic output concise.
      //
      // Detailed EntryStats will be printed at Shutdown.
      //------------------------------------------------------------
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
