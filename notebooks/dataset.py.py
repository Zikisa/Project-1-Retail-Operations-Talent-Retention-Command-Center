import pandas as pd
import numpy as np

# Set random seed for reproducibility
np.random.seed(42)
n_samples = 1000

# 1. Base Employee Info
emp_ids = [f"EMP{i:04d}" for i in range(1, n_samples + 1)]
departments = ['Sales Floor', 'Cashier', 'Stockroom', 'Customer Service', 'Management']
emp_dept = np.random.choice(departments, size=n_samples, p=[0.45, 0.30, 0.12, 0.08, 0.05])
age = np.random.randint(18, 62, size=n_samples)

# 2. Logic-bound tenure (cannot exceed realistic work life)
tenure_months = np.array([np.random.randint(1, max(2, int((a - 17) * 12))) for a in age])

# 3. Market-based hourly rates by role
base_rates = {'Sales Floor': 14.50, 'Cashier': 14.00, 'Stockroom': 15.00, 'Customer Service': 16.00, 'Management': 24.00}
hourly_rate = np.array([base_rates[d] + round(np.random.uniform(0, 3) + (t / 36), 2) for d, t in zip(emp_dept, tenure_months)])

# 4. Operational Risk Factors
distance = np.random.gamma(shape=2, scale=3, size=n_samples).round(1) # Skewed commute distribution
overtime_hours = np.array([max(0, round(np.random.normal(6, 4), 1)) if np.random.rand() > 0.4 else 0.0 for _ in range(n_samples)])
job_satisfaction = np.random.choice([1, 2, 3, 4, 5], size=n_samples, p=[0.12, 0.23, 0.35, 0.20, 0.10])
manager_change = np.random.choice([0, 1], size=n_samples, p=[0.72, 0.28])
perf_rating = np.random.choice([1, 2, 3, 4, 5], size=n_samples, p=[0.06, 0.14, 0.55, 0.18, 0.07])

# 5. Math-driven Turn-over Logic (Logistic regression simulation)
# Positive coefficients push towards quitting, negative coefficients pull towards staying
log_odds = (
    2.2 
    - 1.3 * job_satisfaction 
    + 0.14 * distance 
    + 0.18 * overtime_hours 
    - 0.25 * (hourly_rate - 14)
    - 0.01 * tenure_months
    + 0.9 * manager_change
    - 0.4 * perf_rating
)
prob_churn = 1 / (1 + np.exp(-log_odds))
left_company = np.random.binomial(1, prob_churn)

# Build DataFrame
retail_turnover_df = pd.DataFrame({
    'Employee_ID': emp_ids,
    'Age': age,
    'Department': emp_dept,
    'Tenure_Months': tenure_months,
    'Hourly_Rate': hourly_rate,
    'Distance_From_Store_Miles': distance,
    'Overtime_Hours_Weekly': overtime_hours,
    'Job_Satisfaction_Score': job_satisfaction,
    'Manager_Change_Last_6M': manager_change,
    'Performance_Rating': perf_rating,
    'Left_Company': left_company
})

# Save to CSV
retail_turnover_df.to_csv('retail_employee_turnover.csv', index=False)
print("Dataset created successfully! Row count:", len(retail_turnover_df))
