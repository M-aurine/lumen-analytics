-- Level 1. Using ROW_NUMBER(), rank all customers by total successful payments, highest first, across the whole company (no partitioning yet)
WITH customer_totals AS (
    SELECT c.customer_id,
        COALESCE(SUM(p.amount),0) AS total_payments
    FROM customers c
    LEFT JOIN payments p
        ON p.customer_id = c.customer_id
     AND p.payment_status = 'Paid'
    GROUP BY c.customer_id
)
SELECT customer_id,
    total_payments,
    ROW_NUMBER() OVER(ORDER BY total_payments DESC)
FROM customer_totals;

-- Level 2. Now PARTITION BY region so the ranking restarts for each region.
WITH customer_totals AS (
    SELECT c.customer_id,
        c.region,
        COALESCE(SUM(p.amount),0) AS total_payments
    FROM customers c
    LEFT JOIN payments p
        ON p.customer_id = c.customer_id
     AND p.payment_status = 'Paid'
    GROUP BY c.customer_id, c.region 
)
SELECT customer_id,
    region,
    total_payments,
    ROW_NUMBER() OVER(PARTITION BY region ORDER BY total_payments DESC)
FROM customer_totals;

-- Level 3. Explain, in your own words, what would change in your result if you used RANK() instead of ROW_NUMBER() -- then find (or construct a case for) a tie in the data that would actually show the difference.
-- ROW_NUMBER() forces an arbitrary tiebreak even on exact ties, while RANK() gives tied rows the same number and then skips ahead
WITH customer_totals AS (
    SELECT c.customer_id, c.region,
           COALESCE(SUM(p.amount), 0) AS total_payments
    FROM customers c
    LEFT JOIN payments p
        ON p.customer_id = c.customer_id AND p.payment_status = 'Paid'
    GROUP BY c.customer_id, c.region
)
SELECT customer_id, region, total_payments,
       ROUND(total_payments, -2) AS rounded_total,
       ROW_NUMBER() OVER (PARTITION BY region ORDER BY ROUND(total_payments, -2) DESC) AS row_num,
       RANK() OVER (PARTITION BY region ORDER BY ROUND(total_payments, -2) DESC) AS rank_num
FROM customer_totals
ORDER BY region, rounded_total DESC;

-- Level 4. Sales's actual request: the top 3 customers by lifetime value in each region, in one result set, with their rank clearly shown. Filter to just the top 3 per region using a CTE plus a WHERE on the window function's result (remember: window functions can't be filtered directly in WHERE in the same query level).
WITH customer_totals AS (
    SELECT c.customer_id, c.region,
           COALESCE(SUM(p.amount), 0) AS total_payments
    FROM customers c
    LEFT JOIN payments p
        ON p.customer_id = c.customer_id AND p.payment_status = 'Paid'
    GROUP BY c.customer_id, c.region
),
ranked_customers AS (
    SELECT customer_id,
        region,
        total_payments,
        RANK() OVER(PARTITION BY region ORDER BY total_payments DESC) AS payment_rank
    FROM customer_totals
)
SELECT customer_id,
    region,
    total_payments,
    payment_rank
FROM ranked_customers
WHERE payment_rank <= 3;
