-- ============================================
-- AGGIORNAMENTO PEOPLE COUNTER (CONTA PERSONE)
-- ============================================

-- 1. Tabella event_area (Aree / Piani)
CREATE TABLE IF NOT EXISTS event_area (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    current_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    
    UNIQUE(event_id, name)
);

CREATE INDEX IF NOT EXISTS idx_event_area_event ON event_area(event_id);

-- Trigger updated_at per event_area
DROP TRIGGER IF EXISTS update_event_area_updated_at ON event_area;
CREATE TRIGGER update_event_area_updated_at
    BEFORE UPDATE ON event_area
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- 2. Tabella event_area_log (Log incrementi/decrementi)
CREATE TABLE IF NOT EXISTS event_area_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    area_id UUID NOT NULL REFERENCES event_area(id) ON DELETE CASCADE,
    delta INT NOT NULL, -- +1 o -1
    staff_user_id UUID REFERENCES staff_user(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_event_area_log_area ON event_area_log(area_id);
CREATE INDEX IF NOT EXISTS idx_event_area_log_created ON event_area_log(created_at);


-- 3. Funzione di Consolidamento
CREATE OR REPLACE FUNCTION fn_consolidate_area_logs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_log_count INT;
    v_area_id UUID;
BEGIN
    v_area_id := NEW.area_id;

    -- 1. Aggiorna il contatore principale su event_area
    UPDATE event_area
    SET current_count = current_count + NEW.delta,
        updated_at = NOW()
    WHERE id = v_area_id;

    -- 2. Conta quanti log ci sono per questa area
    SELECT COUNT(*) INTO v_log_count
    FROM event_area_log
    WHERE area_id = v_area_id;

    -- 3. Se superiamo 130 log, consolidiamo (elimina i più vecchi)
    IF v_log_count > 130 THEN
        DELETE FROM event_area_log
        WHERE id IN (
            SELECT id
            FROM event_area_log
            WHERE area_id = v_area_id
            ORDER BY created_at ASC
            LIMIT (v_log_count - 100) -- Ne lasciamo 100
        );
    END IF;

    RETURN NEW;
END;
$$;

-- 4. Trigger su INSERT event_area_log
DROP TRIGGER IF EXISTS trg_consolidate_area_logs ON event_area_log;
CREATE TRIGGER trg_consolidate_area_logs
    AFTER INSERT ON event_area_log
    FOR EACH ROW
    EXECUTE FUNCTION fn_consolidate_area_logs();

-- ============================================
-- PERMISSIONS & RLS (MUST RUN THIS!!)
-- ============================================

-- 0. Grant Usage on Schema (Good practice)
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;

-- 1. Grant Table Permissions (Fixing 42501 Error)
GRANT ALL ON TABLE event_area TO authenticated;
GRANT ALL ON TABLE event_area TO service_role;

GRANT ALL ON TABLE event_area_log TO authenticated;
GRANT ALL ON TABLE event_area_log TO service_role;

-- 2. Enable RLS
ALTER TABLE event_area ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_area_log ENABLE ROW LEVEL SECURITY;

-- 3. Drop existing policies to ensure idempotency (Cleanup)
DROP POLICY IF EXISTS "Staff can view event areas" ON event_area;
DROP POLICY IF EXISTS "Staff can view event area logs" ON event_area_log;
DROP POLICY IF EXISTS "Admin and Staff3 can insert/update/delete areas" ON event_area;
DROP POLICY IF EXISTS "Admin and Staff3 can insert logs" ON event_area_log;

-- 4. RLS Policy Definitions

-- POLICY: Read Access (Staff & Admin)
CREATE POLICY "Staff can view event areas" ON event_area
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM event_staff es
            WHERE es.event_id = event_area.event_id
            AND es.staff_user_id = auth.uid()
        )
    );

CREATE POLICY "Staff can view event area logs" ON event_area_log
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM event_area ea
            JOIN event_staff es ON es.event_id = ea.event_id
            WHERE ea.id = event_area_log.area_id
            AND es.staff_user_id = auth.uid()
        )
    );

-- POLICY: Write Access (Admin & Staff3 Only)
CREATE POLICY "Admin and Staff3 can insert/update/delete areas" ON event_area
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM event_staff es
            JOIN role r ON es.role_id = r.id
            WHERE es.event_id = event_area.event_id
            AND es.staff_user_id = auth.uid()
            AND (LOWER(r.name) = 'admin' OR LOWER(r.name) = 'staff3')
        )
    );

CREATE POLICY "Admin and Staff3 can insert logs" ON event_area_log
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM event_area ea
            JOIN event_staff es ON es.event_id = ea.event_id
            JOIN role r ON es.role_id = r.id
            WHERE ea.id = area_id
            AND es.staff_user_id = auth.uid()
            AND (LOWER(r.name) = 'admin' OR LOWER(r.name) = 'staff3')
        )
    );

-- ============================================
-- REALTIME PUBLICATION (CRITICAL FOR LIVE UPDATES)
-- ============================================

-- Add tables to the supabase_realtime publication
-- This makes changes visible to the Flutter app's Stream
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'event_area'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE event_area;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'event_area_log'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE event_area_log;
  END IF;
END $$;

ALTER TABLE event_area REPLICA IDENTITY FULL;
