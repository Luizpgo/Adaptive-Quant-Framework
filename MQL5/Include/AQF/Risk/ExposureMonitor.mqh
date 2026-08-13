#ifndef __AQF_EXPOSURE_MONITOR_MQH__
#define __AQF_EXPOSURE_MONITOR_MQH__

class CAQFExposureMonitor
{
private:

   int    m_maxOpenPositions;
   double m_maxSymbolVolume;

public:

   CAQFExposureMonitor()
   {
      m_maxOpenPositions = 5;
      m_maxSymbolVolume  = 10.0;
   }

   void SetMaxOpenPositions(const int value)
   {
      if(value > 0)
         m_maxOpenPositions = value;
   }

   void SetMaxSymbolVolume(const double value)
   {
      if(value > 0.0)
         m_maxSymbolVolume = value;
   }

   int OpenPositions()
   {
      return PositionsTotal();
   }

   double SymbolVolume(const string symbol)
   {
      double totalVolume = 0.0;

      int total = PositionsTotal();

      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);

         if(ticket == 0)
            continue;

         string positionSymbol =
            PositionGetString(POSITION_SYMBOL);

         if(positionSymbol != symbol)
            continue;

         totalVolume +=
            PositionGetDouble(POSITION_VOLUME);
      }

      return totalVolume;
   }

   double ApproxSymbolNotional(
      const string symbol,
      const double marketPrice)
   {
      if(marketPrice <= 0.0)
         return 0.0;

      double totalNotional = 0.0;
      int total = PositionsTotal();

      double contractSize =
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_CONTRACT_SIZE
         );

      if(contractSize <= 0.0)
         return 0.0;

      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);

         if(ticket == 0)
            continue;

         string positionSymbol =
            PositionGetString(POSITION_SYMBOL);

         if(positionSymbol != symbol)
            continue;

         double volume =
            PositionGetDouble(POSITION_VOLUME);

         totalNotional +=
            volume *
            contractSize *
            marketPrice;
      }

      return totalNotional;
   }

   double ProposedNotional(
      const string symbol,
      const double proposedVolume,
      const double marketPrice)
   {
      double contractSize =
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_CONTRACT_SIZE
         );

      if(contractSize <= 0.0 ||
         proposedVolume <= 0.0 ||
         marketPrice <= 0.0)
      {
         return 0.0;
      }

      return
         proposedVolume *
         contractSize *
         marketPrice;
   }

   bool CanAdd(
      const string symbol,
      const double proposedVolume,
      string &reason)
   {
      reason = "";

      if(proposedVolume <= 0.0)
      {
         reason = "Proposed volume is invalid";
         return false;
      }

      if(OpenPositions() >= m_maxOpenPositions)
      {
         reason = "Maximum open position count reached";
         return false;
      }

      double currentSymbolVolume =
         SymbolVolume(symbol);

      if((currentSymbolVolume +
          proposedVolume) >
         m_maxSymbolVolume)
      {
         reason =
            "Maximum symbol volume exposure reached";

         return false;
      }

      return true;
   }
};

#endif