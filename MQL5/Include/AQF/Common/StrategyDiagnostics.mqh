#ifndef __AQF_STRATEGY_DIAGNOSTICS_MQH__
#define __AQF_STRATEGY_DIAGNOSTICS_MQH__

#include "TradeSignal.mqh"
#include "StrategyType.mqh"

//+------------------------------------------------------------------+
//| Strategy diagnostics                                             |
//|                                                                  |
//| Measures what the Strategy layer is actually doing.              |
//+------------------------------------------------------------------+
class CAQFStrategyDiagnostics
{
private:

   long m_evaluations;

   long m_noStrategy;
   long m_trendFollowingSelected;

   long m_strategyEvaluationFailed;

   long m_buySignals;
   long m_sellSignals;
   long m_noDirectionSignals;

   long m_validSignals;
   long m_invalidSignals;

   long m_lowQuality;
   long m_mediumQuality;
   long m_highQuality;

   long m_confidenceBelow60;
   long m_confidence60To79;
   long m_confidence80Plus;

   long m_reportInterval;
   long m_lastReportEvaluation;

public:

   //==============================================================
   // Constructor
   //==============================================================
   CAQFStrategyDiagnostics()
   {
      m_reportInterval = 1000;

      Reset();
   }

   //==============================================================
   // Reset
   //==============================================================
   void Reset()
   {
      m_evaluations = 0;

      m_noStrategy = 0;
      m_trendFollowingSelected = 0;

      m_strategyEvaluationFailed = 0;

      m_buySignals = 0;
      m_sellSignals = 0;
      m_noDirectionSignals = 0;

      m_validSignals = 0;
      m_invalidSignals = 0;

      m_lowQuality = 0;
      m_mediumQuality = 0;
      m_highQuality = 0;

      m_confidenceBelow60 = 0;
      m_confidence60To79 = 0;
      m_confidence80Plus = 0;

      m_lastReportEvaluation = 0;
   }

   //==============================================================
   // Report Interval
   //==============================================================
   void SetReportInterval(
      const long interval)
   {
      if(interval > 0)
         m_reportInterval = interval;
   }

   //==============================================================
   // Evaluation
   //==============================================================
   void RecordEvaluation()
   {
      m_evaluations++;
   }

   //==============================================================
   // Selector result
   //==============================================================
   void RecordNoStrategy()
   {
      m_noStrategy++;
   }

   void RecordStrategySelected(
      const ENUM_AQF_STRATEGY_TYPE strategy)
   {
      if(strategy ==
         AQF_STRATEGY_TREND_FOLLOWING)
      {
         m_trendFollowingSelected++;
      }
   }

   //==============================================================
   // Evaluation failure
   //==============================================================
   void RecordEvaluationFailure()
   {
      m_strategyEvaluationFailed++;
   }

   //==============================================================
   // Signal result
   //==============================================================
   void RecordSignal(
      const CAQFTradeSignal &signal)
   {
      //------------------------------------------------------------
      // Direction
      //------------------------------------------------------------

      if(signal.Direction ==
         AQF_SIGNAL_BUY)
      {
         m_buySignals++;
      }
      else if(signal.Direction ==
              AQF_SIGNAL_SELL)
      {
         m_sellSignals++;
      }
      else
      {
         m_noDirectionSignals++;
      }

      //------------------------------------------------------------
      // Validity
      //------------------------------------------------------------

      if(signal.Valid)
         m_validSignals++;
      else
         m_invalidSignals++;

      //------------------------------------------------------------
      // Quality
      //------------------------------------------------------------

      if(signal.Quality ==
         AQF_SIGNAL_QUALITY_LOW)
      {
         m_lowQuality++;
      }
      else if(signal.Quality ==
              AQF_SIGNAL_QUALITY_MEDIUM)
      {
         m_mediumQuality++;
      }
      else if(signal.Quality ==
              AQF_SIGNAL_QUALITY_HIGH)
      {
         m_highQuality++;
      }

      //------------------------------------------------------------
      // Confidence bands
      //------------------------------------------------------------

      if(signal.Confidence < 60.0)
      {
         m_confidenceBelow60++;
      }
      else if(signal.Confidence < 80.0)
      {
         m_confidence60To79++;
      }
      else
      {
         m_confidence80Plus++;
      }
   }

   //==============================================================
   // Should Report?
   //==============================================================
   bool ShouldReport()
   {
      if(m_evaluations <= 0)
         return false;

      if((m_evaluations -
          m_lastReportEvaluation) <
         m_reportInterval)
      {
         return false;
      }

      m_lastReportEvaluation =
         m_evaluations;

      return true;
   }

   //==============================================================
   // Summary
   //==============================================================
   string Summary()
   {
      double signalRate = 0.0;
      double noStrategyRate = 0.0;

      if(m_evaluations > 0)
      {
         signalRate =
            ((double)m_validSignals /
             (double)m_evaluations) *
            100.0;

         noStrategyRate =
            ((double)m_noStrategy /
             (double)m_evaluations) *
            100.0;
      }

      return
         "StrategyStats" +
         " | Eval=" +
         IntegerToString(
            (int)m_evaluations) +

         " | NoStrategy=" +
         IntegerToString(
            (int)m_noStrategy) +

         " | NoStrategy%=" +
         DoubleToString(
            noStrategyRate,
            2) +

         " | TrendSelected=" +
         IntegerToString(
            (int)m_trendFollowingSelected) +

         " | EvalFailed=" +
         IntegerToString(
            (int)m_strategyEvaluationFailed) +

         " | BUY=" +
         IntegerToString(
            (int)m_buySignals) +

         " | SELL=" +
         IntegerToString(
            (int)m_sellSignals) +

         " | NONE=" +
         IntegerToString(
            (int)m_noDirectionSignals) +

         " | Valid=" +
         IntegerToString(
            (int)m_validSignals) +

         " | Invalid=" +
         IntegerToString(
            (int)m_invalidSignals) +

         " | SignalRate%=" +
         DoubleToString(
            signalRate,
            3) +

         " | QLow=" +
         IntegerToString(
            (int)m_lowQuality) +

         " | QMedium=" +
         IntegerToString(
            (int)m_mediumQuality) +

         " | QHigh=" +
         IntegerToString(
            (int)m_highQuality) +

         " | Conf<60=" +
         IntegerToString(
            (int)m_confidenceBelow60) +

         " | Conf60-79=" +
         IntegerToString(
            (int)m_confidence60To79) +

         " | Conf80+=" +
         IntegerToString(
            (int)m_confidence80Plus);
   }
};

#endif