-- Verification Script: Server-Side Calculation Logic
-- Run this script in the Supabase SQL Editor AFTER applying the migration.
-- If successful, it will print "ALL TESTS PASSED SUCCESSFULLY".

BEGIN;

DO $$
DECLARE
    test_user_id UUID;
    entry_id_1 UUID;
    entry_id_2 UUID;
    entry_id_3 UUID;
    mins INTEGER;
    bonus NUMERIC;
    net_work INTEGER;
    surcharge NUMERIC;
BEGIN
    -- 1. Get an existing User ID (Prioritize 'Test-Installer')
    SELECT user_id INTO test_user_id FROM user_settings WHERE display_name = 'Test-Installer';
    
    -- Fallback if Test-Installer not found
    IF test_user_id IS NULL THEN
        SELECT user_id INTO test_user_id FROM user_settings LIMIT 1;
    END IF;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE 'Skipping Tests: No user found in user_settings table.';
        RETURN;
    END IF;

    RAISE NOTICE 'Testing with User ID: %', test_user_id;

    -- 2. Test Case 1: Standard Work Entry (08:00 - 12:00 = 4 hours = 240 mins)
    INSERT INTO time_entries (id, user_id, date, start_time, end_time, type, client_name, hours)
    VALUES (gen_random_uuid(), test_user_id, '2099-01-01', '08:00', '12:00', 'work', 'Test Client', 0)
    RETURNING id INTO entry_id_1;

    SELECT calc_duration_minutes INTO mins FROM time_entries WHERE id = entry_id_1;
    IF mins != 240 THEN
        RAISE EXCEPTION 'Test Case 1 Failed: Expected 240 mins, got %', mins;
    END IF;

    -- 3. Test Case 2: Break Entry (10:00 - 10:30 = 30 mins)
    INSERT INTO time_entries (id, user_id, date, start_time, end_time, type, client_name, hours)
    VALUES (gen_random_uuid(), test_user_id, '2099-01-01', '10:00', '10:30', 'break', 'Test Break', 0)
    RETURNING id INTO entry_id_2;

    SELECT calc_duration_minutes INTO mins FROM time_entries WHERE id = entry_id_2;
    IF mins != 30 THEN
        RAISE EXCEPTION 'Test Case 2 Failed: Expected 30 mins, got %', mins;
    END IF;

    -- 4. Test Case 3: Surcharge Calculation (18:00 - 20:00 = 2 hours, 50% Surcharge = 1 hour bonus)
    INSERT INTO time_entries (id, user_id, date, start_time, end_time, type, client_name, surcharge, hours)
    VALUES (gen_random_uuid(), test_user_id, '2099-01-01', '18:00', '20:00', 'emergency_service', 'Emergency', 50, 0)
    RETURNING id INTO entry_id_3;

    SELECT calc_surcharge_hours INTO bonus FROM time_entries WHERE id = entry_id_3;
    IF bonus != 1.00 THEN
        RAISE EXCEPTION 'Test Case 3 Failed: Expected 1.00 bonus hour, got %', bonus;
    END IF;

    -- 5. Test Case 4: View Aggregation
    -- Work: 240 mins + 120 mins (emergency) = 360 mins
    -- Break: 30 mins
    -- Net Work: 330 mins
    -- Surcharge Hours: 1.0
    SELECT total_work_minutes, total_surcharge_hours
    INTO net_work, surcharge
    FROM view_daily_summary
    WHERE user_id = test_user_id AND date = '2099-01-01';

    IF net_work != 330 THEN
        RAISE EXCEPTION 'Test Case 4 (View) Failed: Expected 330 net work minutes, got %', net_work;
    END IF;
    
    IF surcharge != 1.00 THEN
        RAISE EXCEPTION 'Test Case 4 (View) Failed: Expected 1.00 surcharge hours, got %', surcharge;
    END IF;

    RAISE NOTICE 'ALL TESTS PASSED SUCCESSFULLY';
END $$;

ROLLBACK; -- Always rollback in a test script to avoid polluting DB
