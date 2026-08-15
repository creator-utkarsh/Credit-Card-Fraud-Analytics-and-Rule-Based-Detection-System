from pathlib import Path
import os
import pandas as pd
import pymysql
from dotenv import load_dotenv
from datetime import datetime
import time

# Load Environment Variables
load_dotenv()

# Database Connection Parameters
HOST = os.getenv('DB_HOST', 'localhost')
PORT = int(os.getenv('DB_PORT', '3306'))
DATABASE = os.getenv('DB_NAME', 'fraud_db')
USER = os.getenv('DB_USER', 'root')
PASSWORD = os.getenv('DB_PASSWORD', 'Password')

# Project Paths
ROOT = Path(__file__).resolve().parent.parent

RAW_FILE = ROOT / "data" / "fraudTrain.csv"

TEMP_DIR = ROOT / "temp"
TEMP_DIR.mkdir(exist_ok=True)

TEMP_FILE = TEMP_DIR / "transactions_clean.csv"
SQL_DIR = ROOT / "sql"

# Database Connection
connection = pymysql.connect(
    host=HOST,
    port=PORT,
    user=USER,
    password=PASSWORD,
    local_infile=True,
    autocommit=True
)

# Execute SQL Script
def execute_sql_file(cursor, file_path):
    print(f"Executing {file_path.name}")
    with open(file_path, "r", encoding="utf-8") as f:
        sql = f.read()

    for statement in sql.split(";"):
        statement = statement.strip()
        if statement:
            cursor.execute(statement)

# Extract Data
def extract_data():
    print("\nReading Raw Dataset...")
    df = pd.read_csv(RAW_FILE, parse_dates=["trans_date_trans_time", "dob"])

    print(f"Rows : {len(df):,}")
    return df

# Transform Data
def transform_data(df):

    print("Cleaning Dataset...")

    # Memory Before
    memory_before = df.memory_usage(deep=True).sum() / (1024 ** 2)
    print("=" * 60)
    print(f"Memory Before Optimization : {memory_before:.2f} MB")
    print("=" * 60)

    # Rename Columns for Clarity
    df.rename(columns={'trans_date_trans_time': 'trans_datetime','age': 'customer_age',
                    'long': 'longitude', 'lat': 'latitude', 'first': 'first_name', 'last': 'last_name'}, inplace=True)

    # Remove unnecessary columns
    if 'Unnamed: 0' in df.columns:
        df.drop(columns=['Unnamed: 0'], inplace=True)
        print("\n Dropped redundant index column 'Unnamed: 0'.") 

    # Data Transformation & Standardizing Types
    print("\n Transforming data types for database optimization")

    # To proper DateTime format
    df['trans_datetime'] = pd.to_datetime(df['trans_datetime'])
    df['dob'] = pd.to_datetime(df['dob'])

    # ZIP codes
    if "zip" in df.columns:
        df["zip"] = df["zip"].astype("string")

    # Remove the synthetic "fraud_" prefix from merchant names
    if "merchant" in df.columns:
        df["merchant"] = ( df["merchant"].str.replace("^fraud_", "", regex=True).astype("category"))

    # ==========================================================
    # Categorical Columns
    categorical_columns = [ "category", "first_name", "last_name", "gender",
                            "street", "city", "state", "job" ] 
   
    for col in categorical_columns:
        if col in df.columns:
            df[col] = df[col].astype("category")

    # ==========================================================
    # Float Columns
    float_columns = [ "amt", "latitude", "longitude", "merch_lat", "merch_long" ]

    for col in float_columns:
        if col in df.columns:
            df[col] = pd.to_numeric( df[col], downcast="float" )

    # ==========================================================
    # Integer Columns
    integer_columns = [ "city_pop", "is_fraud" ]
    
    for col in integer_columns:
        if col in df.columns:
            df[col] = pd.to_numeric( df[col], downcast="integer" )

    # ==========================================================
    # Feature Engineering: Extracting Hour and Customer Age
    df['trans_hour'] = df['trans_datetime'].dt.hour.astype('int8')
    df['customer_age'] = ((df['trans_datetime'] - df['dob']).dt.days // 365).astype('int8') 

    # ==========================================================
    # Memory After Optimization
    memory_after = df.memory_usage(deep=True).sum() / (1024 ** 2)

    reduction = ((memory_before - memory_after) / memory_before * 100 )

    print(f"Memory After Optimization  : {memory_after:.2f} MB")
    print(f"Memory Saved               : {memory_before - memory_after:.2f} MB")
    print(f"Reduction                  : {reduction:.2f}%")
    print("\n Data types successfully optimized.")

    print("=" * 60)
    print("Cleaning and Transformation Completed.")

    return df

# Save Temporary CSV
def save_temp_csv(df):

    print("Creating Temporary CSV...")

    df.to_csv( TEMP_FILE, index=False, na_rep="\\N" )

    print(TEMP_FILE)

# Bulk Load
def bulk_load(cursor):

    print("Bulk Loading Into MySQL...")

    cursor.execute(f"USE {DATABASE}")

    temp_path = str(TEMP_FILE).replace("\\", "/")

    cursor.execute("SET SESSION unique_checks = 0")
    cursor.execute("SET SESSION foreign_key_checks = 0")
    cursor.execute("SET SESSION autocommit = 0")

    try:
        sql = f"""
        LOAD DATA LOCAL INFILE '{temp_path}'
        INTO TABLE transactions
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
        LINES TERMINATED BY '\r\n'
        IGNORE 1 LINES
        (trans_datetime, cc_num, merchant, category, amt, first_name, last_name, 
        gender, street, city, state, zip, latitude, longitude, city_pop, job, 
        dob, trans_num, unix_time, merch_lat, merch_long, is_fraud, trans_hour, 
        customer_age);
        """

        cursor.execute(sql)
        cursor.execute("COMMIT")
    finally:
        cursor.execute("SET SESSION unique_checks = 1")
        cursor.execute("SET SESSION foreign_key_checks = 1")
        cursor.execute("SET SESSION autocommit = 1")

    print("Bulk Load Completed.")

# Verify
def verify(cursor):

    cursor.execute(f"USE {DATABASE}")

    cursor.execute("SELECT COUNT(*) FROM transactions")

    rows = cursor.fetchone()[0]

    print(f"\nRows Loaded : {rows:,}")

# Cleanup
def cleanup():

    if TEMP_FILE.exists():

        TEMP_FILE.unlink()
        print("Temporary CSV Deleted.")

    if TEMP_DIR.exists():

        try:
            TEMP_DIR.rmdir()
        except:
            pass

#=========================================================
# Main function to orchestrate the ETL process
def main():

    # Record start time
    start_time = datetime.now()
    start_perf = time.perf_counter()

    print("=" * 60)
    print(" FRAUD DETECTION ETL PIPELINE ")
    print("=" * 60)

    cursor = connection.cursor()

    # Enable local_infile on the MySQL server dynamically for this session
    print("Enabling local_infile on MySQL server...")
    cursor.execute("SET GLOBAL local_infile = 1")
    
    sql_time_start = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f" Start Time for sql creation of database and tables: {sql_time_start}")

    execute_sql_file(
        cursor,
        SQL_DIR / "create_database.sql"
    )

    execute_sql_file(
        cursor,
        SQL_DIR / "create_table.sql"
    )

    sql_time_end = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f" End Time for sql creation of database and tables: {sql_time_end}")

    df = extract_data()

    df = transform_data(df)

    save_temp_csv(df)

    bulk_load_start = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f" Start Time for bulk load: {bulk_load_start}")

    bulk_load(cursor)

    bulk_load_end = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f" End Time for bulk load: {bulk_load_end}")

    execute_sql_file(
        cursor,
        SQL_DIR / "create_index.sql"
    )

    verify(cursor)

    cleanup()

    cursor.close()
    connection.close()

    # Record end time & calculate duration
    end_time = datetime.now()
    duration_seconds = time.perf_counter() - start_perf

    # Format duration into minutes and seconds
    minutes, seconds = divmod(duration_seconds, 60)

    print(f" Start Time : {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f" End Time   : {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f" Total Duration: {int(minutes)}m {seconds:.2f}s")
    print("\nETL Completed Successfully!")

# ==========================================================

if __name__ == "__main__":
    main()

