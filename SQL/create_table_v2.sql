-- CREATE TABLE --
USE cc_fraud_db;

CREATE TABLE transactions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    trans_datetime DATETIME NOT NULL,
    cc_num BIGINT NOT NULL,
    merchant VARCHAR(100) NOT NULL,
    category VARCHAR(40) NOT NULL,
    amt DECIMAL(10,2) NOT NULL,
    first_name VARCHAR(30) NOT NULL,
    last_name VARCHAR(30) NOT NULL,
    gender CHAR(1) NOT NULL,
    street VARCHAR(100) NOT NULL,
    city VARCHAR(60) NOT NULL,
    state CHAR(2) NOT NULL,
    zip VARCHAR(10) NOT NULL,
    latitude DECIMAL(9 , 6 ) NOT NULL,
    longitude DECIMAL(9 , 6 ) NOT NULL,
    city_pop INT UNSIGNED NOT NULL,
    job VARCHAR(100) NOT NULL,
    dob DATE NOT NULL,
    trans_num VARCHAR(40) NOT NULL UNIQUE,
    unix_time INT NOT NULL,
    merch_lat DECIMAL(9 , 6 ) NOT NULL,
    merch_long DECIMAL(9 , 6 ) NOT NULL,
    is_fraud TINYINT NOT NULL,
    trans_hour TINYINT UNSIGNED NOT NULL,
    customer_age TINYINT UNSIGNED NOT NULL
); 