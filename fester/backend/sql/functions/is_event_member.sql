-- Drop vecchia versione della funzione se esiste
DROP FUNCTION IF EXISTS public.is_event_member(uuid, uuid);
DROP FUNCTION IF EXISTS public.is_event_member(uuid);

-- Funzione che verifica se un utente è membro di un evento
CREATE OR REPLACE FUNCTION public.is_event_member(_event_id uuid) 
RETURNS boolean AS $$
DECLARE
    _user_id uuid;
BEGIN
    -- Get current user id
    _user_id := auth.uid();
    
    -- Check if user is null
    IF _user_id IS NULL THEN
        RETURN false;
    END IF;

    RETURN EXISTS (
        SELECT 1 
        FROM public.events e
        WHERE e.id = _event_id
        AND (
            e.creato_da = _user_id  -- L'utente è il creatore
            OR EXISTS (
                SELECT 1 
                FROM public.event_participants ep
                WHERE ep.event_id = _event_id
                AND ep.user_id = _user_id
            )
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Concedi i permessi di esecuzione agli utenti autenticati
GRANT EXECUTE ON FUNCTION public.is_event_member(uuid) TO authenticated; 