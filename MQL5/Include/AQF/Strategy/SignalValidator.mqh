#ifndef __AQF_SIGNAL_VALIDATOR_MQH__
#define __AQF_SIGNAL_VALIDATOR_MQH__

#include "../Common/TradeSignal.mqh"
#include "../Common/SignalValidation.mqh"

//+------------------------------------------------------------------+
//| Signal validation layer                                          |
//+------------------------------------------------------------------+
class CAQFSignalValidator
{
private:

   double m_minimumConfidence;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFSignalValidator()
   {
      m_minimumConfidence = 60.0;
   }

   //==============================================================
   // Minimum confidence
   //==============================================================
   void SetMinimumConfidence(
      const double minimumConfidence)
   {
      if(minimumConfidence < 0.0)
         m_minimumConfidence = 0.0;
      else if(minimumConfidence > 100.0)
         m_minimumConfidence = 100.0;
      else
         m_minimumConfidence = minimumConfidence;
   }

   //==============================================================
   // Validate
   //==============================================================
   bool Validate(
      const CAQFTradeSignal &signal,
      CAQFSignalValidationResult &result)
   {
      result.Reset();

      //------------------------------------------------------------
      // Signal internally invalid
      //------------------------------------------------------------

      if(!signal.Valid)
      {
         Reject(
            result,
            AQF_REJECTION_INVALID_SIGNAL,
            "Strategy marked signal as invalid"
         );

         return true;
      }

      //------------------------------------------------------------
      // Strategy
      //------------------------------------------------------------

      if(signal.Strategy == AQF_STRATEGY_NONE)
      {
         Reject(
            result,
            AQF_REJECTION_NO_STRATEGY,
            "No strategy generated the signal"
         );

         return true;
      }

      //------------------------------------------------------------
      // Direction
      //------------------------------------------------------------

      if(signal.Direction == AQF_SIGNAL_NONE)
      {
         Reject(
            result,
            AQF_REJECTION_NO_DIRECTION,
            "Signal has no trading direction"
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
            AQF_REJECTION_INVALID_SYMBOL,
            "Signal contains an empty symbol"
         );

         return true;
      }

      //------------------------------------------------------------
      // Timestamp
      //------------------------------------------------------------

      if(signal.Time <= 0)
      {
         Reject(
            result,
            AQF_REJECTION_INVALID_TIME,
            "Signal contains an invalid timestamp"
         );

         return true;
      }

      //------------------------------------------------------------
      // Confidence
      //------------------------------------------------------------

      if(signal.Confidence < m_minimumConfidence)
      {
         Reject(
            result,
            AQF_REJECTION_LOW_CONFIDENCE,
            "Signal confidence below validation threshold"
         );

         return true;
      }

      //------------------------------------------------------------
      // Quality
      //------------------------------------------------------------

      if(signal.Quality == AQF_SIGNAL_QUALITY_LOW ||
         signal.Quality == AQF_SIGNAL_QUALITY_UNKNOWN)
      {
         Reject(
            result,
            AQF_REJECTION_LOW_QUALITY,
            "Signal quality is insufficient"
         );

         return true;
      }

      //------------------------------------------------------------
      // Accepted
      //------------------------------------------------------------

      result.Status          = AQF_VALIDATION_ACCEPTED;
      result.RejectionReason = AQF_REJECTION_NONE;

      result.Accepted = true;
      result.Message  = "Signal passed strategy validation";

      return true;
   }

private:

   //==============================================================
   // Reject helper
   //==============================================================
   void Reject(
      CAQFSignalValidationResult &result,
      const ENUM_AQF_SIGNAL_REJECTION_REASON reason,
      const string message)
   {
      result.Status          = AQF_VALIDATION_REJECTED;
      result.RejectionReason = reason;

      result.Accepted = false;
      result.Message  = message;
   }
};

#endif