-- ============================================
-- FESTER 3.0 - SUPABASE (PostgreSQL) SCHEMA
-- ============================================

-- ============================================
-- TABELLE DI LOOKUP / RIFERIMENTO
-- ============================================

CREATE TABLE role (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

COMMENT ON TABLE role IS 'Ruoli utente: admin, organizer, bartender, guest, vip';
COMMENT ON COLUMN role.name IS 'es. admin, bartender, guest, vip';

CREATE TABLE participation_status (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    is_inside BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON COLUMN participation_status.name IS 'invited, confirmed, checked_in, inside, outside, cancelled';
COMMENT ON COLUMN participation_status.is_inside IS 'Indica se lo status significa "dentro all evento"';

CREATE TABLE transaction_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    affects_drink_count BOOLEAN DEFAULT FALSE,
    is_monetary BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON COLUMN transaction_type.name IS 'drink, ticket, fine, sanction, report, refund, fee';
COMMENT ON COLUMN transaction_type.affects_drink_count IS 'Se TRUE, conta nel limite drink';
COMMENT ON COLUMN transaction_type.is_monetary IS 'Se FALSE, Ã¨ una transazione non monetaria';

-- ============================================
-- TABELLA PERSONE
-- ============================================

CREATE TABLE person (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    email VARCHAR(255),
    phone VARCHAR(30),
    image_path TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);

COMMENT ON COLUMN person.date_of_birth IS 'Usata per calcolare age (derived)';
COMMENT ON COLUMN person.image_path IS 'Path in Supabase Storage, es: avatars/user-123.jpg';
COMMENT ON COLUMN person.is_active IS 'Soft delete';
COMMENT ON COLUMN person.deleted_at IS 'Soft delete timestamp';

CREATE INDEX idx_person_email ON person(email);
CREATE INDEX idx_person_active ON person(is_active, deleted_at);

-- ============================================
-- TABELLA STAFF USERS (collegati a Supabase Auth)
-- ============================================

CREATE TABLE staff_user (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    email VARCHAR(255),
    phone VARCHAR(30),
    image_path TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE staff_user IS 'Utenti staff collegati a Supabase Auth';
COMMENT ON COLUMN staff_user.id IS 'Stesso UUID di auth.users(id)';

CREATE INDEX idx_staff_user_email ON staff_user(email);
CREATE INDEX idx_staff_user_active ON staff_user(is_active, deleted_at);



-- ============================================
-- TABELLA EVENTI
-- ============================================

CREATE TABLE event (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_by UUID NOT NULL REFERENCES staff_user(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);

COMMENT ON COLUMN event.deleted_at IS 'Soft delete';

CREATE INDEX idx_event_created_by ON event(created_by);
CREATE INDEX idx_event_deleted ON event(deleted_at);

-- ============================================
-- IMPOSTAZIONI EVENTO (1:1 con event)
-- ============================================

CREATE TABLE event_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID UNIQUE NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    
    -- Impostazioni generali
    max_participants INT,
    allow_guests BOOLEAN DEFAULT TRUE,
    location VARCHAR(255),
    currency VARCHAR(3) DEFAULT 'EUR',
    
    -- Impostazioni temporali
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ,
    check_in_start_time TIMESTAMPTZ,
    check_in_end_time TIMESTAMPTZ,
    late_entry_allowed BOOLEAN DEFAULT TRUE,
    
    -- Impostazioni di sicurezza
    age_restriction INT,
    id_check_required BOOLEAN DEFAULT FALSE,
    max_warnings_before_ban INT DEFAULT 3,
    
    -- Impostazioni drink
    default_max_drinks_per_person INT,
    role_drink_limits JSONB,
    custom_settings JSONB,
    
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID NOT NULL REFERENCES staff_user(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

COMMENT ON COLUMN event_settings.event_id IS 'Relazione 1:1 con event';
COMMENT ON COLUMN event_settings.max_participants IS 'NULL = illimitato';
COMMENT ON COLUMN event_settings.allow_guests IS 'I partecipanti possono invitare ospiti';
COMMENT ON COLUMN event_settings.currency IS 'Codice ISO valuta';
COMMENT ON COLUMN event_settings.check_in_start_time IS 'Inizio check-in';
COMMENT ON COLUMN event_settings.check_in_end_time IS 'Fine check-in';
COMMENT ON COLUMN event_settings.age_restriction IS 'EtÃ  minima richiesta';
COMMENT ON COLUMN event_settings.default_max_drinks_per_person IS 'Limite default, NULL = illimitato';
COMMENT ON COLUMN event_settings.role_drink_limits IS 'JSON: {"bartender": null, "guest": 5, "vip": 10}';
COMMENT ON COLUMN event_settings.custom_settings IS 'Campi custom futuri senza modificare schema';

CREATE INDEX idx_event_settings_event ON event_settings(event_id);
CREATE INDEX idx_event_settings_dates ON event_settings(start_at, end_at);

-- ============================================
-- STAFF ASSEGNATO AGLI EVENTI (con ruoli specifici)
-- ============================================

CREATE TABLE event_staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    staff_user_id UUID NOT NULL REFERENCES staff_user(id) ON DELETE CASCADE,
    role_id INT NOT NULL REFERENCES role(id),
    assigned_by UUID REFERENCES staff_user(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    
    UNIQUE(event_id, staff_user_id)
);

COMMENT ON TABLE event_staff IS 'Assegnazione staff agli eventi con ruoli specifici';
COMMENT ON COLUMN event_staff.role_id IS 'Ruolo dello staff in questo specifico evento (staff1, staff2, staff3)';
COMMENT ON COLUMN event_staff.assigned_by IS 'Chi ha assegnato questo staff all evento';

CREATE INDEX idx_event_staff_event ON event_staff(event_id);
CREATE INDEX idx_event_staff_user ON event_staff(staff_user_id);
CREATE INDEX idx_event_staff_role ON event_staff(role_id);




-- ============================================
-- MENU
-- ============================================

CREATE TABLE menu (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_by UUID NOT NULL REFERENCES staff_user(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_menu_created_by ON menu(created_by);

-- ============================================
-- VOCI DI MENU
-- ============================================

CREATE TABLE menu_item (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_id UUID NOT NULL REFERENCES menu(id) ON DELETE CASCADE,
    transaction_type_id INT NOT NULL REFERENCES transaction_type(id),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    is_available BOOLEAN DEFAULT TRUE,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

COMMENT ON COLUMN menu_item.transaction_type_id IS 'drink, ticket, etc.';
COMMENT ON COLUMN menu_item.sort_order IS 'Ordinamento voci nel menu';

CREATE INDEX idx_menu_item_menu ON menu_item(menu_id);
CREATE INDEX idx_menu_item_available ON menu_item(is_available);
CREATE INDEX idx_menu_item_sort ON menu_item(menu_id, sort_order);

-- ============================================
-- MENU EVENTO (1:1 con event)
-- ============================================

CREATE TABLE event_menu (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID UNIQUE NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    menu_id UUID NOT NULL REFERENCES menu(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

COMMENT ON COLUMN event_menu.event_id IS 'Relazione 1:1 con event';

CREATE INDEX idx_event_menu_event ON event_menu(event_id);
CREATE INDEX idx_event_menu_menu ON event_menu(menu_id);

-- ============================================
-- QUANTITÃ€ DISPONIBILI PER VOCE DI MENU
-- ============================================

CREATE TABLE event_menu_item_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_item(id),
    available_quantity INT,
    consumed_quantity INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    
    UNIQUE(event_id, menu_item_id)
);

COMMENT ON COLUMN event_menu_item_inventory.available_quantity IS 'NULL = illimitato';

CREATE INDEX idx_inventory_event ON event_menu_item_inventory(event_id);
CREATE INDEX idx_inventory_item ON event_menu_item_inventory(menu_item_id);

-- ============================================
-- PARTECIPAZIONI
-- ============================================

CREATE TABLE participation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID NOT NULL REFERENCES person(id),
    event_id UUID NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    status_id INT NOT NULL REFERENCES participation_status(id),
    role_id INT REFERENCES role(id), 
    invited_by UUID REFERENCES person(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    
    UNIQUE(person_id, event_id)
);

COMMENT ON COLUMN participation.invited_by IS 'NULL = auto-join o creato da organizzatore';
COMMENT ON COLUMN participation.role_id IS 'Ruolo del partecipante durante l evento (guest, vip, etc.)';

CREATE INDEX idx_participation_person ON participation(person_id);
CREATE INDEX idx_participation_event ON participation(event_id);
CREATE INDEX idx_participation_status ON participation(status_id);
CREATE INDEX idx_participation_invited_by ON participation(invited_by);
CREATE INDEX idx_participation_role ON participation(role_id);

-- ============================================
-- STORICO STATI PARTECIPAZIONE
-- ============================================

CREATE TABLE participation_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participation_id UUID NOT NULL REFERENCES participation(id) ON DELETE CASCADE,
    status_id INT NOT NULL REFERENCES participation_status(id),
    changed_by UUID REFERENCES person(id),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON COLUMN participation_status_history.changed_by IS 'Chi ha effettuato il cambio';
COMMENT ON COLUMN participation_status_history.notes IS 'Motivazione del cambio';

CREATE INDEX idx_participation_history_participation ON participation_status_history(participation_id);
CREATE INDEX idx_participation_history_created ON participation_status_history(created_at);

-- ============================================
-- TRANSAZIONI
-- ============================================

CREATE TABLE transaction (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participation_id UUID NOT NULL REFERENCES participation(id) ON DELETE CASCADE,
    transaction_type_id INT NOT NULL REFERENCES transaction_type(id),
    menu_item_id UUID REFERENCES menu_item(id),
    
    name VARCHAR(100),
    description TEXT,
    amount DECIMAL(10,2) DEFAULT 0.00,
    quantity INT DEFAULT 1,
    
    created_by UUID NOT NULL REFERENCES staff_user(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON COLUMN transaction.participation_id IS 'Obbligatorio: tutte le transazioni legate a participation';
COMMENT ON COLUMN transaction.menu_item_id IS 'Se la transazione Ã¨ legata a una voce di menu';
COMMENT ON COLUMN transaction.name IS 'Nome custom se non da menu';
COMMENT ON COLUMN transaction.description IS 'Note aggiuntive o motivazione (es. motivo sanzione)';
COMMENT ON COLUMN transaction.amount IS 'Valore monetario';
COMMENT ON COLUMN transaction.quantity IS 'QuantitÃ  (es. numero di drink)';
COMMENT ON COLUMN transaction.created_by IS 'Chi ha registrato la transazione (es. bartender)';

CREATE INDEX idx_transaction_participation ON transaction(participation_id);
CREATE INDEX idx_transaction_type ON transaction(transaction_type_id);
CREATE INDEX idx_transaction_created ON transaction(created_at);
CREATE INDEX idx_transaction_created_by ON transaction(created_by);
CREATE INDEX idx_transaction_composite ON transaction(participation_id, transaction_type_id, created_at);
CREATE INDEX idx_participation_composite ON participation(event_id, status_id, person_id);

-- ============================================
-- VIEW: CALCOLI DERIVATI PER PARTICIPATION
-- ============================================

CREATE OR REPLACE VIEW participation_stats AS
SELECT 
    p.id AS participation_id,
    p.person_id,
    p.event_id,
    p.status_id,
    ps.is_inside,
    
    COALESCE(SUM(
        CASE WHEN tt.affects_drink_count = TRUE 
        THEN t.quantity 
        ELSE 0 END
    ), 0) AS drink_count,
    
    COALESCE(SUM(
        CASE WHEN tt.name IN ('fine', 'sanction', 'report') 
        THEN 1 
        ELSE 0 END
    ), 0) AS sanction_count,
    
    COALESCE(SUM(
        CASE WHEN tt.is_monetary = TRUE 
        THEN t.amount * t.quantity
        ELSE 0 END
    ), 0.00) AS total_amount
    
FROM participation p
LEFT JOIN participation_status ps ON p.status_id = ps.id
LEFT JOIN transaction t ON p.id = t.participation_id
LEFT JOIN transaction_type tt ON t.transaction_type_id = tt.id
GROUP BY p.id, p.person_id, p.event_id, p.status_id, ps.is_inside;

COMMENT ON VIEW participation_stats IS 'Statistiche derivate per partecipazione: drink_count, sanction_count, total_amount';

-- ============================================
-- VIEW: ETÃ€ PERSONE
-- ============================================

CREATE OR REPLACE VIEW person_with_age AS
SELECT 
    p.*,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.date_of_birth))::INT AS age
FROM person p;

COMMENT ON VIEW person_with_age IS 'Vista person con campo age calcolato da date_of_birth';

-- ============================================
-- FUNCTION & TRIGGER: Aggiorna inventario
-- ============================================

CREATE OR REPLACE FUNCTION update_inventory_on_transaction()
RETURNS TRIGGER 
SET search_path = public
AS $$
DECLARE
    v_event_id UUID;
BEGIN
    -- Ottieni event_id dalla participation
    SELECT event_id INTO v_event_id
    FROM participation
    WHERE id = NEW.participation_id;
    
    -- Aggiorna consumed_quantity se la transazione ha un menu_item
    IF NEW.menu_item_id IS NOT NULL THEN
        UPDATE event_menu_item_inventory
        SET consumed_quantity = consumed_quantity + NEW.quantity,
            updated_at = NOW()
        WHERE event_id = v_event_id 
        AND menu_item_id = NEW.menu_item_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_inventory
AFTER INSERT ON transaction
FOR EACH ROW
EXECUTE FUNCTION update_inventory_on_transaction();

COMMENT ON FUNCTION update_inventory_on_transaction() IS 'Aggiorna automaticamente consumed_quantity quando si inserisce una transaction';

-- ============================================
-- FUNCTION: Auto-update updated_at
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER 
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_updated_at_column() IS 'Aggiorna automaticamente il campo updated_at al momento di UPDATE';

-- Applica trigger a tutte le tabelle con updated_at
CREATE TRIGGER update_person_updated_at 
    BEFORE UPDATE ON person
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
    
CREATE TRIGGER update_event_updated_at 
    BEFORE UPDATE ON event
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
    
CREATE TRIGGER update_event_settings_updated_at 
    BEFORE UPDATE ON event_settings
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
    
CREATE TRIGGER update_menu_updated_at 
    BEFORE UPDATE ON menu
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
    
CREATE TRIGGER update_menu_item_updated_at 
    BEFORE UPDATE ON menu_item
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
    
CREATE TRIGGER update_event_menu_updated_at 
    BEFORE UPDATE ON event_menu
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
    
CREATE TRIGGER update_inventory_updated_at 
    BEFORE UPDATE ON event_menu_item_inventory
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
    
CREATE TRIGGER update_participation_updated_at 
    BEFORE UPDATE ON participation
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger per updated_at
CREATE TRIGGER update_staff_user_updated_at 
    BEFORE UPDATE ON staff_user
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_event_staff_updated_at 
    BEFORE UPDATE ON event_staff
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
-- ============================================
-- HELPER FUNCTIONS per RLS (VERSIONE AGGIORNATA)
-- ============================================

-- Funzione: Verifica se l'utente è admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN 
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM staff_user su
        JOIN event_staff es ON su.id = es.staff_user_id
        JOIN role r ON es.role_id = r.id
        WHERE su.id = auth.uid()
        AND r.name = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funzione: Ottieni il ruolo staff per un evento specifico
CREATE OR REPLACE FUNCTION get_event_staff_role(event_uuid UUID)
RETURNS TEXT 
SET search_path = public
AS $$
DECLARE
    staff_role TEXT;
BEGIN
    SELECT r.name INTO staff_role
    FROM event_staff es
    JOIN role r ON es.role_id = r.id
    WHERE es.event_id = event_uuid
    AND es.staff_user_id = auth.uid();
    
    RETURN staff_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funzione: Ottieni il livello staff per un evento (1, 2, 3, o NULL)
CREATE OR REPLACE FUNCTION get_event_staff_level(event_uuid UUID)
RETURNS INT 
SET search_path = public
AS $$
DECLARE
    staff_role TEXT;
BEGIN
    staff_role := get_event_staff_role(event_uuid);
    
    RETURN CASE
        WHEN staff_role = 'staff1' THEN 1
        WHEN staff_role = 'staff2' THEN 2
        WHEN staff_role = 'staff3' THEN 3
        ELSE NULL
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funzione: Verifica se utente ha almeno un certo livello staff per un evento
CREATE OR REPLACE FUNCTION has_event_staff_level(event_uuid UUID, min_level INT)
RETURNS BOOLEAN 
SET search_path = public
AS $$
BEGIN
    RETURN COALESCE(get_event_staff_level(event_uuid), 0) >= min_level;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funzione: Verifica se l'utente è staff di un evento (qualsiasi livello)
CREATE OR REPLACE FUNCTION is_event_staff(event_uuid UUID)
RETURNS BOOLEAN 
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM event_staff es
        WHERE es.event_id = event_uuid
        AND es.staff_user_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funzione: Verifica se l'utente è creatore dell'evento
CREATE OR REPLACE FUNCTION is_event_creator(event_uuid UUID)
RETURNS BOOLEAN 
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM event e
        WHERE e.id = event_uuid
        AND e.created_by = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================
-- ABILITA RLS SU TUTTE LE TABELLE
-- ============================================

ALTER TABLE person ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE event ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_menu ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_menu_item_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE participation ENABLE ROW LEVEL SECURITY;
ALTER TABLE participation_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction ENABLE ROW LEVEL SECURITY;

-- ============================================
-- TABELLA: person
-- ============================================


DROP POLICY IF EXISTS "person_select_policy" ON person;
DROP POLICY IF EXISTS "person_insert_policy" ON person;
DROP POLICY IF EXISTS "person_update_policy" ON person;
DROP POLICY IF EXISTS "person_delete_policy" ON person;

-- SELECT: Solo staff degli eventi in cui la persona partecipa, e admin
CREATE POLICY "person_select_policy"
    ON person FOR SELECT
    USING (
        is_admin()
        OR EXISTS (
            SELECT 1 FROM participation pa
            WHERE pa.person_id = person.id
            AND is_event_staff(pa.event_id)
        )
    );

-- INSERT: Solo staff2+ di qualsiasi evento e admin
CREATE POLICY "person_insert_policy"
    ON person FOR INSERT
    WITH CHECK (
        is_admin()
        OR EXISTS (
            SELECT 1 FROM event_staff es
            WHERE es.staff_user_id = auth.uid()
            AND has_event_staff_level(es.event_id, 2)
        )
    );

-- UPDATE: Solo staff2+ degli eventi in cui partecipa, e admin
CREATE POLICY "person_update_policy"
    ON person FOR UPDATE
    USING (
        is_admin()
        OR EXISTS (
            SELECT 1 FROM participation pa
            WHERE pa.person_id = person.id
            AND has_event_staff_level(pa.event_id, 2)
        )
    );
    
-- DELETE: Solo admin
CREATE POLICY "person_delete_policy"
    ON person FOR DELETE
    USING (is_admin());

-- ============================================
-- TABELLA: event
-- ============================================
DROP POLICY IF EXISTS "event_select_policy" ON event;
DROP POLICY IF EXISTS "event_insert_policy" ON event;
DROP POLICY IF EXISTS "event_update_policy" ON event;
DROP POLICY IF EXISTS "event_delete_policy" ON event;

-- SELECT: Solo staff assegnati all'evento + admin
CREATE POLICY "event_select_policy"
    ON event FOR SELECT
    USING (
        is_event_creator(id)           -- Creatore dell'evento
        OR is_event_staff(id)          -- Staff assegnato all'evento
        OR is_admin()                  -- Admin
    );

-- INSERT: Solo admin e staff3 globali possono creare eventi
CREATE POLICY "event_insert_policy"
    ON event FOR INSERT
    WITH CHECK (
        is_admin()
        OR EXISTS (
            SELECT 1 FROM event_staff es
            JOIN role r ON es.role_id = r.id
            WHERE es.staff_user_id = auth.uid()
            AND r.name = 'staff3'
        )
    );

-- UPDATE: Solo creatore, staff3 dell'evento, e admin
CREATE POLICY "event_update_policy"
    ON event FOR UPDATE
    USING (
        is_event_creator(id)
        OR has_event_staff_level(id, 3)
        OR is_admin()
    );

-- DELETE: Solo admin e staff3 possono eliminare eventi
CREATE POLICY "event_delete_policy"
    ON event FOR DELETE
    USING (
        is_admin()
        OR has_event_staff_level(id, 3)    -- usa id (pk) della tabella event, non event_id
    );

-- ============================================
-- TABELLA: event_settings
-- ============================================
DROP POLICY IF EXISTS "event_settings_select_policy" ON event_settings;
DROP POLICY IF EXISTS "event_settings_insert_policy" ON event_settings;
DROP POLICY IF EXISTS "event_settings_update_policy" ON event_settings;
DROP POLICY IF EXISTS "event_settings_delete_policy" ON event_settings;

-- SELECT: Staff dell'evento vede le settings
CREATE POLICY "event_settings_select_policy"
    ON event_settings FOR SELECT
    USING (
        is_event_creator(event_settings.event_id)
        OR is_event_staff(event_settings.event_id)
        OR is_admin()
    );

-- INSERT: Creatore e staff3 dell'evento
CREATE POLICY "event_settings_insert_policy"
    ON event_settings FOR INSERT
    WITH CHECK (
        is_event_creator(event_settings.event_id)
        OR has_event_staff_level(event_settings.event_id, 3)
        OR is_admin()
    );

-- UPDATE: Creatore e staff3 dell'evento
CREATE POLICY "event_settings_update_policy"
    ON event_settings FOR UPDATE
    USING (
        is_event_creator(event_settings.event_id)
        OR has_event_staff_level(event_settings.event_id, 3)
        OR is_admin()
    );

-- DELETE: Solo admin
CREATE POLICY "event_settings_delete_policy"
    ON event_settings FOR DELETE
    USING (is_admin());

-- ============================================
-- TABELLA: menu
-- ============================================


DROP POLICY IF EXISTS "menu_select_policy" ON menu;
DROP POLICY IF EXISTS "menu_insert_policy" ON menu;
DROP POLICY IF EXISTS "menu_update_policy" ON menu;
DROP POLICY IF EXISTS "menu_delete_policy" ON menu;

-- SELECT: Creatore, qualsiasi staff, admin
CREATE POLICY "menu_select_policy"
    ON menu FOR SELECT
    USING (
        created_by = auth.uid()
        OR is_admin()
        OR EXISTS (
            SELECT 1 FROM event_staff es
            WHERE es.staff_user_id = auth.uid()
        )
    );

-- INSERT: Staff2+ di qualsiasi evento, admin
CREATE POLICY "menu_insert_policy"
    ON menu FOR INSERT
    WITH CHECK (
        is_admin()
        OR EXISTS (
            SELECT 1 FROM event_staff es
            WHERE es.staff_user_id = auth.uid()
            AND has_event_staff_level(es.event_id, 2)
        )
    );

-- UPDATE: Creatore, staff2+ di qualsiasi evento, admin
CREATE POLICY "menu_update_policy"
    ON menu FOR UPDATE
    USING (
        created_by = auth.uid()
        OR is_admin()
        OR EXISTS (
            SELECT 1 FROM event_staff es
            WHERE es.staff_user_id = auth.uid()
            AND has_event_staff_level(es.event_id, 2)
        )
    );

-- DELETE: Admin e staff3 di qualsiasi evento
CREATE POLICY "menu_delete_policy"
    ON menu FOR DELETE
    USING (
        is_admin()
        OR EXISTS (
            SELECT 1
            FROM event_menu em
            JOIN event_staff es ON em.event_id = es.event_id
            WHERE em.menu_id = menu.id
              AND es.staff_user_id = auth.uid()
              AND has_event_staff_level(es.event_id, 3) 
        )
    );

-- ============================================
-- TABELLA: menu_item
-- ============================================

DROP POLICY IF EXISTS "menu_item_select_policy" ON menu_item;
DROP POLICY IF EXISTS "menu_item_insert_policy" ON menu_item;
DROP POLICY IF EXISTS "menu_item_update_policy" ON menu_item;
DROP POLICY IF EXISTS "menu_item_delete_policy" ON menu_item;

-- SELECT: Chi vede il menu vede gli item
CREATE POLICY "menu_item_select_policy"
    ON menu_item FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM menu m
            WHERE m.id = menu_id
            AND (
                m.created_by = auth.uid()
                OR is_admin()
                OR EXISTS (
                    SELECT 1 FROM event_staff es
                    WHERE es.staff_user_id = auth.uid()
                )
            )
        )
    );

-- INSERT: Staff2+ di qualsiasi evento, admin
CREATE POLICY "menu_item_insert_policy"
    ON menu_item FOR INSERT
    WITH CHECK (
        is_admin()
        OR EXISTS (
            SELECT 1 FROM event_staff es
            WHERE es.staff_user_id = auth.uid()
            AND has_event_staff_level(es.event_id, 2)
        )
    );

-- UPDATE: Staff2+ di qualsiasi evento, admin
CREATE POLICY "menu_item_update_policy"
    ON menu_item FOR UPDATE
    USING (
        is_admin()
        OR EXISTS (
            SELECT 1 FROM event_staff es
            WHERE es.staff_user_id = auth.uid()
            AND has_event_staff_level(es.event_id, 2)
        )
    );

-- DELETE: Staff3 di qualsiasi evento, admin
CREATE POLICY "menu_item_delete_policy"
    ON menu_item FOR DELETE
    USING (
        is_admin()
        OR EXISTS (
            SELECT 1
            FROM event_menu em
            JOIN event_staff es ON em.event_id = es.event_id
            WHERE em.menu_id = menu_item.menu_id
              AND es.staff_user_id = auth.uid()
              AND has_event_staff_level(es.event_id, 3)  -- verifica staff3 sull'evento che usa il menu dell'item
        )
    );

-- ============================================
-- TABELLA: staff_user
-- ============================================

-- SELECT: Ognuno vede i propri dati, admin vede tutti
CREATE POLICY "staff_user_select_policy"
    ON staff_user FOR SELECT
    USING (
        id = auth.uid()
        OR is_admin()
    );

-- INSERT: Registrazione automatica + admin
CREATE POLICY "staff_user_insert_policy"
    ON staff_user FOR INSERT
    WITH CHECK (
        id = auth.uid()  -- Auto-registrazione
        OR is_admin()
    );

-- UPDATE: Ognuno aggiorna i propri dati, admin aggiorna tutti
CREATE POLICY "staff_user_update_policy"
    ON staff_user FOR UPDATE
    USING (
        id = auth.uid()
        OR is_admin()
    );

-- DELETE: Solo admin o se stessi
CREATE POLICY "staff_user_delete_policy"
    ON staff_user FOR DELETE
    USING (
        id = auth.uid()
        OR is_admin()
    );

-- ============================================
-- TABELLA: event_staff
-- ============================================

DROP POLICY IF EXISTS "staff_user_select_policy" ON staff_user;
DROP POLICY IF EXISTS "staff_user_insert_policy" ON staff_user;
DROP POLICY IF EXISTS "staff_user_update_policy" ON staff_user;
DROP POLICY IF EXISTS "staff_user_delete_policy" ON staff_user;


-- SELECT: Semplificata per evitare problemi circolari
CREATE POLICY "staff_user_select_policy"
    ON staff_user FOR SELECT
    TO authenticated
    USING (true);
    
-- INSERT: Durante registrazione (service_role) o admin
CREATE POLICY "staff_user_insert_policy"
    ON staff_user FOR INSERT
    WITH CHECK (true);

-- UPDATE: Solo proprio profilo o admin
CREATE POLICY "staff_user_update_policy"
    ON staff_user FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = id
        OR is_admin()
    )
    WITH CHECK (
        auth.uid() = id
        OR is_admin()
    );

-- DELETE: Solo admin (soft delete via update)
CREATE POLICY "staff_user_delete_policy"
    ON staff_user FOR DELETE
    USING (is_admin());


CREATE OR REPLACE FUNCTION create_staff_user_on_signup()
RETURNS TRIGGER AS $$
BEGIN
    -- Inserisci in staff_user quando viene creato un utente in auth.users
    INSERT INTO public.staff_user (
        id,
        first_name,
        last_name,
        email,
        phone,
        date_of_birth
    ) VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'phone', NULL),
        COALESCE((NEW.raw_user_meta_data->>'date_of_birth')::DATE, NULL)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_staff_user_on_signup();

-- ============================================
-- TABELLA: event_menu
-- ============================================

DROP POLICY IF EXISTS "event_menu_select_policy" ON event_menu;
DROP POLICY IF EXISTS "event_menu_insert_policy" ON event_menu;
DROP POLICY IF EXISTS "event_menu_update_policy" ON event_menu;
DROP POLICY IF EXISTS "event_menu_delete_policy" ON event_menu;

-- SELECT: Staff dell'evento vede il menu
CREATE POLICY "event_menu_select_policy"
    ON event_menu FOR SELECT
    USING (
        is_event_creator(event_menu.event_id)
        OR is_event_staff(event_menu.event_id)
        OR is_admin()
    );

-- INSERT: Creatore, staff3 dell'evento, admin
CREATE POLICY "event_menu_insert_policy"
    ON event_menu FOR INSERT
    WITH CHECK (
        is_event_creator(event_menu.event_id)
        OR has_event_staff_level(event_menu.event_id, 3)
        OR is_admin()
    );

-- UPDATE: Creatore, staff3 dell'evento, admin
CREATE POLICY "event_menu_update_policy"
    ON event_menu FOR UPDATE
    USING (
        is_event_creator(event_menu.event_id)
        OR has_event_staff_level(event_menu.event_id, 3)
        OR is_admin()
    );

-- DELETE: Staff3 dell'evento, admin
CREATE POLICY "event_menu_delete_policy"
    ON event_menu FOR DELETE
    USING (
        has_event_staff_level(event_menu.event_id, 3)
        OR is_admin()
    );

-- ============================================
-- TABELLA: event_menu_item_inventory
-- ============================================

DROP POLICY IF EXISTS "inventory_select_policy" ON event_menu_item_inventory;
DROP POLICY IF EXISTS "inventory_insert_policy" ON event_menu_item_inventory;
DROP POLICY IF EXISTS "inventory_update_policy" ON event_menu_item_inventory;
DROP POLICY IF EXISTS "inventory_delete_policy" ON event_menu_item_inventory;

-- SELECT: Staff dell'evento vede l'inventario
CREATE POLICY "inventory_select_policy"
    ON event_menu_item_inventory FOR SELECT
    USING (
        is_event_creator(event_id)
        OR is_event_staff(event_id)
        OR is_admin()
    );

-- INSERT: Creatore, staff2+ dell'evento, admin
CREATE POLICY "inventory_insert_policy"
    ON event_menu_item_inventory FOR INSERT
    WITH CHECK (
        is_event_creator(event_menu_item_inventory.event_id)
        OR has_event_staff_level(event_menu_item_inventory.event_id, 2)
        OR is_admin()
    );

-- UPDATE: Creatore, staff1+ dell'evento (per trigger), admin
CREATE POLICY "inventory_update_policy"
    ON event_menu_item_inventory FOR UPDATE
    USING (
        is_event_creator(event_menu_item_inventory.event_id)
        OR is_event_staff(event_menu_item_inventory.event_id)
        OR is_admin()
    );

-- DELETE: Staff3 dell'evento, admin
DROP POLICY IF EXISTS "inventory_delete_policy" ON event_menu_item_inventory;

CREATE POLICY "inventory_delete_policy"
    ON event_menu_item_inventory FOR DELETE
    USING (
        has_event_staff_level(event_menu_item_inventory.event_id, 3)
        OR is_admin()
    );

-- ============================================
-- TABELLA: participation
-- ============================================

DROP POLICY IF EXISTS "participation_select_policy" ON participation;
DROP POLICY IF EXISTS "participation_insert_policy" ON participation;
DROP POLICY IF EXISTS "participation_update_policy" ON participation;
DROP POLICY IF EXISTS "participation_delete_policy" ON participation;

-- SELECT: Staff dell'evento vede le partecipazioni
CREATE POLICY "participation_select_policy"
    ON participation FOR SELECT
    USING (
        is_event_creator(participation.event_id)
        OR is_event_staff(participation.event_id)
        OR is_admin()
    );

-- INSERT: Creatore, staff2+ dell'evento, admin
CREATE POLICY "participation_insert_policy"
    ON participation FOR INSERT
    WITH CHECK (
        is_event_creator(participation.event_id)
        OR has_event_staff_level(participation.event_id, 2)
        OR is_admin()
    );

-- UPDATE: Creatore, staff2+ dell'evento, admin
CREATE POLICY "participation_update_policy"
    ON participation FOR UPDATE
    USING (
        is_event_creator(participation.event_id)
        OR has_event_staff_level(participation.event_id, 2)
        OR is_admin()
    );

-- DELETE: Staff3 dell'evento, admin
CREATE POLICY "participation_delete_policy"
    ON participation FOR DELETE
    USING (
        has_event_staff_level(participation.event_id, 3)
        OR is_admin()
    );

-- ============================================
-- TABELLA: participation_status_history
-- ============================================

DROP POLICY IF EXISTS "participation_history_select_policy" ON participation_status_history;
DROP POLICY IF EXISTS "participation_history_insert_policy" ON participation_status_history;
DROP POLICY IF EXISTS "participation_history_update_policy" ON participation_status_history;
DROP POLICY IF EXISTS "participation_history_delete_policy" ON participation_status_history;

-- SELECT: Staff dell'evento vede lo storico
CREATE POLICY "participation_history_select_policy"
    ON participation_status_history FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM participation p
            WHERE p.id = participation_id
            AND (
                is_event_creator(p.event_id)
                OR is_event_staff(p.event_id)
                OR is_admin()
            )
        )
    );

-- INSERT: Staff2+ dell'evento, admin
CREATE POLICY "participation_history_insert_policy"
    ON participation_status_history FOR INSERT
    WITH CHECK (
        is_admin()
        OR EXISTS (
            SELECT 1 FROM participation p
            WHERE p.id = participation_id
            AND has_event_staff_level(p.event_id, 2)
        )
    );

-- UPDATE: Solo admin
CREATE POLICY "participation_history_update_policy"
    ON participation_status_history FOR UPDATE
    USING (is_admin());

-- DELETE: Solo admin
CREATE POLICY "participation_history_delete_policy"
    ON participation_status_history FOR DELETE
    USING (is_admin());

-- ============================================
-- TABELLA: transaction
-- ============================================

DROP POLICY IF EXISTS "transaction_select_policy" ON transaction;
DROP POLICY IF EXISTS "transaction_insert_policy" ON transaction;
DROP POLICY IF EXISTS "transaction_update_policy" ON transaction;
DROP POLICY IF EXISTS "transaction_delete_policy" ON transaction;

-- SELECT: Staff dell'evento vede le transazioni
CREATE POLICY "transaction_select_policy"
    ON transaction FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM participation p
            WHERE p.id = participation_id
            AND (
                is_event_creator(p.event_id)
                OR is_event_staff(p.event_id)
                OR is_admin()
            )
        )
    );

-- INSERT: Staff1+ dell'evento crea transazioni
CREATE POLICY "transaction_insert_policy"
    ON transaction FOR INSERT
    WITH CHECK (
        is_admin()
        OR EXISTS (
            SELECT 1 FROM participation p
            WHERE p.id = participation_id
            AND is_event_staff(p.event_id)
        )
    );

-- UPDATE: Staff2+ dell'evento, admin
CREATE POLICY "transaction_update_policy"
    ON transaction FOR UPDATE
    USING (
        is_admin()
        OR EXISTS (
            SELECT 1 FROM participation p
            WHERE p.id = participation_id
            AND has_event_staff_level(p.event_id, 2)
        )
    );

-- DELETE: Staff3 dell'evento, admin
CREATE POLICY "transaction_delete_policy"
    ON transaction FOR DELETE
    USING (
        is_admin()
        OR EXISTS (
            SELECT 1 FROM participation p
            WHERE p.id = participation_id
            AND has_event_staff_level(p.event_id, 3)
        )
    );

-- ============================================
-- REALTIME PUBLICATION
-- ============================================

-- Abilita realtime per aggiornamenti in tempo reale
ALTER PUBLICATION supabase_realtime ADD TABLE transaction;
ALTER PUBLICATION supabase_realtime ADD TABLE participation;
ALTER PUBLICATION supabase_realtime ADD TABLE event_menu_item_inventory;

-- ============================================
-- DATI DI ESEMPIO PER LOOKUP TABLES
-- ============================================

INSERT INTO role (name, description) VALUES
('admin', 'Amministratore del sistema'),
('guest', 'Ospite standard'),
('vip', 'Ospite VIP'),
('staff1', 'Staff livello 1 - Permessi limitati (solo lettura + transazioni)'),
('staff2', 'Staff livello 2 - Permessi medi (gestione partecipanti + menu)'),
('staff3', 'Staff livello 3 - Permessi avanzati (gestione eventi completa)');

INSERT INTO participation_status (name, description, is_inside) VALUES
('invited', 'Invitato ma non confermato', FALSE),
('confirmed', 'Confermato ma non ancora entrato', FALSE),
('checked_in', 'Check-in effettuato', TRUE),
('inside', 'Dentro all evento', TRUE),
('outside', 'Uscito temporaneamente', FALSE),
('left', 'Ha lasciato definitivamente', FALSE),
('cancelled', 'Partecipazione cancellata', FALSE);

INSERT INTO transaction_type (name, description, affects_drink_count, is_monetary) VALUES
('drink', 'Consumazione bevanda', TRUE, TRUE),
('food', 'Consumazione cibo', FALSE, TRUE),
('ticket', 'Biglietto ingresso', FALSE, TRUE),
('fine', 'Multa/PenalitÃ ', FALSE, TRUE),
('sanction', 'Sanzione disciplinare', FALSE, FALSE),
('report', 'Segnalazione', FALSE, FALSE),
('refund', 'Rimborso', FALSE, TRUE),
('fee', 'Commissione/Tassa', FALSE, TRUE);