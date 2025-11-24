-- ================================================
-- FIX TEMPORANEO: Policy permissive per testing
-- ================================================

-- Elimina tutte le policy esistenti
DROP POLICY IF EXISTS "Staff can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Staff can create own notifications" ON notifications;
DROP POLICY IF EXISTS "Staff can update own notifications" ON notifications;
DROP POLICY IF EXISTS "Staff can delete own notifications" ON notifications;

-- Crea una policy permissiva per tutti gli utenti autenticati (temporaneo)
CREATE POLICY "Allow authenticated users all access"
  ON notifications FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- Assicurati che RLS sia abilitata
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
