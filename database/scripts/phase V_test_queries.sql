-- =============================================================================
-- PHASE V: Verification Queries
-- Student: Shania (25793)
-- =============================================================================

-- 1. Check Data Volume
SELECT table_name, num_rows FROM user_tables; 
-- Note: num_rows is only accurate after gathering stats, so use count(*) below
SELECT count(*) as Patient_Count FROM patients;
SELECT count(*) as Encounter_Count FROM encounters;

-- 2. Verify Gender/Name Distribution
-- This query helps spot checks if 'Keza' ended up as 'M' (Should be F)
SELECT gender, full_name 
FROM patients 
WHERE ROWNUM <= 10
ORDER BY gender;


-- 3. Check for Referrals (Severe Cases)
SELECT e.encounter_id, p.full_name, c.diagnosis_code, e.referral_status
FROM encounters e
JOIN patients p ON e.patient_id = p.patient_id
JOIN conditions c ON e.encounter_id = c.encounter_id
WHERE e.referral_status = 'REFERRED';

-- 4. Aggregation: Which village has the most sick kids?
SELECT l.village_name, COUNT(c.condition_id) as total_diagnoses
FROM locations l
JOIN patients p ON l.location_id = p.location_id
JOIN encounters e ON p.patient_id = e.patient_id
JOIN conditions c ON e.encounter_id = c.encounter_id
GROUP BY l.village_name
ORDER BY total_diagnoses DESC;
