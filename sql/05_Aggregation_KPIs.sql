-- Level 1. Count active customers (churn_date IS NULL) by plan_type_at_signup.
SELECT plan_type_at_signup, COUNT(*) as tot_customers
FROM customers
WHERE churn_date IS NULL
GROUP BY plan_type_at_signup;

-- Level 2. For each region, calculate total payments received (successful payments only) and the number of distinct paying customers.
SELECT c.region,SUM(p.amount),COUNT(DISTINCT c.customer_id) AS distinct_paying_cust
FROM customers c
LEFT JOIN payments p
ON c.customer_id =p.customer_id
WHERE p.payment_status = 'Paid'
GROUP BY c.region;

-- Level 3. Calculate an average revenue per customer figure by region. Be explicit in your query and your explanation about what's in your denominator -- all customers, or only paying ones?
SELECT
    c.region,
    SUM(CASE 
            WHEN p.payment_status = 'Paid' THEN p.amount 
            ELSE 0 
        END) / COUNT(DISTINCT c.customer_id) AS avg_revenue_per_customer
FROM customers c
LEFT JOIN payments p
    ON c.customer_id = p.customer_id
GROUP BY c.region;

-- Level 4. Sales asks: "Which regions have more than 10 active customers?" -- a HAVING-filter question. Answer it, then tell Sales in one sentence what the number doesn't tell them.
-- The number does not tell how valuable the customers are - a region can have more than 10 active customers but generate little revenue or have low engagement
SELECT region, COUNT(DISTINCT customer_id) AS active_customers      
FROM customers
WHERE churn_date IS NULL
GROUP BY region
HAVING COUNT(DISTINCT customer_id) > 10;

-- The customer in Europe who has never generated a successful payment
SELECT c.customer_id, c.company_name, c.region, c.churn_date
FROM customers c
LEFT JOIN payments p ON c.customer_id = p.customer_id AND p.payment_status = 'Paid'
WHERE c.region = 'Europe' AND p.payment_id IS NULL;