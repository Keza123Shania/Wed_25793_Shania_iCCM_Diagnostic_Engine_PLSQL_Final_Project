-- =============================================================================
-- PHASE VI: PL/SQL Procedures (3-5 Required)
-- Student: Shania (25793)
-- File: wed_25793_shania_PhaseVI_Procedures.sql
-- =============================================================================
SET SERVEROUTPUT ON;

-- =============================================================================
-- PROCEDURE 1: Register New Patient
-- Purpose: Insert patient with validation and output generated ID
-- Parameters: IN (patient details), OUT (patient_id)
-- =============================================================================
CREATE OR REPLACE PROCEDURE sp_register_patient (
    p_full_name     IN  VARCHAR2,
    p_dob           IN  DATE,
    p_gender        IN  CHAR,
    p_location_id   IN  NUMBER,
    p_patient_id    OUT NUMBER
) AS
    v_age_months NUMBER;
    e_invalid_age EXCEPTION;
    e_invalid_gender EXCEPTION;
    e_invalid_location EXCEPTION;
    v_location_count NUMBER;
BEGIN
    -- Validation: Check location exists
    SELECT COUNT(*) INTO v_location_count 
    FROM locations WHERE location_id = p_location_id;
    
    IF v_location_count = 0 THEN
        RAISE e_invalid_location;
    END IF;
    
    -- Validation: Check age (iCCM is for 2-59 months)
    v_age_months := MONTHS_BETWEEN(SYSDATE, p_dob);
    IF v_age_months < 2 OR v_age_months > 59 THEN
        RAISE e_invalid_age;
    END IF;
    
    -- Validation: Check gender
    IF p_gender NOT IN ('M', 'F') THEN
        RAISE e_invalid_gender;
    END IF;
    
    -- Generate ID and insert
    p_patient_id := seq_common.NEXTVAL;
    INSERT INTO patients (patient_id, full_name, dob, gender, location_id, registered_at)
    VALUES (p_patient_id, p_full_name, p_dob, p_gender, p_location_id, CURRENT_TIMESTAMP);
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Patient registered with ID: ' || p_patient_id);
    
    -- Audit logging
    INSERT INTO audit_logs (log_id, activity, details, log_time)
    VALUES (seq_trans.NEXTVAL, 'PATIENT_REGISTRATION', 
            'Patient ID: ' || p_patient_id || ' | Name: ' || p_full_name, 
            CURRENT_TIMESTAMP);
    COMMIT;
    
EXCEPTION
    WHEN e_invalid_location THEN
        RAISE_APPLICATION_ERROR(-20001, 'ERROR: Location ID ' || p_location_id || ' does not exist');
    WHEN e_invalid_age THEN
        RAISE_APPLICATION_ERROR(-20002, 'ERROR: Patient age must be 2-59 months (iCCM protocol). Age: ' || ROUND(v_age_months) || ' months');
    WHEN e_invalid_gender THEN
        RAISE_APPLICATION_ERROR(-20003, 'ERROR: Gender must be M or F');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20099, 'ERROR: ' || SQLERRM);
END sp_register_patient;
/

-- =============================================================================
-- PROCEDURE 2: Start Clinical Encounter
-- Purpose: Create encounter record with vital signs
-- Parameters: IN (patient_id, chw_id, weight), OUT (encounter_id)
-- =============================================================================
CREATE OR REPLACE PROCEDURE sp_start_encounter (
    p_patient_id    IN  NUMBER,
    p_chw_id        IN  NUMBER,
    p_weight_kg     IN  NUMBER,
    p_encounter_id  OUT NUMBER
) AS
    v_patient_count NUMBER;
    v_chw_count NUMBER;
    e_patient_not_found EXCEPTION;
    e_chw_not_found EXCEPTION;
    e_invalid_weight EXCEPTION;
BEGIN
    -- Validation: Check patient exists
    SELECT COUNT(*) INTO v_patient_count 
    FROM patients WHERE patient_id = p_patient_id;
    
    IF v_patient_count = 0 THEN
        RAISE e_patient_not_found;
    END IF;
    
    -- Validation: Check CHW exists
    SELECT COUNT(*) INTO v_chw_count 
    FROM users WHERE user_id = p_chw_id AND role = 'CHW';
    
    IF v_chw_count = 0 THEN
        RAISE e_chw_not_found;
    END IF;
    
    -- Validation: Check weight is realistic (5-25kg for under-5 children)
    IF p_weight_kg < 5 OR p_weight_kg > 25 THEN
        RAISE e_invalid_weight;
    END IF;
    
    -- Create encounter
    p_encounter_id := seq_trans.NEXTVAL;
    INSERT INTO encounters (encounter_id, patient_id, chw_id, encounter_date, weight_kg, referral_status)
    VALUES (p_encounter_id, p_patient_id, p_chw_id, CURRENT_TIMESTAMP, p_weight_kg, 'NONE');
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Encounter created with ID: ' || p_encounter_id);
    
    -- Audit logging
    INSERT INTO audit_logs (log_id, activity, details, log_time)
    VALUES (seq_trans.NEXTVAL, 'ENCOUNTER_START', 
            'Encounter ID: ' || p_encounter_id || ' | Patient: ' || p_patient_id || ' | CHW: ' || p_chw_id, 
            CURRENT_TIMESTAMP);
    COMMIT;
    
EXCEPTION
    WHEN e_patient_not_found THEN
        RAISE_APPLICATION_ERROR(-20010, 'ERROR: Patient ID ' || p_patient_id || ' not found');
    WHEN e_chw_not_found THEN
        RAISE_APPLICATION_ERROR(-20011, 'ERROR: CHW ID ' || p_chw_id || ' not found or invalid role');
    WHEN e_invalid_weight THEN
        RAISE_APPLICATION_ERROR(-20012, 'ERROR: Weight must be between 5-25kg. Provided: ' || p_weight_kg || 'kg');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20099, 'ERROR: ' || SQLERRM);
END sp_start_encounter;
/

-- =============================================================================
-- PROCEDURE 3: Record Clinical Observations
-- Purpose: Bulk insert multiple symptoms/observations for encounter
-- Parameters: IN/OUT for encounter_id, uses collection for bulk insert
-- =============================================================================
CREATE OR REPLACE PROCEDURE sp_record_observations (
    p_encounter_id  IN NUMBER,
    p_symptom_code  IN VARCHAR2,
    p_measured_val  IN VARCHAR2
) AS
    v_encounter_count NUMBER;
    v_symptom_count NUMBER;
    e_encounter_not_found EXCEPTION;
    e_symptom_not_found EXCEPTION;
BEGIN
    -- Validation: Check encounter exists
    SELECT COUNT(*) INTO v_encounter_count 
    FROM encounters WHERE encounter_id = p_encounter_id;
    
    IF v_encounter_count = 0 THEN
        RAISE e_encounter_not_found;
    END IF;
    
    -- Validation: Check symptom exists in knowledge base
    SELECT COUNT(*) INTO v_symptom_count 
    FROM iccm_symptoms WHERE symptom_code = p_symptom_code;
    
    IF v_symptom_count = 0 THEN
        RAISE e_symptom_not_found;
    END IF;
    
    -- Insert observation
    INSERT INTO observations (obs_id, encounter_id, symptom_code, measured_val)
    VALUES (seq_trans.NEXTVAL, p_encounter_id, p_symptom_code, p_measured_val);
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Observation recorded - ' || p_symptom_code || ': ' || p_measured_val);
    
EXCEPTION
    WHEN e_encounter_not_found THEN
        RAISE_APPLICATION_ERROR(-20020, 'ERROR: Encounter ID ' || p_encounter_id || ' not found');
    WHEN e_symptom_not_found THEN
        RAISE_APPLICATION_ERROR(-20021, 'ERROR: Symptom code ' || p_symptom_code || ' not in knowledge base');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20099, 'ERROR: ' || SQLERRM);
END sp_record_observations;
/

-- =============================================================================
-- PROCEDURE 4: Update Patient Demographics
-- Purpose: Update patient information with validation
-- Parameters: IN (patient_id and fields to update)
-- =============================================================================
CREATE OR REPLACE PROCEDURE sp_update_patient (
    p_patient_id    IN NUMBER,
    p_full_name     IN VARCHAR2 DEFAULT NULL,
    p_location_id   IN NUMBER DEFAULT NULL
) AS
    v_patient_count NUMBER;
    v_location_count NUMBER;
    v_old_name VARCHAR2(100);
    v_old_location NUMBER;
    e_patient_not_found EXCEPTION;
    e_location_invalid EXCEPTION;
    e_no_changes EXCEPTION;
BEGIN
    -- Validation: Check patient exists
    SELECT COUNT(*), MAX(full_name), MAX(location_id) 
    INTO v_patient_count, v_old_name, v_old_location
    FROM patients WHERE patient_id = p_patient_id;
    
    IF v_patient_count = 0 THEN
        RAISE e_patient_not_found;
    END IF;
    
    -- Check if any changes requested
    IF p_full_name IS NULL AND p_location_id IS NULL THEN
        RAISE e_no_changes;
    END IF;
    
    -- Validate location if provided
    IF p_location_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_location_count 
        FROM locations WHERE location_id = p_location_id;
        
        IF v_location_count = 0 THEN
            RAISE e_location_invalid;
        END IF;
    END IF;
    
    -- Update fields
    UPDATE patients 
    SET full_name = NVL(p_full_name, full_name),
        location_id = NVL(p_location_id, location_id)
    WHERE patient_id = p_patient_id;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Patient ' || p_patient_id || ' updated');
    
    -- Audit logging
    INSERT INTO audit_logs (log_id, activity, details, log_time)
    VALUES (seq_trans.NEXTVAL, 'PATIENT_UPDATE', 
            'Patient ID: ' || p_patient_id || ' | Old Name: ' || v_old_name || ' | New Name: ' || NVL(p_full_name, v_old_name), 
            CURRENT_TIMESTAMP);
    COMMIT;
    
EXCEPTION
    WHEN e_patient_not_found THEN
        RAISE_APPLICATION_ERROR(-20030, 'ERROR: Patient ID ' || p_patient_id || ' not found');
    WHEN e_location_invalid THEN
        RAISE_APPLICATION_ERROR(-20031, 'ERROR: Location ID ' || p_location_id || ' does not exist');
    WHEN e_no_changes THEN
        RAISE_APPLICATION_ERROR(-20032, 'ERROR: No changes provided. Supply at least one field to update.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20099, 'ERROR: ' || SQLERRM);
END sp_update_patient;
/

-- =============================================================================
-- PROCEDURE 5: Delete Encounter (Cascade)
-- Purpose: Remove encounter and all related observations/conditions
-- Parameters: IN (encounter_id)
-- Note: Uses ON DELETE CASCADE in schema, but adds audit trail
-- =============================================================================
CREATE OR REPLACE PROCEDURE sp_delete_encounter (
    p_encounter_id IN NUMBER
) AS
    v_encounter_count NUMBER;
    v_obs_count NUMBER;
    v_cond_count NUMBER;
    v_patient_id NUMBER;
    e_encounter_not_found EXCEPTION;
BEGIN
    -- Validation: Check encounter exists and get counts
    SELECT COUNT(*), MAX(patient_id) INTO v_encounter_count, v_patient_id
    FROM encounters WHERE encounter_id = p_encounter_id;
    
    IF v_encounter_count = 0 THEN
        RAISE e_encounter_not_found;
    END IF;
    
    -- Count related records before deletion
    SELECT COUNT(*) INTO v_obs_count 
    FROM observations WHERE encounter_id = p_encounter_id;
    
    SELECT COUNT(*) INTO v_cond_count 
    FROM conditions WHERE encounter_id = p_encounter_id;
    
    -- Delete encounter (CASCADE will handle children)
    DELETE FROM encounters WHERE encounter_id = p_encounter_id;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Encounter ' || p_encounter_id || ' deleted');
    DBMS_OUTPUT.PUT_LINE('  - Observations deleted: ' || v_obs_count);
    DBMS_OUTPUT.PUT_LINE('  - Conditions deleted: ' || v_cond_count);
    
    -- Audit logging
    INSERT INTO audit_logs (log_id, activity, details, log_time)
    VALUES (seq_trans.NEXTVAL, 'ENCOUNTER_DELETION', 
            'Encounter ID: ' || p_encounter_id || ' | Patient: ' || v_patient_id || 
            ' | Obs deleted: ' || v_obs_count || ' | Conditions: ' || v_cond_count, 
            CURRENT_TIMESTAMP);
    COMMIT;
    
EXCEPTION
    WHEN e_encounter_not_found THEN
        RAISE_APPLICATION_ERROR(-20040, 'ERROR: Encounter ID ' || p_encounter_id || ' not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20099, 'ERROR: ' || SQLERRM);
END sp_delete_encounter;
/

PROMPT ========================================================================
PROMPT   5 PROCEDURES CREATED SUCCESSFULLY
PROMPT ========================================================================
PROMPT   1. sp_register_patient      - Register new patient (IN/OUT params)
PROMPT   2. sp_start_encounter        - Create encounter record (IN/OUT params)
PROMPT   3. sp_record_observations    - Insert observations (IN params)
PROMPT   4. sp_update_patient         - Update patient demographics (IN params)
PROMPT   5. sp_delete_encounter       - Delete encounter with cascade (IN params)
PROMPT ========================================================================
