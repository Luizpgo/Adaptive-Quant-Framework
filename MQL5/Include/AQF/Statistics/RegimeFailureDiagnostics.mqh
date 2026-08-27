#ifndef __AQF_REGIME_FAILURE_DIAGNOSTICS_MQH__
#define __AQF_REGIME_FAILURE_DIAGNOSTICS_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Common/TradeSignal.mqh"
#include "../Logger/Logger.mqh"

#define AQF_REGIME_MONTH_SLOTS 36

//+------------------------------------------------------------------+
//| Regime Failure Diagnostics                                       |
//|                                                                  |
//| Sprint 9 - Package A2                                             |
//|                                                                  |
//| Research objective:                                              |
//| Explain WHY frozen H2 behaves differently across periods.        |
//|                                                                  |
//| Frozen H2 remains unchanged:                                     |
//|   TP = 1.50R                                                     |
//|   ATRPercent >= 0.075                                            |
//|   ADX >= 25 and ADX < 40                                         |
//|   ONE active virtual position                                    |
//|                                                                  |
//| This module does NOT create a new filter.                         |
//| It records entry context and realized virtual outcome.           |
//|                                                                  |
//| Diagnostics:                                                     |
//| - Calendar month                                                 |
//| - Direction                                                      |
//| - ADX sub-range                                                  |
//| - ATRPercent sub-range                                           |
//| - Directional RSI                                                |
//| - Directional EMA fast/slow separation                           |
//| - Directional distance from EMA200                               |
//| - Spread as fraction of initial risk (SpreadR)                   |
//| - Previous completed candle range / ATR                        |
//| - Previous completed candle tick volume                          |
//| - Relative tick volume vs prior 20 completed candles             |
//| - Tick-volume z-score vs prior 20 completed candles              |
//| - Directional Efficiency Ratio over 5 / 10 / 20 completed bars   |
//| - Hour of day                                                    |
//| - Day of week                                                    |
//| - MFE / MAE in R                                                 |
//| - Winner MAE and loser MFE                                       |
//|                                                                  |
//| NO OrderSend. NO execution changes.                              |
//+------------------------------------------------------------------+

struct SAQFRegimePosition
{
   bool Active;

   string Symbol;
   ENUM_AQF_SIGNAL_DIRECTION Direction;

   double EntryPrice;
   double StopLoss;
   double StopDistance;
   double TakeProfit;

   datetime EntryTime;
   ENUM_TIMEFRAMES Timeframe;

   //---------------------------------------------------------------
   // Entry context
   //---------------------------------------------------------------

   double ADX;
   double ATRPercent;
   double DirectionalRSI;
   double DirectionalEMASeparationPercent;
   double DirectionalEMA200DistancePercent;
   double SpreadR;
   double RangeATR;

   //---------------------------------------------------------------
   // Sprint 9A2: activity + directional persistence
   //---------------------------------------------------------------

   bool ResearchFeaturesValid;

   long PrevTickVolume;
   double RelativeVolume20;
   double VolumeZScore20;

   double DirectionalER5;
   double DirectionalER10;
   double DirectionalER20;

   int Hour;
   int DayOfWeek;
   int MonthKey;

   //---------------------------------------------------------------
   // Excursion diagnostics
   //---------------------------------------------------------------

   double MFE_R;
   double MAE_R;
};

struct SAQFRegimeStats
{
   long Trades;
   long Wins;
   long Losses;

   double SumR;

   double SumMFE_R;
   double SumMAE_R;

   double SumWinnerMAE_R;
   double SumLoserMFE_R;

   double SumADX;
   double SumATRPercent;
   double SumDirectionalRSI;
   double SumDirectionalEMASeparationPercent;
   double SumDirectionalEMA200DistancePercent;
   double SumSpreadR;
   double SumRangeATR;

   long ResearchFeatureTrades;
   double SumPrevTickVolume;
   double SumRelativeVolume20;
   double SumVolumeZScore20;
   double SumDirectionalER5;
   double SumDirectionalER10;
   double SumDirectionalER20;

   double SumBars;
};

class CAQFRegimeFailureDiagnostics
{
private:

   double m_targetR;
   double m_minATRPercent;
   double m_minADX;
   double m_maxADX;

   SAQFRegimePosition m_position;

   //---------------------------------------------------------------
   // Registration counters
   //---------------------------------------------------------------

   long m_signalsSeen;
   long m_filterRejected;
   long m_eligible;
   long m_opened;
   long m_skippedActive;
   long m_researchFeatureCaptureFailures;

   //---------------------------------------------------------------
   // Overall and monthly statistics
   //---------------------------------------------------------------

   SAQFRegimeStats m_overall;

   int m_monthKey[AQF_REGIME_MONTH_SLOTS];
   SAQFRegimeStats m_monthStats[AQF_REGIME_MONTH_SLOTS];

   //---------------------------------------------------------------
   // Research buckets
   //---------------------------------------------------------------

   SAQFRegimeStats m_direction[2];

   SAQFRegimeStats m_adxBucket[3];
   SAQFRegimeStats m_atrBucket[4];
   SAQFRegimeStats m_directionalRSIBucket[4];
   SAQFRegimeStats m_directionalEMABucket[4];
   SAQFRegimeStats m_ema200Bucket[4];
   SAQFRegimeStats m_spreadRBucket[4];
   SAQFRegimeStats m_rangeATRBucket[4];

   SAQFRegimeStats m_relativeVolume20Bucket[5];
   SAQFRegimeStats m_volumeZScore20Bucket[5];

   SAQFRegimeStats m_directionalER5Bucket[4];
   SAQFRegimeStats m_directionalER10Bucket[4];
   SAQFRegimeStats m_directionalER20Bucket[4];

   SAQFRegimeStats m_hour[24];
   SAQFRegimeStats m_weekday[7];

   bool m_initialized;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFRegimeFailureDiagnostics()
   {
      m_targetR =
         1.50;

      m_minATRPercent =
         0.075;

      m_minADX =
         25.0;

      m_maxADX =
         40.0;

      m_initialized =
         false;

      ResetPosition();
      ResetAllStatistics();
   }

   //==============================================================
   // Initialize
   //==============================================================
   bool Initialize(
      CAQFLogger &logger)
   {
      ResetPosition();
      ResetAllStatistics();

      m_initialized =
         true;

      logger.Info(
         "RegimeFailureDiagnostics initialized."
      );

      logger.Info(
         "Regime research policy FROZEN: H2 | TP=1.50R | ATRPercent>=0.075 | ADX>=25 | ADX<40 | ONE active position"
      );

      logger.Info(
         "Regime diagnostics A2: Month | Direction | ADX | ATR% | DirRSI | DirEMA | EMA200 | SpreadR | PrevRangeATR | RelVol20 | VolZ20 | DirER5/10/20 | Hour | Weekday | MFE/MAE"
      );

      logger.Info(
         "PrevRangeATR uses the previous COMPLETED candle (CopyRates shift=1); H2 signal inputs are unchanged."
      );

      logger.Info(
         "A2 research features use COMPLETED candles only: PrevTickVolume=shift1 | RelativeVolume20/VolZ20 baseline=shifts2..21 | DirER5/10/20=shifts1..6/11/21."
      );

      logger.Info(
         "TickVolume is an ACTIVITY proxy, not centralized exchange volume. A2 features are observational only."
      );

      logger.Info(
         "RegimeFailureDiagnostics is OBSERVATIONAL ONLY - NO FILTER CHANGES - NO ORDER EXECUTION"
      );

      return true;
   }

   //==============================================================
   // Register executable-quality opportunity
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

      m_signalsSeen++;

      //------------------------------------------------------------
      // Frozen H2 gate
      //------------------------------------------------------------

      if(!PolicyAccepts(
            market))
      {
         m_filterRejected++;
         return true;
      }

      m_eligible++;

      //------------------------------------------------------------
      // Same one-position sequential rule as Sprint 8
      //------------------------------------------------------------

      if(m_position.Active)
      {
         m_skippedActive++;
         return true;
      }

      OpenPosition(
         request,
         market
      );

      m_opened++;

      logger.Debug(
         "RegimeOpen" +
         " | " +
         request.Symbol +
         " | Direction=" +
         AQFSignalDirectionToString(
            request.Direction) +
         " | Month=" +
         MonthText(
            m_position.MonthKey) +
         " | Hour=" +
         IntegerToString(
            m_position.Hour) +
         " | ADX=" +
         DoubleToString(
            m_position.ADX,
            2) +
         " | ATR%=" +
         DoubleToString(
            m_position.ATRPercent,
            4) +
         " | DirRSI=" +
         DoubleToString(
            m_position.DirectionalRSI,
            2) +
         " | DirEMA%=" +
         DoubleToString(
            m_position.DirectionalEMASeparationPercent,
            4) +
         " | EMA200%=" +
         DoubleToString(
            m_position.DirectionalEMA200DistancePercent,
            4) +
         " | SpreadR=" +
         DoubleToString(
            m_position.SpreadR,
            4) +
         " | PrevRangeATR=" +
         DoubleToString(
            m_position.RangeATR,
            3) +
         " | ResearchValid=" +
         (
            m_position.ResearchFeaturesValid
            ? "YES"
            : "NO"
         ) +
         " | PrevVol=" +
         IntegerToString(
            (int)m_position.PrevTickVolume) +
         " | RelVol20=" +
         DoubleToString(
            m_position.RelativeVolume20,
            3) +
         " | VolZ20=" +
         DoubleToString(
            m_position.VolumeZScore20,
            3) +
         " | DirER5=" +
         DoubleToString(
            m_position.DirectionalER5,
            3) +
         " | DirER10=" +
         DoubleToString(
            m_position.DirectionalER10,
            3) +
         " | DirER20=" +
         DoubleToString(
            m_position.DirectionalER20,
            3)
      );

      return true;
   }

   //==============================================================
   // Every-tick update
   //==============================================================
   void Update(
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!m_initialized ||
         !m_position.Active)
      {
         return;
      }

      if(!market.Valid ||
         market.Symbol != m_position.Symbol ||
         market.Bid <= 0.0 ||
         market.Ask <= 0.0)
      {
         return;
      }

      double exitPrice =
         0.0;

      bool targetReached =
         false;

      bool stopReached =
         false;

      if(m_position.Direction ==
         AQF_SIGNAL_BUY)
      {
         exitPrice =
            market.Bid;

         targetReached =
            (
               market.Bid >=
               m_position.TakeProfit
            );

         stopReached =
            (
               market.Bid <=
               m_position.StopLoss
            );
      }
      else
      {
         exitPrice =
            market.Ask;

         targetReached =
            (
               market.Ask <=
               m_position.TakeProfit
            );

         stopReached =
            (
               market.Ask >=
               m_position.StopLoss
            );
      }

      //------------------------------------------------------------
      // MFE / MAE in R.
      //
      // Clamp to the modeled barrier so crossing-tick overshoot does
      // not inflate excursion statistics.
      //------------------------------------------------------------

      double currentR =
         CurrentR(
            exitPrice
         );

      if(currentR >
         m_targetR)
      {
         currentR =
            m_targetR;
      }

      if(currentR <
         -1.0)
      {
         currentR =
            -1.0;
      }

      if(currentR >
         m_position.MFE_R)
      {
         m_position.MFE_R =
            currentR;
      }

      if(currentR < 0.0)
      {
         double adverseR =
            MathAbs(
               currentR
            );

         if(adverseR >
            m_position.MAE_R)
         {
            m_position.MAE_R =
               adverseR;
         }
      }

      int barsElapsed =
         CalculateBarsElapsed(
            market.Time
         );

      if(targetReached)
      {
         Resolve(
            true,
            barsElapsed,
            logger
         );

         return;
      }

      if(stopReached)
      {
         Resolve(
            false,
            barsElapsed,
            logger
         );

         return;
      }
   }

   //==============================================================
   // Report
   //==============================================================
   void ReportAll(
      CAQFLogger &logger)
   {
      logger.Info(
         "RegimeStats ============================================"
      );

      ReportStats(
         "RegimeSummary",
         "Scope=ALL",
         m_overall,
         logger
      );

      logger.Info(
         "RegimeSummary | Signals=" +
         IntegerToString(
            (int)m_signalsSeen) +
         " | FilterRejected=" +
         IntegerToString(
            (int)m_filterRejected) +
         " | Eligible=" +
         IntegerToString(
            (int)m_eligible) +
         " | Opened=" +
         IntegerToString(
            (int)m_opened) +
         " | SkippedActive=" +
         IntegerToString(
            (int)m_skippedActive) +
         " | ResearchFeatureFailures=" +
         IntegerToString(
            (int)m_researchFeatureCaptureFailures) +
         " | Open=" +
         (
            m_position.Active
            ? "1"
            : "0"
         )
      );

      //------------------------------------------------------------
      // Calendar months
      //------------------------------------------------------------

      for(int i = 0;
          i < AQF_REGIME_MONTH_SLOTS;
          i++)
      {
         if(m_monthKey[i] == 0 ||
            m_monthStats[i].Trades <= 0)
         {
            continue;
         }

         ReportStats(
            "RegimeMonth",
            "Month=" +
            MonthText(
               m_monthKey[i]),
            m_monthStats[i],
            logger
         );
      }

      //------------------------------------------------------------
      // Direction
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=Direction | Bucket=BUY",
         m_direction[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=Direction | Bucket=SELL",
         m_direction[1],
         logger
      );

      //------------------------------------------------------------
      // ADX within frozen 25-40 range
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=ADX | Bucket=25-29",
         m_adxBucket[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=ADX | Bucket=30-34",
         m_adxBucket[1],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=ADX | Bucket=35-39",
         m_adxBucket[2],
         logger
      );

      //------------------------------------------------------------
      // ATR Percent
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=ATRPercent | Bucket=0.075-0.099",
         m_atrBucket[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=ATRPercent | Bucket=0.100-0.149",
         m_atrBucket[1],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=ATRPercent | Bucket=0.150-0.249",
         m_atrBucket[2],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=ATRPercent | Bucket=0.250+",
         m_atrBucket[3],
         logger
      );

      //------------------------------------------------------------
      // Directional RSI
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=DirRSI | Bucket=<50",
         m_directionalRSIBucket[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirRSI | Bucket=50-54",
         m_directionalRSIBucket[1],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirRSI | Bucket=55-59",
         m_directionalRSIBucket[2],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirRSI | Bucket=60+",
         m_directionalRSIBucket[3],
         logger
      );

      //------------------------------------------------------------
      // Directional EMA fast/slow separation
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=DirEMA | Bucket=<0.010",
         m_directionalEMABucket[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirEMA | Bucket=0.010-0.019",
         m_directionalEMABucket[1],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirEMA | Bucket=0.020-0.039",
         m_directionalEMABucket[2],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirEMA | Bucket=0.040+",
         m_directionalEMABucket[3],
         logger
      );

      //------------------------------------------------------------
      // Directional distance from EMA200
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=EMA200 | Bucket=<0",
         m_ema200Bucket[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=EMA200 | Bucket=0-0.049",
         m_ema200Bucket[1],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=EMA200 | Bucket=0.050-0.149",
         m_ema200Bucket[2],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=EMA200 | Bucket=0.150+",
         m_ema200Bucket[3],
         logger
      );

      //------------------------------------------------------------
      // Spread as risk fraction
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=SpreadR | Bucket=<0.020",
         m_spreadRBucket[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=SpreadR | Bucket=0.020-0.049",
         m_spreadRBucket[1],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=SpreadR | Bucket=0.050-0.099",
         m_spreadRBucket[2],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=SpreadR | Bucket=0.100+",
         m_spreadRBucket[3],
         logger
      );

      //------------------------------------------------------------
      // Previous completed candle range / ATR
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=PrevRangeATR | Bucket=<0.50",
         m_rangeATRBucket[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=PrevRangeATR | Bucket=0.50-0.99",
         m_rangeATRBucket[1],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=PrevRangeATR | Bucket=1.00-1.49",
         m_rangeATRBucket[2],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=PrevRangeATR | Bucket=1.50+",
         m_rangeATRBucket[3],
         logger
      );

      //------------------------------------------------------------
      // Relative tick volume (previous completed candle vs prior 20)
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=RelVol20 | Bucket=<0.75",
         m_relativeVolume20Bucket[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=RelVol20 | Bucket=0.75-0.99",
         m_relativeVolume20Bucket[1],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=RelVol20 | Bucket=1.00-1.24",
         m_relativeVolume20Bucket[2],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=RelVol20 | Bucket=1.25-1.49",
         m_relativeVolume20Bucket[3],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=RelVol20 | Bucket=1.50+",
         m_relativeVolume20Bucket[4],
         logger
      );

      //------------------------------------------------------------
      // Tick-volume z-score vs prior 20 completed candles
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=VolZ20 | Bucket=<-1.00",
         m_volumeZScore20Bucket[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=VolZ20 | Bucket=-1.00--0.25",
         m_volumeZScore20Bucket[1],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=VolZ20 | Bucket=-0.25-0.25",
         m_volumeZScore20Bucket[2],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=VolZ20 | Bucket=0.25-1.00",
         m_volumeZScore20Bucket[3],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=VolZ20 | Bucket=1.00+",
         m_volumeZScore20Bucket[4],
         logger
      );

      //------------------------------------------------------------
      // Directional Efficiency Ratio: 5 completed candles
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=DirER5 | Bucket=<0",
         m_directionalER5Bucket[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirER5 | Bucket=0.00-0.24",
         m_directionalER5Bucket[1],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirER5 | Bucket=0.25-0.49",
         m_directionalER5Bucket[2],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirER5 | Bucket=0.50+",
         m_directionalER5Bucket[3],
         logger
      );

      //------------------------------------------------------------
      // Directional Efficiency Ratio: 10 completed candles
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=DirER10 | Bucket=<0",
         m_directionalER10Bucket[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirER10 | Bucket=0.00-0.24",
         m_directionalER10Bucket[1],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirER10 | Bucket=0.25-0.49",
         m_directionalER10Bucket[2],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirER10 | Bucket=0.50+",
         m_directionalER10Bucket[3],
         logger
      );

      //------------------------------------------------------------
      // Directional Efficiency Ratio: 20 completed candles
      //------------------------------------------------------------

      ReportStats(
         "RegimeBucket",
         "Dimension=DirER20 | Bucket=<0",
         m_directionalER20Bucket[0],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirER20 | Bucket=0.00-0.24",
         m_directionalER20Bucket[1],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirER20 | Bucket=0.25-0.49",
         m_directionalER20Bucket[2],
         logger
      );

      ReportStats(
         "RegimeBucket",
         "Dimension=DirER20 | Bucket=0.50+",
         m_directionalER20Bucket[3],
         logger
      );

      //------------------------------------------------------------
      // Hour
      //------------------------------------------------------------

      for(int hour = 0;
          hour < 24;
          hour++)
      {
         if(m_hour[hour].Trades <= 0)
            continue;

         ReportStats(
            "RegimeHour",
            "Hour=" +
            TwoDigits(
               hour),
            m_hour[hour],
            logger
         );
      }

      //------------------------------------------------------------
      // Weekday
      //------------------------------------------------------------

      for(int day = 0;
          day < 7;
          day++)
      {
         if(m_weekday[day].Trades <= 0)
            continue;

         ReportStats(
            "RegimeWeekday",
            "Day=" +
            WeekdayName(
               day),
            m_weekday[day],
            logger
         );
      }

      logger.Info(
         "RegimeStats ============================================"
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
   // Frozen H2 policy
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
   // Open
   //==============================================================
   void OpenPosition(
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market)
   {
      ResetPosition();

      m_position.Active =
         true;

      m_position.Symbol =
         request.Symbol;

      m_position.Direction =
         request.Direction;

      m_position.EntryPrice =
         request.EntryPrice;

      m_position.StopLoss =
         request.StopLoss;

      m_position.StopDistance =
         request.StopDistance;

      m_position.EntryTime =
         request.SignalTime;

      m_position.Timeframe =
         market.Timeframe;

      double targetDistance =
         request.StopDistance *
         m_targetR;

      if(request.Direction ==
         AQF_SIGNAL_BUY)
      {
         m_position.TakeProfit =
            request.EntryPrice +
            targetDistance;
      }
      else
      {
         m_position.TakeProfit =
            request.EntryPrice -
            targetDistance;
      }

      //------------------------------------------------------------
      // Context
      //------------------------------------------------------------

      m_position.ADX =
         market.ADX;

      m_position.ATRPercent =
         market.ATRPercent;

      m_position.DirectionalRSI =
         DirectionalRSI(
            request.Direction,
            market.RSI
         );

      m_position.DirectionalEMASeparationPercent =
         DirectionalEMASeparationPercent(
            request.Direction,
            market
         );

      m_position.DirectionalEMA200DistancePercent =
         DirectionalEMA200DistancePercent(
            request.Direction,
            market
         );

      m_position.SpreadR =
         0.0;

      if(request.StopDistance > 0.0 &&
         market.Point > 0.0)
      {
         m_position.SpreadR =
            (
               market.SpreadPoints *
               market.Point
            )
            /
            request.StopDistance;
      }

      //------------------------------------------------------------
      // Previous completed candle range / ATR
      //
      // Strategy evaluation occurs on the first tick of a new bar.
      // At that moment market.High and market.Low belong to the new,
      // still-forming candle and are normally equal, which made the
      // original RangeATR diagnostic collapse to ~0.
      //
      // IMPORTANT:
      // We intentionally DO NOT alter MarketEngine or MarketSnapshot,
      // because doing so could change the already-frozen H2 signal
      // sequence. This diagnostic alone reads shift=1: the completed
      // candle immediately before the signal bar.
      //------------------------------------------------------------

      m_position.RangeATR =
         0.0;

      if(market.ATR > 0.0)
      {
         MqlRates previousBar[];

         ArraySetAsSeries(
            previousBar,
            true
         );

         int copiedPrevious =
            CopyRates(
               request.Symbol,
               market.Timeframe,
               1,
               1,
               previousBar
            );

         if(copiedPrevious == 1)
         {
            double previousRange =
               previousBar[0].high -
               previousBar[0].low;

            if(previousRange >= 0.0)
            {
               m_position.RangeATR =
                  previousRange /
                  market.ATR;
            }
         }
      }

      //------------------------------------------------------------
      // Sprint 9A2 - completed-candle activity and persistence
      //------------------------------------------------------------

      if(!CaptureResearchFeatures(
            request,
            market))
      {
         m_researchFeatureCaptureFailures++;
      }

      MqlDateTime dateParts;

      if(TimeToStruct(
            request.SignalTime,
            dateParts))
      {
         m_position.Hour =
            dateParts.hour;

         m_position.DayOfWeek =
            dateParts.day_of_week;

         m_position.MonthKey =
            dateParts.year *
            100 +
            dateParts.mon;
      }

      m_position.MFE_R =
         0.0;

      m_position.MAE_R =
         0.0;
   }

   //==============================================================
   // Resolve
   //==============================================================
   void Resolve(
      const bool win,
      const int barsElapsed,
      CAQFLogger &logger)
   {
      double resultR =
         (
            win
            ? m_targetR
            : -1.0
         );

      //------------------------------------------------------------
      // Overall
      //------------------------------------------------------------

      AddResult(
         m_overall,
         win,
         resultR,
         barsElapsed
      );

      //------------------------------------------------------------
      // Month
      //------------------------------------------------------------

      int monthIndex =
         FindOrCreateMonth(
            m_position.MonthKey
         );

      if(monthIndex >= 0)
      {
         AddResult(
            m_monthStats[monthIndex],
            win,
            resultR,
            barsElapsed
         );
      }

      //------------------------------------------------------------
      // Direction
      //------------------------------------------------------------

      int directionIndex =
         (
            m_position.Direction ==
            AQF_SIGNAL_BUY
            ? 0
            : 1
         );

      AddResult(
         m_direction[directionIndex],
         win,
         resultR,
         barsElapsed
      );

      //------------------------------------------------------------
      // Feature buckets
      //------------------------------------------------------------

      AddResult(
         m_adxBucket[
            ADXBucket(
               m_position.ADX)],
         win,
         resultR,
         barsElapsed
      );

      AddResult(
         m_atrBucket[
            ATRBucket(
               m_position.ATRPercent)],
         win,
         resultR,
         barsElapsed
      );

      AddResult(
         m_directionalRSIBucket[
            DirectionalRSIBucket(
               m_position.DirectionalRSI)],
         win,
         resultR,
         barsElapsed
      );

      AddResult(
         m_directionalEMABucket[
            DirectionalEMABucket(
               m_position.DirectionalEMASeparationPercent)],
         win,
         resultR,
         barsElapsed
      );

      AddResult(
         m_ema200Bucket[
            EMA200Bucket(
               m_position.DirectionalEMA200DistancePercent)],
         win,
         resultR,
         barsElapsed
      );

      AddResult(
         m_spreadRBucket[
            SpreadRBucket(
               m_position.SpreadR)],
         win,
         resultR,
         barsElapsed
      );

      AddResult(
         m_rangeATRBucket[
            RangeATRBucket(
               m_position.RangeATR)],
         win,
         resultR,
         barsElapsed
      );

      //------------------------------------------------------------
      // Sprint 9A2 buckets are populated only when all 21 completed
      // research bars were available. H2 tracking itself is never
      // rejected because of missing research data.
      //------------------------------------------------------------

      if(m_position.ResearchFeaturesValid)
      {
         AddResult(
            m_relativeVolume20Bucket[
               RelativeVolume20Bucket(
                  m_position.RelativeVolume20)],
            win,
            resultR,
            barsElapsed
         );

         AddResult(
            m_volumeZScore20Bucket[
               VolumeZScore20Bucket(
                  m_position.VolumeZScore20)],
            win,
            resultR,
            barsElapsed
         );

         AddResult(
            m_directionalER5Bucket[
               DirectionalERBucket(
                  m_position.DirectionalER5)],
            win,
            resultR,
            barsElapsed
         );

         AddResult(
            m_directionalER10Bucket[
               DirectionalERBucket(
                  m_position.DirectionalER10)],
            win,
            resultR,
            barsElapsed
         );

         AddResult(
            m_directionalER20Bucket[
               DirectionalERBucket(
                  m_position.DirectionalER20)],
            win,
            resultR,
            barsElapsed
         );
      }

      if(m_position.Hour >= 0 &&
         m_position.Hour < 24)
      {
         AddResult(
            m_hour[m_position.Hour],
            win,
            resultR,
            barsElapsed
         );
      }

      if(m_position.DayOfWeek >= 0 &&
         m_position.DayOfWeek < 7)
      {
         AddResult(
            m_weekday[m_position.DayOfWeek],
            win,
            resultR,
            barsElapsed
         );
      }

      logger.Debug(
         "RegimeClose" +
         " | Month=" +
         MonthText(
            m_position.MonthKey) +
         " | Result=" +
         (
            win
            ? "WIN"
            : "LOSS"
         ) +
         " | ResultR=" +
         DoubleToString(
            resultR,
            2) +
         "R" +
         " | MFE=" +
         DoubleToString(
            m_position.MFE_R,
            3) +
         "R" +
         " | MAE=" +
         DoubleToString(
            m_position.MAE_R,
            3) +
         "R" +
         " | Bars=" +
         IntegerToString(
            barsElapsed)
      );

      ResetPosition();
   }

   //==============================================================
   // Add one resolved trade to a statistics bucket
   //==============================================================
   void AddResult(
      SAQFRegimeStats &stats,
      const bool win,
      const double resultR,
      const int barsElapsed)
   {
      stats.Trades++;

      if(win)
      {
         stats.Wins++;

         stats.SumWinnerMAE_R +=
            m_position.MAE_R;
      }
      else
      {
         stats.Losses++;

         stats.SumLoserMFE_R +=
            m_position.MFE_R;
      }

      stats.SumR +=
         resultR;

      stats.SumMFE_R +=
         m_position.MFE_R;

      stats.SumMAE_R +=
         m_position.MAE_R;

      stats.SumADX +=
         m_position.ADX;

      stats.SumATRPercent +=
         m_position.ATRPercent;

      stats.SumDirectionalRSI +=
         m_position.DirectionalRSI;

      stats.SumDirectionalEMASeparationPercent +=
         m_position.DirectionalEMASeparationPercent;

      stats.SumDirectionalEMA200DistancePercent +=
         m_position.DirectionalEMA200DistancePercent;

      stats.SumSpreadR +=
         m_position.SpreadR;

      stats.SumRangeATR +=
         m_position.RangeATR;

      if(m_position.ResearchFeaturesValid)
      {
         stats.ResearchFeatureTrades++;

         stats.SumPrevTickVolume +=
            (double)m_position.PrevTickVolume;

         stats.SumRelativeVolume20 +=
            m_position.RelativeVolume20;

         stats.SumVolumeZScore20 +=
            m_position.VolumeZScore20;

         stats.SumDirectionalER5 +=
            m_position.DirectionalER5;

         stats.SumDirectionalER10 +=
            m_position.DirectionalER10;

         stats.SumDirectionalER20 +=
            m_position.DirectionalER20;
      }

      stats.SumBars +=
         (double)barsElapsed;
   }

   //==============================================================
   // Report one bucket
   //==============================================================
   void ReportStats(
      const string prefix,
      const string label,
      const SAQFRegimeStats &stats,
      CAQFLogger &logger)
   {
      if(stats.Trades <= 0)
         return;

      double winRate =
         (
            (double)stats.Wins /
            (double)stats.Trades
         ) * 100.0;

      double expectancy =
         stats.SumR /
         (double)stats.Trades;

      double avgMFE =
         stats.SumMFE_R /
         (double)stats.Trades;

      double avgMAE =
         stats.SumMAE_R /
         (double)stats.Trades;

      double avgWinnerMAE =
         0.0;

      if(stats.Wins > 0)
      {
         avgWinnerMAE =
            stats.SumWinnerMAE_R /
            (double)stats.Wins;
      }

      double avgLoserMFE =
         0.0;

      if(stats.Losses > 0)
      {
         avgLoserMFE =
            stats.SumLoserMFE_R /
            (double)stats.Losses;
      }

      double grossProfitR =
         (double)stats.Wins *
         m_targetR;

      double grossLossR =
         (double)stats.Losses;

      string profitFactor =
         "INF";

      if(grossLossR > 0.0)
      {
         profitFactor =
            DoubleToString(
               grossProfitR /
               grossLossR,
               3
            );
      }

      double avgPrevTickVolume =
         0.0;

      double avgRelativeVolume20 =
         0.0;

      double avgVolumeZScore20 =
         0.0;

      double avgDirectionalER5 =
         0.0;

      double avgDirectionalER10 =
         0.0;

      double avgDirectionalER20 =
         0.0;

      if(stats.ResearchFeatureTrades > 0)
      {
         double researchN =
            (double)stats.ResearchFeatureTrades;

         avgPrevTickVolume =
            stats.SumPrevTickVolume /
            researchN;

         avgRelativeVolume20 =
            stats.SumRelativeVolume20 /
            researchN;

         avgVolumeZScore20 =
            stats.SumVolumeZScore20 /
            researchN;

         avgDirectionalER5 =
            stats.SumDirectionalER5 /
            researchN;

         avgDirectionalER10 =
            stats.SumDirectionalER10 /
            researchN;

         avgDirectionalER20 =
            stats.SumDirectionalER20 /
            researchN;
      }

      logger.Info(
         prefix +
         " | " +
         label +
         " | Trades=" +
         IntegerToString(
            (int)stats.Trades) +
         " | Wins=" +
         IntegerToString(
            (int)stats.Wins) +
         " | Losses=" +
         IntegerToString(
            (int)stats.Losses) +
         " | WinRate=" +
         DoubleToString(
            winRate,
            2) +
         "%" +
         " | Expectancy=" +
         DoubleToString(
            expectancy,
            3) +
         "R" +
         " | PF=" +
         profitFactor +
         " | CumR=" +
         DoubleToString(
            stats.SumR,
            2) +
         "R" +
         " | AvgMFE=" +
         DoubleToString(
            avgMFE,
            3) +
         "R" +
         " | AvgMAE=" +
         DoubleToString(
            avgMAE,
            3) +
         "R" +
         " | WinMAE=" +
         DoubleToString(
            avgWinnerMAE,
            3) +
         "R" +
         " | LossMFE=" +
         DoubleToString(
            avgLoserMFE,
            3) +
         "R" +
         " | AvgADX=" +
         DoubleToString(
            stats.SumADX /
            (double)stats.Trades,
            2) +
         " | AvgATR%=" +
         DoubleToString(
            stats.SumATRPercent /
            (double)stats.Trades,
            4) +
         " | AvgDirRSI=" +
         DoubleToString(
            stats.SumDirectionalRSI /
            (double)stats.Trades,
            2) +
         " | AvgDirEMA%=" +
         DoubleToString(
            stats.SumDirectionalEMASeparationPercent /
            (double)stats.Trades,
            4) +
         " | AvgEMA200%=" +
         DoubleToString(
            stats.SumDirectionalEMA200DistancePercent /
            (double)stats.Trades,
            4) +
         " | AvgSpreadR=" +
         DoubleToString(
            stats.SumSpreadR /
            (double)stats.Trades,
            4) +
         " | AvgPrevRangeATR=" +
         DoubleToString(
            stats.SumRangeATR /
            (double)stats.Trades,
            3) +
         " | ResearchN=" +
         IntegerToString(
            (int)stats.ResearchFeatureTrades) +
         " | AvgPrevVol=" +
         DoubleToString(
            avgPrevTickVolume,
            1) +
         " | AvgRelVol20=" +
         DoubleToString(
            avgRelativeVolume20,
            3) +
         " | AvgVolZ20=" +
         DoubleToString(
            avgVolumeZScore20,
            3) +
         " | AvgDirER5=" +
         DoubleToString(
            avgDirectionalER5,
            3) +
         " | AvgDirER10=" +
         DoubleToString(
            avgDirectionalER10,
            3) +
         " | AvgDirER20=" +
         DoubleToString(
            avgDirectionalER20,
            3) +
         " | AvgBars=" +
         DoubleToString(
            stats.SumBars /
            (double)stats.Trades,
            1)
      );
   }

   //==============================================================
   // Directional features
   //==============================================================
   double DirectionalRSI(
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const double rsi)
   {
      if(direction ==
         AQF_SIGNAL_BUY)
      {
         return rsi;
      }

      return
         100.0 -
         rsi;
   }

   double DirectionalEMASeparationPercent(
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const CAQFMarketSnapshot &market)
   {
      if(market.Close <= 0.0)
         return 0.0;

      double separation =
         (
            market.EMAFast -
            market.EMASlow
         )
         /
         market.Close *
         100.0;

      if(direction ==
         AQF_SIGNAL_SELL)
      {
         separation =
            -separation;
      }

      return separation;
   }

   double DirectionalEMA200DistancePercent(
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const CAQFMarketSnapshot &market)
   {
      if(market.Close <= 0.0)
         return 0.0;

      double distance =
         (
            market.Close -
            market.EMA200
         )
         /
         market.Close *
         100.0;

      if(direction ==
         AQF_SIGNAL_SELL)
      {
         distance =
            -distance;
      }

      return distance;
   }

   //==============================================================
   // Sprint 9A2 research features
   //
   // All inputs below are known BEFORE the signal is acted on:
   //   researchRates[0]  = shift 1  (previous completed candle)
   //   researchRates[20] = shift 21
   //
   // RelativeVolume20 and VolumeZScore20 compare shift 1 against
   // shifts 2..21, deliberately excluding the measured bar from its
   // own baseline.
   //
   // Directional ER is a signed Kaufman-style efficiency ratio:
   //
   //   signed net displacement / total path length
   //
   // +1 = perfectly efficient movement in trade direction
   //  0 = no net directional progress
   // -1 = perfectly efficient movement against trade direction
   //==============================================================
   bool CaptureResearchFeatures(
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market)
   {
      m_position.ResearchFeaturesValid =
         false;

      m_position.PrevTickVolume =
         0;

      m_position.RelativeVolume20 =
         0.0;

      m_position.VolumeZScore20 =
         0.0;

      m_position.DirectionalER5 =
         0.0;

      m_position.DirectionalER10 =
         0.0;

      m_position.DirectionalER20 =
         0.0;

      MqlRates researchRates[];

      ArraySetAsSeries(
         researchRates,
         true
      );

      int copied =
         CopyRates(
            request.Symbol,
            market.Timeframe,
            1,
            21,
            researchRates
         );

      if(copied != 21)
         return false;

      m_position.PrevTickVolume =
         researchRates[0].tick_volume;

      //------------------------------------------------------------
      // Relative volume and z-score baseline: shifts 2..21
      //------------------------------------------------------------

      double volumeSum =
         0.0;

      for(int i = 1;
          i <= 20;
          i++)
      {
         volumeSum +=
            (double)researchRates[i].tick_volume;
      }

      double volumeMean =
         volumeSum /
         20.0;

      if(volumeMean > 0.0)
      {
         m_position.RelativeVolume20 =
            (double)m_position.PrevTickVolume /
            volumeMean;
      }

      double squaredDiffSum =
         0.0;

      for(int i = 1;
          i <= 20;
          i++)
      {
         double difference =
            (double)researchRates[i].tick_volume -
            volumeMean;

         squaredDiffSum +=
            difference *
            difference;
      }

      double volumeStd =
         MathSqrt(
            squaredDiffSum /
            20.0
         );

      if(volumeStd > 0.0)
      {
         m_position.VolumeZScore20 =
            (
               (double)m_position.PrevTickVolume -
               volumeMean
            )
            /
            volumeStd;
      }

      //------------------------------------------------------------
      // Directional price-path efficiency
      //------------------------------------------------------------

      m_position.DirectionalER5 =
         DirectionalEfficiency(
            request.Direction,
            researchRates,
            5
         );

      m_position.DirectionalER10 =
         DirectionalEfficiency(
            request.Direction,
            researchRates,
            10
         );

      m_position.DirectionalER20 =
         DirectionalEfficiency(
            request.Direction,
            researchRates,
            20
         );

      m_position.ResearchFeaturesValid =
         true;

      return true;
   }

   double DirectionalEfficiency(
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const MqlRates &rates[],
      const int window)
   {
      if(window <= 0 ||
         ArraySize(rates) <
         window + 1)
      {
         return 0.0;
      }

      double netDisplacement =
         rates[0].close -
         rates[window].close;

      if(direction ==
         AQF_SIGNAL_SELL)
      {
         netDisplacement =
            -netDisplacement;
      }

      double pathLength =
         0.0;

      for(int i = 0;
          i < window;
          i++)
      {
         pathLength +=
            MathAbs(
               rates[i].close -
               rates[i + 1].close
            );
      }

      if(pathLength <= 0.0)
         return 0.0;

      double efficiency =
         netDisplacement /
         pathLength;

      if(efficiency > 1.0)
         efficiency = 1.0;

      if(efficiency < -1.0)
         efficiency = -1.0;

      return efficiency;
   }

   //==============================================================
   // Current R
   //==============================================================
   double CurrentR(
      const double exitPrice)
   {
      if(m_position.StopDistance <= 0.0)
         return 0.0;

      if(m_position.Direction ==
         AQF_SIGNAL_BUY)
      {
         return
            (
               exitPrice -
               m_position.EntryPrice
            )
            /
            m_position.StopDistance;
      }

      return
         (
            m_position.EntryPrice -
            exitPrice
         )
         /
         m_position.StopDistance;
   }

   //==============================================================
   // Month storage
   //==============================================================
   int FindOrCreateMonth(
      const int monthKey)
   {
      if(monthKey <= 0)
         return -1;

      for(int i = 0;
          i < AQF_REGIME_MONTH_SLOTS;
          i++)
      {
         if(m_monthKey[i] ==
            monthKey)
         {
            return i;
         }
      }

      for(int i = 0;
          i < AQF_REGIME_MONTH_SLOTS;
          i++)
      {
         if(m_monthKey[i] ==
            0)
         {
            m_monthKey[i] =
               monthKey;

            ResetStats(
               m_monthStats[i]
            );

            return i;
         }
      }

      return -1;
   }

   //==============================================================
   // Buckets
   //==============================================================
   int ADXBucket(
      const double value)
   {
      if(value < 30.0)
         return 0;

      if(value < 35.0)
         return 1;

      return 2;
   }

   int ATRBucket(
      const double value)
   {
      if(value < 0.100)
         return 0;

      if(value < 0.150)
         return 1;

      if(value < 0.250)
         return 2;

      return 3;
   }

   int DirectionalRSIBucket(
      const double value)
   {
      if(value < 50.0)
         return 0;

      if(value < 55.0)
         return 1;

      if(value < 60.0)
         return 2;

      return 3;
   }

   int DirectionalEMABucket(
      const double value)
   {
      if(value < 0.010)
         return 0;

      if(value < 0.020)
         return 1;

      if(value < 0.040)
         return 2;

      return 3;
   }

   int EMA200Bucket(
      const double value)
   {
      if(value < 0.0)
         return 0;

      if(value < 0.050)
         return 1;

      if(value < 0.150)
         return 2;

      return 3;
   }

   int SpreadRBucket(
      const double value)
   {
      if(value < 0.020)
         return 0;

      if(value < 0.050)
         return 1;

      if(value < 0.100)
         return 2;

      return 3;
   }

   int RangeATRBucket(
      const double value)
   {
      if(value < 0.50)
         return 0;

      if(value < 1.00)
         return 1;

      if(value < 1.50)
         return 2;

      return 3;
   }

   int RelativeVolume20Bucket(
      const double value)
   {
      if(value < 0.75)
         return 0;

      if(value < 1.00)
         return 1;

      if(value < 1.25)
         return 2;

      if(value < 1.50)
         return 3;

      return 4;
   }

   int VolumeZScore20Bucket(
      const double value)
   {
      if(value < -1.00)
         return 0;

      if(value < -0.25)
         return 1;

      if(value < 0.25)
         return 2;

      if(value < 1.00)
         return 3;

      return 4;
   }

   int DirectionalERBucket(
      const double value)
   {
      if(value < 0.0)
         return 0;

      if(value < 0.25)
         return 1;

      if(value < 0.50)
         return 2;

      return 3;
   }

   //==============================================================
   // Time helpers
   //==============================================================
   string MonthText(
      const int monthKey)
   {
      int year =
         monthKey /
         100;

      int month =
         monthKey %
         100;

      return
         IntegerToString(
            year) +
         "-" +
         TwoDigits(
            month);
   }

   string TwoDigits(
      const int value)
   {
      if(value < 10)
      {
         return
            "0" +
            IntegerToString(
               value);
      }

      return
         IntegerToString(
            value);
   }

   string WeekdayName(
      const int day)
   {
      if(day == 0)
         return "SUN";

      if(day == 1)
         return "MON";

      if(day == 2)
         return "TUE";

      if(day == 3)
         return "WED";

      if(day == 4)
         return "THU";

      if(day == 5)
         return "FRI";

      if(day == 6)
         return "SAT";

      return "UNKNOWN";
   }

   //==============================================================
   // Bars elapsed
   //==============================================================
   int CalculateBarsElapsed(
      const datetime currentTime)
   {
      int secondsPerBar =
         PeriodSeconds(
            m_position.Timeframe
         );

      if(secondsPerBar <= 0)
         return 0;

      long secondsElapsed =
         (long)(
            currentTime -
            m_position.EntryTime
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
   // Reset
   //==============================================================
   void ResetPosition()
   {
      m_position.Active =
         false;

      m_position.Symbol =
         "";

      m_position.Direction =
         AQF_SIGNAL_NONE;

      m_position.EntryPrice =
         0.0;

      m_position.StopLoss =
         0.0;

      m_position.StopDistance =
         0.0;

      m_position.TakeProfit =
         0.0;

      m_position.EntryTime =
         0;

      m_position.Timeframe =
         PERIOD_CURRENT;

      m_position.ADX =
         0.0;

      m_position.ATRPercent =
         0.0;

      m_position.DirectionalRSI =
         0.0;

      m_position.DirectionalEMASeparationPercent =
         0.0;

      m_position.DirectionalEMA200DistancePercent =
         0.0;

      m_position.SpreadR =
         0.0;

      m_position.RangeATR =
         0.0;

      m_position.ResearchFeaturesValid =
         false;

      m_position.PrevTickVolume =
         0;

      m_position.RelativeVolume20 =
         0.0;

      m_position.VolumeZScore20 =
         0.0;

      m_position.DirectionalER5 =
         0.0;

      m_position.DirectionalER10 =
         0.0;

      m_position.DirectionalER20 =
         0.0;

      m_position.Hour =
         -1;

      m_position.DayOfWeek =
         -1;

      m_position.MonthKey =
         0;

      m_position.MFE_R =
         0.0;

      m_position.MAE_R =
         0.0;
   }

   void ResetStats(
      SAQFRegimeStats &stats)
   {
      stats.Trades =
         0;

      stats.Wins =
         0;

      stats.Losses =
         0;

      stats.SumR =
         0.0;

      stats.SumMFE_R =
         0.0;

      stats.SumMAE_R =
         0.0;

      stats.SumWinnerMAE_R =
         0.0;

      stats.SumLoserMFE_R =
         0.0;

      stats.SumADX =
         0.0;

      stats.SumATRPercent =
         0.0;

      stats.SumDirectionalRSI =
         0.0;

      stats.SumDirectionalEMASeparationPercent =
         0.0;

      stats.SumDirectionalEMA200DistancePercent =
         0.0;

      stats.SumSpreadR =
         0.0;

      stats.SumRangeATR =
         0.0;

      stats.ResearchFeatureTrades =
         0;

      stats.SumPrevTickVolume =
         0.0;

      stats.SumRelativeVolume20 =
         0.0;

      stats.SumVolumeZScore20 =
         0.0;

      stats.SumDirectionalER5 =
         0.0;

      stats.SumDirectionalER10 =
         0.0;

      stats.SumDirectionalER20 =
         0.0;

      stats.SumBars =
         0.0;
   }

   void ResetAllStatistics()
   {
      m_signalsSeen =
         0;

      m_filterRejected =
         0;

      m_eligible =
         0;

      m_opened =
         0;

      m_skippedActive =
         0;

      m_researchFeatureCaptureFailures =
         0;

      ResetStats(
         m_overall
      );

      for(int i = 0;
          i < AQF_REGIME_MONTH_SLOTS;
          i++)
      {
         m_monthKey[i] =
            0;

         ResetStats(
            m_monthStats[i]
         );
      }

      for(int i = 0;
          i < 2;
          i++)
      {
         ResetStats(
            m_direction[i]
         );
      }

      for(int i = 0;
          i < 3;
          i++)
      {
         ResetStats(
            m_adxBucket[i]
         );
      }

      for(int i = 0;
          i < 4;
          i++)
      {
         ResetStats(
            m_atrBucket[i]
         );

         ResetStats(
            m_directionalRSIBucket[i]
         );

         ResetStats(
            m_directionalEMABucket[i]
         );

         ResetStats(
            m_ema200Bucket[i]
         );

         ResetStats(
            m_spreadRBucket[i]
         );

         ResetStats(
            m_rangeATRBucket[i]
         );

         ResetStats(
            m_directionalER5Bucket[i]
         );

         ResetStats(
            m_directionalER10Bucket[i]
         );

         ResetStats(
            m_directionalER20Bucket[i]
         );
      }

      for(int i = 0;
          i < 5;
          i++)
      {
         ResetStats(
            m_relativeVolume20Bucket[i]
         );

         ResetStats(
            m_volumeZScore20Bucket[i]
         );
      }

      for(int i = 0;
          i < 24;
          i++)
      {
         ResetStats(
            m_hour[i]
         );
      }

      for(int i = 0;
          i < 7;
          i++)
      {
         ResetStats(
            m_weekday[i]
         );
      }
   }
};

#endif
