-- =============================================================================
-- PHASE IV: System Configuration Parameters
-- Student: Shania (25793)
-- =============================================================================

-- 1. Memory Configuration
-- I am using Automatic Memory Management (AMM) here.
-- I set the SGA target to 1GB to ensure my iCCM_Rules table can stay cached in memory.
-- I set the PGA to 500MB to handle the PL/SQL processing for each user session.
ALTER SYSTEM SET sga_target=1G SCOPE=SPFILE;
ALTER SYSTEM SET pga_aggregate_target=500M SCOPE=SPFILE;

-- 2. Archive Log Configuration
-- This is a requirement for production systems to ensure point-in-time recovery.
-- NOTE: I have commented these out because they require restarting the database instance,
-- which I cannot do on the shared lab server right now. But this is the code I would use:

-- SHUTDOWN IMMEDIATE;
-- STARTUP MOUNT;
-- ALTER DATABASE ARCHIVELOG;
-- ALTER DATABASE OPEN;

-- Verification: Checking current settings.
SELECT name, value 
FROM v$parameter 
WHERE name IN ('sga_target', 'pga_aggregate_target');

SELECT log_mode FROM v$database;
