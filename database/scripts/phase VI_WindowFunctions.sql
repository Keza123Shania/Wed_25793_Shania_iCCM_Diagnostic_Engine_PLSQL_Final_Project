-- =============================================================================
-- PHASE VI: Window Functions (Analytical SQL)
-- Student: Shania (25793)
-- File: wed_25793_shania_PhaseVI_WindowFunctions.sql
-- Purpose: Advanced analytics using ROW_NUMBER, RANK, DENSE_RANK, LAG, LEAD
-- =============================================================================
SET PAGESIZE 100;
SET LINESIZE 200;

PROMPT ========================================================================
PROMPT   WINDOW FUNCTION DEMO 1: ROW_NUMBER() - Patient Visit Ranking
PROMPT ========================================================================

-- Rank patients by number of visits, with row numbers
SELECT 
    ROW_NUMBER() OVER (ORDER BY visit_count DESC) AS row_num,
    patient_id,
    full_name,
    gender,
    visit_count,
    CASE 
        WHEN visit_count >= 5 THEN 'Frequent Visitor'
        WHEN visit_count >= 3 THEN 'Regular Visitor'
        ELSE 'Occasional Visitor'
    END AS patient_category
FROM (
    SELECT 
        p.patient_id,
        p.full_name,
        p.gender,
        COUNT(e.encounter_id) AS visit_count
    FROM patients p
    LEFT JOIN encounters e ON p.patient_id = e.patient_id
    GROUP BY p.patient_id, p.full_name, p.gender
)
WHERE visit_count > 0
ORDER BY visit_count DESC;

PROMPT;
PROMPT ========================================================================
PROMPT   WINDOW FUNCTION DEMO 2: RANK() and DENSE_RANK() - Disease Prevalence
PROMPT ========================================================================

-- Rank diseases by frequency with ties handled differently
SELECT 
    disease_name,
    diagnosis_count,
    RANK() OVER (ORDER BY diagnosis_count DESC) AS rank_with_gaps,
    DENSE_RANK() OVER (ORDER BY diagnosis_count DESC) AS dense_rank_no_gaps,
    ROUND(diagnosis_count * 100.0 / SUM(diagnosis_count) OVER (), 2) AS percentage
FROM (
    SELECT 
        d.name AS disease_name,
        COUNT(c.condition_id) AS diagnosis_count
    FROM iccm_diseases d
    LEFT JOIN conditions c ON d.disease_id = c.disease_id
    GROUP BY d.name
)
ORDER BY diagnosis_count DESC;

PROMPT;
PROMPT ========================================================================
PROMPT   WINDOW FUNCTION DEMO 3: PARTITION BY - Performance by Location
PROMPT ========================================================================

-- Analyze encounters by location with partitioned ranking
SELECT 
    district_name,
    village_name,
    encounter_count,
    ROW_NUMBER() OVER (PARTITION BY district_name ORDER BY encounter_count DESC) AS rank_in_district,
    ROUND(encounter_count * 100.0 / SUM(encounter_count) OVER (PARTITION BY district_name), 2) AS pct_of_district
FROM (
    SELECT 
        l.district_name,
        l.village_name,
        COUNT(e.encounter_id) AS encounter_count
    FROM locations l
    LEFT JOIN patients p ON l.location_id = p.location_id
    LEFT JOIN encounters e ON p.patient_id = e.patient_id
    GROUP BY l.district_name, l.village_name
)
WHERE encounter_count > 0
ORDER BY district_name, encounter_count DESC;

PROMPT;
PROMPT ========================================================================
PROMPT   WINDOW FUNCTION DEMO 4: LAG() and LEAD() - Trend Analysis
PROMPT ========================================================================

-- Track daily encounter volumes with previous/next day comparison
SELECT 
    encounter_date,
    daily_count,
    LAG(daily_count, 1) OVER (ORDER BY encounter_date) AS previous_day,
    LEAD(daily_count, 1) OVER (ORDER BY encounter_date) AS next_day,
    daily_count - LAG(daily_count, 1) OVER (ORDER BY encounter_date) AS change_from_prev,
    CASE 
        WHEN daily_count > LAG(daily_count, 1) OVER (ORDER BY encounter_date) THEN 'INCREASE'
        WHEN daily_count < LAG(daily_count, 1) OVER (ORDER BY encounter_date) THEN 'DECREASE'
        ELSE 'STABLE'
    END AS trend
FROM (
    SELECT 
        TRUNC(encounter_date) AS encounter_date,
        COUNT(*) AS daily_count
    FROM encounters
    GROUP BY TRUNC(encounter_date)
)
ORDER BY encounter_date DESC
FETCH FIRST 15 ROWS ONLY;

PROMPT;
PROMPT ========================================================================
PROMPT   WINDOW FUNCTION DEMO 5: Moving Averages - Weight Trends
PROMPT ========================================================================

-- Calculate moving average of patient weights over time
SELECT 
    patient_id,
    full_name,
    encounter_date,
    weight_kg AS current_weight,
    ROUND(AVG(weight_kg) OVER (
        PARTITION BY patient_id 
        ORDER BY encounter_date 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_3visits,
    ROUND(weight_kg - LAG(weight_kg, 1) OVER (
        PARTITION BY patient_id 
        ORDER BY encounter_date
    ), 2) AS weight_change
FROM (
    SELECT 
        p.patient_id,
        p.full_name,
        e.encounter_date,
        e.weight_kg
    FROM patients p
    JOIN encounters e ON p.patient_id = e.patient_id
    WHERE e.weight_kg IS NOT NULL
)
ORDER BY patient_id, encounter_date DESC;

PROMPT;
PROMPT ========================================================================
PROMPT   WINDOW FUNCTION DEMO 6: NTILE() - Quartile Distribution
PROMPT ========================================================================

-- Divide patients into quartiles based on visit frequency
SELECT 
    patient_id,
    full_name,
    visit_count,
    NTILE(4) OVER (ORDER BY visit_count) AS quartile,
    CASE NTILE(4) OVER (ORDER BY visit_count)
        WHEN 1 THEN 'Q1 - Lowest Activity'
        WHEN 2 THEN 'Q2 - Below Average'
        WHEN 3 THEN 'Q3 - Above Average'
        WHEN 4 THEN 'Q4 - Highest Activity'
    END AS quartile_label
FROM (
    SELECT 
        p.patient_id,
        p.full_name,
        COUNT(e.encounter_id) AS visit_count
    FROM patients p
    LEFT JOIN encounters e ON p.patient_id = e.patient_id
    GROUP BY p.patient_id, p.full_name
)
WHERE visit_count > 0
ORDER BY quartile, visit_count DESC;

PROMPT;
PROMPT ========================================================================
PROMPT   WINDOW FUNCTION DEMO 7: Cumulative Aggregates
PROMPT ========================================================================

-- Calculate cumulative patient registrations over time
SELECT 
    reg_date,
    daily_registrations,
    SUM(daily_registrations) OVER (ORDER BY reg_date) AS cumulative_total,
    ROUND(AVG(daily_registrations) OVER (
        ORDER BY reg_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_7day_avg
FROM (
    SELECT 
        TRUNC(registered_at) AS reg_date,
        COUNT(*) AS daily_registrations
    FROM patients
    GROUP BY TRUNC(registered_at)
)
ORDER BY reg_date;

PROMPT;
PROMPT ========================================================================
PROMPT   WINDOW FUNCTION DEMO 8: FIRST_VALUE() and LAST_VALUE()
PROMPT ========================================================================

-- Compare each patient's weight to their first and most recent weight
SELECT 
    patient_id,
    full_name,
    encounter_date,
    weight_kg AS current_weight,
    FIRST_VALUE(weight_kg) OVER (
        PARTITION BY patient_id 
        ORDER BY encounter_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS first_weight,
    LAST_VALUE(weight_kg) OVER (
        PARTITION BY patient_id 
        ORDER BY encounter_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS latest_weight,
    ROUND(weight_kg - FIRST_VALUE(weight_kg) OVER (
        PARTITION BY patient_id 
        ORDER BY encounter_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ), 2) AS weight_change_from_first
FROM (
    SELECT 
        p.patient_id,
        p.full_name,
        e.encounter_date,
        e.weight_kg
    FROM patients p
    JOIN encounters e ON p.patient_id = e.patient_id
    WHERE e.weight_kg IS NOT NULL
)
ORDER BY patient_id, encounter_date;

PROMPT;
PROMPT ========================================================================
PROMPT   ALL WINDOW FUNCTIONS DEMONSTRATED
PROMPT ========================================================================
PROMPT   1. ROW_NUMBER()       - Sequential numbering within partitions
PROMPT   2. RANK()             - Ranking with gaps for ties
PROMPT   3. DENSE_RANK()       - Ranking without gaps
PROMPT   4. LAG() / LEAD()     - Access previous/next row values
PROMPT   5. AVG() OVER()       - Moving averages
PROMPT   6. NTILE()            - Divide into equal groups (quartiles)
PROMPT   7. SUM() OVER()       - Cumulative sums
PROMPT   8. FIRST_VALUE()      - First value in window
PROMPT   9. LAST_VALUE()       - Last value in window
PROMPT   10. PARTITION BY      - Separate windows per group
PROMPT ========================================================================
