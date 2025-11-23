-- ============================================
-- STORAGE RLS POLICIES FOR STAFFPROFILES BUCKET
-- ============================================
-- Eseguire questo file in Supabase Dashboard → SQL Editor
-- oppure tramite API

-- Policy per SELECT: tutti gli utenti autenticati possono vedere le immagini
CREATE POLICY "Authenticated users can view StaffProfiles"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'StaffProfiles');

-- Policy per INSERT: utenti possono caricare solo nella propria cartella {user_id}/
CREATE POLICY "Users can upload to own StaffProfiles folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'StaffProfiles' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy per UPDATE: utenti possono modificare solo i propri file
CREATE POLICY "Users can update own StaffProfiles"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'StaffProfiles' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy per DELETE: utenti possono eliminare solo i propri file
CREATE POLICY "Users can delete own StaffProfiles"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'StaffProfiles' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Verifica policies create
SELECT * FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname LIKE '%StaffProfiles%';
