-- Level 1. Calculate the average and the median (PERCENTILE_CONT(0.5)) payment amount. Are they close, or far apart?
SELECT  
    AVG(amount) AS average_payment,
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY amount) as median_payment
FROM payments
WHERE payment_status = 'Paid';

-- Findings
-- The average payment ($218.20) is substantially higher than the median payment ($51.27), suggesting that a relatively small number of unusually large payments are pulling the average upward. This indicates that payment amounts are right-skewed, so the median may better represent a typical payment.

-- Level 2. Calculate the standard deviation of payment amounts. What does a large standard deviation relative to the mean suggest about the distribution?
SELECT STDDEV(amount) AS std_dev
FROM payments;

-- Findings
-- The standard deviation of $248.28 is larger than the mean payment of $218.20, indicating substantial variability in payment amounts. Combined with the much lower median of $51.27, this suggests a highly dispersed, right-skewed distribution where unusually large payments have a significant influence on the mean.


-- Level 3. Break customers into quartiles by their total lifetime payments using NTILE(4). Which quartile of customers is generating the majority of revenue?
WITH customer_payments AS (
    SELECT
        customer_id,
        SUM(amount) AS lifetime_payment
    FROM payments
    GROUP BY customer_id
),
quartiled_customers AS (
    SELECT
        customer_id,
        lifetime_payment,
        NTILE(4) OVER(ORDER BY lifetime_payment) AS quartile
    FROM customer_payments
)
SELECT
    quartile,
    SUM(lifetime_payment) AS total_revenue
FROM quartiled_customers
GROUP BY quartile
ORDER BY quartile;

-- Findings
-- The highest-paying quartile (Q4) generates $163,416.04, representing approximately 69.6% of total lifetime revenue. This indicates that revenue is highly concentrated among the top 25% of customers, highlighting the importance of retaining high-value customers.


-- Level 4. Finance's actual question: "Is 'average revenue per customer' even a useful number to report given what you've found?" Write your recommendation, with the numbers to back it up.
-- The average revenue per customer is useful as a high-level summary, but it should not be reported on its own. The payment data shows substantial skew:
-- The average payment of $218.20 is significantly higher than the median payment of $51.27, suggesting that a relatively small number of large payments are pulling the average upward.
-- The standard deviation of $248.28, which is also larger than the mean, further indicates substantial variability in payment amounts.
-- More importantly, customer-level analysis shows that revenue is highly concentrated.
-- The highest-paying quartile (the top 25% of customers) generates $163,416.04, approximately 69.6% of total lifetime revenue
-- Therefore, an overall average revenue-per-customer figure could mask the large differences in customer value.
-- I recommend that Finance report average revenue per customer alongside the median and customer-value quartiles. The average is useful for understanding overall revenue relative to the customer base, but the median and quartile breakdown provide a more representative view of the typical customer and reveal how heavily revenue depends on high-value customers.

SELECT payment_status, COUNT(*), SUM(amount), AVG(amount)
FROM payments
GROUP BY payment_status;