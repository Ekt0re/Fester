-- ============================================
-- FIX: RLS STAFF USER
-- ============================================
-- Esegui questo script per abilitare RLS su staff_user e permettere l'accesso.

-- 1. Abilita RLS
ALTER TABLE IF EXISTS staff_user ENABLE ROW LEVEL SECURITY;

-- 2. Rimuovi policy esistenti se presenti (per evitare errori di duplicazione)
DROP POLICY IF EXISTS staff_user_select_own ON staff_user;
DROP POLICY IF EXISTS staff_user_update_own ON staff_user;

-- 3. Crea Policy SELECT
CREATE POLICY staff_user_select_own ON staff_user
FOR SELECT
TO authenticated
USING (
    id = auth.uid()
);

-- 4. Crea Policy UPDATE
CREATE POLICY staff_user_update_own ON staff_user
FOR UPDATE
TO authenticated
USING (
    id = auth.uid()
)
WITH CHECK (
    id = auth.uid()
);

-- 5. GRANT Permissions (Cruciale per evitare errore 42501)
GRANT SELECT, UPDATE ON TABLE staff_user TO authenticated;
GRANT ALL ON TABLE staff_user TO service_role;

-- 6. Verifica (Opzionale)
-- SELECT * FROM staff_user WHERE id = auth.uid();
