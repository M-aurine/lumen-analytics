-- Level 1. Count how many customers rows have a NULL acquisition_channel.
SELECT COUNT(*)
FROM customers
WHERE acquisition_channel IS NULL;

-- Level 2. Recompute that count as a percentage of all customers. Then write a version of the channel breakdown that labels NULLs as 'Unknown' instead of dropping them silently -- using COALESCE.
-- NuLL Percentage
SELECT COUNT(CASE 
                WHEN acquisition_channel IS NULL THEN 1 
            END)*100.0/COUNT(*) AS null_percen
FROM customers;

-- Channel breakdown
SELECT COALESCE(acquisition_channel,'Unknown') AS acquisition_channel, COUNT(*) AS customer_count
FROM customers
GROUP BY COALESCE(acquisition_channel, 'Unknown');

-- Level 3. Find every support_tickets row where closed_date is earlier than opened_date. Is this a data entry error, or could there be a legitimate explanation? Justify your answer with a follow-up query if needed.
SELECT *
FROM support_tickets
WHERE closed_date < opened_date;

-- Level 4. The VP of Customer Success asks: "What % of our tickets are still unresolved?" Decide what 'unresolved' should mean given the resolution_status values available, and justify your definition before answering.
SELECT COUNT(CASE
                WHEN resolution_status IN ('Open','Closed - No Fix', 'Escalated') THEN 1
            END)*100.0/COUNT(*) AS unresolved_percen
FROM support_tickets;

-- Level 5. Investigate: are the duplicate customer records (the same company appearing under two different customer_id values) inflating any metric you've calculated so far? Pick one metric and check.
-- Found out there are 70 unique companies
SELECT DISTINCT company_name
FROM customers;

-- There are 3 duplicated company names
SELECT company_name,COUNT(*)
FROM customers
GROUP BY company_name
HAVING COUNT(*) > 1;

-- There are 3 duplicated company's
SELECT *
FROM customers
WHERE company_name IN ('Drake-Thomas','Brady, Taylor and Downs','Fuentes PLC');

-- Churn Rate
-- Overall churn rate for the 73 companies is 26.02%
-- The duplicates are NOT contributing to the churned-customer numerator as they are all NULL.
SELECT COUNT(CASE
                WHEN churn_date IS NOT NULL THEN 1
             END)*100.0/COUNT(*) AS churn_rate
FROM customers;

-- Deduplicated version
-- Resulted to a churn rate of 27.14%, a 1.12 percentage point increase. 
WITH ranked_customers AS (
    SELECT *,
            ROW_NUMBER() OVER(
                PARTITION BY company_name
                ORDER BY signup_date
            )AS rn 
    FROM customers
)
SELECT  COUNT(CASE
                WHEN churn_date IS NOT NULL THEN 1
              END)*100.0/COUNT(*) AS churn_rate
FROM  ranked_customers
WHERE rn = 1;

SELECT customer_id, company_name, signup_date, churn_date
FROM customers
WHERE company_name IN ('Drake-Thomas','Brady, Taylor and Downs','Fuentes PLC')
ORDER BY company_name, signup_date;

-- Conclusion
-- All the duplicated rows have NULL churn date, providing no evidence that the later records represent re-subscriptions following a previous churn.
-- Given that each duplicated company has two different customer IDs, signup dates separated by several months, and otherwise identical customer attributes, the records are more consistent with duplicate company entries than with clearly identifiable re-subscriptions
-- They look like independent duplicate entries, most likely the same company being entered to the system twice, months apart, by someone different ie different sales rep, a different signup flow who did not check whether the company already  exists
-- The likely operational cause of the duplicates cannot be confirmed from the available fields, but possibilities include a company being entered more than once through different processes or without checking for an existing record.
-- If these records represent the same companies, they inflate the customer population from 70 unique companies to 73 customer records. This has a measurable effect on churn: the reported churn rate increases from 26.02% to 27.14% when the suspected duplicates are treated as a single company, a difference of 1.12 percentage points.
