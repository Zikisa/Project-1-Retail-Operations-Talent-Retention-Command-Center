SET search_path TO hr_db;

-- 1. Wipe the old structural template out safely
DROP VIEW IF EXISTS v_employee_retention_metrics CASCADE;

-- 2. Build the updated version including the departure status flag
CREATE VIEW v_employee_retention_metrics AS
WITH PeerMovingAverages AS (
    SELECT 
        Employee_ID,
        Department,
        Tenure_Months,
        Hourly_Rate,
        Left_Company, -- Keep the flag staged here
        
        -- Calculate the 5-employee moving average based on seniority placement
        AVG(Hourly_Rate) OVER (
            PARTITION BY Department
            ORDER BY Tenure_Months ASC
            ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
        ) AS Dept_Tenure_Moving_Avg

    FROM raw_employee_data
    -- Note: Removed the WHERE filter entirely to process both active and departed staff
)
SELECT 
    Employee_ID,
    Department,
    Tenure_Months,
    Hourly_Rate,
    Left_Company, -- Select it here to expose it to Power BI
    
    ROUND(Dept_Tenure_Moving_Avg::NUMERIC, 2) AS Peer_Group_Moving_Avg,
    ROUND((Hourly_Rate - Dept_Tenure_Moving_Avg)::NUMERIC, 2) AS Pay_Variance_From_Moving_Avg,
    
    -- Core Portfolio Risk Flag
    CASE 
        WHEN (Hourly_Rate - Dept_Tenure_Moving_Avg) < -1.00 THEN 1 
        ELSE 0 
    END AS Salary_Equity_Risk_Flag

FROM PeerMovingAverages;



DROP VIEW IF EXISTS v_executive_cohort_summary;

CREATE VIEW v_executive_cohort_summary AS
WITH CohortBasics AS (
    SELECT
        Employee_ID,
        Department,
        Left_Company,
        Tenure_Months,
        -- Injecting departmental biases to make the data realistic
        CASE 
            WHEN Department IN ('Cashier', 'Sales Floor') AND Hourly_Rate < 15.50 THEN 1 
            WHEN Department = 'Management' AND Hourly_Rate < 24.00 THEN 1
            ELSE 0 
        END AS Is_Underpaid,
        
        CASE 
            WHEN Department = 'Cashier' AND Overtime_Hours_Weekly > 6 AND Job_Satisfaction_Score <= 3 THEN 1.5 -- Cashier heavy burnout
            WHEN Overtime_Hours_Weekly > 8 AND Job_Satisfaction_Score <= 2 THEN 1 
            ELSE 0 
        END AS Burnout_Risk,
        
        CASE WHEN Distance_From_Store_Miles > 10 THEN 1 ELSE 0 END AS Long_Commute,
        
        CASE 
            WHEN Department = 'Stockroom' AND Manager_Change_Last_6M = 1 THEN 1.3 -- High management turnover friction in stockroom
            WHEN Manager_Change_Last_6M = 1 THEN 1 
            ELSE 0 
        END AS Manager_Risk,
        
        ('2025-12-01'::DATE - (Tenure_Months || ' months')::INTERVAL)::DATE AS Hire_Date
    FROM raw_employee_data
),
NormalizedCohorts AS (
    SELECT
        Employee_ID,
        Department,
        Left_Company,
        Tenure_Months,
        -- Calculate Total Risk Score with the new department variances
        (Is_Underpaid + Burnout_Risk + Long_Commute + Manager_Risk) AS Employee_Risk_Score,
        TO_CHAR(Hire_Date, 'YYYY-MM') AS Cohort_Month
    FROM CohortBasics
)
SELECT
    Cohort_Month,
    Department, -- Added department group to allow Power BI breakdown
    COUNT(*) AS Total_Hired_In_Cohort,
    ROUND(AVG(Employee_Risk_Score)::NUMERIC, 2) AS Average_Cohort_Risk_Score,
    ROUND((SUM(CASE WHEN Tenure_Months >= 3 OR Left_Company = 0 THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 1) AS Retention_Rate_3M,
    ROUND((SUM(CASE WHEN Tenure_Months >= 6 OR Left_Company = 0 THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 1) AS Retention_Rate_6M,
    ROUND((SUM(CASE WHEN Tenure_Months >= 12 OR Left_Company = 0 THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 1) AS Retention_Rate_12M
FROM NormalizedCohorts
GROUP BY Cohort_Month, Department; -- Grouped by both to pass data dynamically
