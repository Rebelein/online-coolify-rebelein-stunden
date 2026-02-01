-- ==========================================
-- 1. HELPER: Bavarian Holidays - REMOVED PER USER REQUEST
-- Feiertage werden manuell als TimeEntry 'holiday' eingetragen.
-- ==========================================

-- ==========================================
-- 2. HELPER: Daily Target
-- ==========================================
CREATE OR REPLACE FUNCTION get_daily_target(p_user_id UUID, p_date DATE)
RETURNS NUMERIC AS $$
DECLARE
    target NUMERIC := 0;
    dow TEXT;
    settings JSONB;
    month INT;
    day INT;
BEGIN
    -- Dow: 0 (Sun) - 6 (Sat). Note: Types.ts uses 0=Sun. 
    -- PostgreSQL EXTRACT(DOW) returns 0-6 (0=Sun). Matches.
    dow := EXTRACT(DOW FROM p_date)::TEXT;
    
    SELECT target_hours INTO settings
    FROM user_settings
    WHERE user_id = p_user_id;

    IF settings IS NULL THEN
        RETURN 0;
    END IF;

    target := (settings->>dow)::NUMERIC;
    
    IF target IS NULL THEN 
        target := 0; 
    END IF;

    -- Special Logic for 24.12. and 31.12. (Half Day)
    month := EXTRACT(MONTH FROM p_date)::INT;
    day := EXTRACT(DAY FROM p_date)::INT;

    IF month = 12 AND (day = 24 OR day = 31) THEN
        -- Only if it is a weekday (Mo-Fr: 1-5)
        IF dow::INT >= 1 AND dow::INT <= 5 THEN
            target := target / 2;
        END IF;
    END IF;

    RETURN target;
END;
$$ LANGUAGE plpgsql STABLE;

-- ==========================================
-- 3. AGGREGATION: Lifetime Stats
-- ==========================================
-- Returns: target, actual, diff, start_date, cutoff_date
CREATE OR REPLACE FUNCTION get_lifetime_stats(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_start_date DATE;
    v_employment_start DATE;
    v_first_entry DATE;
    v_cutoff_date DATE;
    v_today DATE := CURRENT_DATE;
    
    v_total_target NUMERIC := 0;
    v_total_actual NUMERIC := 0;
    v_initial_balance NUMERIC := 0;
    v_future_reductions NUMERIC := 0;
    
    -- Loop vars
    v_curr DATE;
    v_daily_target NUMERIC;
    v_is_unpaid BOOLEAN;
    v_is_paid_absence BOOLEAN;
    v_absence_type TEXT;
    v_work_mins INT;
    v_surcharge_hrs NUMERIC;
BEGIN
    -- 1. Determine Start Date
    SELECT employment_start_date::DATE, initial_overtime_balance 
    INTO v_employment_start, v_initial_balance
    FROM user_settings 
    WHERE user_id = p_user_id;
    
    SELECT min(date) INTO v_first_entry 
    FROM time_entries 
    WHERE user_id = p_user_id AND (is_deleted IS NULL OR is_deleted = FALSE);
    
    v_start_date := COALESCE(v_employment_start, v_first_entry, v_today);
    
    IF v_start_date > v_today THEN
        RETURN jsonb_build_object('target', 0, 'actual', 0, 'diff', 0);
    END IF;

    -- 2. Determine Cutoff (Last SUBMITTED entry)
    SELECT max(date) INTO v_cutoff_date
    FROM time_entries
    WHERE user_id = p_user_id 
      AND submitted = TRUE 
      AND date <= v_today
      AND (is_deleted IS NULL OR is_deleted = FALSE);
      
    IF v_cutoff_date IS NULL OR v_cutoff_date < v_start_date THEN
        -- Fallback if no submitted entries: Calculate until yesterday? OR return 0?
        -- Frontend returns 0 if no submitted entry found.
        v_cutoff_date := v_start_date; 
        -- Or return early? Frontend: "return { target: 0... }"
        IF v_cutoff_date IS NULL THEN
             RETURN jsonb_build_object('target', 0, 'actual', 0, 'diff', 0);
        END IF;
    END IF;

    -- 3. Calculate Target & Actuals (Iterate Days)
    -- Iteration is safer to match frontend logic exactly (Holiday/Absence checks per day)
    
    v_curr := v_start_date;
    WHILE v_curr <= v_cutoff_date LOOP
        v_daily_target := get_daily_target(p_user_id, v_curr);
        v_is_unpaid := FALSE;
        v_is_paid_absence := FALSE;
        
        -- Check Absences (Priority: Absence Table > Entry Type)
        -- a) UserAbsence Table
        SELECT type INTO v_absence_type
        FROM user_absences
        WHERE user_id = p_user_id 
          AND v_curr >= start_date 
          AND v_curr <= end_date
          AND (is_deleted IS NULL OR is_deleted = FALSE)
        LIMIT 1;
        
        IF v_absence_type IS NOT NULL THEN
            IF v_absence_type IN ('unpaid', 'sick_child', 'sick_pay') THEN
                v_is_unpaid := TRUE;
            ELSE
                v_is_paid_absence := TRUE;
            END IF;
        ELSE
            -- b) TimeEntry Table (Check for absence-like entries acting as absence)
            SELECT type INTO v_absence_type
            FROM time_entries
            WHERE user_id = p_user_id 
              AND date = v_curr 
              AND type IN ('vacation', 'sick', 'holiday', 'unpaid', 'sick_child', 'sick_pay')
              AND (is_deleted IS NULL OR is_deleted = FALSE)
            LIMIT 1;
            
            IF v_absence_type IS NOT NULL THEN
                 IF v_absence_type IN ('unpaid', 'sick_child', 'sick_pay') THEN
                    v_is_unpaid := TRUE;
                ELSE
                    v_is_paid_absence := TRUE;
                END IF;
            END IF;
        END IF;

        -- Sum Targets
        IF NOT v_is_unpaid THEN
            v_total_target := v_total_target + v_daily_target;
            IF v_is_paid_absence THEN
                -- Credits Logic: Paid absence counts as "Work done matching target"
                v_total_actual := v_total_actual + v_daily_target;
            END IF;
        END IF;
        
        v_curr := v_curr + 1;
    END LOOP;

    -- 4. Add Real Work (Actuals)
    -- Sum specific entries in range
    SELECT 
        COALESCE(SUM(calc_duration_minutes), 0) / 60.0,
        COALESCE(SUM(calc_surcharge_hours), 0)
    INTO v_work_mins, v_surcharge_hrs
    FROM time_entries
    WHERE user_id = p_user_id
        AND date >= v_start_date 
        AND date <= v_cutoff_date
        AND type NOT IN ('break', 'vacation', 'sick', 'holiday', 'unpaid', 'overtime_reduction', 'sick_child', 'sick_pay')
        -- Note: special_holiday is NOT in this exclude list in Frontend?
        -- Frontend: !['break', 'vacation', 'sick', 'holiday', 'unpaid', 'overtime_reduction'].includes...
        -- Wait, 'special_holiday' entries are usually added by the system with hours?
        -- Let's stick to Frontend exclude list:
        -- e.type !== 'break' && !['vacation'...]
        AND (is_deleted IS NULL OR is_deleted = FALSE);
        
    v_total_actual := v_total_actual + v_work_mins + v_surcharge_hrs;

    -- 5. Future Reductions (Overtime Reduction AFTER cutoff)
    SELECT COALESCE(SUM(hours), 0) INTO v_future_reductions
    FROM time_entries
    WHERE user_id = p_user_id
      AND type = 'overtime_reduction'
      AND confirmed_at IS NOT NULL
      AND date > v_cutoff_date
      AND (is_deleted IS NULL OR is_deleted = FALSE);

    -- Result
    RETURN jsonb_build_object(
        'target', v_total_target, 
        'actual', v_total_actual, 
        'diff', (v_total_actual - v_total_target - v_future_reductions + COALESCE(v_initial_balance, 0)),
        'start_date', v_start_date,
        'cutoff_date', v_cutoff_date
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- ==========================================
-- 4. AGGREGATION: Month Stats
-- ==========================================
CREATE OR REPLACE FUNCTION get_monthly_stats(p_user_id UUID, p_year INT, p_month INT)
RETURNS JSONB AS $$
DECLARE
    v_start_date DATE;
    v_end_date DATE;
    v_target NUMERIC := 0;
    v_actual NUMERIC := 0;
    v_credits NUMERIC := 0;
    v_project_hours NUMERIC := 0;
    
    v_curr DATE;
    v_daily_target NUMERIC;
    v_absence_type TEXT;
    
    v_work_mins INT;
    v_surcharge_hrs NUMERIC;
BEGIN
    v_start_date := MAKE_DATE(p_year, p_month + 1, 1); -- JS month is 0-indexed, but SQL input usually 1-12? 
    -- User passed JS month (0-11)? Let's assume input matches whatever we call.
    -- Better: Assume Input is 1-12 (SQL Standard). Frontend should adapt.
    -- Correction: Implementation in Frontend sends `year` and `month` (0-11).
    -- Let's make the function accept 0-11 to be consistent with JS structure is weird for SQL.
    -- Let's accept 1-12. Frontend `month + 1`.

    -- Logic: start_date = 1st of month. end_date = last of month.
    v_start_date := MAKE_DATE(p_year, p_month, 1); 
    v_end_date := (v_start_date + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    -- Calculate Target & Credits (Iterate)
    v_curr := v_start_date;
    WHILE v_curr <= v_end_date LOOP
        v_daily_target := get_daily_target(p_user_id, v_curr);
        
        -- Check Absences (simplified check for credit)
        -- In Month View, we want Target for ALL days usually, unless unpaid?
        -- Frontend `calculateTargetHours`: skip unpaid.
        
        -- Check Unpaid
        v_absence_type := NULL;
        
        -- Table check
        SELECT type INTO v_absence_type FROM user_absences
        WHERE user_id = p_user_id AND v_curr BETWEEN start_date AND end_date AND is_deleted IS NOT TRUE LIMIT 1;
        
        IF v_absence_type IS NULL THEN
             SELECT type INTO v_absence_type FROM time_entries 
             WHERE user_id = p_user_id AND date = v_curr AND is_deleted IS NOT TRUE
             AND type IN ('vacation', 'sick', 'holiday', 'unpaid', 'sick_child', 'sick_pay', 'special_holiday') LIMIT 1;
        END IF;

        IF v_absence_type IN ('unpaid', 'sick_child', 'sick_pay') THEN
             -- No Target, No Credit
        ELSE
             v_target := v_target + v_daily_target;
             IF v_absence_type IN ('vacation', 'sick', 'holiday', 'special_holiday') THEN
                 v_credits := v_credits + v_daily_target;
             END IF;
        END IF;
        
        v_curr := v_curr + 1;
    END LOOP;

    -- Real Work
    SELECT 
        COALESCE(SUM(calc_duration_minutes), 0) / 60.0,
        COALESCE(SUM(calc_surcharge_hours), 0)
    INTO v_work_mins, v_surcharge_hrs
    FROM time_entries
    WHERE user_id = p_user_id
        AND date >= v_start_date 
        AND date <= v_end_date
        -- Matches Frontend "projectHours" filter
        AND type NOT IN ('break', 'vacation', 'sick', 'holiday', 'special_holiday', 'sick_child', 'sick_pay', 'unpaid')
        AND (is_deleted IS NULL OR is_deleted = FALSE);

    v_project_hours := v_work_mins + v_surcharge_hrs;
    v_actual := v_project_hours + v_credits;

    RETURN jsonb_build_object(
        'target', v_target,
        'actual', v_actual,
        'project_hours', v_project_hours,
        'credits', v_credits,
        'diff', v_actual - v_target
    );
END;
$$ LANGUAGE plpgsql STABLE;
