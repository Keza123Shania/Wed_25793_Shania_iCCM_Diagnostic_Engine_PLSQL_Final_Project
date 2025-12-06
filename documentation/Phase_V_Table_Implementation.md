# Phase V: Table Implementation & Data Strategy

**Project:** iCCM Diagnostic Engine  
**Student:** Keza Shania (25793) | Database Development with PL/SQL (INSY 8311) | Group C

---

## 1. Physical Schema Implementation
All entities from the logical model have been converted into Oracle physical tables owned by the project user `WED_25793_SHANIA_ICCM_DB`.

### Storage Optimization
* **Data Tablespace (`TBS_ICCM_DATA`):** Stores all core tables (`PATIENTS`, `ENCOUNTERS`, etc.) to isolate project data from system data.
* **Index Tablespace (`TBS_ICCM_IDX`):** Stores B-Tree indexes (`IDX_PAT_LOC`, `IDX_ENC_PAT`) separately. This improves I/O performance by allowing the disk head to read indexes without contending with table data access.

### Constraints & Integrity
* **Primary Keys:** Enforced on all tables using Surrogate Keys (e.g., `PATIENT_ID`).
* **Foreign Keys:** Enforced to ensure referential integrity (e.g., A user cannot be deleted if they have linked encounters).
* **Check Constraints:**
    * `GENDER IN ('M', 'F')`
    * `ROLE IN ('CHW', 'SUPERVISOR')`
* **Default Values:** Timestamps default to `CURRENT_TIMESTAMP`.

---

## 2. Advanced Data Generation Strategy
To meet the requirement of 100-500+ realistic rows, I developed a complex PL/SQL generator (`05_insert_test_data.sql`) rather than using simple static inserts.

### Key Features of the Generator
1.  **Smart Gender Logic:**
    * The script randomly assigns a gender (`'M'` or `'F'`).
    * It then selects a name from a specific `MALE_ARRAY` or `FEMALE_ARRAY` to ensure data consistency (e.g., No "Keza" assigned to "Male").
2.  **Historical Data Simulation:**
    * **DOB:** Randomly generated between 1 month and 5 years ago.
    * **Registration Date:** Generated relative to DOB (always after birth, but before today).
3.  **Randomized Distribution:**
    * **Locations:** Patients are distributed unevenly across 5 villages using `DBMS_RANDOM` (not mathematical modulo), creating realistic population variance.
    * **Disease Scenarios:** Diagnoses follow a weighted probability (33% Malaria, 33% Pneumonia, 33% Healthy).

---

## 3. Testing & Verification Results
The verification script (`06_test_queries.sql`) confirmed the following:

### A. Data Volume
| Table Name | Row Count |
| :--- | :--- |
| PATIENTS | 150 |
| ENCOUNTERS | 150 |
| OBSERVATIONS | ~400 |

### B. Business Rule Validation
* **Referral Logic:** All patients diagnosed with "Severe Pneumonia" correctly have `REFERRAL_STATUS = 'REFERRED'`.
* **Orphan Records:** None found. Every encounter is linked to a valid Patient and User.

### C. Sample Aggregation (Disease by Village)
*Demonstrating unequal/realistic distribution:*

| Village Name | Total Diagnoses |
| :--- | :--- |
| Kibuye Shore | 34 |
| Rwamagana Village | 28 |
| Musanze North | 15 |
