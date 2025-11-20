-- ============================================
-- SCRIPT DI ESEMPIO PER POPOLARE IL DB
-- ============================================
-- Questo script utilizza un blocco DO anonimo per gestire le variabili e le dipendenze tra gli ID.
-- Presuppone che l'utente che esegue lo script sia autenticato (auth.uid() non nullo) 
-- e che il suo ID esista in auth.users.

DO $$
DECLARE
    v_user_id UUID;      -- L'ID dello staff user (preso da auth.uid())
    v_event_id UUID;     -- L'ID dell'evento creato
    v_menu_id UUID;      -- L'ID del menu creato
    v_person_id UUID;    -- L'ID della persona creata
BEGIN
    -- 1. RECUPERA L'UTENTE CORRENTE
    -- Se esegui questo script dalla dashboard SQL di Supabase, auth.uid() potrebbe essere null.
    -- In quel caso, sostituisci auth.uid() con un UUID valido di auth.users.
    v_user_id := auth.uid();
    
    -- Fallback per test se auth.uid() è null (Sostituisci con un UUID reale se necessario)
    -- IF v_user_id IS NULL THEN
    --    v_user_id := '00000000-0000-0000-0000-000000000000'; 
    -- END IF;

    IF v_user_id IS NULL THEN
        RAISE NOTICE 'Attenzione: auth.uid() è NULL. Impossibile creare dati collegati a uno staff user specifico senza un ID valido.';
        -- Per scopi dimostrativi, ci fermiamo qui se non c'è un utente.
        -- Decommenta la riga sotto se vuoi forzare un ID per test
        -- v_user_id := 'tuo-uuid-qui';
        RETURN;
    END IF;

    RAISE NOTICE 'Utilizzando User ID: %', v_user_id;

    -- 2. CREA/AGGIORNA LO STAFF USER
    -- Normalmente creato dal trigger su auth.users, ma lo forziamo per sicurezza
    INSERT INTO staff_user (id, first_name, last_name, email, is_active)
    VALUES (v_user_id, 'Admin', 'User', 'admin@fester.app', TRUE)
    ON CONFLICT (id) DO UPDATE 
    SET is_active = TRUE; -- Assicuriamoci che sia attivo

    -- 3. CREA UN EVENTO
    INSERT INTO event (name, description, created_by)
    VALUES ('Fester Launch Party', 'L evento di lancio ufficiale di Fester 3.0', v_user_id)
    RETURNING id INTO v_event_id;

    RAISE NOTICE 'Evento creato con ID: %', v_event_id;

    -- 4. CREA LE IMPOSTAZIONI DELL'EVENTO
    INSERT INTO event_settings (
        event_id, 
        start_at, 
        end_at, 
        location, 
        created_by,
        max_participants,
        allow_guests
    )
    VALUES (
        v_event_id, 
        NOW() + INTERVAL '1 day', -- Inizia domani
        NOW() + INTERVAL '1 day' + INTERVAL '8 hours', -- Dura 8 ore
        'Rooftop Bar Milano', 
        v_user_id,
        150,
        TRUE
    );

    -- 5. ASSEGNA LO STAFF ALL'EVENTO (L'utente creatore diventa Admin dell'evento)
    INSERT INTO event_staff (event_id, staff_user_id, role_id)
    VALUES (
        v_event_id,
        v_user_id,
        (SELECT id FROM role WHERE name = 'admin')
    );

    -- 6. CREA UN MENU
    INSERT INTO menu (event_id, name, created_by)
    VALUES (v_event_id, 'Cocktail Bar', v_user_id)
    RETURNING id INTO v_menu_id;

    -- 7. AGGIUNGI VOCI AL MENU
    INSERT INTO menu_item (menu_id, transaction_type_id, name, description, price, available_quantity)
    VALUES 
    (v_menu_id, (SELECT id FROM transaction_type WHERE name = 'drink'), 'Negroni', 'Gin, Vermouth Rosso, Campari', 8.00, 100),
    (v_menu_id, (SELECT id FROM transaction_type WHERE name = 'drink'), 'Spritz', 'Aperol/Campari, Prosecco, Soda', 6.00, 150),
    (v_menu_id, (SELECT id FROM transaction_type WHERE name = 'drink'), 'Acqua', 'Naturale o Frizzante', 2.00, NULL); -- NULL = illimitata

    -- 8. CREA UNA PERSONA (PARTECIPANTE)
    -- Simuliamo un utente che si è registrato o è stato invitato
    INSERT INTO person (first_name, last_name, email, phone)
    VALUES ('Mario', 'Rossi', 'mario.rossi@test.com', '+393331234567')
    RETURNING id INTO v_person_id;

    -- 9. AGGIUNGI LA PARTECIPAZIONE
    INSERT INTO participation (person_id, event_id, status_id, role_id)
    VALUES (
        v_person_id, 
        v_event_id, 
        (SELECT id FROM participation_status WHERE name = 'confirmed'),
        (SELECT id FROM role WHERE name = 'guest')
    );

    RAISE NOTICE 'Dati di esempio inseriti correttamente!';
END $$;
