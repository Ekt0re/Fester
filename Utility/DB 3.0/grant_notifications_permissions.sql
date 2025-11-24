-- ================================================
-- GRANT PERMESSI BASE SU NOTIFICATIONS
-- ================================================

-- Dai permessi completi agli utenti autenticati
GRANT ALL ON TABLE notifications TO authenticated;
GRANT ALL ON TABLE notifications TO anon;

-- Permetti anche l'uso della sequence per l'ID (se usi serial/autoincrement)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;

-- Verifica i permessi
SELECT grantee, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_name='notifications';
