# Phase IV: Database Creation & Configuration

**Project:** iCCM Diagnostic Engine
**Student:** Shania (25793) |  **ID:** 25793  |  Database Development with PL/SQL (INSY 8311) | Group C

## 1. Database Identification
To meet the requirement for an isolated environment, I created a new Pluggable Database (PDB).
* **PDB Name:** `Wed_25793_Shania_iCCM_DB`
* **Parent Container:** `ORCL` (Root)
* **Project User:** `WED_25793_SHANIA_ICCM_DB` (Granted DBA privileges)

## 2. Storage Architecture
I designed the storage to optimize performance by separating data from indexes.

| Tablespace Name | Purpose | Configuration |
| :--- | :--- | :--- |
| **TBS_ICCM_DATA** | Holds all patient and clinical tables. | `100MB` Initial, Autoextends by `50MB` |
| **TBS_ICCM_IDX** | Holds B-Tree indexes for fast lookups. | `50MB` Initial, Autoextends by `10MB` |
| **TBS_ICCM_TEMP** | Used for sorting query results. | `50MB` Initial, Autoextends by `10MB` |

## 3. Configuration
* **Persistence:** I ran `SAVE STATE` to ensure my PDB starts automatically when the computer reboots.
* **Archiving:** The database is configured in `ARCHIVELOG` mode for data safety.
* **Memory:** I allocated 1GB to SGA to ensure the diagnostic rules can be cached in memory for speed.

## 4. Execution Proof
All scripts were successfully executed. The Admin user is active and connected to the correct default tablespaces.
