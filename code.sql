CREATE DATABASE IF NOT EXISTS tea_brand_analysis;
USE tea_brand_analysis;

DROP TABLE IF EXISTS customers;
RENAME TABLE storedata_total TO customers;

CREATE TABLE IF NOT EXISTS customers (
    custid VARCHAR(50),
    retained INT,
    created VARCHAR(50),
    firstorder VARCHAR(50),
    lastorder VARCHAR(50),
    esent INT,
    eopenrate DECIMAL(10, 4),
    eclickrate DECIMAL(10, 4),
    avgorder DECIMAL(10, 2),
    ordfreq DECIMAL(10, 6),
    paperless INT,
    refill INT,
    doorstep INT,
    favday VARCHAR(20),
    city VARCHAR(20)
);

SELECT 
    COUNT(*) AS total_customers,
    COUNT(DISTINCT custid) AS total_unique_custid
FROM customers;

SELECT 
    COUNT(DISTINCT city) AS unique_cities_count,
    GROUP_CONCAT(DISTINCT city ORDER BY city SEPARATOR ', ') AS cities_list
FROM customers;

SELECT 
    CASE WHEN retained = 1 THEN 'Retained' ELSE 'Not Retained' END AS customer_status,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customers), 2) AS percentage
FROM customers
GROUP BY retained;

SELECT 
    ROUND(AVG(retained) * 100.0, 2) AS overall_retention_rate_pct
FROM customers;

SELECT 
    ROUND(AVG(avgorder), 2) AS overall_aov
FROM customers;

SELECT 
    ROUND(AVG(ordfreq), 4) AS overall_avg_order_freq
FROM customers;

DROP TABLE IF EXISTS customer_retention_analysis;

CREATE TABLE customer_retention_analysis AS
SELECT 
    CASE WHEN retained = 1 THEN 'Retained' ELSE 'Not Retained' END AS customer_status,
    COUNT(*) AS total_customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customers), 2) AS customer_share_pct,
    ROUND(AVG(avgorder), 2) AS avg_order_value,
    ROUND(AVG(ordfreq), 4) AS avg_order_frequency,
    ROUND(AVG(refill) * 100.0, 2) AS refill_adoption_pct,
    ROUND(AVG(doorstep) * 100.0, 2) AS doorstep_preference_pct,
    ROUND(AVG(paperless) * 100.0, 2) AS paperless_adoption_pct,
    ROUND(AVG(esent), 1) AS avg_emails_sent,
    ROUND(AVG(eopenrate), 2) AS avg_email_open_rate_pct,
    ROUND(AVG(eclickrate), 2) AS avg_email_click_rate_pct
FROM customers
GROUP BY retained;

SELECT * FROM customer_retention_analysis;

DROP TABLE IF EXISTS city_analysis;

CREATE TABLE city_analysis AS
SELECT 
    city,
    COUNT(*) AS customer_count,
    ROUND(AVG(retained) * 100.0, 2) AS retention_rate_pct,
    ROUND(AVG(avgorder), 2) AS avg_order_value,
    ROUND(AVG(ordfreq), 4) AS avg_order_freq
FROM customers
GROUP BY city
ORDER BY customer_count DESC;

SELECT * FROM city_analysis;

SELECT 
    city,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customers), 2) AS share_of_customers_pct
FROM customers
GROUP BY city
ORDER BY customer_count DESC;

SELECT 
    city,
    COUNT(*) AS customer_count,
    SUM(retained) AS retained_customers,
    ROUND(AVG(retained) * 100.0, 2) AS retention_rate_pct
FROM customers
GROUP BY city
ORDER BY retention_rate_pct DESC;

SELECT 
    city,
    ROUND(AVG(avgorder), 2) AS avg_order_value
FROM customers
GROUP BY city
ORDER BY avg_order_value DESC;

SELECT 
    city,
    ROUND(AVG(ordfreq), 4) AS avg_order_frequency
FROM customers
GROUP BY city
ORDER BY avg_order_frequency DESC;

WITH global_metrics AS (
    SELECT AVG(retained) AS avg_ret, AVG(avgorder) AS avg_aov FROM customers
)
SELECT 
    c.city,
    COUNT(*) AS total_customers,
    ROUND(AVG(c.retained) * 100.0, 2) AS retention_rate_pct,
    ROUND(AVG(c.avgorder), 2) AS avg_order_value
FROM customers c
CROSS JOIN global_metrics gm
GROUP BY c.city, gm.avg_ret, gm.avg_aov
HAVING AVG(c.retained) >= gm.avg_ret AND AVG(c.avgorder) >= gm.avg_aov
ORDER BY avg_order_value DESC;

WITH global_metrics AS (
    SELECT AVG(retained) AS avg_ret FROM customers
)
SELECT 
    c.city,
    COUNT(*) AS customer_count,
    ROUND(AVG(c.retained) * 100.0, 2) AS retention_rate_pct
FROM customers c
CROSS JOIN global_metrics gm
GROUP BY c.city, gm.avg_ret
HAVING AVG(c.retained) < gm.avg_ret
ORDER BY customer_count DESC;

DROP TABLE IF EXISTS city_opportunity_analysis;

CREATE TABLE city_opportunity_analysis AS
WITH benchmarks AS (
    SELECT
        AVG(retained) AS overall_retention,
        AVG(avgorder) AS overall_aov,
        AVG(ordfreq) AS overall_frequency
    FROM customers
),
city_metrics AS (
    SELECT
        city,
        COUNT(*) AS customer_count,
        AVG(retained) AS retention_rate,
        AVG(avgorder) AS avg_order_value,
        AVG(ordfreq) AS avg_order_freq
    FROM customers
    GROUP BY city
)
SELECT
    c.city,
    c.customer_count,
    ROUND(c.retention_rate * 100.0, 2) AS retention_rate_pct,
    ROUND(c.avg_order_value, 2) AS avg_order_value,
    ROUND(c.avg_order_freq, 4) AS avg_order_freq,
    CASE
        WHEN c.retention_rate >= b.overall_retention
             AND c.avg_order_value >= b.overall_aov
             AND c.avg_order_freq >= b.overall_frequency
            THEN 'Strong Overall'
        WHEN c.retention_rate >= b.overall_retention
             AND c.avg_order_value >= b.overall_aov
            THEN 'High Value & Loyal'
        WHEN c.avg_order_value >= b.overall_aov
             AND c.retention_rate < b.overall_retention
            THEN 'High Value but Low Retention'
        WHEN c.avg_order_freq >= b.overall_frequency
             AND c.retention_rate < b.overall_retention
            THEN 'Frequent but Low Retention'
        WHEN c.customer_count > (
            SELECT AVG(customer_count)
            FROM city_metrics
        )
             AND c.retention_rate < b.overall_retention
            THEN 'Large Base but Weak Retention'
        ELSE 'Needs Investigation'
    END AS city_opportunity_type
FROM city_metrics c
CROSS JOIN benchmarks b;

SELECT * FROM city_opportunity_analysis;

SELECT 
    city,
    COUNT(*) AS customer_count,
    ROUND(AVG(retained) * 100.0, 2) AS retention_rate_pct,
    SUM(retained) AS active_retained_pool
FROM customers
GROUP BY city
ORDER BY customer_count DESC, retention_rate_pct DESC;

WITH stats AS (
    SELECT 
        (SELECT COUNT(*) / COUNT(DISTINCT city) FROM customers) AS avg_cust_per_city,
        (SELECT AVG(avgorder) FROM customers) AS overall_avg_order
)
SELECT 
    c.city,
    COUNT(*) AS customer_count,
    ROUND(AVG(c.avgorder), 2) AS avg_order_value
FROM customers c
CROSS JOIN stats s
GROUP BY c.city, s.avg_cust_per_city, s.overall_avg_order
HAVING COUNT(*) < s.avg_cust_per_city AND AVG(c.avgorder) >= s.overall_avg_order
ORDER BY avg_order_value DESC;

SELECT 
    city,
    ROUND(AVG(ordfreq), 4) AS avg_order_freq,
    ROUND(AVG(avgorder), 2) AS avg_order_value,
    COUNT(*) AS customer_base
FROM customers
GROUP BY city
ORDER BY avg_order_freq DESC;

SELECT 
    city,
    COUNT(*) AS customer_count,
    ROUND(AVG(retained) * 100.0, 2) AS retention_rate_pct
FROM customers
GROUP BY city
ORDER BY customer_count DESC, retention_rate_pct ASC;

DROP TABLE IF EXISTS city_expansion_score;

CREATE TABLE city_expansion_score AS
WITH city_metrics AS (
    SELECT 
        city,
        COUNT(*) AS customer_volume,
        AVG(retained) AS retention_rate,
        AVG(avgorder) AS avg_order_value,
        AVG(ordfreq) AS avg_order_freq
    FROM customers
    GROUP BY city
),
ranked_metrics AS (
    SELECT 
        city,
        customer_volume,
        retention_rate,
        avg_order_value,
        avg_order_freq,
        PERCENT_RANK() OVER (ORDER BY customer_volume) AS volume_rank,
        PERCENT_RANK() OVER (ORDER BY retention_rate) AS retention_rank,
        PERCENT_RANK() OVER (ORDER BY avg_order_value) AS aov_rank,
        PERCENT_RANK() OVER (ORDER BY avg_order_freq) AS frequency_rank
    FROM city_metrics
)
SELECT 
    city,
    customer_volume,
    ROUND(retention_rate * 100.0, 2) AS retention_rate_pct,
    ROUND(avg_order_value, 2) AS avg_order_value,
    ROUND(avg_order_freq, 4) AS avg_order_freq,
    ROUND(
        (
            volume_rank * 0.35 +
            retention_rank * 0.35 +
            aov_rank * 0.15 +
            frequency_rank * 0.15
        ) * 100,
        2
    ) AS expansion_index_score,
    DENSE_RANK() OVER (
        ORDER BY (
            volume_rank * 0.35 +
            retention_rank * 0.35 +
            aov_rank * 0.15 +
            frequency_rank * 0.15
        ) DESC
    ) AS expansion_priority_rank
FROM ranked_metrics;

SELECT * 
FROM city_expansion_score
ORDER BY expansion_priority_rank;

SELECT 
    CASE WHEN retained = 1 THEN 'Retained' ELSE 'Not Retained' END AS customer_status,
    COUNT(*) AS customer_count,
    ROUND(AVG(avgorder), 2) AS avg_order_value,
    ROUND(AVG(ordfreq), 4) AS avg_order_frequency
FROM customers
GROUP BY retained;

SELECT 
    CASE WHEN retained = 1 THEN 'Retained' ELSE 'Not Retained' END AS customer_status,
    COUNT(*) AS total_customers,
    ROUND(AVG(refill) * 100.0, 2) AS refill_adoption_pct,
    ROUND(AVG(doorstep) * 100.0, 2) AS doorstep_preference_pct,
    ROUND(AVG(paperless) * 100.0, 2) AS paperless_adoption_pct
FROM customers
GROUP BY retained;

SELECT 
    CASE WHEN retained = 1 THEN 'Retained' ELSE 'Not Retained' END AS customer_status,
    ROUND(AVG(esent), 1) AS avg_emails_sent,
    ROUND(AVG(eopenrate), 2) AS avg_open_rate_pct,
    ROUND(AVG(eclickrate), 2) AS avg_click_rate_pct
FROM customers
GROUP BY retained;

SELECT 
    CASE 
        WHEN eopenrate = 0 THEN '0% Opens'
        WHEN eopenrate <= 25 THEN '1% - 25% Opens'
        WHEN eopenrate <= 50 THEN '26% - 50% Opens'
        WHEN eopenrate <= 75 THEN '51% - 75% Opens'
        ELSE '76% - 100% Opens'
    END AS open_rate_tier,
    COUNT(*) AS customer_count,
    ROUND(AVG(retained) * 100.0, 2) AS retention_rate_pct,
    ROUND(AVG(eclickrate), 2) AS avg_click_rate_pct
FROM customers
GROUP BY open_rate_tier
ORDER BY MIN(eopenrate);

DROP TABLE IF EXISTS city_behavior_analysis;

CREATE TABLE city_behavior_analysis AS
SELECT 
    city,
    COUNT(*) AS customer_count,
    ROUND(AVG(refill) * 100.0, 2) AS refill_adoption_pct,
    ROUND(AVG(doorstep) * 100.0, 2) AS doorstep_preference_pct,
    ROUND(AVG(paperless) * 100.0, 2) AS paperless_adoption_pct,
    ROUND(AVG(esent), 1) AS avg_emails_sent,
    ROUND(AVG(eopenrate), 2) AS avg_email_open_rate_pct,
    ROUND(AVG(eclickrate), 2) AS avg_email_click_rate_pct
FROM customers
GROUP BY city;

SELECT * FROM city_behavior_analysis;

SELECT 
    city,
    COUNT(*) AS customer_count,
    ROUND(AVG(refill) * 100.0, 2) AS refill_adoption_pct
FROM customers
GROUP BY city
ORDER BY refill_adoption_pct DESC;

SELECT 
    city,
    COUNT(*) AS customer_count,
    ROUND(AVG(doorstep) * 100.0, 2) AS doorstep_preference_pct
FROM customers
GROUP BY city
ORDER BY doorstep_preference_pct DESC;

SELECT 
    city,
    ROUND(AVG(esent), 1) AS avg_emails_sent,
    ROUND(AVG(eopenrate), 2) AS avg_open_rate_pct,
    ROUND(AVG(eclickrate), 2) AS avg_click_rate_pct
FROM customers
GROUP BY city
ORDER BY avg_open_rate_pct DESC, avg_click_rate_pct DESC;

WITH city_ranks AS (
    SELECT 
        city,
        COUNT(*) AS customer_count,
        ROUND(AVG(retained) * 100.0, 2) AS ret_pct,
        ROUND(AVG(avgorder), 2) AS aov,
        ROUND(AVG(ordfreq), 4) AS freq,
        DENSE_RANK() OVER (ORDER BY AVG(retained) DESC) AS rank_ret,
        DENSE_RANK() OVER (ORDER BY AVG(avgorder) DESC) AS rank_aov,
        DENSE_RANK() OVER (ORDER BY AVG(ordfreq) DESC) AS rank_freq
    FROM customers
    GROUP BY city
)
SELECT 
    city,
    customer_count,
    ret_pct,
    aov,
    freq,
    (rank_ret + rank_aov + rank_freq) AS combined_rank_score
FROM city_ranks
ORDER BY combined_rank_score ASC;

WITH global_benchmarks AS (
    SELECT AVG(retained) AS benchmark_ret, AVG(avgorder) AS benchmark_aov FROM customers
)
SELECT 
    c.city,
    COUNT(*) AS customer_count,
    ROUND(AVG(c.avgorder), 2) AS city_aov,
    ROUND(AVG(c.retained) * 100.0, 2) AS city_retention_pct,
    ROUND(gb.benchmark_aov, 2) AS global_aov,
    ROUND(gb.benchmark_ret * 100.0, 2) AS global_retention_pct
FROM customers c
CROSS JOIN global_benchmarks gb
GROUP BY c.city, gb.benchmark_aov, gb.benchmark_ret
HAVING AVG(c.avgorder) >= gb.benchmark_aov AND AVG(c.retained) < gb.benchmark_ret
ORDER BY city_aov DESC;

WITH global_benchmarks AS (
    SELECT AVG(avgorder) AS benchmark_aov, AVG(ordfreq) AS benchmark_freq FROM customers
)
SELECT 
    c.city,
    COUNT(*) AS customer_count,
    ROUND(AVG(c.avgorder), 2) AS city_aov,
    ROUND(AVG(c.ordfreq), 4) AS city_freq,
    ROUND(gb.benchmark_aov, 2) AS global_aov,
    ROUND(gb.benchmark_freq, 4) AS global_freq
FROM customers c
CROSS JOIN global_benchmarks gb
GROUP BY c.city, gb.benchmark_aov, gb.benchmark_freq
HAVING AVG(c.avgorder) < gb.benchmark_aov AND AVG(c.ordfreq) >= gb.benchmark_freq
ORDER BY city_freq DESC;


