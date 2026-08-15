#ifndef __AQF_DUPLICATE_GUARD_MQH__
#define __AQF_DUPLICATE_GUARD_MQH__

#include "../Common/TradeRequest.mqh"

class CAQFDuplicateGuard
{
public:

   CAQFDuplicateGuard()
   {
   }

   bool HasDuplicate(
      const CAQFTradeRequest &request,
      string &reason)
   {
      reason = "";

      if(request.Symbol == "" ||
         request.MagicNumber == 0)
      {
         reason = "Invalid duplicate-check request";
         return true;
      }

      if(HasMatchingPosition(request))
      {
         reason =
            "Matching AQF position already exists";

         return true;
      }

      if(HasMatchingPendingOrder(request))
      {
         reason =
            "Matching AQF pending order already exists";

         return true;
      }

      return false;
   }

private:

   bool HasMatchingPosition(
      const CAQFTradeRequest &request)
   {
      int total =
         PositionsTotal();

      for(int i = 0; i < total; i++)
      {
         ulong ticket =
            PositionGetTicket(i);

         if(ticket == 0)
            continue;

         string symbol =
            PositionGetString(
               POSITION_SYMBOL
            );

         long magic =
            PositionGetInteger(
               POSITION_MAGIC
            );

         long positionType =
            PositionGetInteger(
               POSITION_TYPE
            );

         if(symbol != request.Symbol)
            continue;

         if((ulong)magic !=
            request.MagicNumber)
         {
            continue;
         }

         if(request.Direction ==
            AQF_SIGNAL_BUY &&
            positionType ==
            POSITION_TYPE_BUY)
         {
            return true;
         }

         if(request.Direction ==
            AQF_SIGNAL_SELL &&
            positionType ==
            POSITION_TYPE_SELL)
         {
            return true;
         }
      }

      return false;
   }

   bool HasMatchingPendingOrder(
      const CAQFTradeRequest &request)
   {
      int total =
         OrdersTotal();

      for(int i = 0; i < total; i++)
      {
         ulong ticket =
            OrderGetTicket(i);

         if(ticket == 0)
            continue;

         string symbol =
            OrderGetString(
               ORDER_SYMBOL
            );

         long magic =
            OrderGetInteger(
               ORDER_MAGIC
            );

         ENUM_ORDER_TYPE orderType =
            (ENUM_ORDER_TYPE)
            OrderGetInteger(
               ORDER_TYPE
            );

         if(symbol != request.Symbol)
            continue;

         if((ulong)magic !=
            request.MagicNumber)
         {
            continue;
         }

         if(request.Direction ==
            AQF_SIGNAL_BUY &&
            IsBuyOrder(orderType))
         {
            return true;
         }

         if(request.Direction ==
            AQF_SIGNAL_SELL &&
            IsSellOrder(orderType))
         {
            return true;
         }
      }

      return false;
   }

   bool IsBuyOrder(
      const ENUM_ORDER_TYPE type)
   {
      return
      (
         type == ORDER_TYPE_BUY ||
         type == ORDER_TYPE_BUY_LIMIT ||
         type == ORDER_TYPE_BUY_STOP ||
         type == ORDER_TYPE_BUY_STOP_LIMIT
      );
   }

   bool IsSellOrder(
      const ENUM_ORDER_TYPE type)
   {
      return
      (
         type == ORDER_TYPE_SELL ||
         type == ORDER_TYPE_SELL_LIMIT ||
         type == ORDER_TYPE_SELL_STOP ||
         type == ORDER_TYPE_SELL_STOP_LIMIT
      );
   }
};

#endif