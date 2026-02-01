-- Fix: Remove the erroneous p_month + 1 calculation which caused 2026-13-01 error for December.

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
    -- Input p_month is expected to be 1-12.
    -- v_start_date := MAKE_DATE(p_year, p_month + 1, 1); -- REMOVED BUGGY LINE

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
