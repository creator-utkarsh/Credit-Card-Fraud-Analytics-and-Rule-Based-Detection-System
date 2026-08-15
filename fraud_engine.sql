CREATE OR REPLACE VIEW v_fraud_rule_engine AS
WITH cust_history AS (
-- Historical average spending per cardholder/customer
SELECT 
    cc_num, AVG(amt) AS avg_card_spend
FROM
    transactions
GROUP BY cc_num ),
-- Previous transaction and location details
trans_history as (
SELECT  t.id, t.cc_num, t.trans_datetime, t.amt, t.merchant, t.category, t.merch_lat, t.merch_long, 
		t.is_fraud, c.avg_card_spend, t.state, t.trans_hour, t.customer_age,
        lag(t.trans_datetime) over(partition by t.cc_num order by t.trans_datetime) AS prev_trans_time,
        lag(t.amt) over(partition by t.cc_num order by t.trans_datetime) AS prev_amt,
-- Geospatial rules are not that much suitable in this dataset (already checked)
        lag(t.merch_lat) over(partition by t.cc_num order by t.trans_datetime) AS prev_merch_lat,
        lag(t.merch_long) over(partition by t.cc_num order by t.trans_datetime) AS prev_merch_long,
-- Flag if this is the 1st transaction on the card
        CASE WHEN LAG(t.trans_datetime) OVER (PARTITION BY t.cc_num ORDER BY t.trans_datetime) IS NULL 
            THEN 1 ELSE 0 
        END AS is_first_trans,
        count(t.id) over(partition by t.cc_num order by t.trans_datetime RANGE BETWEEN INTERVAL 15 MINUTE preceding AND current row) AS trans_count_15m
        #count(t.id) over(partition by t.cc_num order by t.trans_datetime RANGE BETWEEN INTERVAL 1 HOUR preceding AND current row) AS trans_count_1h
from transactions t JOIN cust_history c ON t.cc_num = c.cc_num
), 
fraud_rules AS ( SELECT *,
-- Seconds elapsed since previous transaction
#   TIMESTAMPDIFF(SECOND, prev_trans_time, trans_datetime) AS seconds_since_last_trans,
        
-- THE 5 HEURISTIC RULES FOR FRAUD DETECTION
-- ---------------------------------------------------------------------------
-- Rule 1: Spike in Spend (Amount > 5x customer baseline)
CASE WHEN amt > (5 * avg_card_spend) AND amt < (21 * avg_card_spend) THEN 1 ELSE 0 END AS rule_spike_in_spend,

-- Rule 2: High-Frequency Velocity (> 3 transactions in 15 minutes and 1hr)
CASE  
WHEN is_first_trans = 1 AND amt > 90 THEN 1
		WHEN trans_count_15m >= 3 THEN 1
        #WHEN trans_count_1h >= 3 THEN 1       #this increased overall false positive by ~24600
        ELSE 0
END AS rule_high_velocity,

-- Rule 3: Micro-Card Testing (Prev amt < $2, current amt > $200, time <= 10 mins)
-- FOR THIS DATASET, THIS RULE IS NOT WORKING, BUT GOOD FOR REAL BANK DATASETS
#CASE WHEN prev_amt < 5.00 AND amt > 200.00 
#	      AND TIMESTAMPDIFF(MINUTE, prev_trans_time, trans_datetime) <= 10 
#     THEN 1 ELSE 0 
#END AS rule_card_testing,

-- Rule 4: Impossible Travel (Distance > 100 miles in < 1 hour)
-- NOT WORTH IT, data is not suitable for this kind of rule, but it works good in real-life
CASE 
WHEN  TIMESTAMPDIFF(SECOND, prev_trans_time, trans_datetime) < 60  AND category NOT IN ('shopping_net', 'misc_net', 'grocery_net') 
-- Haversine Distance Calculation (in Miles) between previous and current merchant location
			   AND ( 3958.8 * 2 * ASIN(SQRT(
                   POWER(SIN(RADIANS(merch_lat - prev_merch_lat) / 2), 2) +
                   COS(RADIANS(prev_merch_lat)) * COS(RADIANS(merch_lat)) *
                   POWER(SIN(RADIANS(merch_long - prev_merch_long) / 2), 2)
                     )) ) > 4
THEN 1 ELSE 0 
END AS rule_impossible_travel,

-- Rule 5: Late Night High-Risk Category (10 PM - 4 AM, high risk category, > $250)
CASE 
WHEN /*HOUR(trans_datetime)*/ trans_hour IN (22, 23, 0, 1, 2, 3) 
	 AND category IN ('shopping_net', 'misc_net', 'shopping_pos','grocery_pos','entertainment','home','misc_pos') AND amt > 250.00 
THEN 1 ELSE 0 
END AS rule_late_night_high_risk

FROM trans_history
)
SELECT id, cc_num, prev_trans_time, trans_datetime, amt, merchant, category, is_fraud AS actual_fraud, state, trans_hour, customer_age,   
-- Individual Rule Flag Outputs
    rule_spike_in_spend,
    rule_high_velocity,
    #rule_card_testing,
    rule_impossible_travel,
    rule_late_night_high_risk,
    
-- Composite Master Flag (Flags if ANY of the 5 rules trigger)
CASE 
    WHEN (rule_spike_in_spend + rule_high_velocity + rule_impossible_travel + rule_late_night_high_risk) > 0
    THEN 1 ELSE 0 
END AS system_flagged_fraud,
    
-- Risk Score (0 to 100 Weighted Score)
LEAST(100, (
    rule_spike_in_spend * 30 + 
    rule_high_velocity * 20 + 
    rule_impossible_travel * 10 + 
    rule_late_night_high_risk * 40
 )) AS risk_score
FROM fraud_rules; 

select * from v_fraud_rule_engine 
where rule_impossible_travel = 1 AND actual_fraud = 1 AND rule_spike_in_spend = 0 
	AND rule_high_velocity =0 AND rule_late_night_high_risk= 0;

SELECT count(*) as total_transactions, sum(is_fraud) as total_fraud_trans, (100.0*sum(is_fraud) / count(*)) as fraud_rate
 FROM transactions where trans_hour IN (22,23,0,1,2,3);

CREATE TABLE fraud_rule_engine as 
SELECT * FROM v_fraud_rule_engine;
ALTER TABLE fraud_rule_engine
ADD INDEX idx_fraud_rule (system_flagged_fraud, actual_fraud);