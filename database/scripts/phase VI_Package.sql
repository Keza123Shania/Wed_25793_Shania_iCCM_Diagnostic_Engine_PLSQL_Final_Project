-- =============================================================================
-- PHASE VI: PL/SQL Package (Diagnostic Engine)
-- Student: Shania (25793)
-- File: wed_25793_shania_PhaseVI_Package.sql
-- Components: Package Specification + Package Body
-- =============================================================================
SET SERVEROUTPUT ON;

-- =============================================================================
-- PACKAGE SPECIFICATION (Public Interface)
-- Purpose: Defines public procedures, functions, and types
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_diagnostic_engine AS
    
    -- Public procedure: Run full diagnostic analysis on encounter
    PROCEDURE analyze_encounter (
        p_encounter_id IN NUMBER
    );
    
    -- Public function: Get diagnosis summary for encounter
    FUNCTION get_diagnosis_summary (
        p_encounter_id IN NUMBER
    ) RETURN VARCHAR2;
    
    -- Public function: Get treatment recommendations
    FUNCTION get_treatment_plan (
        p_encounter_id IN NUMBER
    ) RETURN VARCHAR2;
    
    -- Public procedure: Generate prescriptions based on diagnoses
    PROCEDURE generate_prescriptions (
        p_encounter_id IN NUMBER
    );
    
    -- Public function: Check if referral is needed
    FUNCTION requires_referral (
        p_encounter_id IN NUMBER
    ) RETURN BOOLEAN;
    
END pkg_diagnostic_engine;
/

-- =============================================================================
-- PACKAGE BODY (Implementation)
-- Purpose: Contains the actual logic for all public and private members
-- =============================================================================
CREATE OR REPLACE PACKAGE BODY pkg_diagnostic_engine AS
    
    -- =========================================================================
    -- PRIVATE FUNCTIONS (Not accessible outside package)
    -- =========================================================================
    
    -- Private function: Calculate confidence for a specific disease
    FUNCTION calculate_disease_score (
        p_encounter_id IN NUMBER,
        p_disease_id IN NUMBER
    ) RETURN NUMBER
    AS
        v_total_points NUMBER := 0;
        v_max_possible NUMBER := 0;
        v_confidence NUMBER;
        
        CURSOR c_rules IS
            SELECT r.symptom_code, r.operator, r.compare_val, r.points_weight
            FROM iccm_rules r
            WHERE r.disease_id = p_disease_id;
        
        v_measured_val VARCHAR2(50);
        v_numeric_measured NUMBER;
        v_numeric_compare NUMBER;
        v_match BOOLEAN;
    BEGIN
        FOR rule IN c_rules LOOP
            v_max_possible := v_max_possible + rule.points_weight;
            
            BEGIN
                SELECT measured_val INTO v_measured_val
                FROM observations
                WHERE encounter_id = p_encounter_id
                  AND symptom_code = rule.symptom_code;
                
                v_match := FALSE;
                
                IF rule.operator = '=' THEN
                    v_match := (v_measured_val = rule.compare_val);
                ELSE
                    v_numeric_measured := TO_NUMBER(v_measured_val);
                    v_numeric_compare := TO_NUMBER(rule.compare_val);
                    
                    IF rule.operator = '>' THEN
                        v_match := (v_numeric_measured > v_numeric_compare);
                    ELSIF rule.operator = '<' THEN
                        v_match := (v_numeric_measured < v_numeric_compare);
                    ELSIF rule.operator = '>=' THEN
                        v_match := (v_numeric_measured >= v_numeric_compare);
                    END IF;
                END IF;
                
                IF v_match THEN
                    v_total_points := v_total_points + rule.points_weight;
                END IF;
                
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;
        END LOOP;
        
        IF v_max_possible > 0 THEN
            v_confidence := ROUND((v_total_points / v_max_possible) * 100, 0);
        ELSE
            v_confidence := 0;
        END IF;
        
        RETURN v_confidence;
    END calculate_disease_score;
    
    -- Private function: Determine severity level
    FUNCTION get_severity_level (
        p_confidence IN NUMBER
    ) RETURN VARCHAR2
    AS
    BEGIN
        IF p_confidence >= 80 THEN
            RETURN 'CRITICAL';
        ELSIF p_confidence >= 60 THEN
            RETURN 'SEVERE';
        ELSIF p_confidence >= 40 THEN
            RETURN 'MODERATE';
        ELSE
            RETURN 'MILD';
        END IF;
    END get_severity_level;
    
    -- =========================================================================
    -- PUBLIC PROCEDURE 1: Analyze Encounter
    -- Purpose: Run diagnostic rules and create condition records
    -- =========================================================================
    PROCEDURE analyze_encounter (
        p_encounter_id IN NUMBER
    )
    AS
        v_encounter_count NUMBER;
        v_weight NUMBER;
        
        CURSOR c_diseases IS
            SELECT disease_id, name, score_threshold
            FROM iccm_diseases;
        
        v_confidence NUMBER;
        v_severity VARCHAR2(20);
        v_condition_id NUMBER;
        
    BEGIN
        -- Validate encounter exists
        SELECT COUNT(*), MAX(weight_kg) INTO v_encounter_count, v_weight
        FROM encounters WHERE encounter_id = p_encounter_id;
        
        IF v_encounter_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20100, 'ERROR: Encounter ' || p_encounter_id || ' not found');
        END IF;
        
        -- Clear any existing diagnoses
        DELETE FROM conditions WHERE encounter_id = p_encounter_id;
        
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('DIAGNOSTIC ANALYSIS');
        DBMS_OUTPUT.PUT_LINE('Encounter ID: ' || p_encounter_id);
        DBMS_OUTPUT.PUT_LINE('Patient Weight: ' || v_weight || ' kg');
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE(' ');
        
        -- Evaluate each disease
        FOR disease IN c_diseases LOOP
            v_confidence := calculate_disease_score(p_encounter_id, disease.disease_id);
            
            -- Only record if confidence meets threshold
            IF v_confidence >= (disease.score_threshold * 10) THEN
                v_severity := get_severity_level(v_confidence);
                
                -- Insert diagnosis
                v_condition_id := seq_trans.NEXTVAL;
                INSERT INTO conditions (condition_id, encounter_id, disease_id, 
                                       confidence_score, severity, created_at)
                VALUES (v_condition_id, p_encounter_id, disease.disease_id,
                       v_confidence, v_severity, CURRENT_TIMESTAMP);
                
                DBMS_OUTPUT.PUT_LINE('DIAGNOSIS: ' || disease.name);
                DBMS_OUTPUT.PUT_LINE('  Confidence: ' || v_confidence || '%');
                DBMS_OUTPUT.PUT_LINE('  Severity: ' || v_severity);
                DBMS_OUTPUT.PUT_LINE('----------------------------------------');
            END IF;
        END LOOP;
        
        COMMIT;
        
        -- Audit log
        INSERT INTO audit_logs (log_id, activity, details, log_time)
        VALUES (seq_trans.NEXTVAL, 'DIAGNOSTIC_ANALYSIS', 
                'Encounter: ' || p_encounter_id, CURRENT_TIMESTAMP);
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('Analysis complete.');
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20199, 'ERROR: ' || SQLERRM);
    END analyze_encounter;
    
    -- =========================================================================
    -- PUBLIC FUNCTION 1: Get Diagnosis Summary
    -- Purpose: Return formatted text summary of all diagnoses
    -- =========================================================================
    FUNCTION get_diagnosis_summary (
        p_encounter_id IN NUMBER
    ) RETURN VARCHAR2
    AS
        v_summary VARCHAR2(4000) := '';
        v_count NUMBER := 0;
        
        CURSOR c_conditions IS
            SELECT d.name, c.confidence_score, c.severity
            FROM conditions c
            JOIN iccm_diseases d ON c.disease_id = d.disease_id
            WHERE c.encounter_id = p_encounter_id
            ORDER BY c.confidence_score DESC;
    BEGIN
        v_summary := 'DIAGNOSES: ';
        
        FOR cond IN c_conditions LOOP
            v_count := v_count + 1;
            v_summary := v_summary || CHR(10) || v_count || '. ' || cond.name || 
                        ' (' || cond.confidence_score || '%, ' || cond.severity || ')';
        END LOOP;
        
        IF v_count = 0 THEN
            v_summary := 'No diagnoses found. Run analyze_encounter() first.';
        END IF;
        
        RETURN v_summary;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR: ' || SQLERRM;
    END get_diagnosis_summary;
    
    -- =========================================================================
    -- PUBLIC FUNCTION 2: Get Treatment Plan
    -- Purpose: Return medication recommendations based on diagnoses
    -- =========================================================================
    FUNCTION get_treatment_plan (
        p_encounter_id IN NUMBER
    ) RETURN VARCHAR2
    AS
        v_plan VARCHAR2(4000) := '';
        v_weight NUMBER;
        v_count NUMBER := 0;
        
        CURSOR c_treatments IS
            SELECT d.name, m.med_name, p.dosage_instruction
            FROM conditions c
            JOIN iccm_diseases d ON c.disease_id = d.disease_id
            JOIN iccm_protocols p ON d.disease_id = p.disease_id
            JOIN iccm_medications m ON p.med_id = m.med_id
            WHERE c.encounter_id = p_encounter_id
              AND c.encounter_id IN (
                  SELECT encounter_id FROM encounters 
                  WHERE encounter_id = p_encounter_id
                    AND weight_kg BETWEEN p.min_weight_kg AND p.max_weight_kg
              );
    BEGIN
        SELECT weight_kg INTO v_weight
        FROM encounters WHERE encounter_id = p_encounter_id;
        
        v_plan := 'TREATMENT PLAN (Weight: ' || v_weight || ' kg):' || CHR(10);
        
        FOR treat IN c_treatments LOOP
            v_count := v_count + 1;
            v_plan := v_plan || CHR(10) || v_count || '. ' || treat.name || ':';
            v_plan := v_plan || CHR(10) || '   ' || treat.med_name || ' - ' || treat.dosage_instruction;
        END LOOP;
        
        IF v_count = 0 THEN
            v_plan := v_plan || CHR(10) || 'No treatment protocols found. Check diagnoses and weight.';
        END IF;
        
        RETURN v_plan;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR: ' || SQLERRM;
    END get_treatment_plan;
    
    -- =========================================================================
    -- PUBLIC PROCEDURE 2: Generate Prescriptions
    -- Purpose: Insert prescription records based on treatment plan
    -- =========================================================================
    PROCEDURE generate_prescriptions (
        p_encounter_id IN NUMBER
    )
    AS
        v_weight NUMBER;
        v_script_count NUMBER := 0;
        
        CURSOR c_treatments IS
            SELECT c.condition_id, m.med_name, p.dosage_instruction, p.disease_id
            FROM conditions c
            JOIN iccm_protocols p ON c.disease_id = p.disease_id
            JOIN iccm_medications m ON p.med_id = m.med_id
            WHERE c.encounter_id = p_encounter_id;
        
    BEGIN
        -- Get patient weight
        SELECT weight_kg INTO v_weight
        FROM encounters WHERE encounter_id = p_encounter_id;
        
        -- Clear existing prescriptions
        DELETE FROM prescriptions 
        WHERE condition_id IN (SELECT condition_id FROM conditions 
                              WHERE encounter_id = p_encounter_id);
        
        -- Generate new prescriptions
        FOR treat IN c_treatments LOOP
            IF v_weight BETWEEN 5 AND 25 THEN
                INSERT INTO prescriptions (script_id, condition_id, med_name, dosage, quantity)
                VALUES (seq_trans.NEXTVAL, treat.condition_id, treat.med_name, 
                       treat.dosage_instruction, 
                       CASE WHEN treat.disease_id = 1 THEN 3  -- Malaria: 3 days
                            WHEN treat.disease_id = 2 THEN 5  -- Pneumonia: 5 days
                            ELSE 7 END);
                
                v_script_count := v_script_count + 1;
            END IF;
        END LOOP;
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('Generated ' || v_script_count || ' prescription(s)');
        
        -- Audit
        INSERT INTO audit_logs (log_id, activity, details, log_time)
        VALUES (seq_trans.NEXTVAL, 'PRESCRIPTION_GENERATED', 
                'Encounter: ' || p_encounter_id || ', Count: ' || v_script_count, 
                CURRENT_TIMESTAMP);
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20199, 'ERROR: ' || SQLERRM);
    END generate_prescriptions;
    
    -- =========================================================================
    -- PUBLIC FUNCTION 3: Requires Referral
    -- Purpose: Check if any diagnosis requires hospital referral
    -- =========================================================================
    FUNCTION requires_referral (
        p_encounter_id IN NUMBER
    ) RETURN BOOLEAN
    AS
        v_severe_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_severe_count
        FROM conditions
        WHERE encounter_id = p_encounter_id
          AND severity IN ('CRITICAL', 'SEVERE');
        
        RETURN (v_severe_count > 0);
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END requires_referral;
    
END pkg_diagnostic_engine;
/

PROMPT ========================================================================
PROMPT   PACKAGE CREATED SUCCESSFULLY
PROMPT ========================================================================
PROMPT   Package Name: pkg_diagnostic_engine
PROMPT   
PROMPT   PUBLIC INTERFACE:
PROMPT     1. analyze_encounter(encounter_id)      - Run diagnostic analysis
PROMPT     2. get_diagnosis_summary(encounter_id)  - Get diagnosis text
PROMPT     3. get_treatment_plan(encounter_id)     - Get treatment recommendations
PROMPT     4. generate_prescriptions(encounter_id) - Create prescription records
PROMPT     5. requires_referral(encounter_id)      - Check if referral needed
PROMPT   
PROMPT   PRIVATE FUNCTIONS (Internal use only):
PROMPT     - calculate_disease_score() - Score disease likelihood
PROMPT     - get_severity_level()      - Map confidence to severity
PROMPT ========================================================================
