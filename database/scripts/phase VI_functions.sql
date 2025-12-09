-- =============================================================================
-- PHASE VI: PL/SQL Functions (3-5 Required)
-- Student: Shania (25793)
-- File: wed_25793_shania_PhaseVI_Functions.sql
-- =============================================================================
SET SERVEROUTPUT ON;

-- =============================================================================
-- FUNCTION 1: Calculate Patient Age in Months
-- Purpose: Return age in months for dosing calculations
-- Return Type: NUMBER
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_calculate_age_months (
    p_patient_id IN NUMBER
) RETURN NUMBER
AS
    v_dob DATE;
    v_age_months NUMBER;
    e_patient_not_found EXCEPTION;
BEGIN
    -- Get DOB
    SELECT dob INTO v_dob
    FROM patients WHERE patient_id = p_patient_id;
    
    -- Calculate age
    v_age_months := MONTHS_BETWEEN(SYSDATE, v_dob);
    
    RETURN ROUND(v_age_months, 0);
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20050, 'ERROR: Patient ID ' || p_patient_id || ' not found');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20099, 'ERROR: ' || SQLERRM);
END fn_calculate_age_months;
/

-- =============================================================================
-- FUNCTION 2: Get Recommended Medication Dosage
-- Purpose: Lookup appropriate dosage based on disease and weight
-- Return Type: VARCHAR2 (dosage instruction)
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_get_dosage (
    p_disease_id IN NUMBER,
    p_weight_kg IN NUMBER
) RETURN VARCHAR2
AS
    v_dosage VARCHAR2(255);
    v_med_name VARCHAR2(100);
BEGIN
    -- Find matching protocol based on weight range
    SELECT m.med_name || ': ' || p.dosage_instruction
    INTO v_dosage
    FROM iccm_protocols p
    JOIN iccm_medications m ON p.med_id = m.med_id
    WHERE p.disease_id = p_disease_id
      AND p_weight_kg BETWEEN p.min_weight_kg AND p.max_weight_kg
      AND ROWNUM = 1;
    
    RETURN v_dosage;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'NO PROTOCOL FOUND - Refer to clinician';
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END fn_get_dosage;
/

-- =============================================================================
-- FUNCTION 3: Validate Symptom Value
-- Purpose: Check if observed value is valid for symptom type
-- Return Type: VARCHAR2 ('VALID' or error message)
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_validate_symptom (
    p_symptom_code IN VARCHAR2,
    p_measured_val IN VARCHAR2
) RETURN VARCHAR2
AS
    v_data_type VARCHAR2(20);
    v_numeric_val NUMBER;
BEGIN
    -- Get symptom data type
    SELECT data_type INTO v_data_type
    FROM iccm_symptoms WHERE symptom_code = p_symptom_code;
    
    -- Validate based on type
    IF v_data_type = 'BOOLEAN' THEN
        IF p_measured_val NOT IN ('YES', 'NO') THEN
            RETURN 'INVALID: Boolean symptoms must be YES or NO';
        END IF;
    ELSIF v_data_type = 'NUMERIC' THEN
        BEGIN
            v_numeric_val := TO_NUMBER(p_measured_val);
            IF v_numeric_val < 0 THEN
                RETURN 'INVALID: Numeric value cannot be negative';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RETURN 'INVALID: Value must be numeric';
        END;
    END IF;
    
    RETURN 'VALID';
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'ERROR: Symptom code ' || p_symptom_code || ' not found';
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END fn_validate_symptom;
/

-- =============================================================================
-- FUNCTION 4: Calculate Diagnostic Confidence Score
-- Purpose: Score encounter against disease rules (0-100%)
-- Return Type: NUMBER
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_calculate_confidence (
    p_encounter_id IN NUMBER,
    p_disease_id IN NUMBER
) RETURN NUMBER
AS
    v_total_points NUMBER := 0;
    v_max_possible NUMBER := 0;
    v_confidence NUMBER;
    
    CURSOR c_rules IS
        SELECT r.symptom_code, r.operator, r.compare_val, r.points_weight
        FROM iccm_rules r
        WHERE r.disease_id = p_disease_id;
    
    v_measured_val VARCHAR2(50);
    v_numeric_measured NUMBER;
    v_numeric_compare NUMBER;
    v_match BOOLEAN;
BEGIN
    -- Loop through all rules for this disease
    FOR rule IN c_rules LOOP
        v_max_possible := v_max_possible + rule.points_weight;
        
        -- Get observed value
        BEGIN
            SELECT measured_val INTO v_measured_val
            FROM observations
            WHERE encounter_id = p_encounter_id
              AND symptom_code = rule.symptom_code;
            
            -- Evaluate rule
            v_match := FALSE;
            
            IF rule.operator = '=' THEN
                v_match := (v_measured_val = rule.compare_val);
            ELSE
                -- Numeric comparison
                v_numeric_measured := TO_NUMBER(v_measured_val);
                v_numeric_compare := TO_NUMBER(rule.compare_val);
                
                IF rule.operator = '>' THEN
                    v_match := (v_numeric_measured > v_numeric_compare);
                ELSIF rule.operator = '<' THEN
                    v_match := (v_numeric_measured < v_numeric_compare);
                ELSIF rule.operator = '>=' THEN
                    v_match := (v_numeric_measured >= v_numeric_compare);
                END IF;
            END IF;
            
            -- Add points if matched
            IF v_match THEN
                v_total_points := v_total_points + rule.points_weight;
            END IF;
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL; -- Symptom not observed, skip rule
            WHEN OTHERS THEN
                NULL; -- Skip invalid data
        END;
    END LOOP;
    
    -- Calculate percentage confidence
    IF v_max_possible > 0 THEN
        v_confidence := ROUND((v_total_points / v_max_possible) * 100, 0);
    ELSE
        v_confidence := 0;
    END IF;
    
    RETURN v_confidence;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 0;
END fn_calculate_confidence;
/

-- =============================================================================
-- FUNCTION 5: Get Patient Full Summary
-- Purpose: Return formatted patient demographics and stats
-- Return Type: VARCHAR2 (multi-line summary)
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_patient_summary (
    p_patient_id IN NUMBER
) RETURN VARCHAR2
AS
    v_summary VARCHAR2(4000);
    v_full_name VARCHAR2(100);
    v_gender CHAR(1);
    v_age_months NUMBER;
    v_village VARCHAR2(100);
    v_district VARCHAR2(100);
    v_encounter_count NUMBER;
    v_last_visit DATE;
BEGIN
    -- Get patient demographics
    SELECT p.full_name, p.gender, 
           ROUND(MONTHS_BETWEEN(SYSDATE, p.dob), 0),
           l.village_name, l.district_name
    INTO v_full_name, v_gender, v_age_months, v_village, v_district
    FROM patients p
    JOIN locations l ON p.location_id = l.location_id
    WHERE p.patient_id = p_patient_id;
    
    -- Get encounter statistics
    SELECT COUNT(*), MAX(encounter_date)
    INTO v_encounter_count, v_last_visit
    FROM encounters
    WHERE patient_id = p_patient_id;
    
    -- Build summary
    v_summary := '========================================' || CHR(10);
    v_summary := v_summary || 'PATIENT SUMMARY' || CHR(10);
    v_summary := v_summary || '========================================' || CHR(10);
    v_summary := v_summary || 'ID: ' || p_patient_id || CHR(10);
    v_summary := v_summary || 'Name: ' || v_full_name || CHR(10);
    v_summary := v_summary || 'Gender: ' || v_gender || CHR(10);
    v_summary := v_summary || 'Age: ' || v_age_months || ' months' || CHR(10);
    v_summary := v_summary || 'Location: ' || v_village || ', ' || v_district || CHR(10);
    v_summary := v_summary || 'Total Visits: ' || v_encounter_count || CHR(10);
    v_summary := v_summary || 'Last Visit: ' || TO_CHAR(v_last_visit, 'DD-MON-YYYY') || CHR(10);
    v_summary := v_summary || '========================================';
    
    RETURN v_summary;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'ERROR: Patient ID ' || p_patient_id || ' not found';
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END fn_patient_summary;
/

PROMPT ========================================================================
PROMPT   5 FUNCTIONS CREATED SUCCESSFULLY
PROMPT ========================================================================
PROMPT   1. fn_calculate_age_months   - Calculate patient age (NUMBER)
PROMPT   2. fn_get_dosage              - Lookup medication dosage (VARCHAR2)
PROMPT   3. fn_validate_symptom        - Validate observation value (VARCHAR2)
PROMPT   4. fn_calculate_confidence    - Score disease likelihood (NUMBER)
PROMPT   5. fn_patient_summary         - Get patient demographics (VARCHAR2)
PROMPT ========================================================================
