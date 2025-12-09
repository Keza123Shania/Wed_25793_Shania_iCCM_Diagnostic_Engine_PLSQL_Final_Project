-- =============================================================================
-- PHASE VII: Advanced Programming & Auditing
-- Student: Shania (25793)
-- File: wed_25793_shania_PhaseVII_HolidaySetup.sql
-- Purpose: Holiday management and audit infrastructure
-- =============================================================================
SET SERVEROUTPUT ON;

PROMPT ========================================================================
PROMPT   PHASE VII: HOLIDAY MANAGEMENT SETUP
PROMPT   Student: Shania (25793)
PROMPT ========================================================================
PROMPT;

-- =============================================================================
-- 1. CREATE HOLIDAY MANAGEMENT TABLE
-- =============================================================================
PROMPT Creating holiday management table...

CREATE TABLE public_holidays (
    holiday_id      NUMBER(10)      CONSTRAINT pk_holidays PRIMARY KEY,
    holiday_name    VARCHAR2(100)   NOT NULL,
    holiday_date    DATE            NOT NULL UNIQUE,
    description     VARCHAR2(255),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
) TABLESPACE tbs_iccm_data;

-- Sequence for holidays
CREATE SEQUENCE seq_holidays START WITH 1 INCREMENT BY 1;

PROMPT Holiday table created successfully.
PROMPT;

-- =============================================================================
-- 2. LOAD UPCOMING PUBLIC HOLIDAYS (December 2025 - January 2026)
-- =============================================================================
PROMPT Loading Rwanda public holidays for next 2 months...

BEGIN
    -- December 2025
    INSERT INTO public_holidays VALUES (seq_holidays.NEXTVAL, 
        'Christmas Day', DATE '2025-12-25', 'Christmas celebration', CURRENT_TIMESTAMP);
    
    INSERT INTO public_holidays VALUES (seq_holidays.NEXTVAL, 
        'Boxing Day', DATE '2025-12-26', 'Day after Christmas', CURRENT_TIMESTAMP);
    
    -- January 2026
    INSERT INTO public_holidays VALUES (seq_holidays.NEXTVAL, 
        'New Year Day', DATE '2026-01-01', 'New Year celebration', CURRENT_TIMESTAMP);
    
    INSERT INTO public_holidays VALUES (seq_holidays.NEXTVAL, 
        'Heroes Day', DATE '2026-01-31', 'National Heroes Day', CURRENT_TIMESTAMP);
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Loaded ' || SQL%ROWCOUNT || ' public holidays');
END;
/

-- Display loaded holidays
PROMPT;
PROMPT Upcoming Public Holidays:
PROMPT ------------------------;
SELECT holiday_name, TO_CHAR(holiday_date, 'Day, DD-MON-YYYY') AS holiday_date
FROM public_holidays
ORDER BY holiday_date;

PROMPT;
PROMPT ========================================================================
PROMPT   HOLIDAY SETUP COMPLETE
PROMPT ========================================================================
