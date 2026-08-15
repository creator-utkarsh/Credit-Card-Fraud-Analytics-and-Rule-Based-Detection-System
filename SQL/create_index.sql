-- Customer lookups --
CREATE INDEX idx_cc_num ON transactions(cc_num);

-- Time Analysis --
CREATE INDEX idx_trans_datetime ON transactions(trans_datetime);

-- Merchant Analysis --
CREATE INDEX idx_merchant ON transactions(merchant);

--  Category analytics --
CREATE INDEX idx_category ON transactions(category);

-- State analysis
CREATE INDEX idx_state ON transactions(state);

-- Fraud filtering
CREATE INDEX idx_is_fraud ON transactions(is_fraud);