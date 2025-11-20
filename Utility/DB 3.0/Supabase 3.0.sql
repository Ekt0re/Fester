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
-- TABELLA staff_user
-- ============================================

CREATE TABLE IF NOT EXISTS staff_user (
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

COMMENT ON TABLE staff_user IS 'Profilo interno dello user collegato ad auth.users. id = auth.users.id';

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE OR REPLACE FUNCTION create_staff_user_on_signup()
RETURNS TRIGGER
SET search_path = public
AS $$
DECLARE
    v_first     TEXT;
    v_last      TEXT;
    v_full      TEXT;
    v_dob       DATE;
    v_phone     TEXT;
    um          JSONB;
BEGIN
    -- Usa raw_user_meta_data invece di user_metadata
    um := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
    
    -- Se esiste già una staff_user con lo stesso id, non fare nulla
    IF EXISTS (SELECT 1 FROM staff_user WHERE id = NEW.id) THEN
        RETURN NEW;
    END IF;

    -- Estrai i dati dall'oggetto data
    v_first := um->>'first_name';
    v_last := um->>'last_name';
    v_full := um->>'full_name';
    v_phone := um->>'phone';
    
    -- Gestisci la data di nascita
    BEGIN
        v_dob := (um->>'date_of_birth')::DATE;
    EXCEPTION WHEN OTHERS THEN
        v_dob := NULL;
    END;

    -- Se non abbiamo first_name o last_name, proviamo a estrarli da full_name
    IF (v_first IS NULL OR v_first = '') AND v_full IS NOT NULL THEN
        v_first := split_part(v_full, ' ', 1);
        IF v_last IS NULL OR v_last = '' THEN
            v_last := NULLIF(trim(substring(v_full FROM length(v_first) + 1)), '');
        END IF;
    END IF;

    -- Se manca ancora il first_name, usiamo l'email
    IF v_first IS NULL OR v_first = '' THEN
        v_first := split_part(NEW.email, '@', 1);
    END IF;

    -- Assicurati che last_name non sia null
    IF v_last IS NULL OR v_last = '' THEN
        v_last := ' '; -- placeholder per NOT NULL
    END IF;

    -- Inserisci il record in staff_user
    INSERT INTO staff_user (
        id, 
        first_name, 
        last_name, 
        email, 
        phone, 
        date_of_birth, 
        created_at, 
        is_active
    ) VALUES (
        NEW.id, 
        LEFT(v_first, 100), 
        LEFT(v_last, 100), 
        NEW.email, 
        NULLIF(v_phone, '')::VARCHAR,
        v_dob,
        COALESCE((um->>'created_at')::TIMESTAMPTZ, NOW()),
        COALESCE((um->>'is_active')::BOOLEAN, TRUE)
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ricrea il trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_staff_user_on_signup();

-- ============================================
-- TABELLA EVENTI
-- ============================================

CREATE TABLE event (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    invite_code VARCHAR(100) NULL,
    created_by UUID NOT NULL REFERENCES staff_user(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);

COMMENT ON COLUMN event.deleted_at IS 'Soft delete';

CREATE INDEX idx_event_created_by ON event(created_by);
CREATE INDEX idx_event_deleted ON event(deleted_at);

-- ============================================
-- STAFF ASSEGNATO AGLI EVENTI (con ruoli specifici)
-- ============================================

CREATE TABLE event_staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    staff_user_id UUID REFERENCES staff_user(id) ON DELETE CASCADE, -- Nullable per inviti
    role_id INT NOT NULL REFERENCES role(id),
    mail VARCHAR(255) NULL,
    assigned_by UUID REFERENCES staff_user(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    
    UNIQUE(event_id, staff_user_id),
    UNIQUE(event_id, mail) -- Unica mail per evento (invito)
);

COMMENT ON TABLE event_staff IS 'Assegnazione staff agli eventi con ruoli specifici';
COMMENT ON COLUMN event_staff.role_id IS 'Ruolo dello staff in questo specifico evento (staff1, staff2, staff3)';
COMMENT ON COLUMN event_staff.assigned_by IS 'Chi ha assegnato questo staff all evento';

CREATE INDEX IF NOT EXISTS idx_event_staff_event ON event_staff(event_id);
CREATE INDEX IF NOT EXISTS idx_event_staff_user ON event_staff(staff_user_id);
CREATE INDEX IF NOT EXISTS idx_event_staff_role ON event_staff(role_id);

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
    id_event VARCHAR(255), -- ID visualizzabile (Codice)
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
    created_by UUID NOT NULL REFERENCES staff_user(id) ON DELETE CASCADE,
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
-- MENU
-- ============================================

-- Abilita gen_random_uuid() (pgcrypto)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- TABELLA menu (ogni menu è collegato 1:1 ad un event)
CREATE TABLE IF NOT EXISTS menu (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL UNIQUE REFERENCES event(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_by UUID NOT NULL REFERENCES staff_user(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_menu_event ON menu(event_id);

-- TABELLA menu_item (quantità specifica per quel menu/evento)
CREATE TABLE IF NOT EXISTS menu_item (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_id UUID NOT NULL REFERENCES menu(id) ON DELETE CASCADE,
    transaction_type_id INT NOT NULL REFERENCES transaction_type(id),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL,
    is_available BOOLEAN DEFAULT TRUE,
    sort_order INT DEFAULT 0,
    available_quantity INT, -- nullable = illimitata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

COMMENT ON COLUMN menu_item.transaction_type_id IS 'drink, ticket, etc.';
COMMENT ON COLUMN menu_item.sort_order IS 'Ordinamento voci nel menu';

CREATE INDEX idx_menu_item_menu ON menu_item(menu_id);
CREATE INDEX idx_menu_item_available ON menu_item(is_available);
CREATE INDEX idx_menu_item_sort ON menu_item(menu_id, sort_order);


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
    
    created_by UUID NOT NULL REFERENCES staff_user(id) ON DELETE CASCADE,
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

-- ============================================
-- FUNCTION & TRIGGER: Aggiorna inventario
-- Gestisce INSERT / UPDATE / DELETE sulla tabella "transaction"
-- Presupposti:
--  - la tabella "transaction" ha almeno: id, menu_item_id UUID (nullable), quantity INT
--  - la tabella "menu_item" ha: id UUID, available_quantity INT (nullable = illimitata)
-- ============================================

CREATE OR REPLACE FUNCTION fn_inventory_adjust_on_transaction()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_menu_item_id UUID;
    v_new_menu_item_id UUID;
    v_old_qty INT := 0;
    v_new_qty INT := 0;
    v_avail INT;
    v_new_avail INT;
BEGIN
    -- Prendi riferimenti e quantità (gestisce caso NULL)
    IF TG_OP = 'INSERT' THEN
        v_new_menu_item_id := NEW.menu_item_id;
        v_new_qty := COALESCE(NEW.quantity, 0);

        IF v_new_menu_item_id IS NULL OR v_new_qty = 0 THEN
            RETURN NEW;
        END IF;

        -- Lock riga menu_item per evitare race
        SELECT available_quantity INTO v_avail
        FROM menu_item
        WHERE id = v_new_menu_item_id
        FOR UPDATE;

        -- se available_quantity IS NULL => illimitata -> niente da fare
        IF v_avail IS NULL THEN
            RETURN NEW;
        END IF;

        v_new_avail := v_avail - v_new_qty;
        IF v_new_avail < 0 THEN
            RAISE EXCEPTION 'Disponibilità insufficiente per menu_item %: richieste %, disponibili %', v_new_menu_item_id, v_new_qty, v_avail;
        END IF;

        UPDATE menu_item SET available_quantity = v_new_avail, updated_at = NOW() WHERE id = v_new_menu_item_id;
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        v_old_menu_item_id := OLD.menu_item_id;
        v_old_qty := COALESCE(OLD.quantity, 0);

        IF v_old_menu_item_id IS NULL OR v_old_qty = 0 THEN
            RETURN OLD;
        END IF;

        SELECT available_quantity INTO v_avail
        FROM menu_item
        WHERE id = v_old_menu_item_id
        FOR UPDATE;

        -- se illimitata (NULL) -> niente da fare
        IF v_avail IS NULL THEN
            RETURN OLD;
        END IF;

        v_new_avail := v_avail + v_old_qty;
        UPDATE menu_item SET available_quantity = v_new_avail, updated_at = NOW() WHERE id = v_old_menu_item_id;
        RETURN OLD;

    ELSIF TG_OP = 'UPDATE' THEN
        v_old_menu_item_id := OLD.menu_item_id;
        v_new_menu_item_id := NEW.menu_item_id;
        v_old_qty := COALESCE(OLD.quantity, 0);
        v_new_qty := COALESCE(NEW.quantity, 0);

        -- Caso 1: stesso menu_item (modifica quantità) -> aggiusta delta
        IF v_old_menu_item_id IS NOT NULL AND v_old_menu_item_id = v_new_menu_item_id THEN
            IF v_new_qty = v_old_qty THEN
                RETURN NEW; -- niente da fare
            END IF;

            SELECT available_quantity INTO v_avail
            FROM menu_item
            WHERE id = v_new_menu_item_id
            FOR UPDATE;

            IF v_avail IS NULL THEN
                RETURN NEW; -- illimitata
            END IF;

            v_new_avail := v_avail - (v_new_qty - v_old_qty); -- se incremento quantità, si sottrae di più
            IF v_new_avail < 0 THEN
                RAISE EXCEPTION 'Disponibilità insufficiente per menu_item %: delta richiesto %, disponibili %', v_new_menu_item_id, (v_new_qty - v_old_qty), v_avail;
            END IF;

            UPDATE menu_item SET available_quantity = v_new_avail, updated_at = NOW() WHERE id = v_new_menu_item_id;
            RETURN NEW;
        END IF;

        -- Caso 2: menu_item è cambiato -> ripristina vecchio e decrementa nuovo
        IF v_old_menu_item_id IS NOT NULL THEN
            -- ripristino vecchio
            SELECT available_quantity INTO v_avail
            FROM menu_item
            WHERE id = v_old_menu_item_id
            FOR UPDATE;

            IF v_avail IS NOT NULL THEN
                UPDATE menu_item SET available_quantity = v_avail + v_old_qty, updated_at = NOW() WHERE id = v_old_menu_item_id;
            END IF;
        END IF;

        IF v_new_menu_item_id IS NOT NULL THEN
            -- decremento nuovo
            SELECT available_quantity INTO v_avail
            FROM menu_item
            WHERE id = v_new_menu_item_id
            FOR UPDATE;

            IF v_avail IS NULL THEN
                RETURN NEW; -- illimitata
            END IF;

            v_new_avail := v_avail - v_new_qty;
            IF v_new_avail < 0 THEN
                RAISE EXCEPTION 'Disponibilità insufficiente per menu_item %: richieste %, disponibili %', v_new_menu_item_id, v_new_qty, v_avail;
            END IF;

            UPDATE menu_item SET available_quantity = v_new_avail, updated_at = NOW() WHERE id = v_new_menu_item_id;
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;


-- Trigger per chiamare la funzione ad ogni modifica sulla tabella "transaction"
DROP TRIGGER IF EXISTS trg_inventory_on_transaction ON "transaction";
CREATE TRIGGER trg_inventory_on_transaction
AFTER INSERT OR UPDATE OR DELETE ON "transaction"
FOR EACH ROW
EXECUTE FUNCTION fn_inventory_adjust_on_transaction();

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
    
CREATE TRIGGER update_participation_updated_at 
    BEFORE UPDATE ON participation
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_event_staff_updated_at 
    BEFORE UPDATE ON event_staff
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE FUNCTION update_updated_at_column_staff_user()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS update_staff_user_updated_at ON staff_user;
CREATE TRIGGER update_staff_user_updated_at
    BEFORE UPDATE ON staff_user
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column_staff_user();

-- ============================================
-- AUTOMAZIONE INVITI STAFF (event_staff <-> staff_user)
-- ============================================

-- 1. Trigger su event_staff: Quando creo un invito (staff_user_id NULL, mail NOT NULL)
--    Cerco se esiste già uno staff_user con quella mail e lo collego.
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

DROP TRIGGER IF EXISTS trg_link_invite_to_staff_user ON event_staff;
CREATE TRIGGER trg_link_invite_to_staff_user
    BEFORE INSERT OR UPDATE ON event_staff
    FOR EACH ROW
    EXECUTE FUNCTION fn_link_invite_to_staff_user();


-- 2. Trigger su staff_user: Quando un utente si iscrive o cambia email
--    Cerca se ci sono inviti pendenti (event_staff con quella mail e staff_user_id NULL)
--    e li collega a questo utente.
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

DROP TRIGGER IF EXISTS trg_link_staff_user_to_invite ON staff_user;
CREATE TRIGGER trg_link_staff_user_to_invite
    AFTER INSERT OR UPDATE ON staff_user
    FOR EACH ROW
    EXECUTE FUNCTION fn_link_staff_user_to_invite();

-- ============================================
-- HELPER FUNCTIONS per RLS (VERSIONE AGGIORNATA)
-- ============================================

-- Helper: UUID dell'utente chiamante (supporta auth.uid() e jwt.claims.user_id)
CREATE OR REPLACE FUNCTION public._caller_uuid()
RETURNS uuid
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT COALESCE(
        NULLIF(current_setting('jwt.claims.user_id', true), '')::uuid,
        NULLIF(auth.uid()::text, '')::uuid
    );
$$ SECURITY DEFINER;

-- Funzione: Verifica se l'utente è admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN 
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM event_staff es
        JOIN role r ON es.role_id = r.id
        WHERE es.staff_user_id = public._caller_uuid()
        AND lower(r.name) = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funzione: Ottieni il ruolo staff per un evento specifico
CREATE OR REPLACE FUNCTION public.get_event_staff_role(event_uuid UUID)
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
      AND es.staff_user_id = public._caller_uuid()
    LIMIT 1;
    
    RETURN staff_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ottieni il livello numerico (1/2/3) del role dello staff sull'evento
CREATE OR REPLACE FUNCTION public.get_event_staff_level(event_uuid UUID)
RETURNS INT 
SET search_path = public
AS $$
DECLARE
    staff_role TEXT;
BEGIN
    staff_role := get_event_staff_role(event_uuid);
    
    RETURN CASE lower(COALESCE(staff_role,''))
        WHEN 'staff1' THEN 1
        WHEN 'staff2' THEN 2
        WHEN 'staff3' THEN 3
        WHEN 'admin'  THEN 4
        ELSE NULL
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Funzione: Verifica se utente ha almeno un certo livello staff per un evento
CREATE OR REPLACE FUNCTION public.has_event_staff_level(event_uuid UUID, min_level INT)
RETURNS BOOLEAN 
SET search_path = public
AS $$
BEGIN
    RETURN COALESCE(get_event_staff_level(event_uuid), 0) >= COALESCE(min_level, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funzione: Verifica se l'utente è staff di un evento (qualsiasi livello)
CREATE OR REPLACE FUNCTION public.is_event_staff(event_uuid UUID)
RETURNS BOOLEAN 
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM event_staff es
        WHERE es.event_id = event_uuid
          AND es.staff_user_id = public._caller_uuid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funzione: Verifica se l'utente è creatore dell'evento
CREATE OR REPLACE FUNCTION public.is_event_creator(event_uuid UUID)
RETURNS BOOLEAN 
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM event e
        WHERE e.id = event_uuid
          AND e.created_by = public._caller_uuid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper: ritorna il nome del ruolo dato role.id
CREATE OR REPLACE FUNCTION public.es_role_name(role_input TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN role_input IS NULL THEN NULL
    WHEN role_input ~ '^\s*\d+\s*$' THEN (SELECT name FROM role WHERE id = role_input::int)
    ELSE role_input
  END;
$$;

CREATE OR REPLACE FUNCTION public.es_role_name(role_input INT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT name FROM role WHERE id = role_input LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public._role_rank(role_text TEXT)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE LOWER(COALESCE(role_text,''))
        WHEN 'admin' THEN 4
        WHEN 'staff3' THEN 3
        WHEN 'staff2' THEN 2
        WHEN 'staff1' THEN 1
        ELSE 0
    END;
$$;

-- 1) TEXT,TEXT implementation (canonical)
CREATE OR REPLACE FUNCTION public.is_negative_role_change(old_role TEXT, new_role TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT public._role_rank(public.es_role_name(COALESCE(new_role, '')))
       <= public._role_rank(public.es_role_name(COALESCE(old_role, '')));
$$;

-- 2) INT,INT overload (wrapper)
CREATE OR REPLACE FUNCTION public.is_negative_role_change(old_role INT, new_role INT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT public.is_negative_role_change(
    public.es_role_name(COALESCE(old_role::text, '')),
    public.es_role_name(COALESCE(new_role::text, ''))
  );
$$;

CREATE POLICY event_staff_self_negative_update ON event_staff
FOR UPDATE TO authenticated
USING (staff_user_id = auth.uid()::uuid)
WITH CHECK (
    staff_user_id = auth.uid()::uuid
    AND public._role_rank(public.es_role_name(event_staff.role_id)) >= 
        public._role_rank(public.es_role_name((SELECT role_id FROM event_staff es WHERE es.id = event_staff.id)))
);




-- ============================================
-- ABILITA RLS SU TUTTE LE TABELLE
-- ============================================

ALTER TABLE IF EXISTS event_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS event ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS participation ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS person ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS menu ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS transaction ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS staff_user ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS staff_user
-- ============================================

-- 2.0 POLICY: SELECT - permettere a ciascuno di leggere il proprio record
CREATE POLICY staff_user_select_own ON staff_user
FOR SELECT
TO authenticated
USING (
    id = auth.uid()
);

-- 2.1 POLICY: UPDATE - permettere a ciascuno di aggiornare il proprio record
CREATE POLICY staff_user_update_own ON staff_user
FOR UPDATE
TO authenticated
USING (
    id = auth.uid()
)
WITH CHECK (
    id = auth.uid()
);

-- ============================================
-- RLS event_staff
-- ============================================

-- 3.0 POLICY: SELECT - permettere a ciascuno di leggere i propri record
CREATE POLICY event_staff_select_own ON event_staff
FOR SELECT
TO authenticated
USING (
    staff_user_id = auth.uid()::uuid
);

-- 3.1 POLICY: consentire INSERT per chi è admin o per il sistema (admin crea assegnazioni),
-- ma lasciare che l'app usi ruolo admin per inserire. Qui diamo permesso GENERICO a utenti autenticati:
CREATE POLICY event_staff_insert_for_authenticated ON event_staff 
FOR INSERT TO authenticated 
WITH CHECK (
    -- Chi inserisce deve essere autenticato (auth.uid() IS NOT NULL è implicito in TO authenticated, ma ok)
    -- E deve avere i permessi (gestiti da logica app o altre policy, ma qui lasciamo aperto l'inserimento tecnico)
    -- Nota: idealmente dovremmo controllare che chi inserisce sia staff >= 2 dell'evento, 
    -- ma in INSERT non possiamo accedere facilmente a NEW.event_id in una subquery sulla stessa tabella se non con logiche complesse.
    -- Per ora manteniamo la policy lasca come prima, ma l'app deve garantire i controlli.
    auth.uid() IS NOT NULL
);

-- 3.2 POLICY: permettere a ciascuno di cancellare la propria riga (rimuoversi dall'evento)
CREATE POLICY event_staff_self_delete ON event_staff
FOR DELETE TO authenticated
USING (staff_user_id = auth.uid()::uuid);

-- 3.4 POLICY: permettere a chi ha ruolo superiore di modificare/eliminare ruoli inferiori sullo stesso evento
-- Modifica (UPDATE) di altre righe: richiesto rank > rank(target)
CREATE POLICY event_staff_hierarchy_update ON event_staff
FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM event_staff myes
        WHERE myes.event_id = event_staff.event_id
          AND myes.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(myes.role_id)) > public._role_rank(public.es_role_name(event_staff.role_id))
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM event_staff myes
        WHERE myes.event_id = event_staff.event_id
          AND myes.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(myes.role_id)) > public._role_rank(public.es_role_name(event_staff.role_id))
    )
);

-- 3.5 POLICY: permettere delete di altre righe solo se il chiamante ha rank > target rank
CREATE POLICY event_staff_hierarchy_delete ON event_staff
FOR DELETE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM event_staff myes
        WHERE myes.event_id = event_staff.event_id
          AND myes.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(myes.role_id)) > public._role_rank(es_role_name(event_staff.role_id))
    )
);

-- ============================================
-- RLS participation
-- ============================================

-- 4.1 Lettura: staff1+ possono leggere le partecipazioni del loro evento
CREATE POLICY participation_select_by_event_staff ON participation
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = participation.event_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 1
    )
);

-- 4.2 Inserimento: staff2+ possono creare partecipazioni
CREATE POLICY participation_insert_staff2 ON participation
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = participation.event_id  -- Cambiato da NEW.event_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
);

-- 4.3 UPDATE: staff2+ possono aggiornare partecipazioni
CREATE POLICY participation_update_staff2 ON participation
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = participation.event_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
);

-- 4.4 DELETE: staff2+ possono cancellare partecipazioni
CREATE POLICY participation_delete_staff2 ON participation
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = participation.event_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
);

-- ============================================
-- RLS menu
-- ============================================

-- SELECT: tutti gli staff (>=1) possono leggere
CREATE POLICY menu_select_by_staff ON menu
FOR SELECT
TO authenticated
USING (
    EXISTS (SELECT 1 FROM event_staff es WHERE es.event_id = menu.event_id AND es.staff_user_id = auth.uid()::uuid AND public._role_rank(es_role_name(es.role_id)) >= 1)
);

-- INSERT: staff2+
CREATE POLICY menu_insert_staff2 ON menu
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM event_staff es 
        WHERE es.event_id = menu.event_id  -- Cambiato da NEW.event_id
          AND es.staff_user_id = auth.uid()::uuid 
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
);

-- UPDATE: staff2+
CREATE POLICY menu_update_staff2 ON menu
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM event_staff es 
        WHERE es.event_id = menu.event_id 
          AND es.staff_user_id = auth.uid()::uuid 
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM event_staff es 
        WHERE es.event_id = menu.event_id  -- Cambiato da NEW.event_id
          AND es.staff_user_id = auth.uid()::uuid 
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
);

-- DELETE: staff2+
CREATE POLICY menu_delete_staff2 ON menu
FOR DELETE
TO authenticated
USING (
    EXISTS (SELECT 1 FROM event_staff es WHERE es.event_id = menu.event_id AND es.staff_user_id = auth.uid()::uuid AND public._role_rank(es_role_name(es.role_id)) >= 2)
);

-- ============================================
-- RLS transaction
-- ============================================

-- SELECT: staff1+ possono leggere transazioni collegate a un evento dove sono staff
CREATE POLICY transaction_select_by_staff ON transaction
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.id = transaction.participation_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 1
    )
);

-- INSERT: staff1+ possono creare una transaction solo se la participation appartiene a un evento su cui sono staff
CREATE POLICY transaction_insert_staff1 ON transaction
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.id = transaction.participation_id  -- Cambiato da NEW.participation_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 1
    )
);

-- UPDATE: staff2+ (correzioni) — usare la participation collegata alla riga (vecchia o nuova)
CREATE POLICY transaction_update_staff2 ON transaction
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.id = transaction.participation_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.id = transaction.participation_id  -- Cambiato da NEW.participation_id a transaction.participation_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
);

-- DELETE: staff2+ possono cancellare transazioni legate al loro evento
CREATE POLICY transaction_delete_staff2 ON transaction
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.id = transaction.participation_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
);

-- ============================================
-- RLS person
-- ============================================

-- SELECT: Staff può leggere persone che hanno una participation per eventi dove sono staff
CREATE POLICY person_select_by_staff ON person
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.person_id = person.id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 1
    )
);

-- INSERT: consentiamo a staff2+ di creare persone (non possiamo verificare event qui perché person non ha event_id)
CREATE POLICY person_insert_staff2 ON person
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
);

-- UPDATE: staff2+ possono aggiornare persone se esiste una participation che lega quella person a un evento di cui sono staff
CREATE POLICY person_update_staff2 ON person
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.person_id = person.id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.person_id = person.id  -- Cambiato da NEW.id a person.id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
);

-- DELETE: staff2+ possono cancellare persone legate al loro evento tramite participation
CREATE POLICY person_delete_staff2 ON person
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.person_id = person.id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(es_role_name(es.role_id)) >= 2
    )
);

-- ============================================
-- REALTIME event
-- ============================================

-- SELECT: Unified policy - user is creator OR staff (any level)
CREATE POLICY event_select_unified ON event
FOR SELECT
TO authenticated
USING (
    created_by = auth.uid()::uuid
    OR
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = event.id
          AND es.staff_user_id = auth.uid()::uuid
    )
);

-- UPDATE: staff3+ possono aggiornare event
CREATE POLICY event_update_staff3 ON event
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM event_staff es 
        WHERE es.event_id = event.id 
          AND es.staff_user_id = auth.uid()::uuid 
          AND public._role_rank(es_role_name(es.role_id)) >= 3
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM event_staff es 
        WHERE es.event_id = event.id
          AND es.staff_user_id = auth.uid()::uuid 
          AND public._role_rank(es_role_name(es.role_id)) >= 3
    )
);

-- DELETE: solo admin (rank 4)
CREATE POLICY event_delete_admin_only ON event
FOR DELETE
TO authenticated
USING (
    EXISTS (SELECT 1 FROM event_staff es WHERE es.event_id = event.id AND es.staff_user_id = auth.uid()::uuid AND public._role_rank(es_role_name(es.role_id)) = 4)
);


-- ============================================
-- REALTIME PUBLICATION
-- ============================================

-- Abilita realtime per aggiornamenti in tempo reale
ALTER PUBLICATION supabase_realtime ADD TABLE transaction;
ALTER PUBLICATION supabase_realtime ADD TABLE participation;

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

-- ============================================
-- FIX: RLS UNRESTRICTED TABLES (INTEGRATED)
-- ============================================

-- 1. TABELLE DI LOOKUP (Sola lettura per authenticated)
-- ====================================================

ALTER TABLE IF EXISTS role ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS participation_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS transaction_type ENABLE ROW LEVEL SECURITY;

-- Policy: SELECT per tutti gli utenti autenticati
CREATE POLICY role_select_auth ON role FOR SELECT TO authenticated USING (true);
CREATE POLICY participation_status_select_auth ON participation_status FOR SELECT TO authenticated USING (true);
CREATE POLICY transaction_type_select_auth ON transaction_type FOR SELECT TO authenticated USING (true);

-- 2. MENU_ITEM (Contesto Evento)
-- ==============================
ALTER TABLE IF EXISTS menu_item ENABLE ROW LEVEL SECURITY;

-- SELECT: Staff Level >= 1 (tramite menu -> event)
CREATE POLICY menu_item_select_staff ON menu_item
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM menu m
        JOIN event_staff es ON es.event_id = m.event_id
        WHERE m.id = menu_item.menu_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 1
    )
);

-- INSERT/UPDATE/DELETE: Staff Level >= 2
CREATE POLICY menu_item_modify_staff ON menu_item
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM menu m
        JOIN event_staff es ON es.event_id = m.event_id
        WHERE m.id = menu_item.menu_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 2
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM menu m
        JOIN event_staff es ON es.event_id = m.event_id
        WHERE m.id = menu_item.menu_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 2
    )
);

-- 3. PARTICIPATION_STATUS_HISTORY (Contesto Evento)
-- =================================================
ALTER TABLE IF EXISTS participation_status_history ENABLE ROW LEVEL SECURITY;

-- SELECT: Staff Level >= 1 (tramite participation -> event)
CREATE POLICY part_history_select_staff ON participation_status_history
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.id = participation_status_history.participation_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 1
    )
);

-- INSERT/UPDATE/DELETE: Staff Level >= 2
CREATE POLICY part_history_modify_staff ON participation_status_history
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.id = participation_status_history.participation_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 2
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM participation p
        JOIN event_staff es ON es.event_id = p.event_id
        WHERE p.id = participation_status_history.participation_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 2
    )
);

-- 4. EVENT_SETTINGS (Contesto Evento)
-- ===================================
ALTER TABLE IF EXISTS event_settings ENABLE ROW LEVEL SECURITY;

-- SELECT: Staff Level >= 1
CREATE POLICY event_settings_select_staff ON event_settings
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = event_settings.event_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 1
    )
);

-- UPDATE: Staff Level >= 3 (Coerente con event update)
CREATE POLICY event_settings_update_staff ON event_settings
FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = event_settings.event_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 3
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = event_settings.event_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 3
    )
);

-- 5. VISTE (Security Invoker)
-- ===========================
ALTER VIEW participation_stats SET (security_invoker = true);
ALTER VIEW person_with_age SET (security_invoker = true);


-- ============================================
-- PERMISSIONS (GRANT)
-- ============================================

-- 1. Tabelle di Lookup
GRANT SELECT ON TABLE role TO authenticated;
GRANT SELECT ON TABLE participation_status TO authenticated;
GRANT SELECT ON TABLE transaction_type TO authenticated;

-- 2. Tabelle Core
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE staff_user TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE event TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE event_staff TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE person TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE event_settings TO authenticated;

-- 3. Tabelle Menu & Transazioni
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE menu TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE menu_item TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE participation TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE participation_status_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE transaction TO authenticated;

-- 4. Viste
GRANT SELECT ON TABLE participation_stats TO authenticated;
GRANT SELECT ON TABLE person_with_age TO authenticated;

-- 5. Service Role (Accesso completo)
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- 6. Sequenze
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================
-- FIX: INSERT POLICIES (Added post-initial setup)
-- ============================================

-- Fix missing INSERT policy for event table
CREATE POLICY event_insert_authenticated ON event
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid()::uuid = created_by
);

-- Fix missing INSERT policy for event_settings table
CREATE POLICY event_settings_insert_staff ON event_settings
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = event_settings.event_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 3
    )
    OR
    -- Allow creator of the event to insert settings even if not yet in event_staff
    EXISTS (
        SELECT 1 FROM event e
        WHERE e.id = event_settings.event_id
          AND e.created_by = auth.uid()::uuid
    )
);

-- Fix RLS Policy per la tabella person
-- Esegui questo script nell'editor SQL di Supabase per risolvere l'errore 42501

DROP POLICY IF EXISTS person_insert_staff2 ON person;

CREATE POLICY person_insert_authenticated ON person
FOR INSERT
TO authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS person_select_by_staff ON person;

CREATE POLICY person_select_by_staff ON person
FOR SELECT
TO authenticated
USING (true);

