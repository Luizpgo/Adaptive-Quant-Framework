#ifndef __AQF_VALIDATION_SPLIT_MQH__
#define __AQF_VALIDATION_SPLIT_MQH__

#include "../Logger/Logger.mqh"

//+------------------------------------------------------------------+
//| Validation Split                                                 |
//| Sprint 11 - Methodological Validation Layer                      |
//|                                                                  |
//| Default retrospective split:                                    |
//|   IN_SAMPLE         = 2022.01.01 <= t < 2025.01.01              |
//|   OOS_RETROSPECTIVE = 2025.01.01 <= t                           |
//|                                                                  |
//| IMPORTANT                                                        |
//| 2025+ has already been inspected during prior AQF research.      |
//| It cannot be restored retroactively as a pristine untouched OOS. |
//+------------------------------------------------------------------+

enum ENUM_AQF_VALIDATION_SEGMENT
{
   AQF_VALIDATION_OUTSIDE = 0,
   AQF_VALIDATION_IN_SAMPLE,
   AQF_VALIDATION_OOS_RETROSPECTIVE
};

class CAQFValidationSplit
{
private:
   datetime m_inSampleStart;
   datetime m_oosStart;

public:
   CAQFValidationSplit()
   {
      m_inSampleStart = D'2022.01.01 00:00';
      m_oosStart      = D'2025.01.01 00:00';
   }

   bool Initialize(CAQFLogger &logger)
   {
      logger.Info(
         "ValidationSplit | IN_SAMPLE=[2022.01.01,2025.01.01) | OOS_RETROSPECTIVE=[2025.01.01,+INF)"
      );

      logger.Warning(
         "METHODOLOGY: 2025+ was already inspected in prior AQF iterations; treat it as retrospective OOS, NOT a pristine untouched holdout."
      );

      logger.Warning(
         "METHODOLOGY: new hypothesis selection must stay inside IN_SAMPLE; a genuinely untouched final holdout must be predeclared before inspection."
      );

      return true;
   }

   ENUM_AQF_VALIDATION_SEGMENT Resolve(const datetime eventTime)
   {
      if(eventTime <= 0)
         return AQF_VALIDATION_OUTSIDE;

      if(eventTime >= m_inSampleStart &&
         eventTime <  m_oosStart)
      {
         return AQF_VALIDATION_IN_SAMPLE;
      }

      if(eventTime >= m_oosStart)
         return AQF_VALIDATION_OOS_RETROSPECTIVE;

      return AQF_VALIDATION_OUTSIDE;
   }
};

#endif
