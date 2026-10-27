-- =====================================================================
-- Marketing Campaign Performance & Conversion Analytics
-- SQL dialect: MySQL 8.0+
--
-- Dataset: UCI Bank Marketing (Moro, Laureano & Cortez, 2011)
-- Source: bank_marketing_python_cleaned.csv
-- Expected records: 45,211
--
-- IMPORTANT:
-- Import the CSV into bank_marketing before running this script.
-- Estimated_Cost assumes $0.50 per minute of call duration; it is not
-- actual campaign spend. Estimated CPA is a descriptive estimate.
-- Call duration is known after a call and should not be treated as a
-- pre-call targeting variable.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS bank_marketing_db;
USE bank_marketing_db;

-- 0. QUICK DATA PREVIEW
SELECT *
FROM bank_marketing
LIMIT 10;


-- =====================================================================
-- 1. DATA VALIDATION
-- =====================================================================

-- 1.1 Total records (expected: 45,211)
SELECT COUNT(*) AS total_records
FROM bank_marketing;

-- 1.2 Missing values in key columns
SELECT
    SUM(Channel IS NULL)        AS missing_channel,
    SUM(Converted IS NULL)      AS missing_outcome,
    SUM(Converted_Flag IS NULL) AS missing_conversion_flag
FROM bank_marketing;

-- 1.3 Conversion outcomes (expected: no = 39,922; yes = 5,289)
SELECT
    LOWER(Converted) AS conversion_outcome,
    COUNT(*) AS customer_count
FROM bank_marketing
GROUP BY LOWER(Converted)
ORDER BY conversion_outcome;

-- 1.4 Validate Converted_Flag against the yes/no outcome (expected: 0)
SELECT COUNT(*) AS incorrect_flags
FROM bank_marketing
WHERE Converted IS NULL
   OR Converted_Flag IS NULL
   OR Converted_Flag <>
      CASE
          WHEN LOWER(Converted) = 'yes' THEN 1
          ELSE 0
      END;

-- 1.5 Check estimated cost against the $0.50/minute assumption
-- Tolerance of $0.02 allows for rounding differences.
SELECT COUNT(*) AS rows_with_cost_mismatch
FROM bank_marketing
WHERE Duration_Minutes IS NOT NULL
  AND Estimated_Cost IS NOT NULL
  AND ABS(Estimated_Cost - (Duration_Minutes * 0.50)) > 0.02;


-- =====================================================================
-- 2. OVERALL CAMPAIGN KPIs
-- =====================================================================

-- Business question: How did the campaign perform overall?
-- Expected: 45,211 contacts; 5,289 conversions; conversion rate ~11.70%.
SELECT
    COUNT(*) AS total_contacts,
    SUM(Converted_Flag) AS total_conversions,
    COUNT(*) - SUM(Converted_Flag) AS non_conversions,
    ROUND(AVG(Converted_Flag) * 100, 2) AS conversion_rate_pct,
    ROUND(AVG(Duration_Minutes), 2) AS avg_call_duration_minutes
FROM bank_marketing;

-- Business question: What is the estimated cost per subscriber?
-- This uses the documented assumption, not actual campaign expenditure.
SELECT
    ROUND(
        SUM(Estimated_Cost) / NULLIF(SUM(Converted_Flag), 0),
        2
    ) AS estimated_cpa
FROM bank_marketing;


-- =====================================================================
-- 3. CHANNEL AND CUSTOMER SEGMENT ANALYSIS
-- =====================================================================

-- Business question: Which contact channels have the highest observed
-- conversion rates and estimated CPA?
SELECT
    Channel,
    COUNT(*) AS total_contacts,
    SUM(Converted_Flag) AS conversions,
    ROUND(AVG(Converted_Flag) * 100, 2) AS conversion_rate_pct,
    ROUND(
        SUM(Estimated_Cost) / NULLIF(SUM(Converted_Flag), 0),
        2
    ) AS estimated_cpa
FROM bank_marketing
GROUP BY Channel
ORDER BY conversion_rate_pct DESC;

-- Business question: Which job categories have relatively strong
-- conversion rates and what is their estimated CPA?
SELECT
    job,
    COUNT(*) AS total_contacts,
    SUM(Converted_Flag) AS conversions,
    ROUND(AVG(Converted_Flag) * 100, 2) AS conversion_rate_pct,
    ROUND(
        SUM(Estimated_Cost) / NULLIF(SUM(Converted_Flag), 0),
        2
    ) AS estimated_cpa
FROM bank_marketing
GROUP BY job
ORDER BY conversion_rate_pct DESC, total_contacts DESC;

-- Business question: How do job categories rank by conversion rate?
-- RANK() requires MySQL 8.0 or later.
SELECT
    job,
    COUNT(*) AS total_contacts,
    SUM(Converted_Flag) AS conversions,
    ROUND(AVG(Converted_Flag) * 100, 2) AS conversion_rate_pct,
    RANK() OVER (ORDER BY AVG(Converted_Flag) DESC) AS conversion_rank
FROM bank_marketing
GROUP BY job
ORDER BY conversion_rank, job;

-- Business question: How does conversion vary by customer age group?
SELECT
    Age_Band,
    COUNT(*) AS total_contacts,
    SUM(Converted_Flag) AS conversions,
    ROUND(AVG(Converted_Flag) * 100, 2) AS conversion_rate_pct
FROM bank_marketing
GROUP BY Age_Band
ORDER BY
    CASE Age_Band
        WHEN '18-25' THEN 1
        WHEN '26-35' THEN 2
        WHEN '36-45' THEN 3
        WHEN '46-55' THEN 4
        WHEN '56+'   THEN 5
        ELSE 6
    END;

-- Business question: Which months have the strongest conversion rates?
-- Source month labels are abbreviated (jan, feb, ...).
SELECT
    month,
    COUNT(*) AS total_contacts,
    SUM(Converted_Flag) AS conversions,
    ROUND(AVG(Converted_Flag) * 100, 2) AS conversion_rate_pct
FROM bank_marketing
GROUP BY month
ORDER BY FIELD(
    LOWER(month),
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
);


-- =====================================================================
-- 4. PREVIOUS CONTACT AND CAMPAIGN HISTORY
-- =====================================================================

-- Business question: Do previously contacted customers convert
-- differently from customers with no recorded prior contact?
SELECT
    Prior_Contacted,
    COUNT(*) AS total_contacts,
    SUM(Converted_Flag) AS conversions,
    ROUND(AVG(Converted_Flag) * 100, 2) AS conversion_rate_pct
FROM bank_marketing
GROUP BY Prior_Contacted
ORDER BY conversion_rate_pct DESC;

-- Business question: Does the previous campaign outcome relate to
-- conversion in the current campaign?
SELECT
    poutcome,
    COUNT(*) AS total_contacts,
    SUM(Converted_Flag) AS conversions,
    ROUND(AVG(Converted_Flag) * 100, 2) AS conversion_rate_pct
FROM bank_marketing
GROUP BY poutcome
ORDER BY conversion_rate_pct DESC;

-- Business question: How does contact frequency in the current campaign
-- relate to conversion?
SELECT
    Campaign_Bucket,
    COUNT(*) AS total_contacts,
    ROUND(
        100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS share_of_contacts_pct,
    SUM(Converted_Flag) AS conversions,
    ROUND(AVG(Converted_Flag) * 100, 2) AS conversion_rate_pct
FROM bank_marketing
GROUP BY Campaign_Bucket
ORDER BY
    CASE Campaign_Bucket
        WHEN '1 contact' THEN 1
        WHEN '2-3 contacts' THEN 2
        WHEN '4+ contacts' THEN 3
        ELSE 4
    END;


-- =====================================================================
-- 5. BEST-PERFORMING CUSTOMER SEGMENTS
-- =====================================================================

-- Business question: Which job and age-group combinations have the
-- strongest observed conversion rates?
-- Minimum of 100 contacts reduces the influence of very small groups.
SELECT
    job,
    Age_Band,
    COUNT(*) AS total_contacts,
    SUM(Converted_Flag) AS conversions,
    ROUND(AVG(Converted_Flag) * 100, 2) AS conversion_rate_pct
FROM bank_marketing
GROUP BY job, Age_Band
HAVING COUNT(*) >= 100
ORDER BY conversion_rate_pct DESC, total_contacts DESC
LIMIT 10;


-- =====================================================================
-- 6. OVERALL KPI SUMMARY FOR TABLEAU VALIDATION
-- =====================================================================

SELECT
    COUNT(*) AS total_contacts,
    SUM(Converted_Flag) AS total_conversions,
    COUNT(*) - SUM(Converted_Flag) AS non_conversions,
    ROUND(AVG(Converted_Flag) * 100, 2) AS conversion_rate_pct,
    ROUND(AVG(Duration_Minutes), 2) AS avg_call_duration_minutes,
    ROUND(
        SUM(Estimated_Cost) / NULLIF(SUM(Converted_Flag), 0),
        2
    ) AS estimated_cpa
FROM bank_marketing;


-- =====================================================================
-- END OF ANALYSIS
-- Interpretation: These results show associations in historical data.
-- They do not prove that a segment or contact strategy causes conversion.
-- =====================================================================
