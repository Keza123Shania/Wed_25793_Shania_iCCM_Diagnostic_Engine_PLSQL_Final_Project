-- =============================================================================
-- PHASE V: Table Implementation (DDL) - FRESH START
-- Student: Shania (25793)
-- Objective: Create physical schema. Includes "DROP" commands for easy resets.
-- =============================================================================

-- 1. CLEANUP (Destroys old versions to prevent errors)
BEGIN
    FOR t IN (SELECT table_name FROM user_tables) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
    FOR s IN (SELECT sequence_name FROM user_sequences) LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
    END LOOP;
END;
/

-- 2. LOOKUP TABLES
CREATE TABLE locations (
    location_id     NUMBER(10)      CONSTRAINT pk_loc PRIMARY KEY,
    village_name    VARCHAR2(100)   NOT NULL,
    district_name   VARCHAR2(100)   NOT NULL,
    province_name   VARCHAR2(100)   DEFAULT 'Northern Province'
) TABLESPACE tbs_iccm_data;

CREATE TABLE users (
    user_id         NUMBER(10)      CONSTRAINT pk_users PRIMARY KEY,
    username        VARCHAR2(50)    NOT NULL CONSTRAINT uq_username UNIQUE,
    full_name       VARCHAR2(100)   NOT NULL,
    role            VARCHAR2(20)    DEFAULT 'CHW' CHECK (role IN ('CHW', 'SUPERVISOR', 'ADMIN')),
    location_id     NUMBER(10)      CONSTRAINT fk_user_loc REFERENCES locations(location_id),
    is_active       NUMBER(1)       DEFAULT 1 CHECK (is_active IN (0,1))
) TABLESPACE tbs_iccm_data;

CREATE TABLE iccm_rules (
    rule_id         NUMBER(10)      CONSTRAINT pk_rules PRIMARY KEY,
    symptom_trigger VARCHAR2(50)    NOT NULL, 
    operator        VARCHAR2(5)     CHECK (operator IN ('>', '<', '=', '>=', '<=')),
    threshold_val   VARCHAR2(50)    NOT NULL,
    outcome_dx      VARCHAR2(100)   NOT NULL,
    severity        VARCHAR2(20)    CHECK (severity IN ('MILD', 'MODERATE', 'SEVERE'))
) TABLESPACE tbs_iccm_data;

-- 3. CORE ENTITIES
CREATE TABLE patients (
    patient_id      NUMBER(10)      CONSTRAINT pk_patients PRIMARY KEY,
    full_name       VARCHAR2(100)   NOT NULL,
    dob             DATE            NOT NULL,
    gender          CHAR(1)         NOT NULL CHECK (gender IN ('M', 'F')),
    location_id     NUMBER(10)      CONSTRAINT fk_pat_loc REFERENCES locations(location_id),
    registered_at   TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
) TABLESPACE tbs_iccm_data;

CREATE TABLE encounters (
    encounter_id    NUMBER(15)      CONSTRAINT pk_encounters PRIMARY KEY,
    patient_id      NUMBER(10)      NOT NULL CONSTRAINT fk_enc_pat REFERENCES patients(patient_id),
    chw_id          NUMBER(10)      NOT NULL CONSTRAINT fk_enc_chw REFERENCES users(user_id),
    encounter_date  TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    referral_status VARCHAR2(20)    DEFAULT 'NONE' CHECK (referral_status IN ('NONE', 'REFERRED', 'COMPLETED'))
) TABLESPACE tbs_iccm_data;

CREATE TABLE observations (
    observation_id  NUMBER(15)      CONSTRAINT pk_obs PRIMARY KEY,
    encounter_id    NUMBER(15)      NOT NULL CONSTRAINT fk_obs_enc REFERENCES encounters(encounter_id) ON DELETE CASCADE,
    symptom_code    VARCHAR2(50)    NOT NULL,
    measured_val    VARCHAR2(50)    NOT NULL,
    data_type       VARCHAR2(20)    DEFAULT 'STRING'
) TABLESPACE tbs_iccm_data;

-- 4. OUTPUT TABLES
CREATE TABLE conditions (
    condition_id    NUMBER(15)      CONSTRAINT pk_conditions PRIMARY KEY,
    encounter_id    NUMBER(15)      NOT NULL CONSTRAINT fk_cond_enc REFERENCES encounters(encounter_id),
    diagnosis_code  VARCHAR2(50)    NOT NULL,
    severity        VARCHAR2(20)    NOT NULL,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
) TABLESPACE tbs_iccm_data;

CREATE TABLE medication_requests (
    request_id      NUMBER(15)      CONSTRAINT pk_meds PRIMARY KEY,
    condition_id    NUMBER(15)      NOT NULL CONSTRAINT fk_med_cond REFERENCES conditions(condition_id),
    drug_name       VARCHAR2(100)   NOT NULL,
    dosage          VARCHAR2(100)   NOT NULL,
    quantity        NUMBER(3)       CHECK (quantity > 0)
) TABLESPACE tbs_iccm_data;

CREATE TABLE audit_logs (
    log_id          NUMBER(15)      CONSTRAINT pk_audit PRIMARY KEY,
    table_name      VARCHAR2(30)    NOT NULL,
    operation       VARCHAR2(10)    NOT NULL,
    record_id       NUMBER(15),
    user_id         NUMBER(10),
    log_timestamp   TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    old_value       VARCHAR2(4000),
    new_value       VARCHAR2(4000)
) TABLESPACE tbs_iccm_data;

-- 5. SEQUENCES & INDEXES
CREATE SEQUENCE seq_loc START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_pat START WITH 1000 INCREMENT BY 1;
CREATE SEQUENCE seq_enc START WITH 50000 INCREMENT BY 1;
CREATE SEQUENCE seq_obs START WITH 100000 INCREMENT BY 1;
CREATE SEQUENCE seq_cond START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_meds START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_audit START WITH 1 INCREMENT BY 1;

CREATE INDEX idx_pat_loc ON patients(location_id) TABLESPACE tbs_iccm_idx;
CREATE INDEX idx_enc_pat ON encounters(patient_id) TABLESPACE tbs_iccm_idx;
