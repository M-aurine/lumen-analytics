-- Level 1. Join customers to payments and count total rows. Does the count match customers, payments, or neither? Explain why.
SELECT *
FROM customers c
FULL OUTER JOIN payments p    
USING(customer_id); --1077 rows

SELECT COUNT(*) FROM payments; -- 1076 rows
SELECT COUNT(*) FROM customers; -- 73 rows

-- Level 2. Before writing any query: if you joined payments AND usage_events onto customers in the same query (not pre-aggregated), what would happen to a customer's payment totals? Answer in words first, then prove it by writing the query and comparing the wrong total to the correct one
-- Wrong joining
-- The payments can be duplicated because they're being matched with every usage event belonging to the customer
SELECT c.customer_id,
        SUM(p.amount) AS revenue
FROM customers c
LEFT JOIN payments p
    ON p.customer_id = c.customer_id AND p.payment_status = 'Paid'
LEFT JOIN usage_events u
    ON u.customer_id = c.customer_id AND p.payment_status = 'Paid'
GROUP BY c.customer_id
ORDER BY c.customer_id;

-- Correct join
SELECT 
    c.customer_id,
    COALESCE(SUM(p.amount), 0) AS correct_payment_total
FROM customers c
LEFT JOIN payments p
    ON c.customer_id = p.customer_id
    AND p.payment_status = 'Paid'
GROUP BY c.customer_id
ORDER BY c.customer_id;

-- Comparison
WITH wrong AS (
    SELECT 
        c.customer_id,
        SUM(p.amount) AS wrong_total
    FROM customers c
    LEFT JOIN payments p
        ON c.customer_id = p.customer_id
    LEFT JOIN usage_events u
        ON c.customer_id = u.customer_id
    WHERE p.payment_status = 'Paid'
    GROUP BY c.customer_id
),

correct AS (
    SELECT 
        c.customer_id,
        COALESCE(SUM(p.amount), 0) AS correct_total
    FROM customers c
    LEFT JOIN payments p
        ON c.customer_id = p.customer_id
        AND p.payment_status = 'Paid'
    GROUP BY c.customer_id
)

SELECT
    w.customer_id,
    w.wrong_total,
    c.correct_total,
    w.wrong_total - c.correct_total AS overstatement
FROM wrong w
JOIN correct c
    ON w.customer_id = c.customer_id
WHERE w.wrong_total <> c.correct_total
ORDER BY overstatement DESC;

-- Level 3. Now build the correct version: pre-aggregate payments and usage_events into per-customer summaries separately (using CTEs), then join those summaries onto customers -- avoiding the fan-out from Level 2
WITH payment_summary AS(
    SELECT customer_id,
        SUM(amount) AS total_paid
    FROM payments
    WHERE payment_status = 'Paid'
    GROUP BY customer_id
),
usage_summary AS (
    SELECT customer_id,
        COUNT(*) AS total_usage_events
    FROM usage_events
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    COALESCE(p.total_paid, 0) AS total_paid,
    COALESCE(u.total_usage_events, 0) AS total_usage_events
FROM customers c
LEFT JOIN payment_summary p
    ON c.customer_id = p.customer_id
LEFT JOIN usage_summary u
    ON c.customer_id = u.customer_id
ORDER BY c.customer_id;

-- Level 4. Customer Success's actual request, in full: one row per customer with plan_type_at_signup,lifetime successful payment total, ticket count, and usage event count, sorted by ticket count descending (their highest-friction customers first)
WITH payment_summary AS(
    SELECT customer_id,
        SUM(amount) AS total_paid
    FROM payments
    WHERE payment_status = 'Paid'
    GROUP BY customer_id
),
usage_summary AS (
    SELECT customer_id,
        COUNT(*) AS total_usage_events
    FROM usage_events
    GROUP BY customer_id
),
ticket_count AS (
    SELECT customer_id,
        COUNT(*) AS total_tickets
    FROM support_tickets
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    c.p--lan_type_at_signup,
    COALESCE(p.total_paid, 0) AS total_paid,
    COALESCE(u.total_usage_events, 0) AS total_usage_events,
    COALESCE(tc.total_tickets,0) AS total_tickets
FROM customers c
LEFT JOIN payment_summary p
    ON c.customer_id = p.customer_id
LEFT JOIN usage_summary u
    ON c.customer_id = u.customer_id
LEFT JOIN ticket_count tc
    ON c.customer_id = tc.customer_id
ORDER BY COALESCE(tc.total_tickets,0) DESC;

_month DESC;
-- Level 5. Investigate: is there a relationship between how many support tickets a customer has filed and whether they've churned? State your finding and at least one alternative explanation for it that isn't "tickets cause churn."
WITH ticket_count AS (
    SELECT
        customer_id,
        COUNT(*) AS total_tickets
    FROM support_tickets
    GROUP BY customer_id
),

customer_metrics AS (
    SELECT
        c.customer_id,
        CASE
            WHEN c.churn_date IS NOT NULL THEN 'Churned'
            ELSE 'Active'
        END AS customer_status,

        COALESCE(tc.total_tickets, 0) AS total_tickets,

        EXTRACT(
            YEAR FROM AGE(
                COALESCE(c.churn_date, CURRENT_DATE),
                c.signup_date
            )
        ) * 12
        +
        EXTRACT(
            MONTH FROM AGE(
                COALESCE(c.churn_date, CURRENT_DATE),
                c.signup_date
            )
        ) AS tenure_months

    FROM customers c
    LEFT JOIN ticket_count tc
        ON c.customer_id = tc.customer_id
)

SELECT
    customer_status,
    COUNT(*) AS customer_count,
    ROUND(
        AVG(
            total_tickets::numeric
            / NULLIF(tenure_months, 0)
        ),
        2
    ) AS avg_tickets_per_month
FROM customer_metrics
GROUP BY customer_status
ORDER BY avg_tickets_per_month DESC;

-- Findings
-- Naive ticket-count comparison suggested churned customers file fewer tickets — but that comparison was confounded by tenure, since churned customers simply have less time to accumulate any. Once normalized to tickets per month of tenure, churned customers show roughly 2x the ticket-filing rate of active customers — consistent with, though not proof of, higher friction preceding churn.