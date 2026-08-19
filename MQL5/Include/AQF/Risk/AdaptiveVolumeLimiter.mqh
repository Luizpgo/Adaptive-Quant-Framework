#ifndef __AQF_ADAPTIVE_VOLUME_LIMITER_MQH__
#define __AQF_ADAPTIVE_VOLUME_LIMITER_MQH__

#include "../Common/VolumeLimitResult.mqh"

class CAQFAdaptiveVolumeLimiter
{
private:

   double m_maxNotionalPercent;
   double m_maxMarginPercent;

public:

   CAQFAdaptiveVolumeLimiter()
   {
      m_maxNotionalPercent = 150.0;
      m_maxMarginPercent   = 20.0;
   }

   void SetMaxNotionalPercent(
      const double value)
   {
      if(value > 0.0)
         m_maxNotionalPercent = value;
   }

   void SetMaxMarginPercent(
      const double value)
   {
      if(value > 0.0)
         m_maxMarginPercent = value;
   }

   bool Calculate(
      const string symbol,
      const ENUM_ORDER_TYPE orderType,
      const double entryPrice,
      const double equity,
      const double freeMargin,
      const double proposedRiskVolume,
      CAQFVolumeLimitResult &result)
   {
      result.Reset();

      if(symbol == "" ||
         entryPrice <= 0.0 ||
         equity <= 0.0 ||
         freeMargin <= 0.0 ||
         proposedRiskVolume <= 0.0)
      {
         result.Status  = AQF_VOLUME_LIMIT_REJECTED;
         result.Message = "Invalid limiter inputs";

         return true;
      }

      double minVolume =
         SymbolInfoDouble(
            symbol,
            SYMBOL_VOLUME_MIN);

      double maxVolume =
         SymbolInfoDouble(
            symbol,
            SYMBOL_VOLUME_MAX);

      double volumeStep =
         SymbolInfoDouble(
            symbol,
            SYMBOL_VOLUME_STEP);

      double contractSize =
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_CONTRACT_SIZE);

      if(minVolume <= 0.0 ||
         maxVolume <= 0.0 ||
         volumeStep <= 0.0 ||
         contractSize <= 0.0)
      {
         result.Status  = AQF_VOLUME_LIMIT_REJECTED;
         result.Message = "Invalid broker symbol limits";

         return true;
      }

      //------------------------------------------------------------
      // Candidate 1: Risk-based volume
      //------------------------------------------------------------

      result.VolumeByRisk =
         NormalizeDown(
            proposedRiskVolume,
            volumeStep);

      //------------------------------------------------------------
      // Candidate 2: Broker absolute maximum
      //------------------------------------------------------------

      result.VolumeByBroker =
         NormalizeDown(
            maxVolume,
            volumeStep);

      //------------------------------------------------------------
      // Candidate 3: Notional exposure cap
      //
      // maxNotionalMoney =
      // equity * maxNotionalPercent / 100
      //
      // volume =
      // maxNotionalMoney /
      // (contractSize * price)
      //------------------------------------------------------------

      double maxNotionalMoney =
         equity *
         (m_maxNotionalPercent / 100.0);

      double notionalPerLot =
         contractSize * entryPrice;

      if(notionalPerLot <= 0.0)
      {
         result.Status  = AQF_VOLUME_LIMIT_REJECTED;
         result.Message = "Invalid notional calculation";

         return true;
      }

      double exposureVolume =
         maxNotionalMoney /
         notionalPerLot;

      result.VolumeByExposure =
         NormalizeDown(
            exposureVolume,
            volumeStep);

      //------------------------------------------------------------
      // Candidate 4: Margin cap
      //
      // Instead of deriving leverage manually, use
      // OrderCalcMargin progressively.
      //------------------------------------------------------------

      double maximumMarginBudget =
         equity *
         (m_maxMarginPercent / 100.0);

      if(maximumMarginBudget >
         freeMargin)
      {
         maximumMarginBudget =
            freeMargin;
      }

      result.VolumeByMargin =
         FindMaximumVolumeByMargin(
            symbol,
            orderType,
            entryPrice,
            maximumMarginBudget,
            minVolume,
            maxVolume,
            volumeStep);

      //------------------------------------------------------------
      // Final candidate = minimum of all positive limits
      //------------------------------------------------------------

      double finalVolume =
         result.VolumeByRisk;

      finalVolume =
         MinimumPositive(
            finalVolume,
            result.VolumeByExposure);

      finalVolume =
         MinimumPositive(
            finalVolume,
            result.VolumeByMargin);

      finalVolume =
         MinimumPositive(
            finalVolume,
            result.VolumeByBroker);

      finalVolume =
         NormalizeDown(
            finalVolume,
            volumeStep);

      //------------------------------------------------------------
      // Broker minimum safety
      //------------------------------------------------------------

      if(finalVolume < minVolume)
      {
         result.Status =
            AQF_VOLUME_LIMIT_REJECTED;

         result.FinalVolume = 0.0;

         result.Valid = false;

         result.Message =
            "No broker-valid volume satisfies risk limits";

         return true;
      }

      result.FinalVolume =
         finalVolume;

      result.Valid =
         true;

      if(finalVolume <
         result.VolumeByRisk)
      {
         result.Status =
            AQF_VOLUME_LIMIT_REDUCED;

         result.Message =
            "Risk volume reduced by adaptive capital limits";
      }
      else
      {
         result.Status =
            AQF_VOLUME_LIMIT_ACCEPTED;

         result.Message =
            "Risk volume accepted without reduction";
      }

      return true;
   }

private:

   double NormalizeDown(
      const double volume,
      const double step)
   {
      if(volume <= 0.0 ||
         step <= 0.0)
      {
         return 0.0;
      }

      return
         MathFloor(
            volume / step)
         * step;
   }

   double MinimumPositive(
      const double a,
      const double b)
   {
      if(a <= 0.0)
         return b;

      if(b <= 0.0)
         return a;

      return MathMin(a, b);
   }

   double FindMaximumVolumeByMargin(
      const string symbol,
      const ENUM_ORDER_TYPE orderType,
      const double entryPrice,
      const double marginBudget,
      const double minVolume,
      const double maxVolume,
      const double volumeStep)
   {
      if(marginBudget <= 0.0)
         return 0.0;

      double bestVolume = 0.0;

      //------------------------------------------------------------
      // Binary search over broker volume steps
      //------------------------------------------------------------

      long minSteps =
         (long)MathCeil(
            minVolume /
            volumeStep);

      long maxSteps =
         (long)MathFloor(
            maxVolume /
            volumeStep);

      long low  = minSteps;
      long high = maxSteps;

      while(low <= high)
      {
         long mid =
            low +
            (high - low) / 2;

         double testVolume =
            (double)mid *
            volumeStep;

         double margin = 0.0;

         ResetLastError();

         if(!OrderCalcMargin(
               orderType,
               symbol,
               testVolume,
               entryPrice,
               margin))
         {
            high =
               mid - 1;

            continue;
         }

         if(margin <= marginBudget)
         {
            bestVolume =
               testVolume;

            low =
               mid + 1;
         }
         else
         {
            high =
               mid - 1;
         }
      }

      return
         NormalizeDown(
            bestVolume,
            volumeStep);
   }
};

#endif