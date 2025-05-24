-- Assicurati che lo schema public esista
CREATE SCHEMA IF NOT EXISTS public;

-- Drop tutte le policy esistenti
DROP POLICY IF EXISTS event_select_policy ON public.events;
DROP POLICY IF EXISTS event_insert_policy ON public.events;
DROP POLICY IF EXISTS event_update_policy ON public.events;
DROP POLICY IF EXISTS event_delete_policy ON public.events;

-- Drop le funzioni esistenti
DROP FUNCTION IF EXISTS public.is_event_member(uuid, uuid);
DROP FUNCTION IF EXISTS public.is_event_member(uuid);

-- Crea la funzione is_event_member
CREATE OR REPLACE FUNCTION public.is_event_member(_event_id uuid) 
RETURNS boolean AS $$
BEGIN
    -- Check if user is null
    IF auth.uid() IS NULL THEN
        RETURN false;
    END IF;

    RETURN EXISTS (
        SELECT 1 
        FROM public.events e
        WHERE e.id = _event_id
        AND (
            e.creato_da = auth.uid()  -- L'utente è il creatore
            OR EXISTS (
                SELECT 1 
                FROM public.event_participants ep
                WHERE ep.event_id = _event_id
                AND ep.user_id = auth.uid()
            )
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Concedi i permessi necessari per la funzione
GRANT EXECUTE ON FUNCTION public.is_event_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_event_member(uuid) TO anon;

-- Crea le policy
CREATE POLICY event_select_policy ON public.events
    FOR SELECT 
    USING (
        public.is_event_member(id) 
        OR stato = 'active'  -- Eventi attivi sono visibili a tutti
    );

CREATE POLICY event_insert_policy ON public.events
    FOR INSERT 
    WITH CHECK (
        auth.uid() IS NOT NULL  -- L'utente deve essere autenticato
        AND creato_da = auth.uid()  -- Il creatore deve essere l'utente corrente
    );

CREATE POLICY event_update_policy ON public.events AS RESTRICTIVE
    FOR UPDATE
    USING (creato_da = auth.uid())  -- Solo il creatore può modificare
    WITH CHECK (
        creato_da = auth.uid()
        AND (
            stato = 'draft'  -- Può modificare se è in bozza
            OR (stato = 'active' AND (SELECT stato FROM public.events WHERE id = events.id) IN ('completed', 'cancelled'))  -- O può solo completare/cancellare se attivo
        )
    );

CREATE POLICY event_delete_policy ON public.events
    FOR DELETE
    USING (
        creato_da = auth.uid()
        AND stato = 'draft'  -- Solo eventi in bozza possono essere eliminati
    );

-- Abilita RLS sulla tabella
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

-- Concedi i permessi necessari per le tabelle
GRANT ALL ON public.events TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon; 