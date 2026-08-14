#ifndef __AQF_ORDER_BUILDER_MQH__
#define __AQF_ORDER_BUILDER_MQH__

#include "../Common/TradeSignal.mqh"
#include "../Common/MarketSnapshot.mqh"
#include "../Common/RiskDecision.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeBuildResult.mqh"

//+------------------------------------------------------------------+
//| Builds an internal AQF trade request                             |
//|                                                                  |
//| NO TRADE EXECUTION EXISTS IN THIS CLASS.                         |
//+------------------------------------------------------------------+
class CAQFOrderBuilder
{
private:

   ulong  m_magicNumber;
   double m_takeProfitRiskReward;

public:

   CAQFOrderBuilder()
   {
      //------------------------------------------------------------
      // Development Magic Number
      //------------------------------------------------------------

      m_magicNumber = 26081301;

      //------------------------------------------------------------
      // Temporary engineering target:
      //
      // TP distance = stop distance * 1.0
      //
      // This is NOT the final scalp exit model.
      //------------------------------------------------------------

      m_takeProfitRiskReward = 1.0;
   }

   void SetMagicNumber(const ulong magicNumber)
   {
      m_magicNumber = magicNumber;
   }

   void SetTakeProfitRiskReward(const double value)
   {
      if(value > 0.0)
         m_takeProfitRiskReward = value;
   }

   bool Build(
      const CAQFTradeSignal &signal,
      const CAQFMarketSnapshot &market,
      const CAQFRiskDecision &risk,
      CAQFTradeRequest &request,
      CAQFTradeBuildResult &result)
   {
      request.Reset();
      result.Reset();

      //------------------------------------------------------------
      // Signal
      //------------------------------------------------------------

      if(!signal.Valid)
      {
         Reject(
            result,
            AQF_TRADE_BUILD_INVALID_SIGNAL,
            "Trade signal is invalid"
         );

         return true;
      }

      //------------------------------------------------------------
      // Risk authorization
      //------------------------------------------------------------

      if(!risk.Authorized)
      {
         Reject(
            result,
            AQF_TRADE_BUILD_RISK_NOT_AUTHORIZED,
            "RiskManager has not authorized the trade"
         );

         return true;
      }

      //------------------------------------------------------------
      // Symbol
      //------------------------------------------------------------

      if(signal.Symbol == "")
      {
         Reject(
            result,
            AQF_TRADE_BUILD_INVALID_SYMBOL,
            "Trade signal contains no symbol"
         );

         return true;
      }

      //------------------------------------------------------------
      // Direction
      //------------------------------------------------------------

      if(signal.Direction != AQF_SIGNAL_BUY &&
         signal.Direction != AQF_SIGNAL_SELL)
      {
         Reject(
            result,
            AQF_TRADE_BUILD_INVALID_DIRECTION,
            "Trade signal direction is invalid"
         );

         return true;
      }

      //------------------------------------------------------------
      // Volume
      //------------------------------------------------------------

      if(risk.NormalizedVolume <= 0.0)
      {
         Reject(
            result,
            AQF_TRADE_BUILD_INVALID_VOLUME,
            "RiskManager produced an invalid volume"
         );

         return true;
      }

      //------------------------------------------------------------
      // Entry
      //------------------------------------------------------------

      double entryPrice = 0.0;

      if(signal.Direction == AQF_SIGNAL_BUY)
         entryPrice = market.Ask;
      else
         entryPrice = market.Bid;

      if(entryPrice <= 0.0)
      {
         Reject(
            result,
            AQF_TRADE_BUILD_INVALID_ENTRY_PRICE,
            "Market entry price is invalid"
         );

         return true;
      }

      //------------------------------------------------------------
      // Stop
      //------------------------------------------------------------

      double stopLoss = risk.StopPrice;

      if(stopLoss <= 0.0 ||
         risk.StopDistance <= 0.0)
      {
         Reject(
            result,
            AQF_TRADE_BUILD_INVALID_STOP,
            "RiskManager produced an invalid stop"
         );

         return true;
      }

      //------------------------------------------------------------
      // Take Profit
      //------------------------------------------------------------

      double takeProfitDistance =
         risk.StopDistance *
         m_takeProfitRiskReward;

      double takeProfit = 0.0;

      if(signal.Direction == AQF_SIGNAL_BUY)
      {
         takeProfit =
            entryPrice + takeProfitDistance;
      }
      else
      {
         takeProfit =
            entryPrice - takeProfitDistance;
      }

      if(takeProfit <= 0.0)
      {
         Reject(
            result,
            AQF_TRADE_BUILD_INVALID_TAKE_PROFIT,
            "Calculated Take Profit is invalid"
         );

         return true;
      }

      //------------------------------------------------------------
      // Broker minimal stop distance
      //------------------------------------------------------------

      double point =
         SymbolInfoDouble(
            signal.Symbol,
            SYMBOL_POINT
         );

      long stopsLevelPoints =
         SymbolInfoInteger(
            signal.Symbol,
            SYMBOL_TRADE_STOPS_LEVEL
         );

      if(point <= 0.0)
      {
         Reject(
            result,
            AQF_TRADE_BUILD_INVALID_SYMBOL,
            "Unable to read symbol point size"
         );

         return true;
      }

      double minimumStopDistance =
         (double)stopsLevelPoints * point;

      //------------------------------------------------------------
      // If broker has a stops level, verify both SL and TP.
      //------------------------------------------------------------

      if(minimumStopDistance > 0.0)
      {
         double slDistance =
            MathAbs(entryPrice - stopLoss);

         double tpDistance =
            MathAbs(entryPrice - takeProfit);

         if(slDistance < minimumStopDistance ||
            tpDistance < minimumStopDistance)
         {
            Reject(
               result,
               AQF_TRADE_BUILD_BROKER_STOP_DISTANCE,
               "SL or TP violates broker minimum stop distance"
            );

            return true;
         }
      }

      //------------------------------------------------------------
      // Build internal request
      //------------------------------------------------------------

      request.Symbol =
         signal.Symbol;

      request.Direction =
         signal.Direction;

      request.Volume =
         risk.NormalizedVolume;

      request.EntryPrice =
         entryPrice;

      request.StopLoss =
         stopLoss;

      request.TakeProfit =
         takeProfit;

      request.StopDistance =
         risk.StopDistance;

      request.TakeProfitDistance =
         takeProfitDistance;

      request.MagicNumber =
         m_magicNumber;

      request.Comment =
         "AQF-" +
         AQFStrategyTypeToString(
            signal.Strategy
         );

      request.SignalTime =
         signal.Time;

      request.Strategy =
         signal.Strategy;

      request.Valid = true;

      //------------------------------------------------------------
      // Ready
      //------------------------------------------------------------

      result.Status =
         AQF_TRADE_BUILD_READY;

      result.RejectionReason =
         AQF_TRADE_BUILD_REJECTION_NONE;

      result.Ready = true;

      result.Message =
         "Trade request successfully built";

      return true;
   }

private:

   void Reject(
      CAQFTradeBuildResult &result,
      const ENUM_AQF_TRADE_BUILD_REJECTION reason,
      const string message)
   {
      result.Status =
         AQF_TRADE_BUILD_REJECTED;

      result.RejectionReason =
         reason;

      result.Ready = false;

      result.Message =
         message;
   }
};

#endif