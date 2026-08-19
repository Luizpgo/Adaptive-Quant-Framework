#ifndef __AQF_RISK_MANAGER_MQH__
#define __AQF_RISK_MANAGER_MQH__

#include "../Core/FrameworkModule.mqh"
#include "../Logger/Logger.mqh"

#include "../Common/TradeSignal.mqh"
#include "../Common/MarketSnapshot.mqh"
#include "../Common/AccountSnapshot.mqh"
#include "../Common/RiskDecision.mqh"
#include "../Common/VolumeLimitResult.mqh"

#include "AccountMonitor.mqh"
#include "PositionSizer.mqh"
#include "ExposureMonitor.mqh"
#include "CapitalLimits.mqh"
#include "AdaptiveVolumeLimiter.mqh"

class CAQFRiskManager : public CAQFFrameworkModule
{
private:

   CAQFAccountMonitor   m_accountMonitor;
   CAQFPositionSizer    m_positionSizer;
   CAQFExposureMonitor  m_exposureMonitor;
   CAQFCapitalLimits    m_capitalLimits;
   CAQFAdaptiveVolumeLimiter m_volumeLimiter;

   CAQFAccountSnapshot  m_accountSnapshot;

   double m_maxDrawdownPercent;
   double m_minimumFreeMarginPercent;
   double m_atrStopMultiplier;

public:

   CAQFRiskManager()
   {
      m_name    = "RiskManager";
      m_version = "0.5.2";

      m_maxDrawdownPercent       = 10.0;
      m_minimumFreeMarginPercent = 30.0;

      m_atrStopMultiplier = 2.0;

      m_positionSizer.SetRiskPercent(0.50);

      m_exposureMonitor.SetMaxOpenPositions(5);
      m_exposureMonitor.SetMaxSymbolVolume(10.0);

      m_capitalLimits.SetMaxRiskPercentPerTrade(0.50);
      m_capitalLimits.SetMaxMarginUsePercent(20.0);
      m_capitalLimits.SetMaxSymbolExposurePercent(150.0);

      m_volumeLimiter.SetMaxNotionalPercent(
      m_capitalLimits.MaxSymbolExposurePercent()
   );

      m_volumeLimiter.SetMaxMarginPercent(
      m_capitalLimits.MaxMarginUsePercent()
   );
   }

   bool Initialize(CAQFLogger &logger)
   {
      m_status = AQF_MODULE_INITIALIZING;

      if(!m_accountMonitor.BuildSnapshot(
            m_accountSnapshot))
      {
         logger.Error(
            "RiskManager failed to build account snapshot."
         );

         m_status = AQF_MODULE_ERROR;

         return false;
      }

      m_status = AQF_MODULE_READY;

      logger.Info(
         "RiskManager initialized."
      );

      logger.Info(
         "Risk policy | RiskPerTrade=" +
         DoubleToString(
            m_positionSizer.RiskPercent(),
            2) +
         "% | MaxMargin=" +
         DoubleToString(
            m_capitalLimits.MaxMarginUsePercent(),
            2) +
         "% | MaxSymbolNotional=" +
         DoubleToString(
            m_capitalLimits.MaxSymbolExposurePercent(),
            2) +
         "%"
      );

      return true;
   }

   bool Evaluate(
      const CAQFTradeSignal &signal,
      const CAQFMarketSnapshot &market,
      CAQFRiskDecision &decision,
      CAQFLogger &logger)
   {
      decision.Reset();

      if(!signal.Valid)
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_INVALID_SIGNAL,
            "RiskManager received an invalid trade signal"
         );

         return true;
      }

      if(!m_accountMonitor.BuildSnapshot(
            m_accountSnapshot))
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_INVALID_ACCOUNT,
            "Unable to read account state"
         );

         return true;
      }

      if(m_accountSnapshot.Equity <= 0.0)
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_INVALID_ACCOUNT,
            "Account equity is invalid"
         );

         return true;
      }

      //------------------------------------------------------------
      // Account drawdown
      //------------------------------------------------------------

      if(m_accountSnapshot.DrawdownPercent >=
         m_maxDrawdownPercent)
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_MAX_DRAWDOWN,
            "Maximum account drawdown reached"
         );

         return true;
      }

      //------------------------------------------------------------
      // Free margin
      //------------------------------------------------------------

      double freeMarginPercent =
         (m_accountSnapshot.FreeMargin /
          m_accountSnapshot.Equity) * 100.0;

      if(freeMarginPercent <
         m_minimumFreeMarginPercent)
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_LOW_FREE_MARGIN,
            "Free margin below minimum threshold"
         );

         return true;
      }

      //------------------------------------------------------------
      // Entry
      //------------------------------------------------------------

      double entryPrice = 0.0;
      ENUM_ORDER_TYPE orderType;

      if(signal.Direction == AQF_SIGNAL_BUY)
      {
         entryPrice = market.Ask;
         orderType  = ORDER_TYPE_BUY;
      }
      else if(signal.Direction == AQF_SIGNAL_SELL)
      {
         entryPrice = market.Bid;
         orderType  = ORDER_TYPE_SELL;
      }
      else
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_INVALID_SIGNAL,
            "Trade signal contains no actionable direction"
         );

         return true;
      }

      if(entryPrice <= 0.0)
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_INVALID_PRICE,
            "Market entry price is invalid"
         );

         return true;
      }

      //------------------------------------------------------------
      // Stop model
      //------------------------------------------------------------

      if(market.ATR <= 0.0)
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_POSITION_SIZING,
            "ATR is invalid for stop calculation"
         );

         return true;
      }

      double stopDistance =
         market.ATR * m_atrStopMultiplier;

      double stopPrice = 0.0;

      if(signal.Direction == AQF_SIGNAL_BUY)
         stopPrice = entryPrice - stopDistance;
      else
         stopPrice = entryPrice + stopDistance;

      decision.StopPrice    = stopPrice;
      decision.StopDistance = stopDistance;

      //------------------------------------------------------------
      // Position sizing
      //------------------------------------------------------------

      double riskMoney        = 0.0;
      double rawVolume        = 0.0;
      double normalizedVolume = 0.0;

      if(!m_positionSizer.Calculate(
            signal.Symbol,
            m_accountSnapshot.Equity,
            entryPrice,
            stopPrice,
            riskMoney,
            rawVolume,
            normalizedVolume))
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_POSITION_SIZING,
            "Unable to calculate safe position size"
         );

         return true;
      }

      decision.RiskPercent =
         m_positionSizer.RiskPercent();

      decision.RiskMoney =
         riskMoney;

      decision.RequestedVolume =
         rawVolume;

      decision.NormalizedVolume =
         normalizedVolume;

//------------------------------------------------------------
// Adaptive Volume Limiting
//------------------------------------------------------------

CAQFVolumeLimitResult volumeLimit;

if(!m_volumeLimiter.Calculate(
      signal.Symbol,
      orderType,
      entryPrice,
      m_accountSnapshot.Equity,
      m_accountSnapshot.FreeMargin,
      normalizedVolume,
      volumeLimit))
{
   Reject(
      decision,
      AQF_RISK_REJECTION_POSITION_SIZING,
      "Adaptive volume limiter execution failed"
   );

   return true;
}

if(!volumeLimit.Valid)
{
   Reject(
      decision,
      AQF_RISK_REJECTION_POSITION_SIZING,
      volumeLimit.Message
   );

   return true;
}

decision.VolumeByRisk =
   volumeLimit.VolumeByRisk;

decision.VolumeByExposure =
   volumeLimit.VolumeByExposure;

decision.VolumeByMargin =
   volumeLimit.VolumeByMargin;

decision.VolumeByBroker =
   volumeLimit.VolumeByBroker;

decision.VolumeLimitStatus =
   AQFVolumeLimitStatusToString(
      volumeLimit.Status
   );

decision.NormalizedVolume =
   volumeLimit.FinalVolume;

normalizedVolume =
   volumeLimit.FinalVolume;

      //------------------------------------------------------------
      // Risk budget guard
      //------------------------------------------------------------

      if(decision.RiskPercent >
         m_capitalLimits.MaxRiskPercentPerTrade())
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_RISK_BUDGET,
            "Risk percentage exceeds capital policy"
         );

         return true;
      }

      //------------------------------------------------------------
      // Legacy exposure limits
      //------------------------------------------------------------

      decision.CurrentSymbolExposure =
         m_exposureMonitor.SymbolVolume(
            signal.Symbol
         );

      string exposureReason = "";

      if(!m_exposureMonitor.CanAdd(
            signal.Symbol,
            normalizedVolume,
            exposureReason))
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_EXPOSURE_LIMIT,
            exposureReason
         );

         return true;
      }

      //------------------------------------------------------------
      // Notional capital exposure
      //------------------------------------------------------------

      decision.CurrentSymbolNotional =
         m_exposureMonitor.ApproxSymbolNotional(
            signal.Symbol,
            entryPrice
         );

      decision.ProposedNotional =
         m_exposureMonitor.ProposedNotional(
            signal.Symbol,
            normalizedVolume,
            entryPrice
         );

      decision.TotalProjectedNotional =
         decision.CurrentSymbolNotional +
         decision.ProposedNotional;

      decision.ProjectedNotionalPercent =
         (decision.TotalProjectedNotional /
          m_accountSnapshot.Equity) * 100.0;

      if(decision.ProjectedNotionalPercent >
         m_capitalLimits.MaxSymbolExposurePercent())
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_CAPITAL_EXPOSURE,
            "Projected symbol notional exposure exceeds policy"
         );

         return true;
      }

      //------------------------------------------------------------
      // Margin estimate
      //------------------------------------------------------------

      double requiredMargin = 0.0;

      ResetLastError();

      if(!OrderCalcMargin(
            orderType,
            signal.Symbol,
            normalizedVolume,
            entryPrice,
            requiredMargin))
      {
         logger.Warning(
            "OrderCalcMargin failed. Error=" +
            IntegerToString(
               GetLastError())
         );

         Reject(
            decision,
            AQF_RISK_REJECTION_MARGIN_REQUIREMENT,
            "Unable to calculate required margin"
         );

         return true;
      }

      decision.EstimatedMargin =
         requiredMargin;

      decision.EstimatedMarginPercent =
         (requiredMargin /
          m_accountSnapshot.Equity) * 100.0;

      //------------------------------------------------------------
      // Margin budget guard
      //------------------------------------------------------------

      if(decision.EstimatedMarginPercent >
         m_capitalLimits.MaxMarginUsePercent())
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_MARGIN_BUDGET,
            "Proposed trade exceeds margin budget"
         );

         return true;
      }

      if(requiredMargin >
         m_accountSnapshot.FreeMargin)
      {
         Reject(
            decision,
            AQF_RISK_REJECTION_MARGIN_REQUIREMENT,
            "Insufficient free margin for proposed volume"
         );

         return true;
      }

      //------------------------------------------------------------
      // Authorized
      //------------------------------------------------------------

      decision.Status =
         AQF_RISK_AUTHORIZED;

      decision.RejectionReason =
         AQF_RISK_REJECTION_NONE;

      decision.Authorized = true;

      decision.Message =
         "Capital and portfolio risk authorization passed";

      if(m_status == AQF_MODULE_READY)
         m_status = AQF_MODULE_RUNNING;

      return true;
   }

   CAQFAccountSnapshot GetAccountSnapshot()
   {
      return m_accountSnapshot;
   }

   virtual void Shutdown()
   {
      m_status = AQF_MODULE_STOPPED;
   }

private:

   void Reject(
      CAQFRiskDecision &decision,
      const ENUM_AQF_RISK_REJECTION_REASON reason,
      const string message)
   {
      decision.Status =
         AQF_RISK_REJECTED;

      decision.RejectionReason =
         reason;

      decision.Authorized = false;

      decision.Message =
         message;
   }
};

#endif