-- ============================================
-- FIX: GLOBAL PERMISSIONS (GRANT)
-- ============================================
-- Esegui questo script per assegnare i permessi CRUD al ruolo "authenticated".
-- Le RLS (Row Level Security) si occuperanno poi di filtrare cosa l'utente può effettivamente vedere/modificare.

-- 1. Tabelle di Lookup (Sola lettura per authenticated consigliata, ma RLS può restringere)
GRANT SELECT ON TABLE role TO authenticated;
GRANT SELECT ON TABLE participation_status TO authenticated;
GRANT SELECT ON TABLE transaction_type TO authenticated;

-- 2. Tabelle Core
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE staff_user TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE event TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE event_staff TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE person TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE event_settings TO authenticated;

-- 3. Tabelle Menu & Transazioni
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE menu TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE menu_item TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE participation TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE participation_status_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE transaction TO authenticated;

-- 4. Viste
GRANT SELECT ON TABLE participation_stats TO authenticated;
GRANT SELECT ON TABLE person_with_age TO authenticated;

-- 5. Service Role (Accesso completo)
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- 6. Sequenze (Necessario per INSERT)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
