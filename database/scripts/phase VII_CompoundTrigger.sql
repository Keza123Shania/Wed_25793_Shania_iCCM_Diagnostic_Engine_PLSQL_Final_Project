-- =============================================================================
-- PHASE VII: Compound Trigger (Advanced)
-- Student: Shania (25793)
-- File: wed_25793_shania_PhaseVII_CompoundTrigger.sql
-- Purpose: Track multiple operations in a single transaction
-- =============================================================================
SET SERVEROUTPUT ON;

PROMPT ========================================================================
PROMPT   PHASE VII: COMPOUND TRIGGER (Statement + Row Level)
PROMPT   Student: Shania (25793)
PROMPT ========================================================================
PROMPT;

-- =============================================================================
-- COMPOUND TRIGGER: Conditions Table - Comprehensive Audit
-- Purpose: Track all DML operations with batch statistics
-- =============================================================================
PROMPT Creating compound trigger: trg_conditions_audit_compound...

CREATE OR REPLACE TRIGGER trg_conditions_audit_compound
FOR INSERT OR UPDATE OR DELETE ON conditions
COMPOUND TRIGGER
    
    -- Package-level variables (shared across all timing points)
    TYPE t_operation_log IS TABLE OF VARCHAR2(500) INDEX BY PLS_INTEGER;
    v_operations t_operation_log;
    v_operation_count NUMBER := 0;
    v_user VARCHAR2(50);
    v_operation_type VARCHAR2(20);
    v_check_result VARCHAR2(255);
    
    -- =============================================================================
    -- BEFORE STATEMENT: Initialize and check restrictions
    -- =============================================================================
    BEFORE STATEMENT IS
    BEGIN
        v_user := USER;
        v_operation_count := 0;
        v_operations.DELETE;
        
        -- Determine operation type
        IF INSERTING THEN
            v_operation_type := 'INSERT';
        ELSIF UPDATING THEN
            v_operation_type := 'UPDATE';
        ELSIF DELETING THEN
            v_operation_type := 'DELETE';
        END IF;
        
        -- Check if operation is allowed
        v_check_result := fn_check_operation_allowed(v_operation_type, 'CONDITIONS', v_user);
        
        IF v_check_result != 'ALLOWED' THEN
            sp_log_audit(v_operation_type, 'CONDITIONS', 0, v_user, 'DENIED', 
                        v_check_result || ' (Batch operation blocked)');
            RAISE_APPLICATION_ERROR(-20600, v_check_result);
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('>>> Compound Trigger: BEFORE STATEMENT - ' || v_operation_type || ' allowed');
    END BEFORE STATEMENT;
    
    -- =============================================================================
    -- BEFORE EACH ROW: Validate individual row data
    -- =============================================================================
    BEFORE EACH ROW IS
        v_detail VARCHAR2(500);
    BEGIN
        IF INSERTING THEN
            v_detail := 'Encounter: ' || :NEW.encounter_id || 
                       ', Disease: ' || :NEW.disease_id || 
                       ', Confidence: ' || :NEW.confidence_score || '%';
            v_operations(v_operation_count + 1) := v_detail;
            
        ELSIF UPDATING THEN
            v_detail := 'Condition: ' || :OLD.condition_id || 
                       ', Severity changed: ' || :OLD.severity || ' -> ' || :NEW.severity;
            v_operations(v_operation_count + 1) := v_detail;
            
        ELSIF DELETING THEN
            v_detail := 'Deleted condition: ' || :OLD.condition_id || 
                       ' (Disease: ' || :OLD.disease_id || ')';
            v_operations(v_operation_count + 1) := v_detail;
        END IF;
        
        v_operation_count := v_operation_count + 1;
        
        DBMS_OUTPUT.PUT_LINE('>>> Compound Trigger: BEFORE EACH ROW #' || v_operation_count);
    END BEFORE EACH ROW;
    
    -- =============================================================================
    -- AFTER EACH ROW: Post-processing (optional validation)
    -- =============================================================================
    AFTER EACH ROW IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('>>> Compound Trigger: AFTER EACH ROW - Row processed successfully');
    END AFTER EACH ROW;
    
    -- =============================================================================
    -- AFTER STATEMENT: Log batch summary
    -- =============================================================================
    AFTER STATEMENT IS
        v_summary VARCHAR2(4000);
    BEGIN
        -- Build summary of all operations
        v_summary := 'Batch ' || v_operation_type || ' completed. Rows affected: ' || v_operation_count;
        
        -- Log the batch operation
        sp_log_audit(v_operation_type || '_BATCH', 'CONDITIONS', 0, v_user, 'ALLOWED', v_summary);
        
        -- Log individual row details
        FOR i IN 1..v_operation_count LOOP
            sp_log_audit(v_operation_type, 'CONDITIONS', i, v_user, 'ALLOWED', v_operations(i));
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('>>> Compound Trigger: AFTER STATEMENT - Logged ' || v_operation_count || ' operations');
        DBMS_OUTPUT.PUT_LINE('>>> Day type: ' || fn_get_day_type);
    END AFTER STATEMENT;
    
END trg_conditions_audit_compound;
/

PROMPT;
PROMPT ========================================================================
PROMPT   COMPOUND TRIGGER CREATED
PROMPT ========================================================================
PROMPT   Name: trg_conditions_audit_compound
PROMPT   Table: CONDITIONS
PROMPT   Features:
PROMPT     - BEFORE STATEMENT: Check restrictions, initialize
PROMPT     - BEFORE EACH ROW: Capture row details
PROMPT     - AFTER EACH ROW: Validate processed row
PROMPT     - AFTER STATEMENT: Log batch summary
PROMPT;
PROMPT   This trigger demonstrates:
PROMPT     - Multiple timing points in single trigger
PROMPT     - Shared state across timing points
PROMPT     - Batch operation tracking
PROMPT     - Comprehensive audit trail
PROMPT ========================================================================
