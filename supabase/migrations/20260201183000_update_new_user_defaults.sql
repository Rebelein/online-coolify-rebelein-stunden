-- Migration: Update user creation trigger with new default hours (7.7h Mo-Fri)

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.user_settings (user_id, display_name, role, target_hours, work_config)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'display_name', 'Benutzer'),
    'installer',
    '{
      "1": 7.7,
      "2": 7.7,
      "3": 7.7,
      "4": 7.7,
      "5": 7.7,
      "6": 0,
      "0": 0
    }'::jsonb,
    '{
      "1": "07:00",
      "2": "07:00",
      "3": "07:00",
      "4": "07:00",
      "5": "07:00",
      "6": "07:00",
      "0": "07:00"
    }'::jsonb
  );
  RETURN new;
END;
$function$;
