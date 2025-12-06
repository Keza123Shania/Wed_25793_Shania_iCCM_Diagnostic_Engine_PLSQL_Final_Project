-- =============================================================================
-- PHASE V: Realistic Data Insertion 
-- Student: Shania (25793)
-- Objective: Generate 150+ rows. ENSURE GENDER MATCHES NAMES.
-- =============================================================================

SET SERVEROUTPUT ON;

DECLARE
    -- Define Array Type
    TYPE t_name_array IS VARRAY(15) OF VARCHAR2(50);
    
    -- MALE Names Only
    v_male_names t_name_array := t_name_array(
        'Manzi', 'Ganza', 'Hirwa', 'Mugisha', 'Rukundo', 'Shema', 
        'Gasana', 'Kagabo', 'Ntwari', 'Eric', 'Patrick', 'Jean', 
        'Claude', 'Olivier', 'Fabrice'
    );
    
    -- FEMALE Names Only
    v_female_names t_name_array := t_name_array(
        'Keza', 'Teta', 'Ineza', 'Uwase', 'Mutoni', 'Umuhoza', 
        'Bwiza', 'Mahoro', 'Mutesi', 'Divine', 'Alice', 'Sandrine', 
        'Clarisse', 'Grace', 'Liane'
    );
    
    -- Variables to hold data during loop
    v_patient_id    NUMBER;
    v_encounter_id  NUMBER;
    v_condition_id  NUMBER;
    
    v_gender        CHAR(1);
    v_first_name    VARCHAR2(50);
    v_last_name     VARCHAR2(50); -- We will reuse the array for last names essentially
    
    v_dob           DATE;
    v_reg_date      TIMESTAMP;
    v_enc_date      TIMESTAMP;

BEGIN
    -- 1. Insert Static Reference Data
    -- Locations
    INSERT INTO locations VALUES (seq_loc.NEXTVAL, 'Rwamagana Village', 'Rwamagana', 'Eastern');
    INSERT INTO locations VALUES (seq_loc.NEXTVAL, 'Kayonza Central', 'Kayonza', 'Eastern');
    INSERT INTO locations VALUES (seq_loc.NEXTVAL, 'Musanze North', 'Musanze', 'Northern');
    INSERT INTO locations VALUES (seq_loc.NEXTVAL, 'Kibuye Shore', 'Karongi', 'Western');
    INSERT INTO locations VALUES (seq_loc.NEXTVAL, 'Nyamata South', 'Bugesera', 'Eastern');

    -- Users (CHWs)
    INSERT INTO users VALUES (101, 'chw_shania', 'Keza Shania', 'SUPERVISOR', 100, 1);
    INSERT INTO users VALUES (102, 'chw_alice', 'Alice Uwase', 'CHW', 101, 1);
    INSERT INTO users VALUES (103, 'chw_john', 'John Mugisha', 'CHW', 102, 1);

    -- Rules
    INSERT INTO iccm_rules VALUES (1, 'BREATHING_RATE', '>', '50', 'Pneumonia', 'SEVERE');
    INSERT INTO iccm_rules VALUES (2, 'TEMP_CELSIUS', '>', '37.5', 'Malaria', 'MODERATE');
    INSERT INTO iccm_rules VALUES (3, 'DIARRHEA_DAYS', '>', '14', 'Severe Dehydration', 'SEVERE');
    INSERT INTO iccm_rules VALUES (4, 'CHEST_INDRAWING', '=', 'YES', 'Severe Pneumonia', 'SEVERE');

    -- 2. LOOP FOR PATIENTS & ENCOUNTERS
    FOR i IN 1..150 LOOP
        
        -- A. Determine Gender Randomly
        IF DBMS_RANDOM.VALUE(0, 1) < 0.5 THEN
            v_gender := 'M';
            -- Pick from Male List
            v_first_name := v_male_names(TRUNC(DBMS_RANDOM.VALUE(1, 16)));
        ELSE
            v_gender := 'F';
            -- Pick from Female List
            v_first_name := v_female_names(TRUNC(DBMS_RANDOM.VALUE(1, 16)));
        END IF;

        -- Pick a random last name (using Male list as generic surname source for simplicity)
        v_last_name := v_male_names(TRUNC(DBMS_RANDOM.VALUE(1, 16)));

        -- B. Generate Dates
        v_dob := SYSDATE - DBMS_RANDOM.VALUE(30, 1800); -- Born 1mo to 5yrs ago
        v_reg_date := v_dob + DBMS_RANDOM.VALUE(1, (SYSDATE - v_dob)); -- Registered after birth
        
        -- C. Insert Patient
        v_patient_id := seq_pat.NEXTVAL; -- Capture ID
        
        INSERT INTO patients (patient_id, full_name, dob, gender, location_id, registered_at)
        VALUES (
            v_patient_id,
            v_first_name || ' ' || v_last_name, 
            v_dob,
            v_gender,
            -- FIX: Use Random Location (100-104) instead of MOD
            TRUNC(DBMS_RANDOM.VALUE(100, 105)),
            v_reg_date
        );

        -- D. Create Encounter (Shortly after registration)
        v_encounter_id := seq_enc.NEXTVAL; -- Capture ID
        v_enc_date := v_reg_date + DBMS_RANDOM.VALUE(0, 30);
        
        INSERT INTO encounters (encounter_id, patient_id, chw_id, encounter_date, referral_status)
        VALUES (
            v_encounter_id,
            v_patient_id,
            102, 
            v_enc_date,
            'NONE'
        );

        -- E. Add Symptoms (Scenario Logic - Random Distribution)
        -- FIX: Use Random Probability instead of MOD to vary disease rates
        -- ~33% Malaria
        IF DBMS_RANDOM.VALUE(0, 1) < 0.33 THEN
            INSERT INTO observations VALUES (seq_obs.NEXTVAL, v_encounter_id, 'TEMP_CELSIUS', '39.0', 'NUMERIC');
            INSERT INTO observations VALUES (seq_obs.NEXTVAL, v_encounter_id, 'COUGH', 'NO', 'STRING');
            
            v_condition_id := seq_cond.NEXTVAL;
            INSERT INTO conditions VALUES (v_condition_id, v_encounter_id, 'Malaria', 'MODERATE', v_enc_date);
            INSERT INTO medication_requests VALUES (seq_meds.NEXTVAL, v_condition_id, 'Coartem', '1 tab 2x', 3);
        
        -- ~33% Pneumonia (If previous check failed, we check next 50% of remainder)
        ELSIF DBMS_RANDOM.VALUE(0, 1) < 0.5 THEN
            INSERT INTO observations VALUES (seq_obs.NEXTVAL, v_encounter_id, 'BREATHING_RATE', '62', 'NUMERIC');
            INSERT INTO observations VALUES (seq_obs.NEXTVAL, v_encounter_id, 'CHEST_INDRAWING', 'YES', 'STRING');
            
            v_condition_id := seq_cond.NEXTVAL;
            INSERT INTO conditions VALUES (v_condition_id, v_encounter_id, 'Severe Pneumonia', 'SEVERE', v_enc_date);
            
            -- Important: Update the header to REFERRED
            UPDATE encounters SET referral_status = 'REFERRED' WHERE encounter_id = v_encounter_id;
            
        ELSE
            -- Healthy / Other
            INSERT INTO observations VALUES (seq_obs.NEXTVAL, v_encounter_id, 'TEMP_CELSIUS', '36.5', 'NUMERIC');
            INSERT INTO observations VALUES (seq_obs.NEXTVAL, v_encounter_id, 'COUGH', 'NO', 'STRING');
        END IF;

    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Success: 150 Rows Generated. Names match Gender. Distribution is Random.');
END;
/
