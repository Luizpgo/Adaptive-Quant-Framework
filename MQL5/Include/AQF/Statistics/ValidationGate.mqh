#ifndef __AQF_VALIDATION_GATE_MQH__
#define __AQF_VALIDATION_GATE_MQH__

//+------------------------------------------------------------------+
//| Validation Gate                                                  |
//| AQF v0.12.1 - Sprint 12B                                        |
//|                                                                  |
//| Frozen WALK-FORWARD promotion screen:                            |
//| 1) Test folds with trades          = 3/3                         |
//| 2) Positive expectancy test folds  = 3/3                         |
//| 3) Aggregate expectancy            > 0R                          |
//| 4) Aggregate profit factor         > 1.00                        |
//| 5) Aggregate cumulative R          > 0R                          |
//| 6) Worst fold expectancy           >= 0R                         |
//| 7) Minimum resolved trades/fold     >= 30                        |
//|                                                                  |
//| This is a rejection/promotion screen, not proof of edge.         |
//| Retrospective 2022-2025 results remain contaminated research.    |
//+------------------------------------------------------------------+

struct SAQFValidationGateResult
{
   bool HasAllTestFolds;
   bool AllTestFoldsPositive;
   bool AggregateExpectancyPositive;
   bool AggregatePFAboveOne;
   bool AggregateCumRPositive;
   bool WorstFoldNonNegative;
   bool MinimumTradesSatisfied;
   int PassedRules;
   int FailedRules;
   bool Passed;
};

class CAQFValidationGate
{
private:
   int m_requiredTestFolds;
   int m_minResolvedTradesPerTestFold;

public:
   CAQFValidationGate()
   {
      m_requiredTestFolds=3;
      m_minResolvedTradesPerTestFold=30;
   }

   SAQFValidationGateResult EvaluateWalkForward(
      const int testFoldsWithTrades,
      const int positiveTestFolds,
      const int minimumResolvedTradesInAnyTestFold,
      const double aggregateExpectancy,
      const double aggregatePF,
      const double aggregateCumR,
      const double worstFoldExpectancy)
   {
      SAQFValidationGateResult r;
      r.HasAllTestFolds=(testFoldsWithTrades==m_requiredTestFolds);
      r.AllTestFoldsPositive=(r.HasAllTestFolds && positiveTestFolds==m_requiredTestFolds);
      r.AggregateExpectancyPositive=(aggregateExpectancy>0.0);
      r.AggregatePFAboveOne=(aggregatePF>1.0);
      r.AggregateCumRPositive=(aggregateCumR>0.0);
      r.WorstFoldNonNegative=(worstFoldExpectancy>=0.0);
      r.MinimumTradesSatisfied=(r.HasAllTestFolds && minimumResolvedTradesInAnyTestFold>=m_minResolvedTradesPerTestFold);
      r.PassedRules=0;
      r.PassedRules+=(r.HasAllTestFolds?1:0);
      r.PassedRules+=(r.AllTestFoldsPositive?1:0);
      r.PassedRules+=(r.AggregateExpectancyPositive?1:0);
      r.PassedRules+=(r.AggregatePFAboveOne?1:0);
      r.PassedRules+=(r.AggregateCumRPositive?1:0);
      r.PassedRules+=(r.WorstFoldNonNegative?1:0);
      r.PassedRules+=(r.MinimumTradesSatisfied?1:0);
      r.FailedRules=7-r.PassedRules;
      r.Passed=(r.FailedRules==0);
      return r;
   }

   string ResultText(const SAQFValidationGateResult &r)
   {
      return (r.Passed?"PASS":"FAIL");
   }

   string PromotionText(const SAQFValidationGateResult &r)
   {
      return (r.Passed?"ELIGIBLE_FOR_NEXT_VALIDATION_STAGE":"REJECTED_AT_WALK_FORWARD_SCREEN");
   }

   string FailReasons(const SAQFValidationGateResult &r)
   {
      string s="";
      Add(s,!r.HasAllTestFolds,"MISSING_TEST_FOLDS");
      Add(s,!r.AllTestFoldsPositive,"NOT_ALL_TEST_FOLDS_POSITIVE");
      Add(s,!r.AggregateExpectancyPositive,"AGG_EXPECTANCY_LE_0");
      Add(s,!r.AggregatePFAboveOne,"AGG_PF_LE_1");
      Add(s,!r.AggregateCumRPositive,"AGG_CUMR_LE_0");
      Add(s,!r.WorstFoldNonNegative,"WORST_FOLD_EXPECTANCY_LT_0");
      Add(s,!r.MinimumTradesSatisfied,"MIN_TRADES_PER_FOLD_LT_30");
      return (s==""?"NONE":s);
   }

private:
   void Add(string &s,const bool failed,const string reason)
   {
      if(!failed) return;
      if(s!="") s+=",";
      s+=reason;
   }
};

#endif
