-- Level 1. Write a query that shows each distinct category value in support_tickets exactly as stored, with a count of rows for each
SELECT category, COUNT(*)
FROM support_tickets
GROUP BY category;

-- Level 2. Rewrite that query so casing variants of the same category (e.g., 'Bug Report' and 'BUG REPORT') are collapsed into one consistent value.
SELECT UPPER(category) AS category, 
        COUNT(*) AS ticket_count
FROM support_tickets
GROUP BY UPPER(category);

SELECT INITCAP(category) AS category, 
        COUNT(*) AS ticket_count
FROM support_tickets
GROUP BY INITCAP(category);


-- Level 3. Using CASE, bucket customers.company_size_band into two groups: 'SMB' (1-10, 11-50) and 'Mid-Market+' (51-200, 201-500, 500+). Count customers in each bucket.
SELECT CASE
            WHEN company_size_band IN ('1-10', '11-50') THEN 'SMB'
            WHEN company_size_band IN ('51-200', '201-500', '500+') THEN 'Mid-Market+'
            ELSE 'Unclassified'
        END AS customer_bucket,
            COUNT(*) AS customer_count
FROM customers
GROUP BY 
       CASE
            WHEN company_size_band IN('1-10', '11-50') THEN 'SMB'
            WHEN company_size_band IN ('51-200', '201-500', '500+') THEN 'Mid-Market+'
            ELSE 'Unclassified'
        END;

-- Finance wants every payment amount displayed as a clean 2-decimal currency figure in a report, with refunds clearly distinguishable from regular charges. Design the output.
SELECT ROUND(amount,2) AS amount,
        CASE
            WHEN amount < 0 THEN 'Refund'
            WHEN amount > 0 THEN 'Regular Charge'
            ELSE 'zero'
        END AS transaction_type, 
FROM payments;

-- gROUP BY
SELECT
    CASE
        WHEN amount < 0 THEN 'Refund'
        WHEN amount > 0 THEN 'Regular Charge'
        ELSE 'Zero'
    END AS transaction_type,
    COUNT(*) AS transaction_count
FROM payments
GROUP BY
    CASE
        WHEN amount < 0 THEN 'Refund'
        WHEN amount > 0 THEN 'Regular Charge'
        ELSE 'Zero'
    END;