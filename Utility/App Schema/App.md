# Struttura App FESTER 3.0

## 📱 Architettura Pagine

### 🔐 Autenticazione
- **Login**
  - Email/Password
  - Link a registrazione
  - Recupero password
  
- **Registrazione**
  - Dati anagrafici
    - nome, cognome, data di nascita.
    - Link accesso
  - Dati di contatto
    - email, telefono
  - Password
    - password e Accettazione termini e condizioni
  - Attendi conferma account da supabase


- **Recupero Password**
  - Inserimento email/numero telefono
  - Invio link reset

---

### 🏠 Elenco eventi

- **Lista Eventi**
  - Visualizzazione eventi disponibili
  - Filtri: eventi futuri, passati, in programma
  - Card evento con: nome, data, location, icona livello staff(Staff3, staff2, staff1)
  - Menù a tendina: "Visualizza eventi passati"
  - Pulsanti rapidi: "Crea evento"

---

### 🎉 Gestione Eventi

#### **Creazione Evento**
- Crea evento
    - Nome e descrizione
- Info evento
    - Impostazioni temporali (data/ora inizio/fine)
    - Location
- Impostazioni check-in
    - Restrizioni età
    - Limite partecipanti
    - Impostazioni drink (limiti per ruolo)
- Aggiungi Staff
    - Link di invito staff
    - Aggiungi manuale
        - Popup: Aggiunta mail e password
- Aggiungi munù e preziario
- Creazione evento

#### **Gestione Evento Dashboard** 
- Card Staff Member
    - Benvenuto, Nome
    - Minuti da ultimo sync con database
- Impostazioni: modifica    parametri evento
- Widget Card
    - Gestione Partecipanti
    - Elenco consumazioni
    - Gestione Staff
    - Gestione Statistiche
- Bottone scan QR
- Tab navigation:
  - **Gestione Partecipanti**
  - **Allert evento**
  - **Dashboard**
  - **Statistiche**
  - **Gestione bar**

---

### 👥 Gestione Partecipanti

- **Lista Partecipanti**
  - Ricerca per nome, cognome, Id, QR CODE
  - Filtri per status (invited, confirmed, inside, outside, cancelled)
  - Azioni rapide: check-in, cambio status, aggiungi transazione

- **Dettaglio Partecipante**
  - Immagine profilo
  - Dati anagrafici
  - Status attuale + menù a tendina storico cambi status
  - Statistiche: drink_count, sanction_count, total_amount
  - Visualizza opzioni di contatto
  - Area Segnalazioni: Visuallizza i flag, le segnalazioni ecc che ha un account. 
  - Menù a tendina: Lista transazioni personali
  - Pulsanti azione (in base a ruolo):
    - Cambia status
    - Aggiungi drink/transazione
    - Aggiungi sanzione
    - Visualizza storico completo
    - Modifica dati anagrafici

- **Aggiungi Partecipante**
  - Creazione nuova persona
  - Selezione status iniziale
  - Campo "invitato da" (opzionale)

---

### 🍹 Gestione bar

- **Nuova Transazione** 
  - Selezione partecipante (scanner/ricerca)
  - Scelta tipo transazione (drink, food, ticket, fine, sanction)
  - Selezione da menu o inserimento manuale
  - Quantità
  - Note (obbligatorie per sanzioni)
  - Verifica limiti drink automatica

- **Storico Transazioni**
  - Filtri: tipo, periodo, partecipante, staff
  - Visualizzazione: timestamp, tipo, nome item, quantità, importo, creato da
  - Ricerca

---

### 📋 Gestione Menu

- **Lista Menu**
  - Visualizzazione menu creati
  - Ricerca
  - Pulsante crea nuovo menu

- **Dettaglio Menu**
  - Nome e descrizione
  - Lista menu items ordinati (sort_order)
  - Toggle disponibilità items
  - Modifica/elimina items
  - Aggiungi nuovo item

- **Crea/Modifica Menu Item**
  - Nome e descrizione
  - Tipo transazione (drink, food, ticket, ecc.)
  - Prezzo
  - Disponibilità
  - Ordinamento

---

### 📦 Inventario

- **Gestione Inventario Evento**
  - Lista items del menu evento
  - Per ogni item:
    - Nome
    - Quantità disponibile iniziale
    - Quantità consumata
    - Quantità rimanente (calcolata)
    - Alert per scorte basse
  - Modifica quantità disponibili
  - Visualizzazione real-time aggiornamenti

---

### 👤 Profilo Utente

- **Il Mio Profilo**
  - Visualizzazione dati personali
  - Upload/modifica foto profilo
  - Ruolo attuale (visualizzazione)
  - Modifica dati anagrafici
  - Cambio password
  - Logout

- **Storico Personale**
  - Eventi a cui ho partecipato
  - Totale consumi per evento
  - Sanzioni ricevute
  - Statistiche aggregate

---

### ⚙️ Impostazioni

#### **Impostazioni Generali App** (admin/staff3)
- Gestione ruoli sistema
- Configurazioni globali
- Log sistema

#### **Impostazioni Evento** (staff3)
- Modifica tutte le impostazioni evento
- Gestione menu associato
- Configurazione inventario iniziale
- Impostazioni avanzate (custom_settings)

#### **Impostazioni APP** 
- Tema
- Lingua
- Forza/test sync con DB
- Info app

---


### 📊 Report e Statistiche

- **Dashboard Analitica**
  - Report evento:
    - Incassi totali
    - Consumi per tipologia
    - Partecipazione (trend check-in)
    - Top consumers
    - Sanzioni totali
  - Export dati (CSV/PDF)
  - Grafici real-time

---

## 🔧 Funzionalità Principali

### Core Features

1. **Autenticazione e Autorizzazione**
   - Login/Registrazione via Supabase Auth
   - Gestione ruoli con RLS
   - Permessi gerarchici (guest → staff1 → staff2 → staff3 → admin)

2. **Gestione Eventi**
   - Creazione/modifica/eliminazione eventi
   - Impostazioni avanzate (limiti, check-in, età)
   - Associazione menu
   - Inventario per evento

3. **Check-in Dinamico**
   - QR code scanner
   - Ricerca manuale
   - Cambio status partecipanti
   - Storico movimenti (inside/outside)

4. **Sistema Transazioni Real-time**
   - Registrazione drink/food
   - Controllo automatico limiti drink per ruolo
   - Sanzioni e report
   - Aggiornamento inventario automatico
   - Calcolo totali in tempo reale

5. **Gestione Menu e Inventario**
   - CRUD menu e menu items
   - Associazione menu-evento
   - Tracking inventario con consumed_quantity
   - Alert scorte basse

6. **Permessi Multi-livello**
   - **Admin**: controllo totale sistema
   - **Staff3**: gestione eventi, utenti, menu
   - **Staff2**: gestione partecipanti, menu, transazioni
   - **Staff1**: solo transazioni e lettura

7. **Real-time Updates**
   - Supabase Realtime per:
     - Transazioni
     - Partecipazioni
     - Inventario
   - Aggiornamenti istantanei su tutti i device

8. **Statistiche e Report**
   - Views SQL pre-calcolate (participation_stats, person_with_age)
   - Dashboard analitiche
   - Export dati

---

## 🎨 Componenti UI Riutilizzabili

- **Cards**: EventCard, ParticipantCard, TransactionCard, MenuItemCard
- **Dialogs**: AddTransactionDialog, ChangeStatusDialog, SanctionDialog
- **Bottoms Sheets**: FilterSheet, ParticipantActionsSheet
- **Lists**: DismissibleList (swipe actions), InfiniteScrollList
- **Forms**: DynamicForm con validazione
- **Scanner**: QRCodeScanner per check-in
- **Charts**: RealtimeChart per dashboard
- **Badges**: StatusBadge, NotificationBadge
- **Avatar**: UserAvatar con fallback
- **EmptyStates**: illustrazioni per liste vuote

---

## 🔔 Notifiche e Real-time

- Push notifications per:
  - Invito a evento
  - Utente riceve sanzione
  - Aggiornamenti evento
- Real-time listener su tabelle critiche
- Badge counter per notifiche non lette

---

## 🔒 Sicurezza

- Row Level Security (RLS) su tutte le tabelle
- Helper functions per verifica permessi
- Soft delete per dati sensibili
- Validazione input client e server-side
- Gestione errori con fallback

---

## 📱 Navigazione App

```
├── Auth Flow (non autenticato)
│   ├── Login
│   ├── Registrazione
│   └── Recupero Password
│
└── Main App (autenticato)
    ├── Bottom Navigation
    │   ├── Home (Lista Eventi)
    │   ├── Profilo
    │   └── Impostazioni (solo admin/staff)
    │
    ├── Event Flow
    │   ├── Dettaglio Evento
    │   ├── Gestione Evento (organizzatore/staff)
    │   │   ├── Dashboard
    │   │   ├── Partecipanti
    │   │   ├── Check-in
    │   │   ├── Transazioni
    │   │   └── Inventario
    │   └── Crea/Modifica Evento
    │
    ├── Menu Flow
    │   ├── Lista Menu
    │   ├── Dettaglio Menu
    │   └── Crea/Modifica Item
    │
    ├── User Management (admin/staff3)
    │   ├── Lista Utenti
    │   └── Dettaglio Utente
    │
    └── Report (admin/staff)
        └── Dashboard Analitica
```