-- Create schema
CREATE SCHEMA hr_db;

SET search_path TO hr_db;

-- Create employee table database in your database
CREATE TABLE IF NOT EXISTS raw_employee_data (
    Employee_ID VARCHAR(20) PRIMARY KEY,
    Age INT,
    Department VARCHAR(50),
    Tenure_Months INT,
    Hourly_Rate NUMERIC(5,2),
    Distance_From_Store_Miles NUMERIC(4,1),
    Overtime_Hours_Weekly NUMERIC(4,1),
    Job_Satisfaction_Score INT,
    Manager_Change_Last_6M INT,
    Performance_Rating INT,
    Left_Company INT
);

-- Clear old data if re-running the pipeline
TRUNCATE TABLE raw_employee_data;


COPY raw_employee_data FROM 'C:/temp/retail_employee_turnover.csv' WITH DELIMITER ',' CSV HEADER;

