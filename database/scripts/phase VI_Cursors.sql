-- =============================================================================
-- PHASE VI: Explicit Cursors & Bulk Operations
-- Student: Shania (25793)
-- File: wed_25793_shania_PhaseVI_Cursors.sql
-- =============================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED;

-- =============================================================================
-- CURSOR DEMO 1: Explicit Cursor with Manual OPEN/FETCH/CLOSE
-- Purpose: Process all patients and display summary
-- =============================================================================
DECLARE
    -- Explicit cursor definition
    CURSOR c_patients IS
        SELECT p.patient_id, p.full_name, p.gender,
               ROUND(MONTHS_BETWEEN(SYSDATE, p.dob), 0) AS age_months,
               l.village_name, l.district_name,
               COUNT(e.encounter_id) AS visit_count
        FROM patients p
        LEFT JOIN locations l ON p.location_id = l.location_id
        LEFT JOIN encounters e ON p.patient_id = e.patient_id
        GROUP BY p.patient_id, p.full_name, p.gender, p.dob, 
                 l.village_name, l.district_name
        ORDER BY p.patient_id;
    
    -- Record variable
    v_patient_rec c_patients%ROWTYPE;
    v_counter NUMBER := 0;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE('PATIENT CENSUS REPORT (Explicit Cursor Demo)');
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE(' ');
    
    -- OPEN cursor
    OPEN c_patients;
    
    -- FETCH loop
    LOOP
        FETCH c_patients INTO v_patient_rec;
        EXIT WHEN c_patients%NOTFOUND;
        
        v_counter := v_counter + 1;
        
        DBMS_OUTPUT.PUT_LINE('Patient #' || v_counter);
        DBMS_OUTPUT.PUT_LINE('  ID: ' || v_patient_rec.patient_id);
        DBMS_OUTPUT.PUT_LINE('  Name: ' || v_patient_rec.full_name);
        DBMS_OUTPUT.PUT_LINE('  Age: ' || v_patient_rec.age_months || ' months | Gender: ' || v_patient_rec.gender);
        DBMS_OUTPUT.PUT_LINE('  Location: ' || v_patient_rec.village_name || ', ' || v_patient_rec.district_name);
        DBMS_OUTPUT.PUT_LINE('  Total Visits: ' || v_patient_rec.visit_count);
        DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    END LOOP;
    
    -- CLOSE cursor
    CLOSE c_patients;
    
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('Total Patients Processed: ' || v_counter);
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    
END;
/

-- =============================================================================
-- CURSOR DEMO 2: Cursor FOR Loop (Implicit OPEN/FETCH/CLOSE)
-- Purpose: Generate diagnostic summary for all encounters
-- =============================================================================
DECLARE
    -- Cursor with parameter
    CURSOR c_encounters (p_days_back NUMBER) IS
        SELECT e.encounter_id, e.encounter_date, e.weight_kg,
               p.patient_id, p.full_name, p.gender,
               u.full_name AS chw_name,
               COUNT(o.obs_id) AS symptom_count,
               COUNT(DISTINCT c.disease_id) AS diagnosis_count
        FROM encounters e
        JOIN patients p ON e.patient_id = p.patient_id
        JOIN users u ON e.chw_id = u.user_id
        LEFT JOIN observations o ON e.encounter_id = o.encounter_id
        LEFT JOIN conditions c ON e.encounter_id = c.encounter_id
        WHERE e.encounter_date >= SYSDATE - p_days_back
        GROUP BY e.encounter_id, e.encounter_date, e.weight_kg,
                 p.patient_id, p.full_name, p.gender, u.full_name
        ORDER BY e.encounter_date DESC;
    
    v_counter NUMBER := 0;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE('RECENT ENCOUNTERS REPORT (Last 30 Days)');
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE(' ');
    
    -- Cursor FOR loop (automatic OPEN/FETCH/CLOSE)
    FOR rec IN c_encounters(30) LOOP
        v_counter := v_counter + 1;
        
        DBMS_OUTPUT.PUT_LINE('Encounter #' || v_counter);
        DBMS_OUTPUT.PUT_LINE('  Encounter ID: ' || rec.encounter_id);
        DBMS_OUTPUT.PUT_LINE('  Date: ' || TO_CHAR(rec.encounter_date, 'DD-MON-YYYY HH24:MI'));
        DBMS_OUTPUT.PUT_LINE('  Patient: ' || rec.full_name || ' (' || rec.gender || ')');
        DBMS_OUTPUT.PUT_LINE('  Weight: ' || rec.weight_kg || ' kg');
        DBMS_OUTPUT.PUT_LINE('  CHW: ' || rec.chw_name);
        DBMS_OUTPUT.PUT_LINE('  Symptoms Recorded: ' || rec.symptom_count);
        DBMS_OUTPUT.PUT_LINE('  Diagnoses Made: ' || rec.diagnosis_count);
        DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('Total Recent Encounters: ' || v_counter);
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    
END;
/

-- =============================================================================
-- BULK OPERATIONS: FORALL with Bulk Collect
-- Purpose: High-performance batch update of encounter referral status
-- Innovation: Demonstrates bulk DML for performance optimization
-- =============================================================================
DECLARE
    -- Collections for bulk operations
    TYPE t_encounter_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_severities IS TABLE OF VARCHAR2(20) INDEX BY PLS_INTEGER;
    
    v_encounter_ids t_encounter_ids;
    v_severities t_severities;
    
    -- Cursor to identify severe cases needing referral
    CURSOR c_severe_cases IS
        SELECT DISTINCT e.encounter_id, c.severity
        FROM encounters e
        JOIN conditions c ON e.encounter_id = c.encounter_id
        WHERE c.severity IN ('SEVERE', 'CRITICAL')
          AND e.referral_status = 'NONE';
    
    v_start_time NUMBER;
    v_end_time NUMBER;
    v_elapsed NUMBER;
    
BEGIN
    v_start_time := DBMS_UTILITY.GET_TIME;
    
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE('BULK OPERATIONS DEMO: Update Referral Status');
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE(' ');
    
    -- BULK COLLECT: Fetch all rows at once
    OPEN c_severe_cases;
    FETCH c_severe_cases BULK COLLECT INTO v_encounter_ids, v_severities;
    CLOSE c_severe_cases;
    
    DBMS_OUTPUT.PUT_LINE('Severe cases found: ' || v_encounter_ids.COUNT);
    DBMS_OUTPUT.PUT_LINE(' ');
    
    IF v_encounter_ids.COUNT > 0 THEN
        -- FORALL: Bulk UPDATE operation
        FORALL i IN 1..v_encounter_ids.COUNT
            UPDATE encounters
            SET referral_status = CASE 
                WHEN v_severities(i) = 'CRITICAL' THEN 'REFERRED_EMERGENCY'
                WHEN v_severities(i) = 'SEVERE' THEN 'REFERRED_HOSPITAL'
                ELSE 'REFERRED_CLINIC'
            END
            WHERE encounter_id = v_encounter_ids(i);
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('Updated ' || SQL%ROWCOUNT || ' encounter records');
        
        -- Display updated records
        FOR i IN 1..v_encounter_ids.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('  Encounter ' || v_encounter_ids(i) || 
                               ' (' || v_severities(i) || ') -> Referral Updated');
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('No severe cases requiring referral update.');
    END IF;
    
    v_end_time := DBMS_UTILITY.GET_TIME;
    v_elapsed := (v_end_time - v_start_time) / 100; -- Convert to seconds
    
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('Performance: Operation completed in ' || v_elapsed || ' seconds');
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
END;
/

-- =============================================================================
-- BULK OPERATIONS: Bulk INSERT with FORALL
-- Purpose: Batch insert audit records for data quality monitoring
-- =============================================================================
DECLARE
    TYPE t_activities IS TABLE OF VARCHAR2(50) INDEX BY PLS_INTEGER;
    TYPE t_details IS TABLE OF VARCHAR2(4000) INDEX BY PLS_INTEGER;
    
    v_activities t_activities;
    v_details t_details;
    v_counter NUMBER := 0;
    
    -- Cursor to find data quality issues
    CURSOR c_quality_checks IS
        -- Missing observations
        SELECT 'MISSING_OBSERVATIONS' AS activity,
               'Encounter ' || encounter_id || ' has no recorded symptoms' AS details
        FROM encounters e
        WHERE NOT EXISTS (SELECT 1 FROM observations WHERE encounter_id = e.encounter_id)
        UNION ALL
        -- Missing diagnoses
        SELECT 'MISSING_DIAGNOSIS' AS activity,
               'Encounter ' || encounter_id || ' has observations but no diagnosis' AS details
        FROM encounters e
        WHERE EXISTS (SELECT 1 FROM observations WHERE encounter_id = e.encounter_id)
          AND NOT EXISTS (SELECT 1 FROM conditions WHERE encounter_id = e.encounter_id)
        UNION ALL
        -- Low weight alerts
        SELECT 'LOW_WEIGHT_ALERT' AS activity,
               'Patient ' || patient_id || ' has abnormal weight: ' || weight_kg || ' kg' AS details
        FROM encounters
        WHERE weight_kg < 5 OR weight_kg > 25;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE('BULK INSERT DEMO: Data Quality Audit');
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE(' ');
    
    -- Bulk collect quality issues
    OPEN c_quality_checks;
    FETCH c_quality_checks BULK COLLECT INTO v_activities, v_details;
    CLOSE c_quality_checks;
    
    DBMS_OUTPUT.PUT_LINE('Data quality issues found: ' || v_activities.COUNT);
    DBMS_OUTPUT.PUT_LINE(' ');
    
    IF v_activities.COUNT > 0 THEN
        -- Bulk insert audit logs
        FORALL i IN 1..v_activities.COUNT
            INSERT INTO audit_logs (log_id, activity, details, log_time)
            VALUES (seq_trans.NEXTVAL, v_activities(i), v_details(i), CURRENT_TIMESTAMP);
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('Inserted ' || SQL%ROWCOUNT || ' audit log entries');
        DBMS_OUTPUT.PUT_LINE(' ');
        
        -- Display issues
        FOR i IN 1..LEAST(v_activities.COUNT, 10) LOOP
            DBMS_OUTPUT.PUT_LINE('  [' || v_activities(i) || '] ' || v_details(i));
        END LOOP;
        
        IF v_activities.COUNT > 10 THEN
            DBMS_OUTPUT.PUT_LINE('  ... and ' || (v_activities.COUNT - 10) || ' more issues');
        END IF;
    ELSE
        DBMS_OUTPUT.PUT_LINE('No data quality issues detected - system is healthy!');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
END;
/

PROMPT ========================================================================
PROMPT   CURSOR & BULK OPERATIONS COMPLETED
PROMPT ========================================================================
PROMPT   1. Explicit Cursor (OPEN/FETCH/CLOSE)    - Patient Census
PROMPT   2. Cursor FOR Loop (Implicit)             - Encounter Report
PROMPT   3. FORALL Bulk UPDATE                     - Referral Status
PROMPT   4. FORALL Bulk INSERT                     - Audit Logging
PROMPT ========================================================================
PROMPT   Performance Note: Bulk operations are 10-100x faster than row-by-row
PROMPT ========================================================================
