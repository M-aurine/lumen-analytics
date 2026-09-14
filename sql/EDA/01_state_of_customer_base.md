# Lumen Analytics — State of the Customer Base

## EDA Process — Steps 1–10

## 1. Understand what each table represents

* **Customers:** Represents the subscribing companies, with one customer record containing attributes such as tier, region, signup date, and churn date.
* **Payments:** Contains one record per billing transaction, linked to customers through `customer_id`.
* The `customers` table provides customer-level information, while `payments` provides transaction-level information.
* The data spans **2024–2026**.

## 2. Profile row counts and distributions

* The `customers` table contains **73 records representing 70 unique companies**, with 3 apparent duplicate company records.
* The `payments` table contains **1,076 payment transactions**.
* Across all 73 customer records, **Starter is the largest tier with 43 customers**, followed by Growth (19) and Scale (11).
* Of the 73 customer records, **54 are active and 19 have churned**.
* Among active customers, Starter remains the largest tier with 30 customers, followed by Growth (13) and Scale (11).
* Customer tenure ranges from **37 to 962 days**, with a median of **501 days (~1.4 years)** and an average of **479 days (~1.3 years)**.

## 3. Assess data quality

* There are **3 apparent duplicate company records** among the 73 customer records.
* The available fields do not establish whether these are true duplicates or separate operational records, so the cause cannot be confirmed.
* Possible explanations include the same company being entered through different processes or being created without checking for an existing record.
* Because these records may represent separate customer entries, they should be treated cautiously rather than automatically removed.

### Seasonality

* No reliable seasonal pattern can be established for customer signups or churn.
* The dataset contains 73 customer records covering approximately 2.5 years, with 2026 only partially represented.
* The limited history and relatively small number of customers make it difficult to distinguish genuine seasonal trends from normal fluctuations.
* Seasonal patterns should therefore be treated as inconclusive until more customer history is available.

## 4. Explore individual variables

### Customers

* Customer tenure ranges from **37 to 962 days**.
* The median tenure is **501 days (~1.4 years)**, while the average is **479 days (~1.3 years)**.

### Payments

* The average paid transaction amount is **$231.45**.
* The median payment amount is **$51.36** for Paid transactions.
* Payment standard deviation is **$248.28**, showing substantial variation in payment values.
* The median is more representative of a typical payment because larger payments pull the average upward.

## 5. Explore relationships between variables

* Customer count does not necessarily correspond to customer value.
* A region can have many active customers but generate relatively low revenue.
* Revenue is highly concentrated among a relatively small group of high-value customers.
* The top 25% of customers generate **$163,416.04**, representing **69.6% of total lifetime revenue**.
* This shows that looking only at total customer counts or overall averages can hide substantial differences in economic value.
* The concentration of revenue also means that losing a small number of high-value customers could have a disproportionately large effect on total revenue.

## 6. Segment

* Customers can be segmented by **tier, region, customer value, and payment status**.
* Across the full customer base, **Starter** is the largest tier with 43 customers, followed by **Growth** (19) and **Scale** (11).
* Among active customers, Starter remains the largest segment with 30 customers, followed by Growth (13) and Scale (11).
* Customer count does not necessarily indicate revenue contribution.
* The top 25% of customers account for **69.6% of lifetime revenue**, making customer-value segmentation particularly important.
* Finance and Sales should consider both customer volume and customer value when evaluating the customer base and revenue exposure.

### Payment Status

* Of the 1,076 payment transactions, **995 (92.5%) were Paid**, **49 (4.6%) Failed**, and **32 (3.0%) were Refunded**.
* The large majority of transactions were successfully paid, while failed and refunded transactions represent a smaller portion of payment activity.
* Payment status provides another useful way to segment payment activity and monitor potential revenue leakage from failed or refunded transactions.

## 7. Investigate anomalies

### Duplicate company names

* 3 company names appear more than once in the `customers` table:

  * `Brady, Taylor and Downs` — 2 records
  * `Drake-Thomas` — 2 records
  * `Fuentes PLC` — 2 records

* Further investigation shows that each repeated company name has a different `customer_id` and `signup_date`, but the records share the same plan type and region.

* The records also have different payment histories:

  * `Brady, Taylor and Downs`: customer 61 had 12 paid payments totaling **$2,388.95**, while customer 72 had 1 paid payment totaling **$207.52**.
  * `Drake-Thomas`: customer 58 had 26 paid payments totaling **$11,100.55**, while customer 73 had 18 paid payments totaling **$840.50**.
  * `Fuentes PLC`: customer 25 had 15 paid payments totaling **$688.63**, while customer 71 had no payments and therefore **$0.00** in paid revenue.

* The records are therefore not identical duplicates. However, the repeated company names are anomalous and warrant further investigation because they may represent duplicate customer records or separate records for the same company.

### Payment reconciliation

* The anomaly investigation distinguishes **paid revenue** from the raw sum of all payment transactions.
* Summing `amount` without filtering by `payment_status` includes Failed and Refunded transactions.
* For customer-value analysis, the paid-only totals are used because they better represent successfully collected revenue.

## 8. Form hypotheses

### Duplicate company names

* **Hypothesis:** The repeated company names may represent the same companies being entered into the customer table more than once, potentially through different operational processes or without checking for an existing record.
* **Alternative explanation:** The repeated names may represent legitimate separate customer records or other business circumstances not captured in the available fields.
* The different customer IDs, signup dates, and payment histories mean the records cannot be confirmed as duplicates based on company name alone.

## 9. Test hypotheses with SQL

### SQL investigation

```sql
SELECT
    company_name,
    customer_id,
    signup_date,
    churn_date,
    plan_type_at_signup,
    region
FROM customers
WHERE company_name IN (
    'Drake-Thomas',
    'Brady, Taylor and Downs',
    'Fuentes PLC'
)
ORDER BY company_name, signup_date;
```

### Payment history investigation

Payment history was compared across the customer records sharing the same company name.

* For `Brady, Taylor and Downs`, customer 61 had an established monthly payment history from July 2025 to June 2026, while customer 72 was created on June 17, 2026 and made a payment on the same day. Both records are Growth customers in Africa.

* For `Drake-Thomas`, customer 58 had an established payment history from May 2024 to June 2026, while customer 73 was created on January 22, 2025 and began a separate monthly payment history while customer 58 was still active. Both records are Starter customers in Asia Pacific.

* For `Fuentes PLC`, customer 25 had payments from April 2025 to June 2026, while customer 71 was created on August 5, 2026 and has no payment history yet.

* The overlapping payment activity for `Brady, Taylor and Downs` and `Drake-Thomas` supports the hypothesis that some repeated company names may represent duplicate customer records.

* The `Fuentes PLC` case is inconclusive because the second customer record has not generated any payments yet.

* Overall, the available data supports further investigation of the repeated customer records but does not conclusively establish the operational cause.

## 10. Communicate findings in plain language

### State of the customer base

Lumen currently has **73 customer records representing 70 unique company names**, indicating 3 apparent duplicate company records that should be reviewed before relying on customer counts for decision-making.

The customer base is concentrated in the **Starter tier**, with 43 customers, compared with 19 Growth customers and 11 Scale customers. Of the 73 customer records, 54 are currently active and 19 have churned.

Payment activity is generally successful: **92.5% of the 1,076 payment transactions were marked as Paid**, while 4.6% Failed and 3.0% were Refunded. However, payment amounts vary considerably, meaning the median is more representative of a typical payment than the average.

Customer value is highly concentrated. The **top 25% of customers account for approximately 69.6% of lifetime revenue**. This means that customer count alone does not show where Lumen's financial exposure is concentrated.

The analysis also identified repeated company names with separate customer IDs, signup dates, and payment histories. Some cases show overlapping payment activity, which supports the possibility of duplicate customer records, although the available data cannot confirm the operational cause.

Overall, the customer base has a large Starter segment, generally successful payment activity, and substantial revenue concentration among a smaller group of customers. The most important follow-up areas are reviewing the repeated customer records and monitoring the high-value customer segment.
