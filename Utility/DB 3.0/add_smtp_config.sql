-- ========================================================
-- TABELLA PER LA CONFIGURAZIONE SMTP DEGLI EVENTI
-- ========================================================

CREATE TABLE IF NOT EXISTS public.event_smtp_config (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES public.event(id) ON DELETE CASCADE,
    host TEXT NOT NULL,
    port INTEGER NOT NULL DEFAULT 587,
    username TEXT NOT NULL,
    password TEXT NOT NULL,
    sender_name TEXT NOT NULL,
    sender_email TEXT NOT NULL,
    ssl BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(event_id)
);

-- GRANT dei permessi per risolvere l'errore 42501
ALTER TABLE public.event_smtp_config OWNER TO postgres;
GRANT ALL ON TABLE public.event_smtp_config TO postgres;
GRANT ALL ON TABLE public.event_smtp_config TO authenticated;
GRANT ALL ON TABLE public.event_smtp_config TO service_role;

-- Funzioni Helper SECURITY DEFINER per bypassare la ricorsione RLS
CREATE OR REPLACE FUNCTION public.check_is_event_admin_or_staff3(p_event_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.event_staff es
        JOIN public.role r ON es.role_id = r.id
        WHERE es.event_id = p_event_id
        AND es.staff_user_id = auth.uid()
        AND LOWER(r.name) IN ('admin', 'staff3')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.check_is_event_creator(p_event_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.event
        WHERE id = p_event_id
        AND created_by = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Abilitazione RLS
ALTER TABLE public.event_smtp_config ENABLE ROW LEVEL SECURITY;

-- Reset e creazione Policy
DROP POLICY IF EXISTS "Admins can view SMTP config" ON public.event_smtp_config;
DROP POLICY IF EXISTS "Admins can insert SMTP config" ON public.event_smtp_config;
DROP POLICY IF EXISTS "Admins can update SMTP config" ON public.event_smtp_config;
DROP POLICY IF EXISTS "Admins can delete SMTP config" ON public.event_smtp_config;

-- SELECT policy
CREATE POLICY "Admins can view SMTP config" ON public.event_smtp_config
    FOR SELECT
    TO authenticated
    USING (
        public.check_is_event_admin_or_staff3(event_id)
        OR
        public.check_is_event_creator(event_id)
    );

-- INSERT policy
CREATE POLICY "Admins can insert SMTP config" ON public.event_smtp_config
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.check_is_event_admin_or_staff3(event_id)
        OR
        public.check_is_event_creator(event_id)
    );

-- UPDATE policy
CREATE POLICY "Admins can update SMTP config" ON public.event_smtp_config
    FOR UPDATE
    TO authenticated
    USING (
        public.check_is_event_admin_or_staff3(event_id)
        OR
        public.check_is_event_creator(event_id)
    );

-- DELETE policy
CREATE POLICY "Admins can delete SMTP config" ON public.event_smtp_config
    FOR DELETE
    TO authenticated
    USING (
        public.check_is_event_admin_or_staff3(event_id)
        OR
        public.check_is_event_creator(event_id)
    );

-- Trigger per updated_at
DROP TRIGGER IF EXISTS update_event_smtp_config_updated_at ON public.event_smtp_config;
CREATE TRIGGER update_event_smtp_config_updated_at
    BEFORE UPDATE ON public.event_smtp_config
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
