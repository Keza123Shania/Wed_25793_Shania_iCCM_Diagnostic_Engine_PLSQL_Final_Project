-- =============================================================================
-- PHASE VII: Business Rules Functions
-- Student: Shania (25793)
-- File: wed_25793_shania_PhaseVII_Functions.sql
-- Purpose: Restriction check and audit logging functions
-- =============================================================================
SET SERVEROUTPUT ON;

PROMPT ========================================================================
PROMPT   PHASE VII: BUSINESS RULE FUNCTIONS
PROMPT   Student: Shania (25793)
PROMPT ========================================================================
PROMPT;

-- =============================================================================
-- FUNCTION 1: Check if date is a public holiday
-- =============================================================================
PROMPT Creating holiday check function...

CREATE OR REPLACE FUNCTION fn_is_public_holiday (
    p_check_date IN DATE
) RETURN BOOLEAN
AS
    v_holiday_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_holiday_count
    FROM public_holidays
    WHERE TRUNC(holiday_date) = TRUNC(p_check_date);
    
    RETURN (v_holiday_count > 0);
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END fn_is_public_holiday;
/

-- =============================================================================
-- FUNCTION 2: Check if operation is allowed (main restriction logic)
-- =============================================================================
PROMPT Creating restriction check function...

CREATE OR REPLACE FUNCTION fn_check_operation_allowed (
    p_operation IN VARCHAR2,
    p_table_name IN VARCHAR2,
    p_user_name IN VARCHAR2
) RETURN VARCHAR2
AS
    v_day_name VARCHAR2(20);
    v_day_number NUMBER;
    v_is_holiday BOOLEAN;
    v_current_date DATE := SYSDATE;
BEGIN
    -- Get day information
    v_day_name := TO_CHAR(v_current_date, 'Day');
    v_day_number := TO_NUMBER(TO_CHAR(v_current_date, 'D')); -- 1=Sunday, 7=Saturday
    
    -- Check if it's a holiday
    v_is_holiday := fn_is_public_holiday(v_current_date);
    
    -- BUSINESS RULE: Block operations on weekdays (Monday-Friday) and holidays
    -- Allow operations on weekends (Saturday-Sunday) only if not a holiday
    
    IF v_is_holiday THEN
        RETURN 'DENIED: Operations not allowed on public holidays';
    ELSIF v_day_number BETWEEN 2 AND 6 THEN -- Monday to Friday
        RETURN 'DENIED: Operations not allowed on weekdays (Monday-Friday)';
    ELSE
        RETURN 'ALLOWED';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END fn_check_operation_allowed;
/

-- =============================================================================
-- PROCEDURE: Log audit trail with restriction checks
-- =============================================================================
PROMPT Creating audit logging procedure...

CREATE OR REPLACE PROCEDURE sp_log_audit (
    p_operation IN VARCHAR2,
    p_table_name IN VARCHAR2,
    p_record_id IN NUMBER,
    p_user_name IN VARCHAR2,
    p_status IN VARCHAR2,
    p_details IN VARCHAR2
) AS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO audit_logs (log_id, activity, details, log_time)
    VALUES (
        seq_trans.NEXTVAL,
        p_operation || ' on ' || p_table_name,
        'User: ' || p_user_name || 
        ' | Record ID: ' || p_record_id || 
        ' | Status: ' || p_status || 
        ' | Details: ' || p_details ||
        ' | Day: ' || TO_CHAR(SYSDATE, 'Day') ||
        ' | Date: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
        CURRENT_TIMESTAMP
    );
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
END sp_log_audit;
/

-- =============================================================================
-- FUNCTION 3: Get current day type (for display)
-- =============================================================================
PROMPT Creating day type function...

CREATE OR REPLACE FUNCTION fn_get_day_type RETURN VARCHAR2
AS
    v_day_name VARCHAR2(20);
    v_day_number NUMBER;
    v_is_holiday BOOLEAN;
    v_holiday_name VARCHAR2(100);
BEGIN
    v_day_name := TO_CHAR(SYSDATE, 'Day');
    v_day_number := TO_NUMBER(TO_CHAR(SYSDATE, 'D'));
    v_is_holiday := fn_is_public_holiday(SYSDATE);
    
    IF v_is_holiday THEN
        SELECT holiday_name INTO v_holiday_name
        FROM public_holidays
        WHERE TRUNC(holiday_date) = TRUNC(SYSDATE);
        RETURN 'PUBLIC HOLIDAY (' || TRIM(v_holiday_name) || ')';
    ELSIF v_day_number BETWEEN 2 AND 6 THEN
        RETURN 'WEEKDAY (' || TRIM(v_day_name) || ')';
    ELSE
        RETURN 'WEEKEND (' || TRIM(v_day_name) || ')';
    END IF;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        IF v_day_number BETWEEN 2 AND 6 THEN
            RETURN 'WEEKDAY (' || TRIM(v_day_name) || ')';
        ELSE
            RETURN 'WEEKEND (' || TRIM(v_day_name) || ')';
        END IF;
    WHEN OTHERS THEN
        RETURN 'UNKNOWN';
END fn_get_day_type;
/

PROMPT;
PROMPT ========================================================================
PROMPT   BUSINESS RULE FUNCTIONS CREATED
PROMPT ========================================================================
PROMPT   1. fn_is_public_holiday      - Check if date is holiday
PROMPT   2. fn_check_operation_allowed - Main restriction logic
PROMPT   3. sp_log_audit               - Audit trail logging
PROMPT   4. fn_get_day_type            - Display current day type
PROMPT ========================================================================
