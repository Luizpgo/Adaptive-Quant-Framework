#ifndef __AQF_VALIDATION_SUITE_MQH__
#define __AQF_VALIDATION_SUITE_MQH__

#include "../Common/MarketSnapshot.mqh"
#include "../Common/TradeRequest.mqh"
#include "../Logger/Logger.mqh"
#include "ValidationSplit.mqh"
#include "HypothesisValidationSimulator.mqh"
#include "RandomDirectionBenchmarkSimulator.mqh"
#include "H3MatchedRandomDirectionBenchmarkSimulator.mqh"
#include "H3PairedDirectionalRandomizationSimulator.mqh"
#include "WalkForwardValidationSimulator.mqh"

//+------------------------------------------------------------------+
//| AQF Validation Suite                                             |
//| Sprint 11-12 - Methodological Validation Layer                      |
//|                                                                  |
//| Additional validation only. Existing AQF simulators remain       |
//| untouched and continue running independently.                    |
//+------------------------------------------------------------------+

class CAQFValidationSuite
{
private:
   CAQFValidationSplit m_split;
   CAQFHypothesisValidationSimulator m_hypothesisValidation;
   CAQFRandomDirectionBenchmarkSimulator m_randomBenchmark;
   CAQFH3MatchedRandomDirectionBenchmarkSimulator m_h3MatchedRandomBenchmark;
   CAQFH3PairedDirectionalRandomizationSimulator m_h3PairedDirectionalRandomization;
   CAQFWalkForwardValidationSimulator m_walkForward;

   bool m_initialized;

public:
   CAQFValidationSuite()
   {
      m_initialized = false;
   }

   bool Initialize(CAQFLogger &logger)
   {
      if(!m_split.Initialize(logger))
      {
         logger.Error("ValidationSplit initialization failed.");
         return false;
      }

      if(!m_hypothesisValidation.Initialize(logger))
      {
         logger.Error("HypothesisValidationSimulator initialization failed.");
         return false;
      }

      if(!m_randomBenchmark.Initialize(logger))
      {
         logger.Error("RandomDirectionBenchmarkSimulator initialization failed.");
         return false;
      }

      if(!m_h3MatchedRandomBenchmark.Initialize(logger))
      {
         logger.Error("H3MatchedRandomDirectionBenchmarkSimulator initialization failed.");
         return false;
      }

      if(!m_h3PairedDirectionalRandomization.Initialize(logger))
      {
         logger.Error("H3PairedDirectionalRandomizationSimulator initialization failed.");
         return false;
      }

      if(!m_walkForward.Initialize(logger))
      {
         logger.Error("WalkForwardValidationSimulator initialization failed.");
         return false;
      }

      m_initialized = true;

      logger.Info(
         "AQF ValidationSuite initialized - additional validation layer only."
      );

      return true;
   }

   void Update(
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return;

      m_hypothesisValidation.Update(
         market,
         logger
      );

      m_randomBenchmark.Update(
         market,
         logger
      );

      m_h3MatchedRandomBenchmark.Update(
         market,
         logger
      );

      m_h3PairedDirectionalRandomization.Update(
         market,
         logger
      );

      m_walkForward.Update(
         market,
         logger
      );
   }

   bool Register(
      const CAQFTradeRequest &request,
      const CAQFMarketSnapshot &market,
      CAQFLogger &logger)
   {
      if(!m_initialized)
         return false;

      if(!m_walkForward.Register(
            request,
            market,
            logger))
      {
         return false;
      }

      datetime eventTime =
         request.SignalTime;

      if(eventTime <= 0)
         eventTime = market.Time;

      ENUM_AQF_VALIDATION_SEGMENT segment =
         m_split.Resolve(eventTime);

      if(segment == AQF_VALIDATION_OUTSIDE)
         return true;

      if(!m_hypothesisValidation.Register(
            request,
            market,
            segment,
            logger))
      {
         return false;
      }

      if(!m_randomBenchmark.Register(
            request,
            market,
            segment,
            logger))
      {
         return false;
      }

      if(!m_h3MatchedRandomBenchmark.Register(
            request,
            market,
            segment,
            logger))
      {
         return false;
      }

      if(!m_h3PairedDirectionalRandomization.Register(
            request,
            market,
            segment,
            logger))
      {
         return false;
      }

      return true;
   }

   void Shutdown(CAQFLogger &logger)
   {
      if(!m_initialized)
         return;

      m_hypothesisValidation.Shutdown(logger);
      m_randomBenchmark.Shutdown(logger);
      m_h3MatchedRandomBenchmark.Shutdown(logger);
      m_h3PairedDirectionalRandomization.Shutdown(logger);
      m_walkForward.Shutdown(logger);

      ReportComparison(
         AQF_VALIDATION_IN_SAMPLE,
         logger
      );

      ReportComparison(
         AQF_VALIDATION_OOS_RETROSPECTIVE,
         logger
      );

      ReportMatchedH3Comparison(
         AQF_VALIDATION_IN_SAMPLE,
         logger
      );

      ReportMatchedH3Comparison(
         AQF_VALIDATION_OOS_RETROSPECTIVE,
         logger
      );

      m_initialized = false;
   }

private:
   void ReportComparison(
      const ENUM_AQF_VALIDATION_SEGMENT segment,
      CAQFLogger &logger)
   {
      long h3N =
         m_hypothesisValidation.H3Resolved(
            segment
         );

      long randomN =
         m_randomBenchmark.Resolved(
            segment
         );

      double h3Exp =
         m_hypothesisValidation.H3Expectancy(
            segment
         );

      double randomExp =
         m_randomBenchmark.Expectancy(
            segment
         );

      double h3DD =
         m_hypothesisValidation.H3MaxDD(
            segment
         );

      double randomDD =
         m_randomBenchmark.MaxDD(
            segment
         );

      logger.Info(
         "ValidationComparison" +
         " | Segment=" + SegmentText(segment) +
         " | Control=BROAD_H2_GATE_RANDOM_DIRECTION_50_50" +
         " | H3_N=" + IntegerToString((int)h3N) +
         " | H3_Expectancy=" + DoubleToString(h3Exp, 3) + "R" +
         " | H3_MaxDD=" + DoubleToString(h3DD, 2) + "R" +
         " | Random_N=" + IntegerToString((int)randomN) +
         " | Random_Expectancy=" + DoubleToString(randomExp, 3) + "R" +
         " | Random_MaxDD=" + DoubleToString(randomDD, 2) + "R" +
         " | DeltaExpectancy_H3_minus_Random=" +
         DoubleToString(h3Exp - randomExp, 3) + "R"
      );
   }


   void ReportMatchedH3Comparison(
      const ENUM_AQF_VALIDATION_SEGMENT segment,
      CAQFLogger &logger)
   {
      long h3N =
         m_hypothesisValidation.H3Resolved(
            segment
         );

      long randomN =
         m_h3MatchedRandomBenchmark.Resolved(
            segment
         );

      double h3Exp =
         m_hypothesisValidation.H3Expectancy(
            segment
         );

      double randomExp =
         m_h3MatchedRandomBenchmark.Expectancy(
            segment
         );

      double h3DD =
         m_hypothesisValidation.H3MaxDD(
            segment
         );

      double randomDD =
         m_h3MatchedRandomBenchmark.MaxDD(
            segment
         );

      logger.Info(
         "ValidationMatchedComparison" +
         " | Segment=" +
         SegmentText(
            segment) +
         " | Control=H3_MATCHED_CANDIDATE_RANDOM_DIRECTION_50_50" +
         " | H3_N=" +
         IntegerToString(
            (int)h3N) +
         " | H3_Expectancy=" +
         DoubleToString(
            h3Exp,
            3) +
         "R" +
         " | H3_MaxDD=" +
         DoubleToString(
            h3DD,
            2) +
         "R" +
         " | Random_N=" +
         IntegerToString(
            (int)randomN) +
         " | Random_Expectancy=" +
         DoubleToString(
            randomExp,
            3) +
         "R" +
         " | Random_MaxDD=" +
         DoubleToString(
            randomDD,
            2) +
         "R" +
         " | DeltaExpectancy_H3_minus_MatchedRandom=" +
         DoubleToString(
            h3Exp -
            randomExp,
            3) +
         "R"
      );
   }

   string SegmentText(const ENUM_AQF_VALIDATION_SEGMENT segment)
   {
      if(segment == AQF_VALIDATION_IN_SAMPLE)
         return "IN_SAMPLE";

      if(segment == AQF_VALIDATION_OOS_RETROSPECTIVE)
         return "OOS_RETROSPECTIVE";

      return "OUTSIDE";
   }
};

#endif
