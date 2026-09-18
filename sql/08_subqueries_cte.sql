-- Using a subquery (not a CTE this time — deliberately, so you get practice with both forms), find all customers whose total successful payments exceed the average total payment across all customers.
SELECT customer_id, total
FROM (SELECT customer_id, SUM(amount) AS total
     FROM payments 
     WHERE payment_status = 'Paid'
     GROUP BY customer_id) AS customer_totals
WHERE total > (SELECT AVG(total) FROM (SELECT customer_id, SUM(amount) AS total
     FROM payments 
     WHERE payment_status = 'Paid'
     GROUP BY customer_id)AS customer_totals) ;
     
-- Level 2. Using a CTE, calculate each customer's usage_event count, then in the final SELECT flag customers whose count is in the bottom 10% (hint: you'll want a percentile or NTILE from Phase 6 here)
WITH usage_counts AS (
     SELECT customer_id,
          COUNT(*) AS usage_count
     FROM usage_events
     GROUP BY customer_id   
),
tiled_customers AS (
     SELECT customer_id,
          usage_count,
          NTILE(10) OVER(ORDER BY usage_count) AS tile
     FROM usage_counts
)
SELECT 
     customer_id,
     usage_count,
     CASE WHEN tile = 1 THEN 'Bottom 10%'
          WHEN tile = 10 THEN 'Top 10%'
          ELSE 'Middle 80%'
     END AS customer_flag
FROM tiled_customers;

-- With 73 customers divided into 10 NTILE buckets, the groups cannot be exactly equal. `NTILE(10)` distributes the customers as evenly as possible, resulting in some buckets containing 8 customers and others 7. Therefore, Tile 1 represents approximately the bottom 10% rather than exactly 10% of customers.
-- Because the CTE starts from usage_events instead of customers, customers with zero usage events are excluded entirely and cannot be flagged as low-usage customers.
-- Customer 71 — Fuentes PLC — has zero usage events.

WITH usage_counts AS (
    SELECT customer_id, COUNT(*) AS usage_count
    FROM usage_events
    GROUP BY customer_id
),
all_customers AS (
    SELECT c.customer_id, COALESCE(u.usage_count, 0) AS usage_count
    FROM customers c
    LEFT JOIN usage_counts u ON c.customer_id = u.customer_id
),
tiled_customers AS (
    SELECT customer_id, usage_count,
           NTILE(10) OVER (ORDER BY usage_count) AS tile
    FROM all_customers
)
SELECT customer_id, usage_count,
       CASE WHEN tile = 1 THEN 'Bottom 10%'
            WHEN tile = 10 THEN 'Top 10%'
            ELSE 'Middle 80%' END AS customer_flag
FROM tiled_customers;

-- Level 3. Build a 2-stage CTE: first stage aggregates usage_events per customer per plan tier; second stage compares each customer's usage to their plan tier's average usage, showing customers meaningfully above or below their peers
WITH usage_count AS (
     SELECT c.customer_id, 
          c.plan_type_at_signup, 
          COUNT(u.customer_id) AS usage_count
     FROM customers c
     LEFT JOIN usage_events u
        ON  c.customer_id = u.customer_id
     GROUP BY c.customer_id, c.plan_type_at_signup
),
avg_partition AS(
     SELECT customer_id, 
          plan_type_at_signup, 
          usage_count,
          AVG(usage_count) OVER (PARTITION BY plan_type_at_signup) AS plan_avg_usage,
          STDDEV(usage_count) OVER (PARTITION BY plan_type_at_signup) AS plan_stddev_usage
     FROM usage_count
)
SELECT customer_id,
     plan_type_at_signup,
     usage_count,
     plan_avg_usage,
     plan_stddev_usage, -- Gives us spread around the centre
     CASE 
          WHEN usage_count > plan_avg_usage + plan_stddev_usage 
               THEN 'Above Typical Range'
          WHEN usage_count < plan_avg_usage - plan_stddev_usage 
               THEN 'Below Typical Range'
          ELSE 'Within Typical Range'
     END AS usage_tier
FROM avg_partition;

-- CLASSIFICATION COUNT
SELECT 
    usage_tier,
    COUNT(*) AS customer_count
FROM (
    WITH usage_count AS (
        SELECT 
            c.customer_id, 
            c.plan_type_at_signup, 
            COUNT(u.customer_id) AS usage_count
        FROM customers c
        LEFT JOIN usage_events u
            ON c.customer_id = u.customer_id
        GROUP BY c.customer_id, c.plan_type_at_signup
    ),
    avg_partition AS (
        SELECT 
            customer_id, 
            plan_type_at_signup, 
            usage_count,
            AVG(usage_count) OVER (
                PARTITION BY plan_type_at_signup
            ) AS plan_avg_usage,
            STDDEV(usage_count) OVER (
                PARTITION BY plan_type_at_signup
            ) AS plan_stddev_usage
        FROM usage_count
    )
    SELECT 
        customer_id,
        plan_type_at_signup,
        usage_count,
        plan_avg_usage,
        plan_stddev_usage,
        CASE 
            WHEN usage_count > plan_avg_usage + plan_stddev_usage 
                THEN 'Above Typical Range'
            WHEN usage_count < plan_avg_usage - plan_stddev_usage 
                THEN 'Below Typical Range'
            ELSE 'Within Typical Range'
        END AS usage_tier
    FROM avg_partition
) AS classified_customers
GROUP BY usage_tier
ORDER BY customer_count DESC;

-- ±1 SD flagged ~37% of customers as atypical, split evenly between high and low — close to the ~32% you'd expect under a normal distribution, suggesting the threshold is well-calibrated and usage is roughly symmetric within tiers

-- Level 4. Product's actual ask: "Give me the 10 customers using the product the least, relative to how long they've been a customer.
WITH customer_usage AS(
     SELECT c.customer_id, 
          EXTRACT(YEAR FROM AGE(COALESCE(c.churn_date,CURRENT_DATE), c.signup_date))*12 +
          EXTRACT(MONTH FROM AGE(COALESCE(c.churn_date,CURRENT_DATE),c.signup_date)) AS tenure_months,
          COUNT(u.customer_id) AS usage_count
     FROM customers c
     LEFT JOIN usage_events u
     ON u.customer_id = c.customer_id
     GROUP BY c.customer_id, EXTRACT(YEAR FROM AGE(COALESCE(c.churn_date,CURRENT_DATE), c.signup_date))*12 +
                              EXTRACT(MONTH FROM AGE(COALESCE(c.churn_date,CURRENT_DATE),c.signup_date))
),
usage_event_rate AS (
     SELECT customer_id,
          usage_count,
          tenure_months,
          usage_count::float/NULLIF(tenure_months,0) AS usage_rate
     FROM customer_usage
)
SELECT customer_id,
     usage_count,
     tenure_months,
     usage_rate       
FROM usage_event_rate
ORDER BY usage_rate ASC
LIMIT 10;

-- Customer 71 (Fuentes PLC): Bottom of the list due to zero usage, but this is likely explained by the duplicate/new-signup data-quality issue.
-- Customer 58 (Drake-Thomas): More significant finding — a long-tenured customer with 26 successful payments totaling $11K+, but only 6 usage events over 28 months.
-- Key takeaway: Distinguish data-quality anomalies from genuine low-engagement customers who may need Product/Customer Success attention.
