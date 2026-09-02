#ifndef __AQF_BOOTSTRAP_MONTE_CARLO_MQH__
#define __AQF_BOOTSTRAP_MONTE_CARLO_MQH__

#include "../Logger/Logger.mqh"
#include "DeterministicRNG.mqh"

//+------------------------------------------------------------------+
//| Bootstrap / Monte Carlo                                          |
//| Sprint 11 - Methodological Validation Layer                      |
//|                                                                  |
//| Standard IID trade bootstrap:                                    |
//| - stores closed trade results in R                               |
//| - resamples WITH replacement                                     |
//| - reports total-R and max-drawdown distributions                 |
//|                                                                  |
//| TotalR P10 is the requested pessimistic profit scenario.         |
//| For drawdown, HIGHER is worse, so P90 is the pessimistic tail.   |
//+------------------------------------------------------------------+

class CAQFBootstrapMonteCarlo
{
private:
   double m_results[];
   CAQFDeterministicRNG m_rng;

public:
   CAQFBootstrapMonteCarlo()
   {
      Reset();
   }

   void Reset()
   {
      ArrayResize(m_results, 0);
   }

   bool AddResult(const double resultR)
   {
      int size = ArraySize(m_results);

      if(ArrayResize(m_results, size + 1) != size + 1)
         return false;

      m_results[size] = resultR;
      return true;
   }

   int Count()
   {
      return ArraySize(m_results);
   }

   void Report(
      const string segmentLabel,
      int runs,
      uint seed,
      CAQFLogger &logger)
   {
      int tradeCount = ArraySize(m_results);

      if(tradeCount <= 0)
      {
         logger.Info(
            "BootstrapMC | Segment=" + segmentLabel +
            " | Trades=0 | Status=NO_DATA"
         );
         return;
      }

      if(runs < 100)
         runs = 100;

      double totalDistribution[];
      double ddDistribution[];

      if(ArrayResize(totalDistribution, runs) != runs ||
         ArrayResize(ddDistribution,    runs) != runs)
      {
         logger.Error("BootstrapMC allocation failed.");
         return;
      }

      uint state = seed;
      if(state == 0)
         state = 1;

      long nonPositiveRuns = 0;

      for(int run = 0; run < runs; run++)
      {
         double cumulativeR = 0.0;
         double peakR       = 0.0;
         double maxDD       = 0.0;

         for(int i = 0; i < tradeCount; i++)
         {
            int index = m_rng.NextIndex(state, tradeCount);
            double resultR = m_results[index];

            cumulativeR += resultR;

            if(cumulativeR > peakR)
               peakR = cumulativeR;

            double dd = peakR - cumulativeR;

            if(dd > maxDD)
               maxDD = dd;
         }

         totalDistribution[run] = cumulativeR;
         ddDistribution[run]    = maxDD;

         if(cumulativeR <= 0.0)
            nonPositiveRuns++;
      }

      ArraySort(totalDistribution);
      ArraySort(ddDistribution);

      double originalTotalR = 0.0;
      double originalPeakR  = 0.0;
      double originalMaxDD  = 0.0;

      for(int i = 0; i < tradeCount; i++)
      {
         originalTotalR += m_results[i];

         if(originalTotalR > originalPeakR)
            originalPeakR = originalTotalR;

         double dd = originalPeakR - originalTotalR;

         if(dd > originalMaxDD)
            originalMaxDD = dd;
      }

      double probabilityNonPositive =
         100.0 * (double)nonPositiveRuns / (double)runs;

      logger.Info(
         "BootstrapMC" +
         " | Segment=" + segmentLabel +
         " | Trades=" + IntegerToString(tradeCount) +
         " | Runs=" + IntegerToString(runs) +
         " | Seed=" + IntegerToString((int)seed) +
         " | OriginalTotal=" + DoubleToString(originalTotalR, 2) + "R" +
         " | TotalR_P10=" + DoubleToString(PercentileSorted(totalDistribution, 0.10), 2) + "R" +
         " | TotalR_P50=" + DoubleToString(PercentileSorted(totalDistribution, 0.50), 2) + "R" +
         " | TotalR_P90=" + DoubleToString(PercentileSorted(totalDistribution, 0.90), 2) + "R" +
         " | P_TotalR_LE_0=" + DoubleToString(probabilityNonPositive, 2) + "%"
      );

      logger.Info(
         "BootstrapDD" +
         " | Segment=" + segmentLabel +
         " | Trades=" + IntegerToString(tradeCount) +
         " | OriginalMaxDD=" + DoubleToString(originalMaxDD, 2) + "R" +
         " | MaxDD_P10=" + DoubleToString(PercentileSorted(ddDistribution, 0.10), 2) + "R" +
         " | MaxDD_P50=" + DoubleToString(PercentileSorted(ddDistribution, 0.50), 2) + "R" +
         " | MaxDD_P90_PESSIMISTIC=" + DoubleToString(PercentileSorted(ddDistribution, 0.90), 2) + "R"
      );
   }

private:
   double PercentileSorted(double &values[], double percentile)
   {
      int size = ArraySize(values);

      if(size <= 0)
         return 0.0;

      if(percentile < 0.0)
         percentile = 0.0;

      if(percentile > 1.0)
         percentile = 1.0;

      int index = (int)MathRound(percentile * (double)(size - 1));

      if(index < 0)
         index = 0;

      if(index >= size)
         index = size - 1;

      return values[index];
   }
};

#endif
