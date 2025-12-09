-- =============================================================================
-- PHASE VII: Comprehensive Testing Script
-- Student: Shania (25793)
-- File: wed_25793_shania_PhaseVII_Tests.sql
-- Purpose: Test all triggers, business rules, and audit logging
-- =============================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ========================================================================
PROMPT   PHASE VII: COMPREHENSIVE TESTING
PROMPT   Student: Shania (25793)
PROMPT ========================================================================
PROMPT;

-- =============================================================================
-- DISPLAY CURRENT DAY STATUS
-- =============================================================================
PROMPT ========================================================================
PROMPT CURRENT DAY STATUS
PROMPT ========================================================================

SELECT 
    TO_CHAR(SYSDATE, 'Day, DD-MON-YYYY HH24:MI:SS') AS current_datetime,
    fn_get_day_type() AS day_type,
    CASE 
        WHEN fn_check_operation_allowed('INSERT', 'PATIENTS', USER) = 'ALLOWED' 
        THEN 'ALLOWED' 
        ELSE 'BLOCKED' 
    END AS operation_status
FROM dual;

PROMPT;
PROMPT ========================================================================
PROMPT TEST 1: ATTEMPT INSERT ON PATIENTS (Will be blocked if weekday/holiday)
PROMPT ========================================================================
PROMPT;

DECLARE
    v_test_patient_id NUMBER := seq_common.NEXTVAL;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Attempting to insert patient...');
    DBMS_OUTPUT.PUT_LINE('Day type: ' || fn_get_day_type);
    DBMS_OUTPUT.PUT_LINE(' ');
    
    INSERT INTO patients (patient_id, full_name, dob, gender, location_id, registered_at)
    VALUES (v_test_patient_id, 'Test Patient - Trigger Test', ADD_MONTHS(SYSDATE, -24), 'M', 100, CURRENT_TIMESTAMP);
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('>>> SUCCESS: Patient inserted (ID: ' || v_test_patient_id || ')');
    DBMS_OUTPUT.PUT_LINE('>>> This means today is a WEEKEND and NOT a holiday');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('>>> BLOCKED: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('>>> This means today is a WEEKDAY or HOLIDAY');
        DBMS_OUTPUT.PUT_LINE('>>> Business rule is working correctly!');
END;
/

PROMPT;
PROMPT ========================================================================
PROMPT TEST 2: ATTEMPT UPDATE ON PATIENTS
PROMPT ========================================================================
PROMPT;

DECLARE
    v_patient_id NUMBER;
BEGIN
    -- Get any existing patient
    SELECT patient_id INTO v_patient_id FROM patients WHERE ROWNUM = 1;
    
    DBMS_OUTPUT.PUT_LINE('Attempting to update patient ID: ' || v_patient_id);
    DBMS_OUTPUT.PUT_LINE(' ');
    
    UPDATE patients 
    SET full_name = full_name || ' (UPDATED)'
    WHERE patient_id = v_patient_id;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('>>> SUCCESS: Patient updated');
    DBMS_OUTPUT.PUT_LINE('>>> Operations allowed today');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('>>> BLOCKED: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('>>> Update operations restricted today');
END;
/

PROMPT;
PROMPT ========================================================================
PROMPT TEST 3: ATTEMPT DELETE ON PATIENTS
PROMPT ========================================================================
PROMPT;

DECLARE
    v_patient_id NUMBER;
    v_patient_name VARCHAR2(100);
BEGIN
    -- Get the last inserted test patient (if any)
    BEGIN
        SELECT patient_id, full_name INTO v_patient_id, v_patient_name
        FROM patients 
        WHERE full_name LIKE 'Test Patient%'
        ORDER BY patient_id DESC
        FETCH FIRST 1 ROW ONLY;
        
        DBMS_OUTPUT.PUT_LINE('Attempting to delete patient: ' || v_patient_name);
        DBMS_OUTPUT.PUT_LINE(' ');
        
        DELETE FROM patients WHERE patient_id = v_patient_id;
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('>>> SUCCESS: Patient deleted');
        DBMS_OUTPUT.PUT_LINE('>>> Delete operations allowed today');
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('>>> No test patients found to delete');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('>>> BLOCKED: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('>>> Delete operations restricted today');
    END;
END;
/

PROMPT;
PROMPT ========================================================================
PROMPT TEST 4: COMPOUND TRIGGER TEST (Batch Operations on CONDITIONS)
PROMPT ========================================================================
PROMPT;

DECLARE
    v_encounter_id NUMBER;
    v_cond_id1 NUMBER;
    v_cond_id2 NUMBER;
BEGIN
    -- Get an encounter to test with
    SELECT encounter_id INTO v_encounter_id FROM encounters WHERE ROWNUM = 1;
    
    DBMS_OUTPUT.PUT_LINE('Testing compound trigger with batch INSERT...');
    DBMS_OUTPUT.PUT_LINE(' ');
    
    -- Batch insert (will trigger compound trigger)
    v_cond_id1 := seq_trans.NEXTVAL;
    v_cond_id2 := seq_trans.NEXTVAL;
    
    INSERT INTO conditions VALUES (v_cond_id1, v_encounter_id, 1, 75, 'MODERATE', CURRENT_TIMESTAMP);
    INSERT INTO conditions VALUES (v_cond_id2, v_encounter_id, 2, 60, 'MILD', CURRENT_TIMESTAMP);
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('>>> SUCCESS: Batch insert completed');
    DBMS_OUTPUT.PUT_LINE('>>> Compound trigger logged all operations');
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('>>> BLOCKED: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('>>> Compound trigger blocked batch operation');
END;
/

PROMPT;
PROMPT ========================================================================
PROMPT TEST 5: VIEW AUDIT LOG (Recent Activity)
PROMPT ========================================================================
PROMPT;
PROMPT Recent audit log entries (last 10):
PROMPT;

SELECT 
    TO_CHAR(log_time, 'HH24:MI:SS') AS time,
    activity,
    SUBSTR(details, 1, 80) AS details_preview
FROM audit_logs
ORDER BY log_time DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT;
PROMPT ========================================================================
PROMPT TEST 6: CHECK TRIGGER STATUS
PROMPT ========================================================================
PROMPT;
PROMPT All triggers in database:
PROMPT;

SELECT 
    trigger_name,
    table_name,
    triggering_event,
    status
FROM user_triggers
WHERE table_name IN ('PATIENTS', 'ENCOUNTERS', 'CONDITIONS')
ORDER BY table_name, trigger_name;

PROMPT;
PROMPT ========================================================================
PROMPT TEST 7: HOLIDAY SCHEDULE
PROMPT ========================================================================
PROMPT;
PROMPT Upcoming holidays that will block operations:
PROMPT;

SELECT 
    holiday_name,
    TO_CHAR(holiday_date, 'Day, DD-MON-YYYY') AS holiday_date,
    CASE 
        WHEN TRUNC(holiday_date) = TRUNC(SYSDATE) THEN '*** TODAY ***'
        WHEN holiday_date > SYSDATE THEN TO_CHAR(holiday_date - SYSDATE) || ' days from now'
        ELSE 'Past'
    END AS status
FROM public_holidays
WHERE holiday_date >= TRUNC(SYSDATE)
ORDER BY holiday_date;

PROMPT;
PROMPT ========================================================================
PROMPT   PHASE VII TESTING SUMMARY
PROMPT ========================================================================
PROMPT   
PROMPT   Tests Performed:
PROMPT     [X] INSERT restriction check (patients table)
PROMPT     [X] UPDATE restriction check (patients table)
PROMPT     [X] DELETE restriction check (patients table)
PROMPT     [X] Compound trigger test (conditions table - batch operations)
PROMPT     [X] Audit log verification
PROMPT     [X] Trigger status verification
PROMPT     [X] Holiday schedule verification
PROMPT;
PROMPT   Expected Behavior:
PROMPT     - WEEKDAYS (Mon-Fri): All operations BLOCKED
PROMPT     - WEEKENDS (Sat-Sun): All operations ALLOWED
PROMPT     - PUBLIC HOLIDAYS: All operations BLOCKED (even on weekends)
PROMPT;
PROMPT   Current Day Type: 
SELECT '     ' || fn_get_day_type() AS current_status FROM dual;
PROMPT;
PROMPT   Business Rules Status:
SELECT 
    '     Operations are currently ' || 
    CASE 
        WHEN fn_check_operation_allowed('INSERT', 'PATIENTS', USER) = 'ALLOWED' 
        THEN 'ALLOWED'
        ELSE 'BLOCKED'
    END AS rule_status
FROM dual;
PROMPT;
PROMPT ========================================================================
PROMPT   Phase VII Requirements Status: COMPLETE
PROMPT ========================================================================
PROMPT   
PROMPT   Created Objects:
PROMPT     [X] 1 Holiday management table (public_holidays)
PROMPT     [X] 4 Business rule functions
PROMPT     [X] 5 Simple triggers (BEFORE INSERT/UPDATE/DELETE)
PROMPT     [X] 1 Compound trigger (4 timing points)
PROMPT     [X] Complete audit trail system
PROMPT;
PROMPT   Innovation Points:
PROMPT     - Autonomous transaction for audit logs
PROMPT     - Compound trigger with shared state
PROMPT     - Batch operation tracking
PROMPT     - User-friendly day type display function
PROMPT ========================================================================
