-- Verification Script: Vacation Logic (Calculation & Deletion)
-- Run this script in the Supabase SQL Editor.

BEGIN;

DO $$
DECLARE
    test_user_id UUID;
    entry_id UUID;
    target_hrs_friday NUMERIC;
    calc_mins INTEGER;
    view_vac_hours NUMERIC;
BEGIN
    -- 1. Setup: Get User (Test-Installer or fallback)
    SELECT user_id INTO test_user_id FROM user_settings WHERE display_name = 'Test-Installer';
    IF test_user_id IS NULL THEN
        SELECT user_id INTO test_user_id FROM user_settings LIMIT 1;
    END IF;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE 'Skipping Tests: No user found.';
        RETURN;
    END IF;

    RAISE NOTICE 'Testing Vacation Logic with User ID: %', test_user_id;

    -- 2. Check Target Hours for Friday (Day 5)
    -- Ensure we have a known target for Friday (e.g. 4.5h or 8h depending on user)
    -- We'll read it from settings to assert correctness relative to settings.
    SELECT (target_hours->>'5')::NUMERIC INTO target_hrs_friday FROM user_settings WHERE user_id = test_user_id;
    RAISE NOTICE 'Target Hours for Friday: %', target_hrs_friday;

    -- 3. Create Vacation Entry on a Friday
    INSERT INTO time_entries (id, user_id, date, type, hours)
    VALUES (gen_random_uuid(), test_user_id, '2099-01-02', 'vacation', 0) -- 2099-01-02 is a Friday
    RETURNING id INTO entry_id;

    -- 4. Verify Calculation (Trigger should use Target Hours)
    SELECT calc_duration_minutes INTO calc_mins FROM time_entries WHERE id = entry_id;
    
    IF calc_mins != (target_hrs_friday * 60)::INTEGER THEN
        RAISE EXCEPTION 'Vacation Calc Failed: Expected % mins (Target Hours), got % mins', (target_hrs_friday * 60), calc_mins;
    END IF;
    RAISE NOTICE '✅ Vacation Calculation correct (Matches Target Hours)';

    -- 5. Verify "Confirmed" status (should not affect calculation, but strictly ensuring persistence)
    UPDATE time_entries SET submitted = TRUE, confirmed_at = now() WHERE id = entry_id;
    
    SELECT calc_duration_minutes INTO calc_mins FROM time_entries WHERE id = entry_id;
    IF calc_mins != (target_hrs_friday * 60)::INTEGER THEN
        RAISE EXCEPTION 'Calc changed after confirm! Expected %, got %', (target_hrs_friday * 60), calc_mins;
    END IF;
    RAISE NOTICE '✅ Calculation stable after confirmation';

    -- 6. Verify View Inclusion
    SELECT vacation_hours INTO view_vac_hours 
    FROM view_daily_summary 
    WHERE user_id = test_user_id AND date = '2099-01-02';
    
    -- Allow small float diffs
    IF ABS(view_vac_hours - target_hrs_friday) > 0.01 THEN
         RAISE EXCEPTION 'View Failed: Expected % vacation hours, got %', target_hrs_friday, view_vac_hours;
    END IF;
    RAISE NOTICE '✅ Entry correctly included in View';

    -- 7. Verify Deletion Logic
    -- Soft delete the entry
    UPDATE time_entries SET is_deleted = TRUE WHERE id = entry_id;

    -- Check View again - should be 0 or NULL (row might exist if other entries exist, or no row)
    SELECT vacation_hours INTO view_vac_hours 
    FROM view_daily_summary 
    WHERE user_id = test_user_id AND date = '2099-01-02';

    IF view_vac_hours IS NOT NULL AND view_vac_hours > 0 THEN
        RAISE EXCEPTION 'Deletion Failed: Entry still visible in View with % hours', view_vac_hours;
    END IF;
    RAISE NOTICE '✅ Entry correctly removed from View after soft delete';

    RAISE NOTICE 'ALL VACATION TESTS PASSED SUCCESSFULLY';
END $$;

ROLLBACK; -- Clean up
