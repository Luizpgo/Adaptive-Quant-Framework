#ifndef __AQF_MARKET_ENGINE_MQH__
#define __AQF_MARKET_ENGINE_MQH__

#include "../Core/FrameworkModule.mqh"
#include "../Common/MarketSnapshot.mqh"
#include "../Logger/Logger.mqh"

//+------------------------------------------------------------------+
//| Market data acquisition engine                                  |
//+------------------------------------------------------------------+
class CAQFMarketEngine : public CAQFFrameworkModule
{
private:

   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFMarketEngine()
   {
      m_name      = "MarketEngine";
      m_version   = "0.2.0";
      m_symbol    = "";
      m_timeframe = PERIOD_M1;
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(string symbol,
                   ENUM_TIMEFRAMES timeframe,
                   CAQFLogger &logger)
   {
      m_status = AQF_MODULE_INITIALIZING;

      if(symbol == "")
      {
         logger.Error("MarketEngine received an empty symbol.");
         m_status = AQF_MODULE_ERROR;

         return false;
      }

      if(!SymbolSelect(symbol, true))
      {
         logger.Error("Unable to select symbol: " + symbol);
         m_status = AQF_MODULE_ERROR;

         return false;
      }

      m_symbol    = symbol;
      m_timeframe = timeframe;

      m_status = AQF_MODULE_READY;

      logger.Info("MarketEngine initialized for " +
                  m_symbol +
                  " / " +
                  EnumToString(m_timeframe));

      return true;
   }

   //==============================================================
   // Build latest market snapshot
   //==============================================================
   bool BuildSnapshot(CAQFMarketSnapshot &snapshot,
                      CAQFLogger &logger)
   {
      snapshot.Reset();

      MqlTick tick;

      if(!SymbolInfoTick(m_symbol, tick))
      {
         logger.Error("SymbolInfoTick failed for " + m_symbol);
         m_status = AQF_MODULE_ERROR;

         return false;
      }

      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      if(point <= 0.0)
      {
         logger.Error("Invalid point size for " + m_symbol);
         m_status = AQF_MODULE_ERROR;

         return false;
      }

      MqlRates rates[];

      ArraySetAsSeries(rates, true);

      int copied = CopyRates(m_symbol,
                             m_timeframe,
                             0,
                             1,
                             rates);

      if(copied != 1)
      {
         logger.Debug("CopyRates data not ready for " + m_symbol);

         return false;
      }

      snapshot.Symbol       = m_symbol;
      snapshot.Timeframe    = m_timeframe;
      snapshot.Time         = tick.time;

      snapshot.Bid          = tick.bid;
      snapshot.Ask          = tick.ask;
      snapshot.Last         = tick.last;

      snapshot.Point        = point;
      snapshot.SpreadPoints = (tick.ask - tick.bid) / point;

      snapshot.Open         = rates[0].open;
      snapshot.High         = rates[0].high;
      snapshot.Low          = rates[0].low;
      snapshot.Close        = rates[0].close;

      snapshot.TickVolume   = rates[0].tick_volume;

      snapshot.Valid        = true;

      if(m_status == AQF_MODULE_READY)
         m_status = AQF_MODULE_RUNNING;

      return true;
   }

   //==============================================================
   // Shutdown
   //==============================================================
   virtual void Shutdown()
   {
      m_status = AQF_MODULE_STOPPED;
   }
};

#endif