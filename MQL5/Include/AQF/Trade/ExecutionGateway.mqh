#ifndef __AQF_EXECUTION_GATEWAY_MQH__
#define __AQF_EXECUTION_GATEWAY_MQH__

#include "../Common/TradeRequest.mqh"
#include "../Common/TradePreflightResult.mqh"
#include "../Common/ExecutionResult.mqh"

#include "DuplicateGuard.mqh"

//+------------------------------------------------------------------+
//| Execution Gateway                                                |
//|                                                                  |
//| Sprint 6 Package C:                                              |
//| native request construction + hard execution lock                |
//+------------------------------------------------------------------+
class CAQFExecutionGateway
{
private:

   bool m_executionEnabled;

   CAQFDuplicateGuard m_duplicateGuard;

public:

   CAQFExecutionGateway()
   {
      //------------------------------------------------------------
      // HARD LOCK
      //------------------------------------------------------------

      m_executionEnabled = false;
   }

   void SetExecutionEnabled(
      const bool enabled)
   {
      //------------------------------------------------------------
      // Package C deliberately ignores attempts to enable it.
      //------------------------------------------------------------

      m_executionEnabled = false;
   }

   bool ExecutionEnabled()
   {
      return m_executionEnabled;
   }

   bool Prepare(
      const CAQFTradeRequest &request,
      const CAQFTradePreflightResult &preflight,
      CAQFExecutionResult &result,
      MqlTradeRequest &nativeRequest)
   {
      result.Reset();
      ZeroMemory(nativeRequest);

      //------------------------------------------------------------
      // Internal request
      //------------------------------------------------------------

      if(!request.Valid)
      {
         Reject(
            result,
            AQF_EXECUTION_INVALID_REQUEST,
            "Internal trade request is invalid"
         );

         return true;
      }

      //------------------------------------------------------------
      // Preflight
      //------------------------------------------------------------

      if(!preflight.Passed)
      {
         Reject(
            result,
            AQF_EXECUTION_PREFLIGHT_NOT_PASSED,
            "Broker preflight has not passed"
         );

         return true;
      }

      //------------------------------------------------------------
      // Duplicate protection
      //------------------------------------------------------------

      string duplicateReason = "";

      if(m_duplicateGuard.HasDuplicate(
            request,
            duplicateReason))
      {
         Reject(
            result,
            AQF_EXECUTION_DUPLICATE,
            duplicateReason
         );

         return true;
      }

      //------------------------------------------------------------
      // Build native MQL5 request
      //
      // IMPORTANT:
      // Building this structure does NOT send anything.
      //------------------------------------------------------------

      if(!BuildNativeRequest(
            request,
            preflight,
            nativeRequest))
      {
         Reject(
            result,
            AQF_EXECUTION_NATIVE_BUILD_FAILED,
            "Unable to construct native MqlTradeRequest"
         );

         return true;
      }

      //------------------------------------------------------------
      // Package C hard lock
      //------------------------------------------------------------

      if(!m_executionEnabled)
      {
         result.Status =
            AQF_EXECUTION_BLOCKED;

         result.RejectionReason =
            AQF_EXECUTION_DISABLED;

         result.Ready = true;
         result.Sent  = false;

         result.Message =
            "Native request ready but execution is physically disabled";

         return true;
      }

      //------------------------------------------------------------
      // There is intentionally NO OrderSend() in Package C.
      //------------------------------------------------------------

      Reject(
         result,
         AQF_EXECUTION_DISABLED,
         "Package C has no execution implementation"
      );

      return true;
   }

private:

   bool BuildNativeRequest(
      const CAQFTradeRequest &request,
      const CAQFTradePreflightResult &preflight,
      MqlTradeRequest &nativeRequest)
   {
      ZeroMemory(nativeRequest);

      nativeRequest.action =
         TRADE_ACTION_DEAL;

      nativeRequest.symbol =
         request.Symbol;

      nativeRequest.magic =
         request.MagicNumber;

      nativeRequest.volume =
         request.Volume;

      nativeRequest.sl =
         request.StopLoss;

      nativeRequest.tp =
         request.TakeProfit;

      nativeRequest.comment =
         request.Comment;

      nativeRequest.type_filling =
         preflight.FillingMode;

      if(request.Direction ==
         AQF_SIGNAL_BUY)
      {
         nativeRequest.type =
            ORDER_TYPE_BUY;
      }
      else if(request.Direction ==
              AQF_SIGNAL_SELL)
      {
         nativeRequest.type =
            ORDER_TYPE_SELL;
      }
      else
      {
         return false;
      }

      MqlTick tick;

      if(!SymbolInfoTick(
            request.Symbol,
            tick))
      {
         return false;
      }

      if(request.Direction ==
         AQF_SIGNAL_BUY)
      {
         nativeRequest.price =
            tick.ask;
      }
      else
      {
         nativeRequest.price =
            tick.bid;
      }

      return
      (
         nativeRequest.symbol != "" &&
         nativeRequest.volume > 0.0 &&
         nativeRequest.price > 0.0
      );
   }

   void Reject(
      CAQFExecutionResult &result,
      const ENUM_AQF_EXECUTION_REJECTION reason,
      const string message)
   {
      result.Status =
         AQF_EXECUTION_REJECTED;

      result.RejectionReason =
         reason;

      result.Ready = false;
      result.Sent  = false;

      result.Message =
         message;
   }
};

#endif