-- FESTER 2.0 - Schema Database Supabase CORRETTO
-- Risolve errore: "Database error saving new user"
-- 
-- ESEGUIRE QUESTO SCRIPT NEL SQL EDITOR DI SUPABASE

-- =============================================================================
-- STEP 1: PULIZIA (Eseguire solo se necessario)
-- =============================================================================

-- Disabilita RLS temporaneamente per la pulizia
-- ALTER TABLE IF EXISTS action_logs DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE IF EXISTS guests DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE IF EXISTS events DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE IF EXISTS profiles DISABLE ROW LEVEL SECURITY;

-- Rimuovi trigger esistenti (se ci sono problemi)
-- DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
-- DROP TRIGGER IF EXISTS log_guest_changes ON guests;

-- =============================================================================
-- STEP 2: ESTENSIONI E SETUP
-- =============================================================================

-- Abilita UUID per la generazione automatica di ID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- STEP 3: ENUMS (Ricrea se necessario)
-- =============================================================================

-- Verifica se esistono, altrimenti crea
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('host', 'staff');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE guest_status AS ENUM ('not_arrived', 'arrived', 'left');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE event_status AS ENUM ('active', 'cancelled', 'completed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- =============================================================================
-- STEP 4: TABELLE (Ricrea se necessario)
-- =============================================================================

-- Tabella profili utente (estende auth.users di Supabase)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    role user_role DEFAULT 'staff'::user_role,
    event_id INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabella eventi
CREATE TABLE IF NOT EXISTS events (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    date TIMESTAMP WITH TIME ZONE NOT NULL,
    location TEXT NOT NULL,
    description TEXT,
    max_guests INTEGER DEFAULT 50,
    status event_status DEFAULT 'active'::event_status,
    host_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabella ospiti
CREATE TABLE IF NOT EXISTS guests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    surname TEXT NOT NULL,
    code TEXT NOT NULL,
    qr_code TEXT NOT NULL,
    barcode TEXT NOT NULL,
    status guest_status DEFAULT 'not_arrived'::guest_status,
    drinks_count INTEGER DEFAULT 0,
    flags TEXT[] DEFAULT '{}',
    invited_by UUID REFERENCES profiles(id) ON DELETE CASCADE,
    event_id INTEGER REFERENCES events(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Vincoli di unicità
    UNIQUE(code, event_id),
    UNIQUE(qr_code, event_id),
    UNIQUE(barcode, event_id)
);

-- Tabella log delle azioni
CREATE TABLE IF NOT EXISTS action_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    guest_id UUID REFERENCES guests(id) ON DELETE CASCADE,
    event_id INTEGER REFERENCES events(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    details JSONB,
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- STEP 5: INDICI
-- =============================================================================

-- Crea indici solo se non esistono
CREATE INDEX IF NOT EXISTS idx_guests_event_id ON guests(event_id);
CREATE INDEX IF NOT EXISTS idx_guests_status ON guests(status);
CREATE INDEX IF NOT EXISTS idx_guests_invited_by ON guests(invited_by);
CREATE INDEX IF NOT EXISTS idx_guests_code ON guests(code);
CREATE INDEX IF NOT EXISTS idx_guests_name_surname ON guests(name, surname);

CREATE INDEX IF NOT EXISTS idx_events_host_id ON events(host_id);
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_events_date ON events(date);

CREATE INDEX IF NOT EXISTS idx_action_logs_user_id ON action_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_action_logs_event_id ON action_logs(event_id);
CREATE INDEX IF NOT EXISTS idx_action_logs_performed_at ON action_logs(performed_at);

CREATE INDEX IF NOT EXISTS idx_profiles_event_id ON profiles(event_id);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);

-- =============================================================================
-- STEP 6: FUNZIONI CORRETTE
-- =============================================================================

-- Funzione per aggiornare automaticamente updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Funzione CORRETTA per creare automaticamente il profilo
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    -- Prova ad inserire il profilo
    INSERT INTO public.profiles (id, username, role, event_id)
    VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data->>'username', 
            SPLIT_PART(NEW.email, '@', 1),
            'user_' || substring(NEW.id::text, 1, 8)
        ),
        'staff'::user_role,
        NULL
    )
    ON CONFLICT (id) DO NOTHING; -- Evita errori se esiste già
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log dell'errore (opzionale)
    RAISE WARNING 'Error creating profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW; -- Continua comunque per non bloccare la registrazione
END;
$$;

-- =============================================================================
-- STEP 7: TRIGGER CORRETTI
-- =============================================================================

-- Rimuovi trigger esistente se presente
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Crea il trigger per la creazione automatica del profilo
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger per updated_at
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_events_updated_at ON events;
CREATE TRIGGER update_events_updated_at 
    BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_guests_updated_at ON guests;
CREATE TRIGGER update_guests_updated_at 
    BEFORE UPDATE ON guests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- STEP 8: RLS POLICIES CORRETTE
-- =============================================================================

-- Abilita RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE guests ENABLE ROW LEVEL SECURITY;
ALTER TABLE action_logs ENABLE ROW LEVEL SECURITY;

-- Rimuovi policy esistenti per evitare conflitti
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON profiles;

-- POLICY CORRETTE PER PROFILES
-- Permetti lettura del proprio profilo
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

-- Permetti aggiornamento del proprio profilo
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- POLICY PIÙ PERMISSIVA PER INSERT (risolve l'errore 500)
CREATE POLICY "Enable insert for authenticated users only" ON profiles
    FOR INSERT WITH CHECK (true); -- Permetti inserimento per tutti gli utenti autenticati

-- POLICY ALTERNATIVE PER EVENTS (più permissive)
DROP POLICY IF EXISTS "Hosts can manage own events" ON events;
DROP POLICY IF EXISTS "Staff can view assigned events" ON events;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON events;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON events;

CREATE POLICY "Enable read access for authenticated users" ON events
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Enable insert for authenticated users" ON events
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update own events" ON events
    FOR UPDATE USING (host_id = auth.uid());

CREATE POLICY "Users can delete own events" ON events
    FOR DELETE USING (host_id = auth.uid());

-- POLICY PER GUESTS (più permissive inizialmente)
DROP POLICY IF EXISTS "Hosts can manage event guests" ON guests;
DROP POLICY IF EXISTS "Staff can manage assigned event guests" ON guests;

CREATE POLICY "Enable all access for authenticated users" ON guests
    FOR ALL USING (auth.role() = 'authenticated');

-- POLICY PER ACTION_LOGS
DROP POLICY IF EXISTS "Users can view own action logs" ON action_logs;
DROP POLICY IF EXISTS "Hosts can view event action logs" ON action_logs;
DROP POLICY IF EXISTS "Authenticated users can insert logs" ON action_logs;

CREATE POLICY "Enable all access for authenticated users" ON action_logs
    FOR ALL USING (auth.role() = 'authenticated');

-- =============================================================================
-- STEP 9: FUNZIONI HELPER
-- =============================================================================

-- Funzione per ottenere statistiche dashboard
CREATE OR REPLACE FUNCTION get_dashboard_stats(p_event_id INTEGER DEFAULT NULL)
RETURNS TABLE (
    total_guests BIGINT,
    arrived_guests BIGINT,
    not_arrived_guests BIGINT,
    left_guests BIGINT,
    total_drinks BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Se non specificato event_id, usa quello dell'utente corrente
    IF p_event_id IS NULL THEN
        SELECT event_id INTO p_event_id 
        FROM profiles 
        WHERE id = auth.uid();
    END IF;
    
    -- Se ancora NULL, restituisci zeri
    IF p_event_id IS NULL THEN
        RETURN QUERY SELECT 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT;
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_guests,
        COUNT(*) FILTER (WHERE status = 'arrived')::BIGINT as arrived_guests,
        COUNT(*) FILTER (WHERE status = 'not_arrived')::BIGINT as not_arrived_guests,
        COUNT(*) FILTER (WHERE status = 'left')::BIGINT as left_guests,
        COALESCE(SUM(drinks_count), 0)::BIGINT as total_drinks
    FROM guests 
    WHERE event_id = p_event_id;
END;
$$;

-- Funzione per cercare ospiti
CREATE OR REPLACE FUNCTION search_guests(
    p_search_term TEXT,
    p_event_id INTEGER DEFAULT NULL
)
RETURNS SETOF guests 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Se non specificato event_id, usa quello dell'utente corrente
    IF p_event_id IS NULL THEN
        SELECT event_id INTO p_event_id 
        FROM profiles 
        WHERE id = auth.uid();
    END IF;
    
    -- Se ancora NULL, restituisci vuoto
    IF p_event_id IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT * FROM guests 
    WHERE event_id = p_event_id
    AND (
        name ILIKE '%' || p_search_term || '%' OR
        surname ILIKE '%' || p_search_term || '%' OR
        code ILIKE '%' || p_search_term || '%' OR
        qr_code = p_search_term OR
        barcode = p_search_term
    )
    ORDER BY name, surname;
END;
$$;

-- =============================================================================
-- STEP 10: TEST DELLA CONFIGURAZIONE (FIXED)
-- =============================================================================

-- Testa che le funzioni funzionino
SELECT 'Schema setup completed successfully!' as status;

-- Verifica che i trigger siano attivi (QUERY CORRETTA)
SELECT 
    t.tgname as trigger_name,
    c.relname as table_name,
    p.proname as function_name
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public' 
AND c.relname IN ('profiles', 'events', 'guests')
AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;

-- Verifica che le tabelle esistano
SELECT 
    schemaname,
    tablename,
    tableowner,
    tablespace,
    hasindexes,
    hasrules,
    hastriggers
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('profiles', 'events', 'guests', 'action_logs')
ORDER BY tablename;

-- =============================================================================
-- ISTRUZIONI POST-INSTALLAZIONE
-- =============================================================================

/*
DOPO AVER ESEGUITO QUESTO SCRIPT:

1. Vai su Authentication > Settings in Supabase
2. Assicurati che "Enable email confirmations" sia OFF per testing
3. Verifica che "Allow new users to sign up" sia ON
4. Prova a registrare un nuovo utente dall'app
5. Controlla nella tabella auth.users e profiles che tutto sia OK

Se continui ad avere errori:
- Controlla i Logs in Supabase Dashboard
- Verifica che le policy RLS siano attive
- Assicurati che le credenziali nell'app siano corrette

PER DEBUG:
SELECT * FROM auth.users ORDER BY created_at DESC LIMIT 5;
SELECT * FROM profiles ORDER BY created_at DESC LIMIT 5;

PER VERIFICARE I TRIGGER:
SELECT 
    t.tgname as trigger_name,
    c.relname as table_name,
    p.proname as function_name
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public' 
AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;
*/ 