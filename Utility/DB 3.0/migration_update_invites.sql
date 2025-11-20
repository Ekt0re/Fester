-- ==============================================================================
-- MIGRATION SCRIPT: UPDATE EVENT STAFF INVITES
-- ==============================================================================
-- Questo script applica le modifiche per gestire gli inviti staff via email
-- e l'automazione del collegamento utente.
-- ESEGUIRE NELL'EDITOR SQL DI SUPABASE.
-- ==============================================================================

-- 1. Modifica tabella event_staff
-- Rendiamo staff_user_id opzionale per permettere l'inserimento di inviti solo con email
ALTER TABLE event_staff ALTER COLUMN staff_user_id DROP NOT NULL;

-- Aggiungiamo vincolo per evitare inviti duplicati per la stessa email nello stesso evento
-- Nota: Se fallisce perché esiste già un vincolo simile, puoi ignorare questa riga o cambiare nome.
ALTER TABLE event_staff ADD CONSTRAINT event_staff_event_id_mail_unique UNIQUE (event_id, mail);

-- ==============================================================================
-- 2. Funzione per collegare invito a utente esistente (Trigger su event_staff)
-- ==============================================================================
CREATE OR REPLACE FUNCTION fn_link_invite_to_staff_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing_user_id UUID;
BEGIN
    -- Se staff_user_id è già settato, non fare nulla
    IF NEW.staff_user_id IS NOT NULL THEN
        RETURN NEW;
    END IF;

    -- Se mail è presente, cerca utente
    IF NEW.mail IS NOT NULL THEN
        SELECT id INTO v_existing_user_id
        FROM staff_user
        WHERE email = NEW.mail
        LIMIT 1;

        IF v_existing_user_id IS NOT NULL THEN
            NEW.staff_user_id := v_existing_user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- 3. Trigger su event_staff
DROP TRIGGER IF EXISTS trg_link_invite_to_staff_user ON event_staff;
CREATE TRIGGER trg_link_invite_to_staff_user
    BEFORE INSERT OR UPDATE ON event_staff
    FOR EACH ROW
    EXECUTE FUNCTION fn_link_invite_to_staff_user();

-- ==============================================================================
-- 4. Funzione per collegare utente a inviti pendenti (Trigger su staff_user)
-- ==============================================================================
CREATE OR REPLACE FUNCTION fn_link_staff_user_to_invite()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Se è un INSERT o se l'email è cambiata
    IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE' AND NEW.email IS DISTINCT FROM OLD.email) THEN
        
        -- Aggiorna gli inviti pendenti che matchano la nuova email
        UPDATE event_staff
        SET staff_user_id = NEW.id
        WHERE mail = NEW.email
          AND staff_user_id IS NULL;
          
    END IF;
    RETURN NEW;
END;
$$;

-- 5. Trigger su staff_user
DROP TRIGGER IF EXISTS trg_link_staff_user_to_invite ON staff_user;
CREATE TRIGGER trg_link_staff_user_to_invite
    AFTER INSERT OR UPDATE ON staff_user
    FOR EACH ROW
    EXECUTE FUNCTION fn_link_staff_user_to_invite();

-- ==============================================================================
-- FINE SCRIPT
-- ==============================================================================
