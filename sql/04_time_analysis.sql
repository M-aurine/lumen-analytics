-- Level 1. Truncate payments.payment_date to the month using DATE_TRUNC, and count payments per month.
SELECT DATE_TRUNC('month',payment_date) AS month, COUNT(*)
FROM payments
GROUP BY DATE_TRUNC('month',payment_date)
ORDER BY month;

-- Level 2. Sum payments.amount (excluding refunds/failed payments) by month. Order chronologically.
SELECT SUM(amount) AS total_payments, DATE_TRUNC('month',payment_date) AS month
FROM payments
WHERE payment_status NOT IN ('Refunded','Failed')
GROUP BY DATE_TRUNC('month',payment_date) 
ORDER BY month;

-- Level 3. For each customer, calculate their tenure in days as of today (or as of their churn_date if they've churned) using AGE() or date subtraction.
SELECT customer_id,
       COALESCE(churn_date,CURRENT_DATE) - signup_date AS tenure_days
FROM customers;

-- Level 4. The CFO's actual concern, restated: "Are there any months where we had zero recorded payments at all?" Your Level 2 query would simply omit those months rather than show them as zero. Use generate_series to build a complete monthly calendar and LEFT JOIN your payment totals onto it so missing months show explicitly as 0.
WITH calendar AS(
    SELECT generate_series(
        DATE_TRUNC('month', MIN(payment_date)),
        DATE_TRUNC('month', MAX(payment_date)),
        '1 month'::interval
    )::date AS month
    FROM payments

),
monthly_revenue AS (
    SELECT DATE_TRUNC('month', payment_date)::date AS month,
            SUM(amount) AS revenue
    FROM payments
    GROUP BY DATE_TRUNC('month', payment_date)
)
SELECT c.month,
        COALESCE(mr.revenue,0) AS revenue
FROM calendar c 
LEFT JOIN monthly_revenue mr  
    ON c.month = mr.month
ORDER BY c.month;


-- Level 5. Investigate: is there a seasonal pattern in either new signups (customers.signup_date) or churn (customers.churn_date)? State your finding and how confident you are in it given the data volume.
SELECT
        MIN(signup_date) AS first_sign_up,
        MAX(signup_date) AS last_sign_up,
        MIN(churn_date) AS first_churn,
        MAX(churn_date) AS last_churn
FROM customers;

-- signups
SELECT 
        EXTRACT(YEAR FROM signup_date) AS year, EXTRACT(MONTH FROM signup_date) AS month,
        COUNT(*) AS signup_count    
FROM customers
GROUP BY year,month
ORDER BY year,month;

-- churns
SELECT 
        EXTRACT(YEAR FROM churn_date) AS year, EXTRACT(MONTH FROM churn_date) AS month,
        COUNT(*) AS signup_count    
FROM customers
GROUP BY year,month
ORDER BY year,month;

-- No reliable seasonal pattern is detectable in either signups or churn — the dataset (73 customers across roughly 2.5 years, with 2026 only partially represented) is too small and too short a history to distinguish a real seasonal effect from ordinary random variation

