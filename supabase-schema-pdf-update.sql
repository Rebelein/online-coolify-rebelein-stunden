-- 1. Tabelle 'user_settings' erweitern (nicht profiles!)
-- Fügt die Spalte nur hinzu, wenn sie noch nicht existiert
ALTER TABLE public.user_settings 
ADD COLUMN IF NOT EXISTS invoice_keyword text DEFAULT 'Arbeitszeit';

-- 2. Storage Bucket 'reports' erstellen
-- Versucht den Bucket zu erstellen, tut nichts wenn er schon existiert
INSERT INTO storage.buckets (id, name, public) 
VALUES ('reports', 'reports', false)
ON CONFLICT (id) DO NOTHING;

-- 3. RLS Policies für den Storage Bucket (Sicherheit)
-- Löscht alte Policies zuerst, um "Policy already exists" Fehler zu vermeiden

DROP POLICY IF EXISTS "Users can upload own reports" ON storage.objects;
CREATE POLICY "Users can upload own reports"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'reports' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can read own reports" ON storage.objects;
CREATE POLICY "Users can read own reports"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'reports' AND
  (storage.foldername(name))[1] = auth.uid()::text
);
