-- System check --
-- Summary of Alerts --
SELECT 
    COUNT(*) AS total_transactions,
    SUM(rule_spike_in_spend) AS rule_1_triggers,
    SUM(rule_high_velocity) AS rule_2_triggers,
    SUM(rule_card_testing) AS rule_3_triggers,
    SUM(rule_impossible_travel) AS rule_4_triggers,
    SUM(rule_late_night_high_risk) AS rule_5_triggers,
    SUM(system_flagged_fraud) AS total_alerts
FROM fraud_rule_engine;

-- Rule Performance and evaluation --
SELECT 
-- Basic Confusion Matrix Totals
    SUM(CASE WHEN system_flagged_fraud = 1 AND actual_fraud = 1 THEN 1 ELSE 0 END) AS true_positives_TP,
    SUM(CASE WHEN system_flagged_fraud = 1 AND actual_fraud = 0 THEN 1 ELSE 0 END) AS false_positives_FP,
    SUM(CASE WHEN system_flagged_fraud = 0 AND actual_fraud = 0 THEN 1 ELSE 0 END) AS true_negatives_TN,
    SUM(CASE WHEN system_flagged_fraud = 0 AND actual_fraud = 1 THEN 1 ELSE 0 END) AS false_negatives_FN,

-- 1. Precision (Out of all system alerts, how many were REAL fraud?)
    ROUND(
        SUM(CASE WHEN system_flagged_fraud = 1 AND actual_fraud = 1 THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(system_flagged_fraud), 0), 2
    ) AS precision_pct,

    -- 2. Recall / Detection Rate (Out of ALL actual frauds, how many did we catch?)
    ROUND(
        SUM(CASE WHEN system_flagged_fraud = 1 AND actual_fraud = 1 THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(actual_fraud), 0), 2
    ) AS recall_detection_rate_pct,

    -- 3. False Positive Rate (FPR) (Percentage of legitimate customers annoyed/blocked)
    ROUND(
        SUM(CASE WHEN system_flagged_fraud = 1 AND actual_fraud = 0 THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(CASE WHEN actual_fraud = 0 THEN 1 ELSE 0 END), 0), 2
    ) AS false_positive_rate_FPR_pct,

    -- 4. False Alarm Ratio (How many false alerts generated per 1 real fraud caught?)
    ROUND(
        SUM(CASE WHEN system_flagged_fraud = 1 AND actual_fraud = 0 THEN 1 ELSE 0 END) * 1.0 / 
        NULLIF(SUM(CASE WHEN system_flagged_fraud = 1 AND actual_fraud = 1 THEN 1 ELSE 0 END), 0), 2
    ) AS false_alerts_per_real_fraud

FROM fraud_rule_engine;

-- Individual Rule Performance
#CREATE TABLE rule_performance AS 
WITH stats AS ( 
SELECT  SUM(actual_fraud) AS total_real_frauds,
SUM(rule_spike_in_spend) AS spike_total,
SUM(CASE WHEN rule_spike_in_spend = 1 AND actual_fraud = 1 THEN 1 ELSE 0 END) AS spike_tp,
SUM(CASE WHEN rule_spike_in_spend = 1 AND actual_fraud = 0 THEN 1 ELSE 0 END) AS spike_fp,
    
SUM(rule_high_velocity) AS velocity_total,
SUM(CASE WHEN rule_high_velocity = 1 AND actual_fraud = 1 THEN 1 ELSE 0 END) AS velocity_tp,
SUM(CASE WHEN rule_high_velocity = 1 AND actual_fraud = 0 THEN 1 ELSE 0 END) AS velocity_fp,
 
-- Card testing was tried but due to negligible result, was removed!!
#SUM(rule_card_testing) AS testing_total,
#SUM(CASE WHEN rule_card_testing = 1 AND actual_fraud = 1 THEN 1 ELSE 0 END) AS testing_tp,
#SUM(CASE WHEN rule_card_testing = 1 AND actual_fraud = 0 THEN 1 ELSE 0 END) AS testing_fp,
    
SUM(rule_impossible_travel) AS travel_total,
SUM(CASE WHEN rule_impossible_travel = 1 AND actual_fraud = 1 THEN 1 ELSE 0 END) AS travel_tp,
SUM(CASE WHEN rule_impossible_travel = 1 AND actual_fraud = 0 THEN 1 ELSE 0 END) AS travel_fp,
    
SUM(rule_late_night_high_risk) AS night_total,
SUM(CASE WHEN rule_late_night_high_risk = 1 AND actual_fraud = 1 THEN 1 ELSE 0 END) AS night_tp,
SUM(CASE WHEN rule_late_night_high_risk = 1 AND actual_fraud = 0 THEN 1 ELSE 0 END) AS night_fp
FROM fraud_rule_engine  )
SELECT  'Spike in Spend' AS rule_name, spike_total AS total_triggers, 
    spike_tp AS true_positives, spike_fp AS false_positives,
    ROUND(spike_tp * 100.0 / NULLIF(spike_total, 0), 2) AS precision_pct,
    ROUND(spike_tp * 100.0 / NULLIF(total_real_frauds, 0), 2) AS recall_detection_rate_pct
FROM stats
UNION ALL
SELECT 
    'High Velocity', velocity_total, velocity_tp, velocity_fp,
    ROUND(velocity_tp * 100.0 / NULLIF(velocity_total, 0), 2),
    ROUND(velocity_tp * 100.0 / NULLIF(total_real_frauds, 0), 2)
FROM stats
#UNION ALL
#SELECT 
#    'Card Testing', testing_total, testing_tp, testing_fp,
#    ROUND(testing_tp * 100.0 / NULLIF(testing_total, 0), 2),
#    ROUND(testing_tp * 100.0 / NULLIF(total_real_frauds, 0), 2)
#FROM stats
UNION ALL
SELECT 
    'Impossible Travel', travel_total, travel_tp, travel_fp,    
    ROUND(travel_tp * 100.0 / NULLIF(travel_total, 0), 2),
    ROUND(travel_tp * 100.0 / NULLIF(total_real_frauds, 0), 2) 
FROM stats
UNION ALL
SELECT 
    'Late Night High Risk', night_total, night_tp, night_fp,
    ROUND(night_tp * 100.0 / NULLIF(night_total, 0), 2),
    ROUND(night_tp * 100.0 / NULLIF(total_real_frauds, 0), 2) 
FROM stats;
