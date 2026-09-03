-- ============================================================
-- Lumen Analytics
-- Phase 1: Data Familiarisation & Grain
-- ============================================================

-- Database: LUMEN
-- Schema: public
-- Tool: PostgreSQL
-- ============================================================
-- Level 1. For each of the 4 tables, write a query confirming its primary key is actually unique (no duplicate IDs)
-- Customers Table
SELECT customer_id, COUNT(*)
FROM public.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- payments Table
SELECT payment_id, COUNT(*)
FROM payments
GROUP BY payments_id
HAVING COUNT(*) > 1;

-- events Table
SELECT event_id, COUNT(*)
FROM usage_events
GROUP BY event_id
HAVING COUNT(*) > 1;

-- tickets Table
SELECT ticket_id, COUNT(*)
FROM support_tickets
GROUP BY ticket_id
HAVING COUNT(*) > 1;

-- Level 1. Return the row count of each table, and the earliest and latest date present in each date column across the dataset
SELECT COUNT(*) AS tot_rows, MIN(signup_date) AS earliest_date, MAX(signup_date) AS latest_date
FROM customers;

SELECT COUNT(*) AS tot_rows, MIN(payment_date) AS earliest_date, MAX(payment_date) AS latest_date
FROM payments;

SELECT COUNT(*) AS tot_rows, MIN(event_date) AS event_date, MAX(event_date) AS latest_date
FROM usage_events;

SELECT COUNT(*) AS tot_rows, MIN(opened_date) AS earliest_date, MAX(opened_date) AS latest_date
FROM support_tickets;

SELECT COUNT(*) AS tot_rows, MIN(closed_date) AS earliest_date, MAX(closed_date) AS latest_date
FROM support_tickets;

-- Level 2. List the distinct values in customers.region, customers.plan_type_at_signup, and payments.payment_status. Do any look suspicious?
SELECT DISTINCT region
FROM customers;

SELECT DISTINCT plan_type_at_signup
FROM customers;

SELECT DISTINCT payment_status
FROM payments;

-- Level 3. For every customer_id in payments, usage_events, and support_tickets, confirm it exists in customers. Are there any orphaned rows?
SELECT p.customer_id,c.customer_id
FROM payments AS p
LEFT JOIN customers AS c
ON p.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT s.customer_id,c.customer_id
FROM support_tickets AS s
LEFT JOIN customers AS c
ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT u.customer_id,c.customer_id
FROM usage_events AS u
LEFT JOIN customers AS c
ON u.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

