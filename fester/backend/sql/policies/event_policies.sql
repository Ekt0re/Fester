-- Rimuovi policy esistenti se presenti
DROP POLICY IF EXISTS event_select_policy ON public.events;
DROP POLICY IF EXISTS event_insert_policy ON public.events;
DROP POLICY IF EXISTS event_update_policy ON public.events;
DROP POLICY IF EXISTS event_delete_policy ON public.events;

-- Policy per SELECT
CREATE POLICY event_select_policy ON public.events
    FOR SELECT 
    USING (
        public.is_event_member(id) 
        OR stato = 'active'  -- Eventi attivi sono visibili a tutti
    );

-- Policy per INSERT
CREATE POLICY event_insert_policy ON public.events
    FOR INSERT 
    WITH CHECK (
        auth.uid() IS NOT NULL  -- L'utente deve essere autenticato
        AND creato_da = auth.uid()  -- Il creatore deve essere l'utente corrente
    );

-- Policy per UPDATE
CREATE POLICY event_update_policy ON public.events
    FOR UPDATE
    USING (creato_da = auth.uid())  -- Solo il creatore può modificare
    WITH CHECK (
        creato_da = auth.uid()
        AND (
            stato = 'draft'  -- Può modificare se è in bozza
            OR (stato = 'active' AND NEW.stato IN ('completed', 'cancelled'))  -- O può solo completare/cancellare se attivo
        )
    );

-- Policy per DELETE
CREATE POLICY event_delete_policy ON public.events
    FOR DELETE
    USING (
        creato_da = auth.uid()
        AND stato = 'draft'  -- Solo eventi in bozza possono essere eliminati
    );

-- Abilita RLS sulla tabella
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

-- Concedi i permessi necessari
GRANT ALL ON public.events TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;