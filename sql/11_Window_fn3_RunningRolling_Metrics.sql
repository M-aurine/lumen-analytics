-- Level 1. Calculate a running total of monthly revenue, ordered chronologically
WITH calendar AS (
    SELECT
        generate_series(
            DATE_TRUNC('month', MIN(payment_date)),
            DATE_TRUNC('month', MAX(payment_date)),
            '1 month'::interval
        )::date AS month
    FROM payments
),

monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', payment_date)::date AS month,
        SUM(amount) AS revenue
    FROM payments
    WHERE payment_status = 'Paid'
    GROUP BY DATE_TRUNC('month', payment_date)
)

SELECT
    c.month,
    COALESCE(mr.revenue, 0) AS revenue,
    SUM(COALESCE(mr.revenue, 0)) OVER (
        ORDER BY c.month
    ) AS cumulative_revenue
FROM calendar c
LEFT JOIN monthly_revenue mr
    ON c.month = mr.month
ORDER BY c.month;

-- Level 2. Calculate a 3-month moving average of monthly revenue
WITH calendar AS (
    SELECT
        generate_series(
            DATE_TRUNC('month', MIN(payment_date)),
            DATE_TRUNC('month', MAX(payment_date)),
            '1 month'::interval
        )::date AS month
    FROM payments
),

monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', payment_date)::date AS month,
        SUM(amount) AS revenue
    FROM payments
    WHERE payment_status = 'Paid'
    GROUP BY DATE_TRUNC('month', payment_date)
)
SELECT 
    c.month,
    COALESCE(mr.revenue, 0) AS revenue),
    AVG(COALESCE(mr.revenue, 0) AS revenue)) OVER(ORDER BY c.month
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_average
FROM calendar c 
LEFT JOIN monthly_revenue mr 
    ON c.month = mr.month;

-- Level 3. For each plan tier, calculate what percentage of total company revenue it represents, using a window function rather than a second query.
WITH tier_rev AS (
    SELECT c.plan_type_at_signup,
           SUM(COALESCE(p.amount, 0)) AS tier_revenue
    FROM customers c
    LEFT JOIN payments p
        ON c.customer_id = p.customer_id
        AND p.payment_status = 'Paid'
    GROUP BY c.plan_type_at_signup
)
SELECT plan_type_at_signup,
       ROUND(tier_revenue / SUM(tier_revenue) OVER () * 100, 2) AS revenue_percentage
FROM tier_rev;

-- Level 4. Build the Board-ready output: month, monthly revenue, running total, 3-month moving average, and month-over-month % change (from Phase 11), all in one result set.
WITH calendar AS (
    SELECT
        generate_series(
            DATE_TRUNC('month', MIN(payment_date)),
            DATE_TRUNC('month', MAX(payment_date)),
            '1 month'::interval
        )::date AS month
    FROM payments
),

monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', payment_date)::date AS month,
        SUM(amount) AS revenue
    FROM payments
    WHERE payment_status = 'Paid'
    GROUP BY DATE_TRUNC('month', payment_date)
),

revenue_metrics AS (
    SELECT
        c.month,
        COALESCE(mr.revenue, 0) AS monthly_revenue,

        LAG(COALESCE(mr.revenue, 0))
            OVER (ORDER BY c.month) AS previous_revenue,

        SUM(COALESCE(mr.revenue, 0))
            OVER (ORDER BY c.month) AS running_total,

        AVG(COALESCE(mr.revenue, 0))
            OVER (
                ORDER BY c.month
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ) AS moving_avg_3_months

    FROM calendar c
    LEFT JOIN monthly_revenue mr
        ON c.month = mr.month
)

SELECT
    month,
    monthly_revenue,
    running_total,
    moving_avg_3_months,
    ROUND(
        (monthly_revenue - previous_revenue)
        / NULLIF(previous_revenue, 0) * 100,
        2
    ) AS mom_percentage_change
FROM revenue_metrics
ORDER BY month;