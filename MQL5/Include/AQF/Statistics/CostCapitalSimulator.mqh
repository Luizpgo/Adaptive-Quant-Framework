#ifndef __AQF_COST_CAPITAL_SIMULATOR_MQH__
#define __AQF_COST_CAPITAL_SIMULATOR_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"

#define AQF_COST_SCENARIO_COUNT 3

//+------------------------------------------------------------------+
//| Cost & Capital Simulator                                         |
//|                                                                  |
//| Sprint 8 - Package B                                             |
//|                                                                  |
//| Frozen trading policy:                                           |
//| TP = 1.50R                                                       |
//| ATRPercent >= 0.075                                              |
//| ADX >= 25 and ADX < 40                                           |
//| ONE active virtual position per scenario                         |
//|                                                                  |
//| Three cost-sensitivity profiles are simulated in parallel:       |
//|                                                                  |
//| NATIVE                                                           |
//|   Native Bid/Ask spread only.                                    |
//|   No extra commission/slippage assumption.                       |
//|                                                                  |
//| BASE_COST                                                        |
//|   Commission = 7.00 account-currency units / lot round turn      |
//|   Slippage   = 3 points per side                                 |
//|                                                                  |
//| STRESS_COST                                                      |
//|   Commission = 10.00 account-currency units / lot round turn     |
//|   Slippage   = 8 points per side                                 |
//|   Extra spread stress = 5 points round turn                      |
//|                                                                  |
//| IMPORTANT                                                        |
//| These are sensitivity assumptions, NOT broker-specific claims.   |
//| Native Bid/Ask spread is already represented by AQF entry/exit.  |
//|                                                                  |
//| NO OrderSend exists in this class.                               |
//+------------------------------------------------------------------+

struct SAQFCostCapitalPosition
{
   bool Active;

   string Symbol;

   ENUM_AQF_SIGNAL_DIRECTION Direction;

   double EntryPrice;
   double StopLoss;
   double StopDistance;
   double TakeProfit;

   double Volume;
   double RiskMoney;
   double RiskPercentActual;

   datetime EntryTime;

   ENUM_TIMEFRAMES Timeframe;
};

class CAQFCostCapitalSimulator
{
private:

   //---------------------------------------------------------------
   // Frozen policy
   //---------------------------------------------------------------

   double m_targetR;
   double m_riskPercent;

   double m_minATRPercent;
   double m_minADX;
   double m_maxADX;

   //---------------------------------------------------------------
   // Capital-protection caps mirrored from AQF risk architecture
   //---------------------------------------------------------------

   double m_maxNotionalPercent;
   double m_maxMarginPercent;

   //---------------------------------------------------------------
   // Cost scenarios
   //---------------------------------------------------------------

   double m_commissionPerLotRoundTurn[AQF_COST_SCENARIO_COUNT];
   double m_slippagePointsPerSide[AQF_COST_SCENARIO_COUNT];
   double m_extraSpreadPointsRoundTurn[AQF_COST_SCENARIO_COUNT];

   //---------------------------------------------------------------
   // Virtual accounts
   //---------------------------------------------------------------

   double m_startingBalance[AQF_COST_SCENARIO_COUNT];
   double m_balance[AQF_COST_SCENARIO_COUNT];

   double m_peakBalance[AQF_COST_SCENARIO_COUNT];
   double m_maxBalanceDrawdownMoney[AQF_COST_SCENARIO_COUNT];
   double m_maxBalanceDrawdownPercent[AQF_COST_SCENARIO_COUNT];

   double m_peakEquity[AQF_COST_SCENARIO_COUNT];
   double m_maxEquityDrawdownMoney[AQF_COST_SCENARIO_COUNT];
   double m_maxEquityDrawdownPercent[AQF_COST_SCENARIO_COUNT];

   //---------------------------------------------------------------
   // Active position per scenario
   //---------------------------------------------------------------

   SAQFCostCapitalPosition m_position[AQF_COST_SCENARIO_COUNT];

   //---------------------------------------------------------------
   // Opportunity statistics
   //---------------------------------------------------------------

   long m_signalsSeen[AQF_COST_SCENARIO_COUNT];
   long m_filterRejected[AQF_COST_SCENARIO_COUNT];
   long m_eligible[AQF_COST_SCENARIO_COUNT];
   long m_opened[AQF_COST_SCENARIO_COUNT];
   long m_skippedActive[AQF_COST_SCENARIO_COUNT];
   long m_sizingRejected[AQF_COST_SCENARIO_COUNT];

   //---------------------------------------------------------------
   // Outcome statistics
   //---------------------------------------------------------------

   long m_targetHits[AQF_COST_SCENARIO_COUNT];
   long m_stopHits[AQF_COST_SCENARIO_COUNT];

   long m_netWins[AQF_COST_SCENARIO_COUNT];
   long m_netLosses[AQF_COST_SCENARIO_COUNT];

   long m_currentLosingStreak[AQF_COST_SCENARIO_COUNT];
   long m_maxLosingStreak[AQF_COST_SCENARIO_COUNT];

   //---------------------------------------------------------------
   // P&L statistics
   //---------------------------------------------------------------

   double m_grossProfitMoney[AQF_COST_SCENARIO_COUNT];
   double m_grossLossMoney[AQF_COST_SCENARIO_COUNT];

   double m_netProfitMoney[AQF_COST_SCENARIO_COUNT];
   double m_netLossMoney[AQF_COST_SCENARIO_COUNT];

   double m_totalCommissionMoney[AQF_COST_SCENARIO_COUNT];
   double m_totalSlippageMoney[AQF_COST_SCENARIO_COUNT];
   double m_totalExtraSpreadMoney[AQF_COST_SCENARIO_COUNT];

   double m_totalNetR[AQF_COST_SCENARIO_COUNT];
   double m_totalCostR[AQF_COST_SCENARIO_COUNT];

   double m_totalVolume[AQF_COST_SCENARIO_COUNT];
   double m_totalActualRiskPercent[AQF_COST_SCENARIO_COUNT];
   double m_totalBars[AQF_COST_SCENARIO_COUNT];

   bool m_initialized;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFCostCapitalSimulator()
   {
      m_initialized =
         false;

      //------------------------------------------------------------
      // Frozen H2 policy
      //------------------------------------------------------------

      m_targetR =
         1.50;

      m_riskPercent =
         0.50;

      m_minATRPercent =
         0.075;

      m_minADX =
         25.0;

      m_maxADX =
         40.0;

      //------------------------------------------------------------
      // Same capital caps currently used by AQF
      //------------------------------------------------------------

      m_maxNotionalPercent =
         150.0;

      m_maxMarginPercent =
         20.0;

      //------------------------------------------------------------
      // Scenario 0: Native Bid/Ask only
      //------------------------------------------------------------

      m_commissionPerLotRoundTurn[0] =
         0.0;

      m_slippagePointsPerSide[0] =
         0.0;

      m_extraSpreadPointsRoundTurn[0] =
         0.0;

      //------------------------------------------------------------
      // Scenario 1: Base sensitivity assumption
      //------------------------------------------------------------

      m_commissionPerLotRoundTurn[1] =
         7.0;

      m_slippagePointsPerSide[1] =
         3.0;

      m_extraSpreadPointsRoundTurn[1] =
         0.0;

      //------------------------------------------------------------
      // Scenario 2: Stress sensitivity assumption
      //------------------------------------------------------------

      m_commissionPerLotRoundTurn[2] =
         10.0;

      m_slippagePointsPerSide[2] =
         8.0;

      m_extraSpreadPointsRoundTurn[2] =
         5.0;

      for(int i = 0;
          i < AQF_COST_SCENARIO_COUNT;
          i++)
      {
         m_startingBalance[i] =
            100000.0;

         ResetPosition(
            i
         );

         ResetStatistics(
            i
         );
      }
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(
      CAQFLogger &logger)
   {
      for(int i = 0;
          i < AQF_COST_SCENARIO_COUNT;
          i++)
      {
         ResetPosition(
            i
         );

         ResetStatistics(
            i
         );
      }

      m_initialized =
         true;

      logger.Info(
         "CostCapitalSimulator initialized."
      );

      logger.Info(
         "CostCapital frozen policy: TP=1.50R | ATRPercent>=0.075 | ADX>=25 | ADX<40 | Risk=0.50%"
      );

      logger.Info(
         "CostCapital NATIVE: Bid/Ask native spread only | Commission=0 | Slippage=0"
      );

      logger.Info(
         "CostCapital BASE_COST: Commission=7.00/lot RT | Slippage=3 points/side"
      );

      logger.Info(
         "CostCapital STRESS_COST: Commission=10.00/lot RT | Slippage=8 points/side | ExtraSpread=5 points RT"
      );

      logger.Info(
         "Cost assumptions are sensitivity scenarios, not broker-specific claims."
      );

      logger.Info(
         "CostCapital barrier fills: TARGET=exact TP | STOP=exact SL | adverse costs applied separately"
      );

      logger.Info(
         "CostCapitalSimulator mode: VIRTUAL CAPITAL ONLY - NO ORDER EXECUTION"
      );

      return true;
   }

   //==============================================================
   // Register Opportunity
   //==============================================================
   bool Register(
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return false;

      if(!request.Valid ||
         !market.Valid ||
         request.Symbol == "" ||
         market.Symbol != request.Symbol ||
         request.EntryPrice <= 0.0 ||
         request.StopLoss <= 0.0 ||
         request.StopDistance <= 0.0)
      {
         return false;
      }

      if(request.Direction != AQF_SIGNAL_BUY &&
         request.Direction != AQF_SIGNAL_SELL)
      {
         return false;
      }

      for(int scenario = 0;
          scenario < AQF_COST_SCENARIO_COUNT;
          scenario++)
      {
         m_signalsSeen[scenario]++;

         //---------------------------------------------------------
         // Frozen H2 filter
         //---------------------------------------------------------

         if(!PolicyAccepts(
               market))
         {
            m_filterRejected[scenario]++;
            continue;
         }

         m_eligible[scenario]++;

         //---------------------------------------------------------
         // One active position per cost scenario
         //---------------------------------------------------------

         if(m_position[scenario].Active)
         {
            m_skippedActive[scenario]++;
            continue;
         }

         //---------------------------------------------------------
         // Virtual capital position sizing
         //---------------------------------------------------------

         double volume =
            0.0;

         double actualRiskMoney =
            0.0;

         double actualRiskPercent =
            0.0;

         if(!CalculatePositionSize(
               request,
               scenario,
               volume,
               actualRiskMoney,
               actualRiskPercent))
         {
            m_sizingRejected[scenario]++;
            continue;
         }

         OpenPosition(
            scenario,
            request,
            market,
            volume,
            actualRiskMoney,
            actualRiskPercent
         );

         m_opened[scenario]++;

         m_totalVolume[scenario] +=
            volume;

         m_totalActualRiskPercent[scenario] +=
            actualRiskPercent;

         logger.Debug(
            "CapitalOpen" +
            " | Scenario=" +
            ScenarioName(
               scenario) +
            " | " +
            request.Symbol +
            " | Direction=" +
            AQFSignalDirectionToString(
               request.Direction) +
            " | Balance=" +
            DoubleToString(
               m_balance[scenario],
               2) +
            " | Volume=" +
            DoubleToString(
               volume,
               2) +
            " | RiskMoney=" +
            DoubleToString(
               actualRiskMoney,
               2) +
            " | Risk%=" +
            DoubleToString(
               actualRiskPercent,
               3) +
            " | ADX=" +
            DoubleToString(
               market.ADX,
               2) +
            " | ATR%=" +
            DoubleToString(
               market.ATRPercent,
               4)
         );
      }

      return true;
   }

   //==============================================================
   // Update
   //
   // Active virtual capital positions are marked-to-market on every
   // tick. Equity drawdown therefore includes floating P&L.
   //==============================================================
   void Update(
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return;

      if(!market.Valid ||
         market.Bid <= 0.0 ||
         market.Ask <= 0.0)
      {
         return;
      }

      for(int scenario = 0;
          scenario < AQF_COST_SCENARIO_COUNT;
          scenario++)
      {
         //---------------------------------------------------------
         // No active trade -> equity equals balance
         //---------------------------------------------------------

         if(!m_position[scenario].Active)
         {
            UpdateEquityDrawdown(
               scenario,
               m_balance[scenario]
            );

            continue;
         }

         if(m_position[scenario].Symbol !=
            market.Symbol)
         {
            continue;
         }

         double exitPrice =
            CurrentExitPrice(
               scenario,
               market
            );

         if(exitPrice <= 0.0)
            continue;

         //---------------------------------------------------------
         // Floating equity
         //---------------------------------------------------------

         double floatingGross =
            0.0;

         if(CalculateGrossProfit(
               scenario,
               exitPrice,
               floatingGross))
         {
            double estimatedCosts =
               EstimateTotalCosts(
                  scenario
               );

            double floatingEquity =
               m_balance[scenario] +
               floatingGross -
               estimatedCosts;

            UpdateEquityDrawdown(
               scenario,
               floatingEquity
            );
         }

         //---------------------------------------------------------
         // TP / SL resolution
         //---------------------------------------------------------

         bool targetReached =
            false;

         bool stopReached =
            false;

         if(m_position[scenario].Direction ==
            AQF_SIGNAL_BUY)
         {
            targetReached =
               (
                  market.Bid >=
                  m_position[scenario].TakeProfit
               );

            stopReached =
               (
                  market.Bid <=
                  m_position[scenario].StopLoss
               );
         }
         else
         {
            targetReached =
               (
                  market.Ask <=
                  m_position[scenario].TakeProfit
               );

            stopReached =
               (
                  market.Ask >=
                  m_position[scenario].StopLoss
               );
         }

         int barsElapsed =
            CalculateBarsElapsed(
               scenario,
               market.Time
            );

         if(targetReached)
         {
            Resolve(
               scenario,
               true,
               exitPrice,
               barsElapsed,
               logger
            );

            continue;
         }

         if(stopReached)
         {
            Resolve(
               scenario,
               false,
               exitPrice,
               barsElapsed,
               logger
            );

            continue;
         }
      }
   }

   //==============================================================
   // Report
   //==============================================================
   void ReportAll(
      CAQFLogger &logger)
   {
      logger.Info(
         "CapitalStats ==========================================="
      );

      for(int scenario = 0;
          scenario < AQF_COST_SCENARIO_COUNT;
          scenario++)
      {
         long resolved =
            m_netWins[scenario] +
            m_netLosses[scenario];

         double winRate =
            0.0;

         double expectancyR =
            0.0;

         double returnPercent =
            (
               (
                  m_balance[scenario] -
                  m_startingBalance[scenario]
               )
               /
               m_startingBalance[scenario]
            ) * 100.0;

         double avgVolume =
            0.0;

         double avgActualRiskPercent =
            0.0;

         double avgCostR =
            0.0;

         double avgBars =
            0.0;

         if(resolved > 0)
         {
            winRate =
               (
                  (double)m_netWins[scenario] /
                  (double)resolved
               ) * 100.0;

            expectancyR =
               m_totalNetR[scenario] /
               (double)resolved;

            avgCostR =
               m_totalCostR[scenario] /
               (double)resolved;

            avgBars =
               m_totalBars[scenario] /
               (double)resolved;
         }

         if(m_opened[scenario] > 0)
         {
            avgVolume =
               m_totalVolume[scenario] /
               (double)m_opened[scenario];

            avgActualRiskPercent =
               m_totalActualRiskPercent[scenario] /
               (double)m_opened[scenario];
         }

         logger.Info(
            "CapitalStats" +
            " | Scenario=" +
            ScenarioName(
               scenario) +
            " | Start=" +
            DoubleToString(
               m_startingBalance[scenario],
               2) +
            " | Balance=" +
            DoubleToString(
               m_balance[scenario],
               2) +
            " | Return=" +
            DoubleToString(
               returnPercent,
               2) +
            "%" +
            " | Signals=" +
            IntegerToString(
               (int)m_signalsSeen[scenario]) +
            " | FilterRejected=" +
            IntegerToString(
               (int)m_filterRejected[scenario]) +
            " | Eligible=" +
            IntegerToString(
               (int)m_eligible[scenario]) +
            " | Opened=" +
            IntegerToString(
               (int)m_opened[scenario]) +
            " | SkippedActive=" +
            IntegerToString(
               (int)m_skippedActive[scenario]) +
            " | SizingRejected=" +
            IntegerToString(
               (int)m_sizingRejected[scenario]) +
            " | Resolved=" +
            IntegerToString(
               (int)resolved) +
            " | TargetHits=" +
            IntegerToString(
               (int)m_targetHits[scenario]) +
            " | StopHits=" +
            IntegerToString(
               (int)m_stopHits[scenario]) +
            " | NetWins=" +
            IntegerToString(
               (int)m_netWins[scenario]) +
            " | NetLosses=" +
            IntegerToString(
               (int)m_netLosses[scenario]) +
            " | Open=" +
            (
               m_position[scenario].Active
               ? "1"
               : "0"
            ) +
            " | WinRate=" +
            DoubleToString(
               winRate,
               2) +
            "%" +
            " | Expectancy=" +
            DoubleToString(
               expectancyR,
               3) +
            "R" +
            " | NetPF=" +
            NetProfitFactorText(
               scenario) +
            " | AvgVol=" +
            DoubleToString(
               avgVolume,
               2) +
            " | AvgRisk%=" +
            DoubleToString(
               avgActualRiskPercent,
               3) +
            " | AvgCost=" +
            DoubleToString(
               avgCostR,
               3) +
            "R" +
            " | TotalCost=" +
            DoubleToString(
               TotalCostMoney(
                  scenario),
               2) +
            " | MaxBalDD=" +
            DoubleToString(
               m_maxBalanceDrawdownMoney[scenario],
               2) +
            " (" +
            DoubleToString(
               m_maxBalanceDrawdownPercent[scenario],
               2) +
            "%)" +
            " | MaxEqDD=" +
            DoubleToString(
               m_maxEquityDrawdownMoney[scenario],
               2) +
            " (" +
            DoubleToString(
               m_maxEquityDrawdownPercent[scenario],
               2) +
            "%)" +
            " | MaxLossStreak=" +
            IntegerToString(
               (int)m_maxLosingStreak[scenario]) +
            " | AvgBars=" +
            DoubleToString(
               avgBars,
               1)
         );
      }

      logger.Info(
         "CapitalStats ==========================================="
      );
   }

   //==============================================================
   // Shutdown
   //==============================================================
   void Shutdown(
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return;

      ReportAll(
         logger
      );

      m_initialized =
         false;
   }

private:

   //==============================================================
   // H2 frozen policy
   //==============================================================
   bool PolicyAccepts(
      const CAQFMarketSnapshot &market)
   {
      return
         (
            market.ATRPercent >=
            m_minATRPercent
            &&
            market.ADX >=
            m_minADX
            &&
            market.ADX <
            m_maxADX
         );
   }

   //==============================================================
   // Position Sizing
   //==============================================================
   bool CalculatePositionSize(
      const CAQFTradeRequest &request,
      const int scenario,
      double &volume,
      double &actualRiskMoney,
      double &actualRiskPercent)
   {
      volume =
         0.0;

      actualRiskMoney =
         0.0;

      actualRiskPercent =
         0.0;

      if(scenario < 0 ||
         scenario >= AQF_COST_SCENARIO_COUNT)
      {
         return false;
      }

      if(m_balance[scenario] <= 0.0)
         return false;

      ENUM_ORDER_TYPE orderType =
         ORDER_TYPE_BUY;

      if(request.Direction ==
         AQF_SIGNAL_SELL)
      {
         orderType =
            ORDER_TYPE_SELL;
      }

      //------------------------------------------------------------
      // Risk budget from virtual balance
      //------------------------------------------------------------

      double riskBudget =
         m_balance[scenario] *
         (
            m_riskPercent /
            100.0
         );

      if(riskBudget <= 0.0)
         return false;

      //------------------------------------------------------------
      // Loss per 1 lot at original SL
      //------------------------------------------------------------

      double oneLotStopProfit =
         0.0;

      if(!OrderCalcProfit(
            orderType,
            request.Symbol,
            1.0,
            request.EntryPrice,
            request.StopLoss,
            oneLotStopProfit))
      {
         return false;
      }

      double riskPerLot =
         MathAbs(
            oneLotStopProfit
         );

      if(riskPerLot <= 0.0)
         return false;

      double volumeByRisk =
         riskBudget /
         riskPerLot;

      //------------------------------------------------------------
      // Broker volume cap
      //------------------------------------------------------------

      double brokerMax =
         SymbolInfoDouble(
            request.Symbol,
            SYMBOL_VOLUME_MAX
         );

      if(brokerMax <= 0.0)
         return false;

      //------------------------------------------------------------
      // Notional cap
      //
      // Mirrors current AQF 150% notional protection.
      //------------------------------------------------------------

      double volumeByExposure =
         brokerMax;

      double contractSize =
         SymbolInfoDouble(
            request.Symbol,
            SYMBOL_TRADE_CONTRACT_SIZE
         );

      if(contractSize > 0.0 &&
         request.EntryPrice > 0.0)
      {
         double maxNotionalMoney =
            m_balance[scenario] *
            (
               m_maxNotionalPercent /
               100.0
            );

         double notionalPerLot =
            contractSize *
            request.EntryPrice;

         if(notionalPerLot > 0.0)
         {
            volumeByExposure =
               maxNotionalMoney /
               notionalPerLot;
         }
      }

      //------------------------------------------------------------
      // Margin cap
      //
      // Mirrors current AQF 20% maximum margin-use protection.
      //------------------------------------------------------------

      double volumeByMargin =
         brokerMax;

      double marginOneLot =
         0.0;

      if(OrderCalcMargin(
            orderType,
            request.Symbol,
            1.0,
            request.EntryPrice,
            marginOneLot))
      {
         if(marginOneLot > 0.0)
         {
            double maxMarginMoney =
               m_balance[scenario] *
               (
                  m_maxMarginPercent /
                  100.0
               );

            volumeByMargin =
               maxMarginMoney /
               marginOneLot;
         }
      }

      //------------------------------------------------------------
      // Final raw volume = minimum candidate
      //------------------------------------------------------------

      double rawVolume =
         volumeByRisk;

      if(volumeByExposure <
         rawVolume)
      {
         rawVolume =
            volumeByExposure;
      }

      if(volumeByMargin <
         rawVolume)
      {
         rawVolume =
            volumeByMargin;
      }

      if(brokerMax <
         rawVolume)
      {
         rawVolume =
            brokerMax;
      }

      volume =
         NormalizeVolumeDown(
            request.Symbol,
            rawVolume
         );

      if(volume <= 0.0)
         return false;

      //------------------------------------------------------------
      // Actual risk after broker/capital normalization
      //------------------------------------------------------------

      double actualStopProfit =
         0.0;

      if(!OrderCalcProfit(
            orderType,
            request.Symbol,
            volume,
            request.EntryPrice,
            request.StopLoss,
            actualStopProfit))
      {
         return false;
      }

      actualRiskMoney =
         MathAbs(
            actualStopProfit
         );

      if(actualRiskMoney <= 0.0)
         return false;

      actualRiskPercent =
         (
            actualRiskMoney /
            m_balance[scenario]
         ) * 100.0;

      return true;
   }

   //==============================================================
   // Normalize volume down to broker step
   //==============================================================
   double NormalizeVolumeDown(
      const string symbol,
      const double rawVolume)
   {
      double minVolume =
         SymbolInfoDouble(
            symbol,
            SYMBOL_VOLUME_MIN
         );

      double maxVolume =
         SymbolInfoDouble(
            symbol,
            SYMBOL_VOLUME_MAX
         );

      double step =
         SymbolInfoDouble(
            symbol,
            SYMBOL_VOLUME_STEP
         );

      if(minVolume <= 0.0 ||
         maxVolume <= 0.0 ||
         step <= 0.0)
      {
         return 0.0;
      }

      double capped =
         rawVolume;

      if(capped >
         maxVolume)
      {
         capped =
            maxVolume;
      }

      if(capped <
         minVolume)
      {
         return 0.0;
      }

      double steps =
         MathFloor(
            (
               capped -
               minVolume
            )
            /
            step
            +
            1e-9
         );

      double normalized =
         minVolume +
         steps *
         step;

      if(normalized >
         maxVolume)
      {
         normalized =
            maxVolume;
      }

      if(normalized <
         minVolume)
      {
         return 0.0;
      }

      return
         NormalizeDouble(
            normalized,
            VolumeDigits(
               step)
         );
   }

   //==============================================================
   // Volume digits
   //==============================================================
   int VolumeDigits(
      const double step)
   {
      if(step >= 1.0)
         return 0;

      if(step >= 0.1)
         return 1;

      if(step >= 0.01)
         return 2;

      if(step >= 0.001)
         return 3;

      return 4;
   }

   //==============================================================
   // Open Position
   //==============================================================
   void OpenPosition(
      const int scenario,
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market,
      const double volume,
      const double riskMoney,
      const double actualRiskPercent)
   {
      ResetPosition(
         scenario
      );

      m_position[scenario].Active =
         true;

      m_position[scenario].Symbol =
         request.Symbol;

      m_position[scenario].Direction =
         request.Direction;

      m_position[scenario].EntryPrice =
         request.EntryPrice;

      m_position[scenario].StopLoss =
         request.StopLoss;

      m_position[scenario].StopDistance =
         request.StopDistance;

      m_position[scenario].Volume =
         volume;

      m_position[scenario].RiskMoney =
         riskMoney;

      m_position[scenario].RiskPercentActual =
         actualRiskPercent;

      m_position[scenario].EntryTime =
         request.SignalTime;

      m_position[scenario].Timeframe =
         market.Timeframe;

      double targetDistance =
         request.StopDistance *
         m_targetR;

      if(request.Direction ==
         AQF_SIGNAL_BUY)
      {
         m_position[scenario].TakeProfit =
            request.EntryPrice +
            targetDistance;
      }
      else
      {
         m_position[scenario].TakeProfit =
            request.EntryPrice -
            targetDistance;
      }
   }

   //==============================================================
   // Resolve
   //==============================================================
   void Resolve(
      const int scenario,
      const bool targetHit,
      const double exitPrice,
      const int barsElapsed,
      CAQFLogger &logger)
   {
      if(scenario < 0 ||
         scenario >= AQF_COST_SCENARIO_COUNT)
      {
         return;
      }

      //------------------------------------------------------------
      // Barrier execution model
      //
      // IMPORTANT:
      // The tick that DETECTS a TP/SL crossing can be beyond the
      // barrier. Using that tick price would artificially change the
      // intended +1.50R / -1.00R payoff and can create optimistic TP
      // overshoot. For the base virtual execution model:
      //
      //   TARGET -> fill at exact TakeProfit
      //   STOP   -> fill at exact StopLoss
      //
      // Adverse commission/slippage/spread sensitivity is then
      // applied separately below.
      //------------------------------------------------------------

      double modeledExitPrice =
         (
            targetHit
            ? m_position[scenario].TakeProfit
            : m_position[scenario].StopLoss
         );

      double grossProfit =
         0.0;

      if(!CalculateGrossProfit(
            scenario,
            modeledExitPrice,
            grossProfit))
      {
         ResetPosition(
            scenario
         );

         return;
      }

      double commission =
         CommissionMoney(
            scenario
         );

      double slippage =
         SlippageMoney(
            scenario
         );

      double extraSpread =
         ExtraSpreadMoney(
            scenario
         );

      double totalCost =
         commission +
         slippage +
         extraSpread;

      double netProfit =
         grossProfit -
         totalCost;

      double netR =
         0.0;

      double costR =
         0.0;

      if(m_position[scenario].RiskMoney >
         0.0)
      {
         netR =
            netProfit /
            m_position[scenario].RiskMoney;

         costR =
            totalCost /
            m_position[scenario].RiskMoney;
      }

      //------------------------------------------------------------
      // Gross outcome
      //------------------------------------------------------------

      if(targetHit)
         m_targetHits[scenario]++;
      else
         m_stopHits[scenario]++;

      //------------------------------------------------------------
      // Gross money statistics
      //------------------------------------------------------------

      if(grossProfit >= 0.0)
         m_grossProfitMoney[scenario] += grossProfit;
      else
         m_grossLossMoney[scenario] += MathAbs(grossProfit);

      //------------------------------------------------------------
      // Net money statistics and losing streak
      //------------------------------------------------------------

      if(netProfit > 0.0)
      {
         m_netWins[scenario]++;

         m_netProfitMoney[scenario] +=
            netProfit;

         m_currentLosingStreak[scenario] =
            0;
      }
      else
      {
         m_netLosses[scenario]++;

         m_netLossMoney[scenario] +=
            MathAbs(
               netProfit
            );

         m_currentLosingStreak[scenario]++;

         if(m_currentLosingStreak[scenario] >
            m_maxLosingStreak[scenario])
         {
            m_maxLosingStreak[scenario] =
               m_currentLosingStreak[scenario];
         }
      }

      //------------------------------------------------------------
      // Costs
      //------------------------------------------------------------

      m_totalCommissionMoney[scenario] +=
         commission;

      m_totalSlippageMoney[scenario] +=
         slippage;

      m_totalExtraSpreadMoney[scenario] +=
         extraSpread;

      m_totalNetR[scenario] +=
         netR;

      m_totalCostR[scenario] +=
         costR;

      m_totalBars[scenario] +=
         (double)barsElapsed;

      //------------------------------------------------------------
      // Compound virtual capital
      //------------------------------------------------------------

      m_balance[scenario] +=
         netProfit;

      UpdateBalanceDrawdown(
         scenario
      );

      UpdateEquityDrawdown(
         scenario,
         m_balance[scenario]
      );

      logger.Debug(
         "CapitalClose" +
         " | Scenario=" +
         ScenarioName(
            scenario) +
         " | Result=" +
         (
            targetHit
            ? "TARGET"
            : "STOP"
         ) +
         " | Gross=" +
         DoubleToString(
            grossProfit,
            2) +
         " | Cost=" +
         DoubleToString(
            totalCost,
            2) +
         " | Net=" +
         DoubleToString(
            netProfit,
            2) +
         " | NetR=" +
         DoubleToString(
            netR,
            3) +
         "R" +
         " | Balance=" +
         DoubleToString(
            m_balance[scenario],
            2) +
         " | ModeledExit=" +
         DoubleToString(
            modeledExitPrice,
            (int)SymbolInfoInteger(
               m_position[scenario].Symbol,
               SYMBOL_DIGITS)) +
         " | CrossTick=" +
         DoubleToString(
            exitPrice,
            (int)SymbolInfoInteger(
               m_position[scenario].Symbol,
               SYMBOL_DIGITS)) +
         " | Bars=" +
         IntegerToString(
            barsElapsed)
      );

      ResetPosition(
         scenario
      );
   }

   //==============================================================
   // Gross profit helper
   //==============================================================
   bool CalculateGrossProfit(
      const int scenario,
      const double exitPrice,
      double &profit)
   {
      profit =
         0.0;

      if(scenario < 0 ||
         scenario >= AQF_COST_SCENARIO_COUNT)
      {
         return false;
      }

      if(!m_position[scenario].Active ||
         exitPrice <= 0.0)
      {
         return false;
      }

      ENUM_ORDER_TYPE orderType =
         ORDER_TYPE_BUY;

      if(m_position[scenario].Direction ==
         AQF_SIGNAL_SELL)
      {
         orderType =
            ORDER_TYPE_SELL;
      }

      return
         OrderCalcProfit(
            orderType,
            m_position[scenario].Symbol,
            m_position[scenario].Volume,
            m_position[scenario].EntryPrice,
            exitPrice,
            profit
         );
   }

   //==============================================================
   // Current closing side
   //==============================================================
   double CurrentExitPrice(
      const int scenario,
      const CAQFMarketSnapshot &market)
   {
      if(m_position[scenario].Direction ==
         AQF_SIGNAL_BUY)
      {
         return market.Bid;
      }

      if(m_position[scenario].Direction ==
         AQF_SIGNAL_SELL)
      {
         return market.Ask;
      }

      return 0.0;
   }

   //==============================================================
   // Costs
   //==============================================================
   double CommissionMoney(
      const int scenario)
   {
      return
         m_commissionPerLotRoundTurn[scenario] *
         m_position[scenario].Volume;
   }

   double SlippageMoney(
      const int scenario)
   {
      double pointsRoundTurn =
         m_slippagePointsPerSide[scenario] *
         2.0;

      return
         PricePointsCostMoney(
            scenario,
            pointsRoundTurn
         );
   }

   double ExtraSpreadMoney(
      const int scenario)
   {
      return
         PricePointsCostMoney(
            scenario,
            m_extraSpreadPointsRoundTurn[scenario]
         );
   }

   double EstimateTotalCosts(
      const int scenario)
   {
      return
         CommissionMoney(
            scenario) +
         SlippageMoney(
            scenario) +
         ExtraSpreadMoney(
            scenario);
   }

   double PricePointsCostMoney(
      const int scenario,
      const double points)
   {
      if(points <= 0.0)
         return 0.0;

      string symbol =
         m_position[scenario].Symbol;

      double point =
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT
         );

      double tickSize =
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_TICK_SIZE
         );

      double tickValue =
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_TICK_VALUE
         );

      if(tickValue <= 0.0)
      {
         tickValue =
            SymbolInfoDouble(
               symbol,
               SYMBOL_TRADE_TICK_VALUE_LOSS
            );
      }

      if(point <= 0.0 ||
         tickSize <= 0.0 ||
         tickValue <= 0.0)
      {
         return 0.0;
      }

      double priceDistance =
         points *
         point;

      double ticks =
         priceDistance /
         tickSize;

      return
         MathAbs(
            ticks *
            tickValue *
            m_position[scenario].Volume
         );
   }

   double TotalCostMoney(
      const int scenario)
   {
      return
         m_totalCommissionMoney[scenario] +
         m_totalSlippageMoney[scenario] +
         m_totalExtraSpreadMoney[scenario];
   }

   //==============================================================
   // Drawdown
   //==============================================================
   void UpdateBalanceDrawdown(
      const int scenario)
   {
      if(m_balance[scenario] >
         m_peakBalance[scenario])
      {
         m_peakBalance[scenario] =
            m_balance[scenario];
      }

      double drawdownMoney =
         m_peakBalance[scenario] -
         m_balance[scenario];

      if(drawdownMoney >
         m_maxBalanceDrawdownMoney[scenario])
      {
         m_maxBalanceDrawdownMoney[scenario] =
            drawdownMoney;
      }

      if(m_peakBalance[scenario] >
         0.0)
      {
         double drawdownPercent =
            (
               drawdownMoney /
               m_peakBalance[scenario]
            ) * 100.0;

         if(drawdownPercent >
            m_maxBalanceDrawdownPercent[scenario])
         {
            m_maxBalanceDrawdownPercent[scenario] =
               drawdownPercent;
         }
      }
   }

   void UpdateEquityDrawdown(
      const int scenario,
      const double equity)
   {
      if(equity >
         m_peakEquity[scenario])
      {
         m_peakEquity[scenario] =
            equity;
      }

      double drawdownMoney =
         m_peakEquity[scenario] -
         equity;

      if(drawdownMoney >
         m_maxEquityDrawdownMoney[scenario])
      {
         m_maxEquityDrawdownMoney[scenario] =
            drawdownMoney;
      }

      if(m_peakEquity[scenario] >
         0.0)
      {
         double drawdownPercent =
            (
               drawdownMoney /
               m_peakEquity[scenario]
            ) * 100.0;

         if(drawdownPercent >
            m_maxEquityDrawdownPercent[scenario])
         {
            m_maxEquityDrawdownPercent[scenario] =
               drawdownPercent;
         }
      }
   }

   //==============================================================
   // Bars
   //==============================================================
   int CalculateBarsElapsed(
      const int scenario,
      const datetime currentTime)
   {
      int secondsPerBar =
         PeriodSeconds(
            m_position[scenario].Timeframe
         );

      if(secondsPerBar <= 0)
         return 0;

      long secondsElapsed =
         (long)(
            currentTime -
            m_position[scenario].EntryTime
         );

      if(secondsElapsed <= 0)
         return 0;

      return
         (int)(
            secondsElapsed /
            secondsPerBar
         );
   }

   //==============================================================
   // Profit Factor
   //==============================================================
   string NetProfitFactorText(
      const int scenario)
   {
      if(m_netLossMoney[scenario] <= 0.0)
      {
         if(m_netProfitMoney[scenario] > 0.0)
            return "INF";

         return "0.000";
      }

      return
         DoubleToString(
            m_netProfitMoney[scenario] /
            m_netLossMoney[scenario],
            3
         );
   }

   //==============================================================
   // Names
   //==============================================================
   string ScenarioName(
      const int scenario)
   {
      if(scenario == 0)
         return "NATIVE";

      if(scenario == 1)
         return "BASE_COST";

      if(scenario == 2)
         return "STRESS_COST";

      return "UNKNOWN";
   }

   //==============================================================
   // Reset Position
   //==============================================================
   void ResetPosition(
      const int scenario)
   {
      if(scenario < 0 ||
         scenario >= AQF_COST_SCENARIO_COUNT)
      {
         return;
      }

      m_position[scenario].Active =
         false;

      m_position[scenario].Symbol =
         "";

      m_position[scenario].Direction =
         AQF_SIGNAL_NONE;

      m_position[scenario].EntryPrice =
         0.0;

      m_position[scenario].StopLoss =
         0.0;

      m_position[scenario].StopDistance =
         0.0;

      m_position[scenario].TakeProfit =
         0.0;

      m_position[scenario].Volume =
         0.0;

      m_position[scenario].RiskMoney =
         0.0;

      m_position[scenario].RiskPercentActual =
         0.0;

      m_position[scenario].EntryTime =
         0;

      m_position[scenario].Timeframe =
         PERIOD_CURRENT;
   }

   //==============================================================
   // Reset Statistics
   //==============================================================
   void ResetStatistics(
      const int scenario)
   {
      if(scenario < 0 ||
         scenario >= AQF_COST_SCENARIO_COUNT)
      {
         return;
      }

      m_balance[scenario] =
         m_startingBalance[scenario];

      m_peakBalance[scenario] =
         m_startingBalance[scenario];

      m_maxBalanceDrawdownMoney[scenario] =
         0.0;

      m_maxBalanceDrawdownPercent[scenario] =
         0.0;

      m_peakEquity[scenario] =
         m_startingBalance[scenario];

      m_maxEquityDrawdownMoney[scenario] =
         0.0;

      m_maxEquityDrawdownPercent[scenario] =
         0.0;

      m_signalsSeen[scenario] =
         0;

      m_filterRejected[scenario] =
         0;

      m_eligible[scenario] =
         0;

      m_opened[scenario] =
         0;

      m_skippedActive[scenario] =
         0;

      m_sizingRejected[scenario] =
         0;

      m_targetHits[scenario] =
         0;

      m_stopHits[scenario] =
         0;

      m_netWins[scenario] =
         0;

      m_netLosses[scenario] =
         0;

      m_currentLosingStreak[scenario] =
         0;

      m_maxLosingStreak[scenario] =
         0;

      m_grossProfitMoney[scenario] =
         0.0;

      m_grossLossMoney[scenario] =
         0.0;

      m_netProfitMoney[scenario] =
         0.0;

      m_netLossMoney[scenario] =
         0.0;

      m_totalCommissionMoney[scenario] =
         0.0;

      m_totalSlippageMoney[scenario] =
         0.0;

      m_totalExtraSpreadMoney[scenario] =
         0.0;

      m_totalNetR[scenario] =
         0.0;

      m_totalCostR[scenario] =
         0.0;

      m_totalVolume[scenario] =
         0.0;

      m_totalActualRiskPercent[scenario] =
         0.0;

      m_totalBars[scenario] =
         0.0;
   }
};

#endif
