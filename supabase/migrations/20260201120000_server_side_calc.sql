-- Migration: Server-Side Calculation
-- Created: 2026-02-01

-- 1. Tabellen-Erweiterung (Calculated Columns)
ALTER TABLE time_entries
ADD COLUMN IF NOT EXISTS calc_duration_minutes INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS calc_surcharge_hours NUMERIC(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS calc_is_late_entry BOOLEAN DEFAULT FALSE;

-- 2. Berechnungs-Funktion
CREATE OR REPLACE FUNCTION calculate_time_metrics()
RETURNS TRIGGER AS $$
DECLARE
    minutes_worked INTEGER := 0;
    target_hrs NUMERIC;
    dow TEXT; -- Key in JSON is usually text
    diff_mins INTEGER;
    s_time TIME;
    e_time TIME;
BEGIN
    -- Dow ermitteln (0=Sunday, 1=Monday ... 6=Saturday)
    -- Types.ts: keys are "0", "1", ...
    dow := EXTRACT(DOW FROM NEW.date)::TEXT;

    -- A) Arbeitszeit Berechnung (Netto)
    IF NEW.type IN ('work', 'break', 'company', 'office', 'warehouse', 'car', 'emergency_service') THEN
        IF NEW.start_time IS NOT NULL AND NEW.end_time IS NOT NULL THEN
            BEGIN
                s_time := NEW.start_time::TIME;
                e_time := NEW.end_time::TIME;
                
                -- Differenz in Minuten
                diff_mins := (EXTRACT(EPOCH FROM (e_time - s_time)) / 60)::INTEGER;
                
                -- Mitternachts-Übergang
                IF diff_mins < 0 THEN
                   diff_mins := diff_mins + (24 * 60);
                END IF;
                
                minutes_worked := diff_mins;
            EXCEPTION WHEN OTHERS THEN
                minutes_worked := 0; -- Fallback bei Parse-Error
            END;
        ELSE
            minutes_worked := 0;
        END IF;

    -- B) Abwesenheit Berechnung (Sollstunden aus Settings)
    ELSIF NEW.type IN ('vacation', 'sick', 'holiday', 'child_sick', 'sick_pay', 'special_holiday') THEN
        -- Hole Sollstunden für diesen Wochentag aus user_settings
        -- Annahme: user_settings.user_id ist FK zu time_entries.user_id (oder auth.uid())
        -- Wir nutzen NEW.user_id
        SELECT (target_hours->>dow)::NUMERIC * 60 INTO target_hrs
        FROM user_settings
        WHERE user_id = NEW.user_id;

        IF target_hrs IS NOT NULL THEN
            minutes_worked := target_hrs::INTEGER;
        ELSE
            minutes_worked := 0;
        END IF;
    
    -- C) Sonstiges
    ELSE
        minutes_worked := 0;
    END IF;

    -- Setze berechnete Dauer
    NEW.calc_duration_minutes := minutes_worked;

    -- C) Zuschlags-Berechnung
    -- Basierend auf 'surcharge' Spalte (Prozent, z.B. 50 oder 100)
    -- calc_surcharge_hours = (minutes / 60) * (percent / 100)
    IF NEW.surcharge IS NOT NULL AND NEW.surcharge > 0 THEN
       NEW.calc_surcharge_hours := (minutes_worked::NUMERIC / 60.0) * (NEW.surcharge::NUMERIC / 100.0);
    ELSE
       NEW.calc_surcharge_hours := 0;
    END IF;

    -- D) Late Entry Logic (Server-Side Check)
    -- Optional: Implementiere Grace Period Check hier oder lasse es vorerst beim Client/Status.
    -- Wir lassen es vorerst, da 'isLateEntry' komplexer ist (Feiertage etc in PLPGSQL).
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Trigger Installation
DROP TRIGGER IF EXISTS trigger_calculate_time_metrics ON time_entries;

CREATE TRIGGER trigger_calculate_time_metrics
BEFORE INSERT OR UPDATE ON time_entries
FOR EACH ROW
EXECUTE FUNCTION calculate_time_metrics();

-- 4. View Erstellung (Daily Summary)
CREATE OR REPLACE VIEW view_daily_summary AS
SELECT
    user_id,
    date,
    -- Grundzeit (Work - Break)
    -- Achtung: Wir summieren hier alle positiven Typen und ziehen Pausen ab.
    -- Typen wie 'company', 'office' zählen auch als Arbeitszeit.
    (
        SUM(CASE WHEN type IN ('work', 'company', 'office', 'warehouse', 'car', 'emergency_service') THEN calc_duration_minutes ELSE 0 END)
        -
        SUM(CASE WHEN type = 'break' THEN calc_duration_minutes ELSE 0 END)
    ) as total_work_minutes,
    
    -- Abwesenheiten (Stunden)
    SUM(CASE WHEN type = 'vacation' THEN calc_duration_minutes ELSE 0 END) / 60.0 as vacation_hours,
    SUM(CASE WHEN type IN ('sick', 'sick_pay', 'child_sick') THEN calc_duration_minutes ELSE 0 END) / 60.0 as sick_hours,
    SUM(CASE WHEN type = 'holiday' THEN calc_duration_minutes ELSE 0 END) / 60.0 as holiday_hours,
    
    -- Zuschläge
    SUM(calc_surcharge_hours) as total_surcharge_hours,

    -- Effektive Gesamtzeit (Arbeit + Zuschlag)
    (
        (
            SUM(CASE WHEN type IN ('work', 'company', 'office', 'warehouse', 'car', 'emergency_service') THEN calc_duration_minutes ELSE 0 END)
            -
            SUM(CASE WHEN type = 'break' THEN calc_duration_minutes ELSE 0 END)
        ) 
        + 
        (SUM(calc_surcharge_hours) * 60)::INTEGER
    ) as total_effective_minutes
    
FROM time_entries
WHERE (is_deleted IS NULL OR is_deleted = FALSE)
GROUP BY user_id, date;

-- 5. Migration (Initiale Berechnung für alle existierenden Einträge)
UPDATE time_entries SET type = type; -- Dummy Update feuert Trigger
