-- =============================================================================
-- PHASE IV: Project Admin User Creation
-- Student: Shania (25793)
-- =============================================================================

-- Creating the main schema owner for the project.
-- This user will own all the tables (Patients, Encounters) and the PL/SQL packages.
-- I am assigning the 'tbs_iccm_data' tablespace as default so objects go there automatically.

CREATE USER WED_25793_SHANIA_ICCM_DB
    IDENTIFIED BY Shania
    DEFAULT TABLESPACE tbs_iccm_data
    TEMPORARY TABLESPACE tbs_iccm_temp
    -- Giving unlimited quota so I don't hit space errors during data insertion.
    QUOTA UNLIMITED ON tbs_iccm_data
    QUOTA UNLIMITED ON tbs_iccm_idx;

-- Granting Privileges:
-- I am granting the DBA role because, as the developer, I need full control 
-- to create any object type (Procedures, Sequences, Triggers) without restriction.
GRANT CONNECT, RESOURCE, DBA TO WED_25793_SHANIA_ICCM_DB;

-- Explicitly granting creation rights just to be safe and clear about what this user does.
GRANT CREATE SESSION TO WED_25793_SHANIA_ICCM_DB;
GRANT CREATE TABLE TO WED_25793_SHANIA_ICCM_DB;
GRANT CREATE VIEW TO WED_25793_SHANIA_ICCM_DB;
GRANT CREATE PROCEDURE TO WED_25793_SHANIA_ICCM_DB;
GRANT CREATE TRIGGER TO WED_25793_SHANIA_ICCM_DB;
GRANT CREATE SEQUENCE TO WED_25793_SHANIA_ICCM_DB;

-- Verification: Confirming the user is created and active.
SELECT username, account_status, default_tablespace 
FROM dba_users 
WHERE username = 'WED_25793_SHANIA_ICCM_DB';
