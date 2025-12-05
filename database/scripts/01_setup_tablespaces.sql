-- =============================================================================
-- PHASE IV: Physical Storage Setup
-- Student: Shania (25793)
-- Context: Running on Wed_25793_Shania_iCCM_DB
-- =============================================================================

-- I decided to separate my Data and Indexes into different tablespaces.
-- This is a performance optimization: it reduces I/O contention because
-- the database can read from the index and the table simultaneously.

-- 1. DATA Tablespace
-- This will hold all my patient records and iCCM rules.
-- I enabled AUTOEXTEND so the system doesn't crash if I insert too much test data.
CREATE TABLESPACE tbs_iccm_data
    DATAFILE 'iccm_data01.dbf' 
    SIZE 100M 
    AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED
    LOGGING
    EXTENT MANAGEMENT LOCAL AUTOALLOCATE
    SEGMENT SPACE MANAGEMENT AUTO;

-- 2. INDEX Tablespace
-- This will store the B-Tree indexes for primary keys and lookups.
CREATE TABLESPACE tbs_iccm_idx
    DATAFILE 'iccm_idx01.dbf' 
    SIZE 50M 
    AUTOEXTEND ON NEXT 10M MAXSIZE UNLIMITED
    LOGGING;

-- 3. TEMP Tablespace
-- I need this for the complex sorting operations in my analytical queries later.
CREATE TEMPORARY TABLESPACE tbs_iccm_temp
    TEMPFILE 'iccm_temp01.dbf' 
    SIZE 50M 
    AUTOEXTEND ON NEXT 10M MAXSIZE 500M;

-- Verification: Checking that my tablespaces exist and are online.
SELECT tablespace_name, status, contents 
FROM dba_tablespaces 
WHERE tablespace_name LIKE 'TBS_ICCM%';
