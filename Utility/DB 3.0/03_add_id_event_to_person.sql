-- Aggiunta colonna id_event alla tabella person
-- Richiesto per mostrare un ID specifico per l'evento
ALTER TABLE person ADD COLUMN id_event VARCHAR(255);

COMMENT ON COLUMN person.id_event IS 'ID visualizzabile della persona per l''evento (Codice)';
