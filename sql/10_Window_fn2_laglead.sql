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
    WHERE payment_status = 'Paid'
    GROUP BY DATE_TRUNC('month', payment_date)
)
SELECT c.month,
        COALESCE(mr.revenue,0) AS revenue,
        LAG(COALESCE(mr.revenue,0)) OVER (ORDER BY c.month) AS previous_revenue
FROM calendar c 
LEFT JOIN monthly_revenue mr  
    ON c.month = mr.month
ORDER BY c.month;

-- Level 2. Calculate month-over-month percentage change in revenue using the LAG() column you just built
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
    WHERE payment_status = 'Paid'
    GROUP BY DATE_TRUNC('month', payment_date)
),
prev_revenue AS (
    SELECT c.month,
        COALESCE(mr.revenue,0) AS revenue,
        LAG(COALESCE(mr.revenue,0)) OVER (ORDER BY c.month) AS previous_revenue
FROM calendar c 
LEFT JOIN monthly_revenue mr  
    ON c.month = mr.month
ORDER BY c.month
)
SELECT month,
    revenue,
    previous_revenue,
    ROUND((revenue - previous_revenue)/NULLIF(previous_revenue,0) *100,1) AS percent_revenue_change
FROM prev_revenue;

-- Determines whether each month is complete by checking if it falls before the month containing the latest available payment data
WITH calendar AS (
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
    WHERE payment_status = 'Paid'
    GROUP BY DATE_TRUNC('month', payment_date)
),
prev_revenue AS (
    SELECT c.month,
           COALESCE(mr.revenue, 0) AS revenue,
           LAG(COALESCE(mr.revenue, 0)) OVER (ORDER BY c.month) AS previous_revenue
    FROM calendar c
    LEFT JOIN monthly_revenue mr
        ON c.month = mr.month
),
final AS (
    SELECT month,
           revenue,
           previous_revenue,
           (revenue - previous_revenue)
               / NULLIF(previous_revenue, 0) * 100 AS percent_revenue_change
    FROM prev_revenue
)
SELECT month,
       revenue,
       previous_revenue,
       percent_revenue_change,
       CASE
           WHEN month < (
               SELECT DATE_TRUNC('month', MAX(payment_date))
               FROM payments
           )::date
           THEN 'Complete'
           ELSE 'Incomplete'
       END AS month_status
FROM final
ORDER BY month;

-- Level 3. For each customer, use LAG() partitioned by customer_id to calculate the number of days between their consecutive payments. Are there customers with unusually long gaps between payments?
WITH payment_history AS (
     SELECT
        customer_id,
        payment_date,
        LAG(payment_date) OVER (
            PARTITION BY customer_id
            ORDER BY payment_date
        ) AS previous_payment_date
    FROM payments
)
SELECT
    customer_id,
    payment_date,
    previous_payment_date,
    payment_date - previous_payment_date AS days_between_payments
FROM payment_history
ORDER BY days_between_payments DESC NULLS LAST;

-- Level 4. The CFO's actual concern: "Tell me when our growth started slowing down, not just that it did." 
-- Use your month-over-month figures to identify the specific period(s) where momentum shifted, and explain your reasoning
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

prev_revenue AS (
    SELECT
        c.month,
        COALESCE(mr.revenue, 0) AS revenue,
        LAG(COALESCE(mr.revenue, 0)) OVER (
            ORDER BY c.month
        ) AS previous_revenue
    FROM calendar c
    LEFT JOIN monthly_revenue mr
        ON c.month = mr.month
),

percentage_revenue_change AS (
    SELECT
        month,
        revenue,
        previous_revenue,
        ROUND(
            (revenue - previous_revenue)
            / NULLIF(previous_revenue, 0) * 100,
            1
        ) AS percent_revenue_change
    FROM prev_revenue
),

prev_percentage_revenue_change AS (
    SELECT
        month,
        revenue,
        previous_revenue,
        percent_revenue_change,
        LAG(percent_revenue_change) OVER (
            ORDER BY month
        ) AS previous_percent_revenue_change
    FROM percentage_revenue_change
)

SELECT
    month,
    revenue,
    previous_revenue,
    percent_revenue_change,
    previous_percent_revenue_change,
    percent_revenue_change - previous_percent_revenue_change
        AS momentum_change_pp
FROM prev_percentage_revenue_change
ORDER BY month;

-- Growth momentum shifted downward beginning in April 2026, with MoM growth falling from 22.2% in March to 7.8% in April and then 1.7% in May. Growth remained positive, but at substantially lower rates.
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

prev_revenue AS (
    SELECT
        c.month,
        COALESCE(mr.revenue, 0) AS revenue,
        LAG(COALESCE(mr.revenue, 0)) OVER (
            ORDER BY c.month
        ) AS previous_revenue
    FROM calendar c
    LEFT JOIN monthly_revenue mr
        ON c.month = mr.month
),

rolling AS (
    SELECT
        month,
        revenue,
        AVG(revenue) OVER (
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3mo_avg
    FROM prev_revenue
),

previous_rolling AS (
    SELECT
        month,
        revenue,
        rolling_3mo_avg,
        LAG(rolling_3mo_avg) OVER (
            ORDER BY month
        ) AS previous_rolling_3mo_avg
    FROM rolling
)

SELECT
    month,
    revenue,
    rolling_3mo_avg,
    previous_rolling_3mo_avg,
    ROUND(
        (rolling_3mo_avg - previous_rolling_3mo_avg)
        / NULLIF(previous_rolling_3mo_avg, 0) * 100,
        1
    ) AS rolling_mom_change
FROM previous_rolling
ORDER BY month;

-- growth continued throughout the period, with no evidence of a sustained slowdown; April showed a temporarily softer month within an otherwise still-growing trend, and May and June show the trend resuming strongly.
