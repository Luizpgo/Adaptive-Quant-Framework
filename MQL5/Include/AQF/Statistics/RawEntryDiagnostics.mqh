#ifndef __AQF_RAW_ENTRY_DIAGNOSTICS_MQH__
#define __AQF_RAW_ENTRY_DIAGNOSTICS_MQH__

#include "../Common/TradeSignal.mqh"
#include "../Common/MarketRegime.mqh"
#include "../Logger/Logger.mqh"

#define AQF_RAW_TARGET_COUNT 6
#define AQF_RAW_ADX_BUCKETS 7
#define AQF_RAW_RSI_BUCKETS 6
#define AQF_RAW_ATR_BUCKETS 5
#define AQF_RAW_EMA_SEPARATION_BUCKETS 5
#define AQF_RAW_MOMENTUM_ALIGNMENT_BUCKETS 3

//+------------------------------------------------------------------+
//| Raw Entry Diagnostics                                            |
//|                                                                  |
//| Sprint 7 B5                                                      |
//|                                                                  |
//| Measures realized WIN/LOSS outcomes against raw entry metrics:   |
//| ADX, RSI, ATR%, EMA separation%, and momentum alignment.         |
//|                                                                  |
//| These buckets are DIAGNOSTIC ONLY. They are not trading filters. |
//+------------------------------------------------------------------+
class CAQFRawEntryDiagnostics
{
private:
   double m_targetR[AQF_RAW_TARGET_COUNT];

   long m_adxWins[AQF_RAW_TARGET_COUNT][AQF_RAW_ADX_BUCKETS];
   long m_adxLosses[AQF_RAW_TARGET_COUNT][AQF_RAW_ADX_BUCKETS];

   long m_rsiWins[AQF_RAW_TARGET_COUNT][AQF_RAW_RSI_BUCKETS];
   long m_rsiLosses[AQF_RAW_TARGET_COUNT][AQF_RAW_RSI_BUCKETS];

   long m_atrWins[AQF_RAW_TARGET_COUNT][AQF_RAW_ATR_BUCKETS];
   long m_atrLosses[AQF_RAW_TARGET_COUNT][AQF_RAW_ATR_BUCKETS];

   long m_emaSeparationWins[AQF_RAW_TARGET_COUNT][AQF_RAW_EMA_SEPARATION_BUCKETS];
   long m_emaSeparationLosses[AQF_RAW_TARGET_COUNT][AQF_RAW_EMA_SEPARATION_BUCKETS];

   long m_momentumAlignmentWins[AQF_RAW_TARGET_COUNT][AQF_RAW_MOMENTUM_ALIGNMENT_BUCKETS];
   long m_momentumAlignmentLosses[AQF_RAW_TARGET_COUNT][AQF_RAW_MOMENTUM_ALIGNMENT_BUCKETS];

   bool m_initialized;

public:
   CAQFRawEntryDiagnostics()
   {
      m_initialized = false;

      for(int i = 0; i < AQF_RAW_TARGET_COUNT; i++)
         m_targetR[i] = 0.0;

      ResetStatistics();
   }

   bool Initialize(CAQFLogger &logger)
   {
      ResetStatistics();
      m_initialized = true;

      logger.Info(
         "Raw entry diagnostics enabled: ADX | RSI | ATR% | EMA separation% | MomentumAlignment"
      );

      logger.Info(
         "Raw diagnostic buckets are observational only - NO FILTER CHANGES"
      );

      return true;
   }

   void SetTargetR(const int index, const double value)
   {
      if(index < 0 || index >= AQF_RAW_TARGET_COUNT)
         return;

      if(value <= 0.0)
         return;

      m_targetR[index] = value;
   }

   void Record(
      const int targetIndex,
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const ENUM_AQF_MOMENTUM_REGIME momentum,
      const double adx,
      const double rsi,
      const double atrPercent,
      const double emaSeparationPercent,
      const bool win)
   {
      if(!m_initialized)
         return;

      if(targetIndex < 0 || targetIndex >= AQF_RAW_TARGET_COUNT)
         return;

      int bucket = ADXBucket(adx);
      if(bucket >= 0)
      {
         if(win)
            m_adxWins[targetIndex][bucket]++;
         else
            m_adxLosses[targetIndex][bucket]++;
      }

      bucket = RSIBucket(rsi);
      if(bucket >= 0)
      {
         if(win)
            m_rsiWins[targetIndex][bucket]++;
         else
            m_rsiLosses[targetIndex][bucket]++;
      }

      bucket = ATRBucket(atrPercent);
      if(bucket >= 0)
      {
         if(win)
            m_atrWins[targetIndex][bucket]++;
         else
            m_atrLosses[targetIndex][bucket]++;
      }

      bucket = EMASeparationBucket(emaSeparationPercent);
      if(bucket >= 0)
      {
         if(win)
            m_emaSeparationWins[targetIndex][bucket]++;
         else
            m_emaSeparationLosses[targetIndex][bucket]++;
      }

      bucket = MomentumAlignmentBucket(direction, momentum);
      if(bucket >= 0)
      {
         if(win)
            m_momentumAlignmentWins[targetIndex][bucket]++;
         else
            m_momentumAlignmentLosses[targetIndex][bucket]++;
      }
   }

   string MomentumAlignmentText(
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const ENUM_AQF_MOMENTUM_REGIME momentum)
   {
      return MomentumAlignmentBucketText(
         MomentumAlignmentBucket(direction, momentum)
      );
   }

   void ReportAll(CAQFLogger &logger)
   {
      logger.Info(
         "RawEntryStats =========================================="
      );

      for(int target = 0; target < AQF_RAW_TARGET_COUNT; target++)
      {
         for(int bucket = 0; bucket < AQF_RAW_ADX_BUCKETS; bucket++)
         {
            ReportSegment(
               logger,
               target,
               "ADX",
               ADXBucketText(bucket),
               m_adxWins[target][bucket],
               m_adxLosses[target][bucket]
            );
         }

         for(int bucket = 0; bucket < AQF_RAW_RSI_BUCKETS; bucket++)
         {
            ReportSegment(
               logger,
               target,
               "RSI",
               RSIBucketText(bucket),
               m_rsiWins[target][bucket],
               m_rsiLosses[target][bucket]
            );
         }

         for(int bucket = 0; bucket < AQF_RAW_ATR_BUCKETS; bucket++)
         {
            ReportSegment(
               logger,
               target,
               "ATR_PCT",
               ATRBucketText(bucket),
               m_atrWins[target][bucket],
               m_atrLosses[target][bucket]
            );
         }

         for(int bucket = 0; bucket < AQF_RAW_EMA_SEPARATION_BUCKETS; bucket++)
         {
            ReportSegment(
               logger,
               target,
               "EMA_SEPARATION_PCT",
               EMASeparationBucketText(bucket),
               m_emaSeparationWins[target][bucket],
               m_emaSeparationLosses[target][bucket]
            );
         }

         for(int bucket = 0; bucket < AQF_RAW_MOMENTUM_ALIGNMENT_BUCKETS; bucket++)
         {
            ReportSegment(
               logger,
               target,
               "MOMENTUM_ALIGNMENT",
               MomentumAlignmentBucketText(bucket),
               m_momentumAlignmentWins[target][bucket],
               m_momentumAlignmentLosses[target][bucket]
            );
         }
      }

      logger.Info(
         "RawEntryStats =========================================="
      );
   }

private:
   void ResetStatistics()
   {
      for(int target = 0; target < AQF_RAW_TARGET_COUNT; target++)
      {
         for(int bucket = 0; bucket < AQF_RAW_ADX_BUCKETS; bucket++)
         {
            m_adxWins[target][bucket] = 0;
            m_adxLosses[target][bucket] = 0;
         }

         for(int bucket = 0; bucket < AQF_RAW_RSI_BUCKETS; bucket++)
         {
            m_rsiWins[target][bucket] = 0;
            m_rsiLosses[target][bucket] = 0;
         }

         for(int bucket = 0; bucket < AQF_RAW_ATR_BUCKETS; bucket++)
         {
            m_atrWins[target][bucket] = 0;
            m_atrLosses[target][bucket] = 0;
         }

         for(int bucket = 0; bucket < AQF_RAW_EMA_SEPARATION_BUCKETS; bucket++)
         {
            m_emaSeparationWins[target][bucket] = 0;
            m_emaSeparationLosses[target][bucket] = 0;
         }

         for(int bucket = 0; bucket < AQF_RAW_MOMENTUM_ALIGNMENT_BUCKETS; bucket++)
         {
            m_momentumAlignmentWins[target][bucket] = 0;
            m_momentumAlignmentLosses[target][bucket] = 0;
         }
      }
   }

   int ADXBucket(const double value)
   {
      if(value < 0.0)
         return -1;

      if(value < 15.0)
         return 0;

      if(value < 20.0)
         return 1;

      if(value < 25.0)
         return 2;

      if(value < 30.0)
         return 3;

      if(value < 35.0)
         return 4;

      if(value < 40.0)
         return 5;

      return 6;
   }

   int RSIBucket(const double value)
   {
      if(value < 0.0 || value > 100.0)
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

   int ATRBucket(const double value)
   {
      if(value < 0.0)
         return -1;

      if(value < 0.025)
         return 0;

      if(value < 0.040)
         return 1;

      if(value < 0.055)
         return 2;

      if(value < 0.075)
         return 3;

      return 4;
   }

   int EMASeparationBucket(const double value)
   {
      double absoluteValue = MathAbs(value);

      if(absoluteValue < 0.005)
         return 0;

      if(absoluteValue < 0.010)
         return 1;

      if(absoluteValue < 0.020)
         return 2;

      if(absoluteValue < 0.040)
         return 3;

      return 4;
   }

   int MomentumAlignmentBucket(
      const ENUM_AQF_SIGNAL_DIRECTION direction,
      const ENUM_AQF_MOMENTUM_REGIME momentum)
   {
      if(direction != AQF_SIGNAL_BUY &&
         direction != AQF_SIGNAL_SELL)
      {
         return -1;
      }

      if(momentum == AQF_MOMENTUM_NEUTRAL)
         return 1;

      if(
         (direction == AQF_SIGNAL_BUY &&
          momentum == AQF_MOMENTUM_BULLISH)
         ||
         (direction == AQF_SIGNAL_SELL &&
          momentum == AQF_MOMENTUM_BEARISH)
      )
      {
         return 0;
      }

      if(
         (direction == AQF_SIGNAL_BUY &&
          momentum == AQF_MOMENTUM_BEARISH)
         ||
         (direction == AQF_SIGNAL_SELL &&
          momentum == AQF_MOMENTUM_BULLISH)
      )
      {
         return 2;
      }

      return -1;
   }

   string ADXBucketText(const int bucket)
   {
      if(bucket == 0) return "<15";
      if(bucket == 1) return "15-19";
      if(bucket == 2) return "20-24";
      if(bucket == 3) return "25-29";
      if(bucket == 4) return "30-34";
      if(bucket == 5) return "35-39";
      if(bucket == 6) return "40+";

      return "UNKNOWN";
   }

   string RSIBucketText(const int bucket)
   {
      if(bucket == 0) return "<40";
      if(bucket == 1) return "40-44";
      if(bucket == 2) return "45-49";
      if(bucket == 3) return "50-54";
      if(bucket == 4) return "55-59";
      if(bucket == 5) return "60+";

      return "UNKNOWN";
   }

   string ATRBucketText(const int bucket)
   {
      if(bucket == 0) return "<0.025";
      if(bucket == 1) return "0.025-0.039";
      if(bucket == 2) return "0.040-0.054";
      if(bucket == 3) return "0.055-0.074";
      if(bucket == 4) return "0.075+";

      return "UNKNOWN";
   }

   string EMASeparationBucketText(const int bucket)
   {
      if(bucket == 0) return "<0.005";
      if(bucket == 1) return "0.005-0.009";
      if(bucket == 2) return "0.010-0.019";
      if(bucket == 3) return "0.020-0.039";
      if(bucket == 4) return "0.040+";

      return "UNKNOWN";
   }

   string MomentumAlignmentBucketText(const int bucket)
   {
      if(bucket == 0) return "ALIGNED";
      if(bucket == 1) return "NEUTRAL";
      if(bucket == 2) return "OPPOSED";

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
      long resolved = wins + losses;

      if(resolved <= 0)
         return;

      double winRate =
         ((double)wins / (double)resolved) *
         100.0;

      double expectancyR =
         (
            ((double)wins * m_targetR[targetIndex])
            -
            (double)losses
         )
         /
         (double)resolved;

      logger.Info(
         "RawEntryStats" +
         " | Target=" +
         DoubleToString(m_targetR[targetIndex], 2) +
         "R" +
         " | Dimension=" +
         dimension +
         " | Bucket=" +
         bucket +
         " | Resolved=" +
         IntegerToString((int)resolved) +
         " | Wins=" +
         IntegerToString((int)wins) +
         " | Losses=" +
         IntegerToString((int)losses) +
         " | WinRate=" +
         DoubleToString(winRate, 2) +
         "%" +
         " | Expectancy=" +
         DoubleToString(expectancyR, 3) +
         "R"
      );
   }
};

#endif
