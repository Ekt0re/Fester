-- ================================================
-- VERIFICA E FIX RLS NOTIFICATIONS
-- ================================================

-- STEP 1: Verifica se RLS è abilitata
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'notifications';

-- STEP 2: Verifica policies esistenti  
SELECT * FROM pg_policies WHERE tablename = 'notifications';

-- STEP 3: DROP policies esistenti e ricrea con logica corretta
DROP POLICY IF EXISTS "Staff can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Staff can create own notifications" ON notifications;
DROP POLICY IF EXISTS "Staff can update own notifications" ON notifications;
DROP POLICY IF EXISTS "Staff can delete own notifications" ON notifications;

-- STEP 4: Ricrea policies con logica corretta
-- La policy deve permettere l'accesso se staff_user_id corrisponde all'utente autenticato

CREATE POLICY "Staff can view own notifications"
  ON notifications FOR SELECT
  USING (
    staff_user_id = auth.uid() 
    OR 
    staff_user_id IS NULL
  );

CREATE POLICY "Staff can create notifications"
  ON notifications FOR INSERT
  WITH CHECK (true);  -- Permetti insert a tutti per ora

CREATE POLICY "Staff can update own notifications"
  ON notifications FOR UPDATE
  USING (staff_user_id = auth.uid() OR staff_user_id IS NULL);

CREATE POLICY "Staff can delete own notifications"
  ON notifications FOR DELETE
  USING (staff_user_id = auth.uid() OR staff_user_id IS NULL);

-- STEP 5: Assicurati che RLS sia abilitata
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
