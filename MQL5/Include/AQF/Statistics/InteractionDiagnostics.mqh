#ifndef __AQF_INTERACTION_DIAGNOSTICS_MQH__
#define __AQF_INTERACTION_DIAGNOSTICS_MQH__

#include "../Common/TradeSignal.mqh"
#include "../Common/MarketRegime.mqh"
#include "../Logger/Logger.mqh"

#define AQF_INTERACTION_TARGET_COUNT 6
#define AQF_INTERACTION_DIRECTION_BUCKETS 2
#define AQF_INTERACTION_ADX_BUCKETS 4
#define AQF_INTERACTION_ATR_BUCKETS 4
#define AQF_INTERACTION_DIRECTIONAL_RSI_BUCKETS 6

//+------------------------------------------------------------------+
//| Interaction Diagnostics                                          |
//|                                                                  |
//| Sprint 7 B6                                                      |
//|                                                                  |
//| Measures interactions between entry variables without changing   |
//| any trading filter or execution rule.                            |
//|                                                                  |
//| Dimensions:                                                      |
//| - Directional RSI                                                |
//| - Direction x ADX                                                |
//| - ADX x ATR%                                                     |
//| - Direction x ADX x ATR%                                         |
//|                                                                  |
//| Diagnostic only. NO ORDER EXECUTION.                             |
//+------------------------------------------------------------------+
class CAQFInteractionDiagnostics
{
private:
   double m_targetR[AQF_INTERACTION_TARGET_COUNT];

   long m_directionalRsiWins
      [AQF_INTERACTION_TARGET_COUNT]
      [AQF_INTERACTION_DIRECTIONAL_RSI_BUCKETS];

   long m_directionalRsiLosses
      [AQF_INTERACTION_TARGET_COUNT]
      [AQF_INTERACTION_DIRECTIONAL_RSI_BUCKETS];

   long m_directionAdxWins
      [AQF_INTERACTION_TARGET_COUNT]
      [AQF_INTERACTION_DIRECTION_BUCKETS]
      [AQF_INTERACTION_ADX_BUCKETS];

   long m_directionAdxLosses
      [AQF_INTERACTION_TARGET_COUNT]
      [AQF_INTERACTION_DIRECTION_BUCKETS]
      [AQF_INTERACTION_ADX_BUCKETS];

   long m_adxAtrWins
      [AQF_INTERACTION_TARGET_COUNT]
      [AQF_INTERACTION_ADX_BUCKETS]
      [AQF_INTERACTION_ATR_BUCKETS];

   long m_adxAtrLosses
      [AQF_INTERACTION_TARGET_COUNT]
      [AQF_INTERACTION_ADX_BUCKETS]
      [AQF_INTERACTION_ATR_BUCKETS];

   long m_directionAdxAtrWins
      [AQF_INTERACTION_TARGET_COUNT]
      [AQF_INTERACTION_DIRECTION_BUCKETS]
      [AQF_INTERACTION_ADX_BUCKETS]
      [AQF_INTERACTION_ATR_BUCKETS];

   long m_directionAdxAtrLosses
      [AQF_INTERACTION_TARGET_COUNT]
      [AQF_INTERACTION_DIRECTION_BUCKETS]
      [AQF_INTERACTION_ADX_BUCKETS]
      [AQF_INTERACTION_ATR_BUCKETS];

   bool m_initialized;

public:
   CAQFInteractionDiagnostics()
   {
      m_initialized = false;

      for(int i = 0;
          i < AQF_INTERACTION_TARGET_COUNT;
          i++)
      {
         m_targetR[i] = 0.0;
      }

      ResetStatistics();
   }

   bool Initialize(
      CAQFLogger &logger)
   {
      ResetStatistics();

      m_initialized = true;

      logger.Info(
         "Interaction diagnostics enabled: DirectionalRSI | DirectionxADX | ADXxATR | DirectionxADXxATR"
      );

      logger.Info(
         "Interaction diagnostic buckets are observational only - NO FILTER CHANGES"
      );

      return true;
   }

   void SetTargetR(
      const int index,
      const double value)
   {
      if(index < 0 ||
         index >= AQF_INTERACTION_TARGET_COUNT)
      {
         return;
      }

      if(value <= 0.0)
         return;

      m_targetR[index] = value;
   }

   void Record(
      const int targetIndex,
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const double adx,
      const double rsi,
      const double atrPercent,
      const bool win)
   {
      if(!m_initialized)
         return;

      if(targetIndex < 0 ||
         targetIndex >= AQF_INTERACTION_TARGET_COUNT)
      {
         return;
      }

      int directionBucket =
         DirectionBucket(direction);

      int adxBucket =
         ADXBucket(adx);

      int atrBucket =
         ATRBucket(atrPercent);

      int directionalRsiBucket =
         DirectionalRSIBucket(
            direction,
            rsi
         );

      if(directionalRsiBucket >= 0)
      {
         if(win)
            m_directionalRsiWins[targetIndex][directionalRsiBucket]++;
         else
            m_directionalRsiLosses[targetIndex][directionalRsiBucket]++;
      }

      if(directionBucket >= 0 &&
         adxBucket >= 0)
      {
         if(win)
            m_directionAdxWins[targetIndex][directionBucket][adxBucket]++;
         else
            m_directionAdxLosses[targetIndex][directionBucket][adxBucket]++;
      }

      if(adxBucket >= 0 &&
         atrBucket >= 0)
      {
         if(win)
            m_adxAtrWins[targetIndex][adxBucket][atrBucket]++;
         else
            m_adxAtrLosses[targetIndex][adxBucket][atrBucket]++;
      }

      if(directionBucket >= 0 &&
         adxBucket >= 0 &&
         atrBucket >= 0)
      {
         if(win)
            m_directionAdxAtrWins[targetIndex][directionBucket][adxBucket][atrBucket]++;
         else
            m_directionAdxAtrLosses[targetIndex][directionBucket][adxBucket][atrBucket]++;
      }
   }

   void ReportAll(
      CAQFLogger &logger)
   {
      logger.Info(
         "InteractionStats ======================================="
      );

      for(int target = 0;
          target < AQF_INTERACTION_TARGET_COUNT;
          target++)
      {
         for(int rsiBucket = 0;
             rsiBucket < AQF_INTERACTION_DIRECTIONAL_RSI_BUCKETS;
             rsiBucket++)
         {
            ReportSegment(
               logger,
               target,
               "DIRECTIONAL_RSI",
               DirectionalRSIBucketText(rsiBucket),
               m_directionalRsiWins[target][rsiBucket],
               m_directionalRsiLosses[target][rsiBucket]
            );
         }

         for(int directionBucket = 0;
             directionBucket < AQF_INTERACTION_DIRECTION_BUCKETS;
             directionBucket++)
         {
            for(int adxBucket = 0;
                adxBucket < AQF_INTERACTION_ADX_BUCKETS;
                adxBucket++)
            {
               ReportSegment(
                  logger,
                  target,
                  "DIRECTION_X_ADX",
                  DirectionBucketText(directionBucket) +
                  "|" +
                  ADXBucketText(adxBucket),
                  m_directionAdxWins[target][directionBucket][adxBucket],
                  m_directionAdxLosses[target][directionBucket][adxBucket]
               );
            }
         }

         for(int adxBucket = 0;
             adxBucket < AQF_INTERACTION_ADX_BUCKETS;
             adxBucket++)
         {
            for(int atrBucket = 0;
                atrBucket < AQF_INTERACTION_ATR_BUCKETS;
                atrBucket++)
            {
               ReportSegment(
                  logger,
                  target,
                  "ADX_X_ATR",
                  ADXBucketText(adxBucket) +
                  "|" +
                  ATRBucketText(atrBucket),
                  m_adxAtrWins[target][adxBucket][atrBucket],
                  m_adxAtrLosses[target][adxBucket][atrBucket]
               );
            }
         }

         for(int directionBucket = 0;
             directionBucket < AQF_INTERACTION_DIRECTION_BUCKETS;
             directionBucket++)
         {
            for(int adxBucket = 0;
                adxBucket < AQF_INTERACTION_ADX_BUCKETS;
                adxBucket++)
            {
               for(int atrBucket = 0;
                   atrBucket < AQF_INTERACTION_ATR_BUCKETS;
                   atrBucket++)
               {
                  ReportSegment(
                     logger,
                     target,
                     "DIRECTION_X_ADX_X_ATR",
                     DirectionBucketText(directionBucket) +
                     "|" +
                     ADXBucketText(adxBucket) +
                     "|" +
                     ATRBucketText(atrBucket),
                     m_directionAdxAtrWins[target][directionBucket][adxBucket][atrBucket],
                     m_directionAdxAtrLosses[target][directionBucket][adxBucket][atrBucket]
                  );
               }
            }
         }
      }

      logger.Info(
         "InteractionStats ======================================="
      );
   }

private:
   void ResetStatistics()
   {
      for(int target = 0;
          target < AQF_INTERACTION_TARGET_COUNT;
          target++)
      {
         for(int rsiBucket = 0;
             rsiBucket < AQF_INTERACTION_DIRECTIONAL_RSI_BUCKETS;
             rsiBucket++)
         {
            m_directionalRsiWins[target][rsiBucket] = 0;
            m_directionalRsiLosses[target][rsiBucket] = 0;
         }

         for(int directionBucket = 0;
             directionBucket < AQF_INTERACTION_DIRECTION_BUCKETS;
             directionBucket++)
         {
            for(int adxBucket = 0;
                adxBucket < AQF_INTERACTION_ADX_BUCKETS;
                adxBucket++)
            {
               m_directionAdxWins[target][directionBucket][adxBucket] = 0;
               m_directionAdxLosses[target][directionBucket][adxBucket] = 0;
            }
         }

         for(int adxBucket = 0;
             adxBucket < AQF_INTERACTION_ADX_BUCKETS;
             adxBucket++)
         {
            for(int atrBucket = 0;
                atrBucket < AQF_INTERACTION_ATR_BUCKETS;
                atrBucket++)
            {
               m_adxAtrWins[target][adxBucket][atrBucket] = 0;
               m_adxAtrLosses[target][adxBucket][atrBucket] = 0;
            }
         }

         for(int directionBucket = 0;
             directionBucket < AQF_INTERACTION_DIRECTION_BUCKETS;
             directionBucket++)
         {
            for(int adxBucket = 0;
                adxBucket < AQF_INTERACTION_ADX_BUCKETS;
                adxBucket++)
            {
               for(int atrBucket = 0;
                   atrBucket < AQF_INTERACTION_ATR_BUCKETS;
                   atrBucket++)
               {
                  m_directionAdxAtrWins[target][directionBucket][adxBucket][atrBucket] = 0;
                  m_directionAdxAtrLosses[target][directionBucket][adxBucket][atrBucket] = 0;
               }
            }
         }
      }
   }

   int DirectionBucket(
      const ENUM_AQF_SIGNAL_DIRECTION direction)
   {
      if(direction == AQF_SIGNAL_BUY)
         return 0;

      if(direction == AQF_SIGNAL_SELL)
         return 1;

      return -1;
   }

   int ADXBucket(
      const double value)
   {
      if(value < 0.0)
         return -1;

      if(value < 25.0)
         return 0;

      if(value < 30.0)
         return 1;

      if(value < 40.0)
         return 2;

      return 3;
   }

   int ATRBucket(
      const double value)
   {
      if(value < 0.0)
         return -1;

      if(value < 0.040)
         return 0;

      if(value < 0.055)
         return 1;

      if(value < 0.075)
         return 2;

      return 3;
   }

   double DirectionalRSIValue(
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const double rsi)
   {
      if(rsi < 0.0 ||
         rsi > 100.0)
      {
         return -1.0;
      }

      if(direction == AQF_SIGNAL_BUY)
         return rsi;

      if(direction == AQF_SIGNAL_SELL)
         return 100.0 - rsi;

      return -1.0;
   }

   int DirectionalRSIBucket(
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const double rsi)
   {
      double value =
         DirectionalRSIValue(
            direction,
            rsi
         );

      if(value < 0.0)
         return -1;

      if(value < 40.0)
         return 0;

      if(value < 45.0)
         return 1;

      if(value < 50.0)
         return 2;

      if(value < 55.0)
         return 3;

      if(value < 60.0)
         return 4;

      return 5;
   }

   string DirectionBucketText(
      const int bucket)
   {
      if(bucket == 0)
         return "BUY";

      if(bucket == 1)
         return "SELL";

      return "UNKNOWN";
   }

   string ADXBucketText(
      const int bucket)
   {
      if(bucket == 0)
         return "<25";

      if(bucket == 1)
         return "25-29";

      if(bucket == 2)
         return "30-39";

      if(bucket == 3)
         return "40+";

      return "UNKNOWN";
   }

   string ATRBucketText(
      const int bucket)
   {
      if(bucket == 0)
         return "<0.040";

      if(bucket == 1)
         return "0.040-0.054";

      if(bucket == 2)
         return "0.055-0.074";

      if(bucket == 3)
         return "0.075+";

      return "UNKNOWN";
   }

   string DirectionalRSIBucketText(
      const int bucket)
   {
      if(bucket == 0)
         return "<40";

      if(bucket == 1)
         return "40-44";

      if(bucket == 2)
         return "45-49";

      if(bucket == 3)
         return "50-54";

      if(bucket == 4)
         return "55-59";

      if(bucket == 5)
         return "60+";

      return "UNKNOWN";
   }

   void ReportSegment(
      CAQFLogger &logger,
      const int targetIndex,
      const string dimension,
      const string bucket,
      const long wins,
      const long losses)
   {
      long resolved =
         wins +
         losses;

      if(resolved <= 0)
         return;

      double winRate =
         (
            (double)wins /
            (double)resolved
         ) * 100.0;

      double expectancyR =
         (
            (
               (double)wins *
               m_targetR[targetIndex]
            )
            -
            (double)losses
         )
         /
         (double)resolved;

      logger.Info(
         "InteractionStats" +
         " | Target=" +
         DoubleToString(
            m_targetR[targetIndex],
            2) +
         "R" +
         " | Dimension=" +
         dimension +
         " | Bucket=" +
         bucket +
         " | Resolved=" +
         IntegerToString(
            (int)resolved) +
         " | Wins=" +
         IntegerToString(
            (int)wins) +
         " | Losses=" +
         IntegerToString(
            (int)losses) +
         " | WinRate=" +
         DoubleToString(
            winRate,
            2) +
         "%" +
         " | Expectancy=" +
         DoubleToString(
            expectancyR,
            3) +
         "R"
      );
   }
};

#endif
