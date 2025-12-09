-- =============================================================================
-- PHASE VII: Simple Triggers (Row-Level)
-- Student: Shania (25793)
-- File: wed_25793_shania_PhaseVII_SimpleTriggers.sql
-- Purpose: Enforce business rules on patient and encounter operations
-- =============================================================================
SET SERVEROUTPUT ON;

PROMPT ========================================================================
PROMPT   PHASE VII: SIMPLE TRIGGERS (Row-Level)
PROMPT   Student: Shania (25793)
PROMPT ========================================================================
PROMPT;

-- =============================================================================
-- TRIGGER 1: Patients Table - INSERT Restriction
-- =============================================================================
PROMPT Creating trigger: trg_patients_insert_check...

CREATE OR REPLACE TRIGGER trg_patients_insert_check
BEFORE INSERT ON patients
FOR EACH ROW
DECLARE
    v_check_result VARCHAR2(255);
    v_user VARCHAR2(50);
BEGIN
    v_user := USER;
    v_check_result := fn_check_operation_allowed('INSERT', 'PATIENTS', v_user);
    
    IF v_check_result != 'ALLOWED' THEN
        -- Log the denied attempt
        sp_log_audit('INSERT', 'PATIENTS', :NEW.patient_id, v_user, 'DENIED', v_check_result);
        
        -- Raise error to block the operation
        RAISE_APPLICATION_ERROR(-20500, v_check_result);
    ELSE
        -- Log successful operation
        sp_log_audit('INSERT', 'PATIENTS', :NEW.patient_id, v_user, 'ALLOWED', 
                    'Patient: ' || :NEW.full_name);
    END IF;
END;
/

-- =============================================================================
-- TRIGGER 2: Patients Table - UPDATE Restriction
-- =============================================================================
PROMPT Creating trigger: trg_patients_update_check...

CREATE OR REPLACE TRIGGER trg_patients_update_check
BEFORE UPDATE ON patients
FOR EACH ROW
DECLARE
    v_check_result VARCHAR2(255);
    v_user VARCHAR2(50);
BEGIN
    v_user := USER;
    v_check_result := fn_check_operation_allowed('UPDATE', 'PATIENTS', v_user);
    
    IF v_check_result != 'ALLOWED' THEN
        sp_log_audit('UPDATE', 'PATIENTS', :OLD.patient_id, v_user, 'DENIED', v_check_result);
        RAISE_APPLICATION_ERROR(-20501, v_check_result);
    ELSE
        sp_log_audit('UPDATE', 'PATIENTS', :OLD.patient_id, v_user, 'ALLOWED', 
                    'Changed: ' || :OLD.full_name || ' -> ' || :NEW.full_name);
    END IF;
END;
/

-- =============================================================================
-- TRIGGER 3: Patients Table - DELETE Restriction
-- =============================================================================
PROMPT Creating trigger: trg_patients_delete_check...

CREATE OR REPLACE TRIGGER trg_patients_delete_check
BEFORE DELETE ON patients
FOR EACH ROW
DECLARE
    v_check_result VARCHAR2(255);
    v_user VARCHAR2(50);
BEGIN
    v_user := USER;
    v_check_result := fn_check_operation_allowed('DELETE', 'PATIENTS', v_user);
    
    IF v_check_result != 'ALLOWED' THEN
        sp_log_audit('DELETE', 'PATIENTS', :OLD.patient_id, v_user, 'DENIED', v_check_result);
        RAISE_APPLICATION_ERROR(-20502, v_check_result);
    ELSE
        sp_log_audit('DELETE', 'PATIENTS', :OLD.patient_id, v_user, 'ALLOWED', 
                    'Deleted patient: ' || :OLD.full_name);
    END IF;
END;
/

-- =============================================================================
-- TRIGGER 4: Encounters Table - INSERT Restriction
-- =============================================================================
PROMPT Creating trigger: trg_encounters_insert_check...

CREATE OR REPLACE TRIGGER trg_encounters_insert_check
BEFORE INSERT ON encounters
FOR EACH ROW
DECLARE
    v_check_result VARCHAR2(255);
    v_user VARCHAR2(50);
BEGIN
    v_user := USER;
    v_check_result := fn_check_operation_allowed('INSERT', 'ENCOUNTERS', v_user);
    
    IF v_check_result != 'ALLOWED' THEN
        sp_log_audit('INSERT', 'ENCOUNTERS', :NEW.encounter_id, v_user, 'DENIED', v_check_result);
        RAISE_APPLICATION_ERROR(-20503, v_check_result);
    ELSE
        sp_log_audit('INSERT', 'ENCOUNTERS', :NEW.encounter_id, v_user, 'ALLOWED', 
                    'Patient ID: ' || :NEW.patient_id || ', Weight: ' || :NEW.weight_kg || 'kg');
    END IF;
END;
/

-- =============================================================================
-- TRIGGER 5: Encounters Table - UPDATE Restriction
-- =============================================================================
PROMPT Creating trigger: trg_encounters_update_check...

CREATE OR REPLACE TRIGGER trg_encounters_update_check
BEFORE UPDATE ON encounters
FOR EACH ROW
DECLARE
    v_check_result VARCHAR2(255);
    v_user VARCHAR2(50);
BEGIN
    v_user := USER;
    v_check_result := fn_check_operation_allowed('UPDATE', 'ENCOUNTERS', v_user);
    
    IF v_check_result != 'ALLOWED' THEN
        sp_log_audit('UPDATE', 'ENCOUNTERS', :OLD.encounter_id, v_user, 'DENIED', v_check_result);
        RAISE_APPLICATION_ERROR(-20504, v_check_result);
    ELSE
        sp_log_audit('UPDATE', 'ENCOUNTERS', :OLD.encounter_id, v_user, 'ALLOWED', 
                    'Referral status changed: ' || :OLD.referral_status || ' -> ' || :NEW.referral_status);
    END IF;
END;
/

PROMPT;
PROMPT ========================================================================
PROMPT   5 SIMPLE TRIGGERS CREATED
PROMPT ========================================================================
PROMPT   Table: PATIENTS
PROMPT     1. trg_patients_insert_check  - BEFORE INSERT
PROMPT     2. trg_patients_update_check  - BEFORE UPDATE
PROMPT     3. trg_patients_delete_check  - BEFORE DELETE
PROMPT;
PROMPT   Table: ENCOUNTERS
PROMPT     4. trg_encounters_insert_check - BEFORE INSERT
PROMPT     5. trg_encounters_update_check - BEFORE UPDATE
PROMPT ========================================================================
