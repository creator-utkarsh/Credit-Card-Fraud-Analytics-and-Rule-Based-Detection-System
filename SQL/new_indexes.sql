-- New indexes in the database as required
ALTER TABLE transactions 
ADD INDEX idx_cc_num_amt (cc_num, amt),
ADD INDEX idx_cc_num_date_amt_fraud (cc_num, trans_datetime, amt, is_fraud);

ALTER TABLE transactions 
ADD INDEX idx_datetime_cat_amt (trans_datetime, category, amt);

SELECT 
    table_name AS `Table`,
    ROUND(((data_length) / 1024 / 1024), 2) AS `Data (MB)`,
    ROUND(((index_length) / 1024 / 1024), 2) AS `Index (MB)`
FROM information_schema.TABLES
WHERE table_schema = 'cc_fraud_db' AND table_name = 'transactions';
SHOW INDEX FROM transactions;
