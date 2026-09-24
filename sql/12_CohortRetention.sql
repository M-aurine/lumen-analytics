-- Level 2. Group customers into monthly signup cohorts using DATE_TRUNC on signup_date. Count customers per cohort.
SELECT 
    DATE_TRUNC('month',signup_date) AS month,
    COUNT(*) AS total_customers
FROM customers
GROUP BY month
ORDER BY month;

-- Level 3. For each cohort, calculate how many customers are still active (churn_date IS NULL) as of today, and what percentage that represents.
SELECT 
    DATE_TRUNC('month',signup_date) AS month,
    COUNT(*) AS total_customers,
    COUNT(CASE
            WHEN churn_date IS NULL THEN 1
        END
    ) AS active_customers,
    COUNT(CASE
            WHEN churn_date IS NULL THEN 1
        END)::float / COUNT(*) * 100 AS retention_percentage
FROM customers
GROUP BY month
ORDER BY month;

-- at this dataset's actual scale (73 customers spread across 2.5 years), monthly cohorts are too small individually to support reliable retention comparisons
 SELECT 
    DATE_TRUNC('month',signup_date) AS cohort_month,
    COUNT(*) AS total_customers,
    COUNT(CASE
            WHEN churn_date IS NULL
                 OR churn_date >= signup_date + INTERVAL '3 months'
            THEN 1
          END
         )::float /COUNT(*) *100 AS retention_3_months,
    COUNT(CASE
            WHEN churn_date IS NULL
                 OR churn_date >= signup_date + INTERVAL '6 months'
            THEN 1
          END
        )::float /COUNT(*) *100 AS retention_6_months
FROM customers
GROUP BY cohort_month
ORDER BY cohort_month;

