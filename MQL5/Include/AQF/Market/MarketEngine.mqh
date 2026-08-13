#ifndef __AQF_MARKET_ENGINE_MQH__
#define __AQF_MARKET_ENGINE_MQH__

#include "../Core/FrameworkModule.mqh"
#include "../Common/MarketSnapshot.mqh"
#include "../Logger/Logger.mqh"

#include "../Indicators/EMA.mqh"
#include "../Indicators/ATR.mqh"
#include "../Indicators/RSI.mqh"
#include "../Indicators/ADX.mqh"

#include "MarketClassifier.mqh"

class CAQFMarketEngine : public CAQFFrameworkModule
{
private:

   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;

   CAQFEMA m_emaFast;
   CAQFEMA m_emaSlow;
   CAQFEMA m_ema200;

   CAQFATR m_atr;
   CAQFRSI m_rsi;
   CAQFADX m_adx;

   CAQFMarketClassifier m_classifier;

public:

   CAQFMarketEngine()
   {
      m_name      = "MarketEngine";
      m_version   = "0.3.0";
      m_symbol    = "";
      m_timeframe = PERIOD_M1;
   }

   //===================================================
   // Initialize
   //===================================================

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

      if(!m_emaFast.Initialize(m_symbol, m_timeframe, 20))
      {
         logger.Error("EMA20 initialization failed.");
         m_status = AQF_MODULE_ERROR;
         return false;
      }

      if(!m_emaSlow.Initialize(m_symbol, m_timeframe, 50))
      {
         logger.Error("EMA50 initialization failed.");
         m_status = AQF_MODULE_ERROR;
         return false;
      }

      if(!m_ema200.Initialize(m_symbol, m_timeframe, 200))
      {
         logger.Error("EMA200 initialization failed.");
         m_status = AQF_MODULE_ERROR;
         return false;
      }

      if(!m_atr.Initialize(m_symbol, m_timeframe, 14))
      {
         logger.Error("ATR initialization failed.");
         m_status = AQF_MODULE_ERROR;
         return false;
      }

      if(!m_rsi.Initialize(m_symbol, m_timeframe, 14))
      {
         logger.Error("RSI initialization failed.");
         m_status = AQF_MODULE_ERROR;
         return false;
      }

      if(!m_adx.Initialize(m_symbol, m_timeframe, 14))
      {
         logger.Error("ADX initialization failed.");
         m_status = AQF_MODULE_ERROR;
         return false;
      }

      m_status = AQF_MODULE_READY;

      logger.Info(
         "MarketEngine initialized for " +
         m_symbol +
         " / " +
         EnumToString(m_timeframe)
      );

      return true;
   }

   //===================================================
   // Build Snapshot
   //===================================================

   bool BuildSnapshot(CAQFMarketSnapshot &snapshot,
                      CAQFLogger &logger)
   {
      snapshot.Reset();

      MqlTick tick;

      if(!SymbolInfoTick(m_symbol, tick))
      {
         logger.Error("SymbolInfoTick failed for " + m_symbol);
         return false;
      }

      double point =
         SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      if(point <= 0.0)
      {
         logger.Error("Invalid point size for " + m_symbol);
         return false;
      }

      MqlRates rates[];
      ArraySetAsSeries(rates, true);

      int copied =
         CopyRates(
            m_symbol,
            m_timeframe,
            0,
            1,
            rates
         );

      if(copied != 1)
      {
         logger.Debug("CopyRates data not ready.");
         return false;
      }

      double emaFast = 0.0;
      double emaSlow = 0.0;
      double ema200  = 0.0;
      double atr     = 0.0;
      double rsi     = 0.0;
      double adx     = 0.0;

      if(!m_emaFast.GetValue(emaFast))
         return false;

      if(!m_emaSlow.GetValue(emaSlow))
         return false;

      if(!m_ema200.GetValue(ema200))
         return false;

      if(!m_atr.GetValue(atr))
         return false;

      if(!m_rsi.GetValue(rsi))
         return false;

      if(!m_adx.GetValue(adx))
         return false;

      snapshot.Symbol    = m_symbol;
      snapshot.Timeframe = m_timeframe;
      snapshot.Time      = tick.time;

      snapshot.Bid  = tick.bid;
      snapshot.Ask  = tick.ask;
      snapshot.Last = tick.last;

      snapshot.Point = point;

      snapshot.SpreadPoints =
         (tick.ask - tick.bid) / point;

      snapshot.Open  = rates[0].open;
      snapshot.High  = rates[0].high;
      snapshot.Low   = rates[0].low;
      snapshot.Close = rates[0].close;

      snapshot.TickVolume = rates[0].tick_volume;

      snapshot.EMAFast = emaFast;
      snapshot.EMASlow = emaSlow;
      snapshot.EMA200  = ema200;

      snapshot.ATR = atr;
      snapshot.RSI = rsi;
      snapshot.ADX = adx;

      // -----------------------------------------------
      // Market Intelligence Layer
      // -----------------------------------------------

      m_classifier.Classify(snapshot);

      snapshot.Valid = true;

      if(m_status == AQF_MODULE_READY)
         m_status = AQF_MODULE_RUNNING;

      return true;
   }

   //===================================================
   // Shutdown
   //===================================================

   virtual void Shutdown()
   {
      m_emaFast.Shutdown();
      m_emaSlow.Shutdown();
      m_ema200.Shutdown();

      m_atr.Shutdown();
      m_rsi.Shutdown();
      m_adx.Shutdown();

      m_status = AQF_MODULE_STOPPED;
   }
};

#endif