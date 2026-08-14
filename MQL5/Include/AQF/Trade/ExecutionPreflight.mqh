#ifndef __AQF_EXECUTION_PREFLIGHT_MQH__
#define __AQF_EXECUTION_PREFLIGHT_MQH__

#include "../Common/TradeRequest.mqh"
#include "../Common/TradePreflightResult.mqh"

class CAQFExecutionPreflight
{
private:

   double m_maxSpreadPoints;

public:

   CAQFExecutionPreflight()
   {
      //------------------------------------------------------------
      // Engineering default.
      // We will calibrate this later for XAUUSD.
      //------------------------------------------------------------
      m_maxSpreadPoints = 100.0;
   }

   void SetMaxSpreadPoints(
      const double value)
   {
      if(value > 0.0)
         m_maxSpreadPoints = value;
   }

   bool Validate(
      const CAQFTradeRequest &request,
      CAQFTradePreflightResult &result)
   {
      result.Reset();

      //------------------------------------------------------------
      // Internal request validity
      //------------------------------------------------------------

      if(!request.Valid ||
         request.Symbol == "")
      {
         Reject(
            result,
            AQF_PREFLIGHT_INVALID_REQUEST,
            "Internal AQF trade request is invalid"
         );

         return true;
      }

      //------------------------------------------------------------
      // Symbol trade mode
      //------------------------------------------------------------

      long tradeMode =
         SymbolInfoInteger(
            request.Symbol,
            SYMBOL_TRADE_MODE
         );

      if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
      {
         Reject(
            result,
            AQF_PREFLIGHT_SYMBOL_DISABLED,
            "Trading is disabled for symbol"
         );

         return true;
      }

      //------------------------------------------------------------
      // Direction permissions
      //------------------------------------------------------------

      if(request.Direction == AQF_SIGNAL_BUY)
      {
         if(tradeMode == SYMBOL_TRADE_MODE_SHORTONLY ||
            tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
         {
            Reject(
               result,
               AQF_PREFLIGHT_DIRECTION_NOT_ALLOWED,
               "BUY trading is not allowed for symbol"
            );

            return true;
         }
      }
      else if(request.Direction == AQF_SIGNAL_SELL)
      {
         if(tradeMode == SYMBOL_TRADE_MODE_LONGONLY ||
            tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
         {
            Reject(
               result,
               AQF_PREFLIGHT_DIRECTION_NOT_ALLOWED,
               "SELL trading is not allowed for symbol"
            );

            return true;
         }
      }
      else
      {
         Reject(
            result,
            AQF_PREFLIGHT_INVALID_REQUEST,
            "Trade direction is invalid"
         );

         return true;
      }

      //------------------------------------------------------------
      // Volume properties
      //------------------------------------------------------------

      double minVolume =
         SymbolInfoDouble(
            request.Symbol,
            SYMBOL_VOLUME_MIN
         );

      double maxVolume =
         SymbolInfoDouble(
            request.Symbol,
            SYMBOL_VOLUME_MAX
         );

      double volumeStep =
         SymbolInfoDouble(
            request.Symbol,
            SYMBOL_VOLUME_STEP
         );

      if(minVolume <= 0.0 ||
         maxVolume <= 0.0 ||
         volumeStep <= 0.0)
      {
         Reject(
            result,
            AQF_PREFLIGHT_INVALID_VOLUME,
            "Unable to read symbol volume limits"
         );

         return true;
      }

      if(request.Volume < minVolume ||
         request.Volume > maxVolume)
      {
         Reject(
            result,
            AQF_PREFLIGHT_INVALID_VOLUME,
            "Requested volume outside broker limits"
         );

         return true;
      }

      //------------------------------------------------------------
      // Volume step
      //------------------------------------------------------------

      double stepRatio =
         request.Volume / volumeStep;

      double roundedRatio =
         MathRound(stepRatio);

      if(MathAbs(stepRatio - roundedRatio) >
         0.0000001)
      {
         Reject(
            result,
            AQF_PREFLIGHT_VOLUME_STEP,
            "Requested volume violates broker volume step"
         );

         return true;
      }

      //------------------------------------------------------------
      // Price
      //------------------------------------------------------------

      if(request.EntryPrice <= 0.0 ||
         request.StopLoss <= 0.0 ||
         request.TakeProfit <= 0.0)
      {
         Reject(
            result,
            AQF_PREFLIGHT_INVALID_PRICE,
            "Entry, SL or TP contains invalid price"
         );

         return true;
      }

      //------------------------------------------------------------
      // Latest market tick
      //------------------------------------------------------------

      MqlTick tick;

      if(!SymbolInfoTick(
            request.Symbol,
            tick))
      {
         Reject(
            result,
            AQF_PREFLIGHT_INVALID_PRICE,
            "Unable to read current market tick"
         );

         return true;
      }

      double point =
         SymbolInfoDouble(
            request.Symbol,
            SYMBOL_POINT
         );

      if(point <= 0.0)
      {
         Reject(
            result,
            AQF_PREFLIGHT_INVALID_PRICE,
            "Unable to read symbol point size"
         );

         return true;
      }

      //------------------------------------------------------------
      // Spread
      //------------------------------------------------------------

      result.SpreadPoints =
         (tick.ask - tick.bid) / point;

      if(result.SpreadPoints >
         m_maxSpreadPoints)
      {
         Reject(
            result,
            AQF_PREFLIGHT_SPREAD_TOO_HIGH,
            "Current spread exceeds execution policy"
         );

         return true;
      }

      //------------------------------------------------------------
      // Revalidate broker stop level against CURRENT market price
      //------------------------------------------------------------

      long stopsLevelPoints =
         SymbolInfoInteger(
            request.Symbol,
            SYMBOL_TRADE_STOPS_LEVEL
         );

      double minimumStopDistance =
         (double)stopsLevelPoints * point;

      double currentEntry = 0.0;

      if(request.Direction == AQF_SIGNAL_BUY)
         currentEntry = tick.ask;
      else
         currentEntry = tick.bid;

      double slDistance =
         MathAbs(
            currentEntry -
            request.StopLoss
         );

      double tpDistance =
         MathAbs(
            currentEntry -
            request.TakeProfit
         );

      if(minimumStopDistance > 0.0)
      {
         if(slDistance < minimumStopDistance ||
            tpDistance < minimumStopDistance)
         {
            Reject(
               result,
               AQF_PREFLIGHT_STOP_DISTANCE,
               "SL or TP violates current broker stop distance"
            );

            return true;
         }
      }

      //------------------------------------------------------------
      // Filling mode
      //------------------------------------------------------------

      ENUM_ORDER_TYPE_FILLING fillingMode;

      if(!ResolveFillingMode(
            request.Symbol,
            fillingMode))
      {
         Reject(
            result,
            AQF_PREFLIGHT_FILLING_MODE,
            "Unable to resolve supported filling mode"
         );

         return true;
      }

      result.FillingMode =
         fillingMode;

      //------------------------------------------------------------
      // Build a native MqlTradeRequest ONLY for OrderCheck.
      //
      // IMPORTANT:
      // OrderCheck does NOT send the order.
      //------------------------------------------------------------

      MqlTradeRequest nativeRequest;
      MqlTradeCheckResult checkResult;

      ZeroMemory(nativeRequest);
      ZeroMemory(checkResult);

      nativeRequest.action =
         TRADE_ACTION_DEAL;

      nativeRequest.symbol =
         request.Symbol;

      nativeRequest.volume =
         request.Volume;

      nativeRequest.magic =
         request.MagicNumber;

      nativeRequest.comment =
         request.Comment;

      nativeRequest.sl =
         request.StopLoss;

      nativeRequest.tp =
         request.TakeProfit;

      nativeRequest.type_filling =
         fillingMode;

      //------------------------------------------------------------
      // Current market price is used for check
      //------------------------------------------------------------

      if(request.Direction == AQF_SIGNAL_BUY)
      {
         nativeRequest.type =
            ORDER_TYPE_BUY;

         nativeRequest.price =
            tick.ask;
      }
      else
      {
         nativeRequest.type =
            ORDER_TYPE_SELL;

         nativeRequest.price =
            tick.bid;
      }

      //------------------------------------------------------------
      // Server-side preflight check
      //------------------------------------------------------------

      ResetLastError();

      bool checkOk =
         OrderCheck(
            nativeRequest,
            checkResult
         );

      result.CheckRetcode =
         checkResult.retcode;

      result.CheckComment =
         checkResult.comment;

      result.CheckBalance =
         checkResult.balance;

      result.CheckEquity =
         checkResult.equity;

      result.CheckMargin =
         checkResult.margin;

      result.CheckFreeMargin =
         checkResult.margin_free;

      result.CheckMarginLevel =
         checkResult.margin_level;

      if(!checkOk)
      {
         Reject(
            result,
            AQF_PREFLIGHT_ORDER_CHECK_FAILED,
            "OrderCheck returned false. Error=" +
            IntegerToString(
               GetLastError()
            )
         );

         return true;
      }

      //------------------------------------------------------------
      // A successful OrderCheck call alone is not sufficient;
      // we also retain broker/server return diagnostics.
      //------------------------------------------------------------

      result.Status =
         AQF_PREFLIGHT_PASSED;

      result.RejectionReason =
         AQF_PREFLIGHT_REJECTION_NONE;

      result.Passed = true;

      result.Message =
         "Broker execution preflight passed";

      return true;
   }

private:

   bool ResolveFillingMode(
      const string symbol,
      ENUM_ORDER_TYPE_FILLING &mode)
   {
      long fillingFlags =
         SymbolInfoInteger(
            symbol,
            SYMBOL_FILLING_MODE
         );

      long executionMode =
         SymbolInfoInteger(
            symbol,
            SYMBOL_TRADE_EXEMODE
         );

      //------------------------------------------------------------
      // FOK and IOC are flags and must be tested individually.
      //------------------------------------------------------------

      if((fillingFlags &
          SYMBOL_FILLING_FOK) ==
         SYMBOL_FILLING_FOK)
      {
         mode = ORDER_FILLING_FOK;
         return true;
      }

      if((fillingFlags &
          SYMBOL_FILLING_IOC) ==
         SYMBOL_FILLING_IOC)
      {
         mode = ORDER_FILLING_IOC;
         return true;
      }

      //------------------------------------------------------------
      // RETURN is not allowed with Market Execution.
      //------------------------------------------------------------

      if(executionMode !=
         SYMBOL_TRADE_EXECUTION_MARKET)
      {
         mode = ORDER_FILLING_RETURN;
         return true;
      }

      return false;
   }

   void Reject(
      CAQFTradePreflightResult &result,
      const ENUM_AQF_PREFLIGHT_REJECTION reason,
      const string message)
   {
      result.Status =
         AQF_PREFLIGHT_REJECTED;

      result.RejectionReason =
         reason;

      result.Passed = false;

      result.Message =
         message;
   }
};

#endif