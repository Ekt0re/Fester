-- ============================================
-- FIX: RLS UNRESTRICTED TABLES
-- ============================================
-- Questo script mette in sicurezza le tabelle che erano "Unrestricted" e le viste.

-- 1. TABELLE DI LOOKUP (Sola lettura per authenticated)
-- ====================================================

ALTER TABLE IF EXISTS role ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS participation_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS transaction_type ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT per tutti gli utenti autenticati
CREATE POLICY role_select_auth ON role FOR SELECT TO authenticated USING (true);
CREATE POLICY participation_status_select_auth ON participation_status FOR SELECT TO authenticated USING (true);
CREATE POLICY transaction_type_select_auth ON transaction_type FOR SELECT TO authenticated USING (true);

-- 2. MENU_ITEM (Contesto Evento)
-- ==============================
ALTER TABLE IF EXISTS menu_item ENABLE ROW LEVEL SECURITY;

-- SELECT: Staff Level >= 1 (tramite menu -> event)
CREATE POLICY menu_item_select_staff ON menu_item
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM menu m
        JOIN event_staff es ON es.event_id = m.event_id
        WHERE m.id = menu_item.menu_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 1
    )
);

-- INSERT/UPDATE/DELETE: Staff Level >= 2
CREATE POLICY menu_item_modify_staff ON menu_item
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM menu m
        JOIN event_staff es ON es.event_id = m.event_id
        WHERE m.id = menu_item.menu_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 2
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM menu m
        JOIN event_staff es ON es.event_id = m.event_id
        WHERE m.id = menu_item.menu_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 2
    )
);

-- 3. PARTICIPATION_STATUS_HISTORY (Contesto Evento)
-- =================================================
ALTER TABLE IF EXISTS participation_status_history ENABLE ROW LEVEL SECURITY;

-- SELECT: Staff Level >= 1 (tramite participation -> event)
CREATE POLICY part_history_select_staff ON participation_status_history
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.id = participation_status_history.participation_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 1
    )
);

-- INSERT/UPDATE/DELETE: Staff Level >= 2
CREATE POLICY part_history_modify_staff ON participation_status_history
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.id = participation_status_history.participation_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 2
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.id = participation_status_history.participation_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 2
    )
);

-- 4. EVENT_SETTINGS (Contesto Evento)
-- ===================================
ALTER TABLE IF EXISTS event_settings ENABLE ROW LEVEL SECURITY;

-- SELECT: Staff Level >= 1
CREATE POLICY event_settings_select_staff ON event_settings
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = event_settings.event_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 1
    )
);

-- UPDATE: Staff Level >= 3 (Coerente con event update)
CREATE POLICY event_settings_update_staff ON event_settings
FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = event_settings.event_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 3
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = event_settings.event_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 3
    )
);

-- 5. VISTE (Security Invoker)
-- ===========================
-- Imposta security_invoker = true per forzare il controllo RLS sulle tabelle sottostanti
-- quando la vista viene interrogata.

ALTER VIEW participation_stats SET (security_invoker = true);
ALTER VIEW person_with_age SET (security_invoker = true);
