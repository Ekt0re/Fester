-- ================================================
-- DISABILITA RLS PER TESTING
-- ================================================

-- Disabilita completamente RLS su notifications
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;

-- Verifica
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'notifications';
