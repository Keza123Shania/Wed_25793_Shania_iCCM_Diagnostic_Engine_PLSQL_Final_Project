-- =============================================================================
-- PHASE IV: PDB Creation
-- Student: Shania (25793)
-- Objective: Create a dedicated environment for the iCCM project.
-- =============================================================================

-- I am creating a specific Pluggable Database (PDB) to isolate my iCCM project
-- data from the system data. This follows the Multitenant architecture.

-- Naming Convention: Group_StudentID_Name_Project_DB
CREATE PLUGGABLE DATABASE Wed_25793_Shania_iCCM_DB
    ADMIN USER pdb_admin IDENTIFIED BY Shania
    ROLES = (DBA)
    -- I'm using file_name_convert to ensure the new data files are created
    -- in a distinct folder, copying the structure from the seed database.
    FILE_NAME_CONVERT = ('pdbseed', 'Wed_25793_Shania_iCCM_DB');

-- By default, a new PDB is created in MOUNTED state. 
-- I need to open it to read/write mode so I can start working.
ALTER PLUGGABLE DATABASE Wed_25793_Shania_iCCM_DB OPEN;

-- IMPORTANT: I'm saving the state so the PDB automatically opens 
-- whenever the database server restarts. Otherwise, I'd have to open it manually every time.
ALTER PLUGGABLE DATABASE Wed_25793_Shania_iCCM_DB SAVE STATE;

-- Verification query to confirm my PDB is up and running.
SELECT name, open_mode 
FROM v$pdbs 
WHERE name = 'WED_25793_SHANIA_ICCM_DB';
