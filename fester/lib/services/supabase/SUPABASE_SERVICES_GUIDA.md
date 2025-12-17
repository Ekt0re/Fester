# Guida Tecnica Completa: Libreria `@SupabaseServicies`

## Indice
- [Introduzione](#introduzione)
- [Struttura dei servizi](#struttura-dei-servizi)
- [Classi principali](#classi-principali)
  - [EventService](#eventservice)
  - [AuthGuard / AuthMiddleware](#authguard--authmiddleware)
  - [DeepLinkHandler](#deeplinkhandler)
  - [ParticipationService](#participationservice)
  - [PersonService](#personservice)
  - [StaffUserService](#staffuserservice)
  - [AuthService](#authservice)
  - [SupabaseConfig](#supabaseconfig)
  - [TransactionService](#transactionservice)
- [Models](#models)
- [Collegamento con Database (Supabase 3.0.sql)](#collegamento-con-database)

---

## Introduzione
Questa guida descrive in dettaglio tutte le classi, i metodi pubblici, parametri, ritorni e il legame tecnico con lo schema dati (`Supabase 3.0.sql`) per la suite di servizi `@SupabaseServicies` usata nell'app FESTER 3.0 (Flutter/Dart). È organizzata come un manuale tecnico simil-JavaDoc in italiano, pensato per uso back-end e front-end.

## Struttura dei servizi
Ogni servizio fornisce l'accesso a determinate entità/risorse Supabase/PostgreSQL. I metodi sono asincroni, usano il client Supabase, ritornano entità di dominio (model) oppure primitive.

---

## Classi principali

### EventService
Gestisce eventi e le loro impostazioni. Mapping diretto con le tabelle `event`, `event_settings`, e relazioni staff (`event_staff`).

**Metodi Principali:**
- `Future<List<Event>> getMyEvents()`
  - Restituisce tutti gli eventi dove lo user corrente è staff.
- `Future<Event?> getEventById(String eventId)`
  - Cerca evento per ID.
- `Future<Event> createEvent({required String name, String? description})`
  - Crea nuovo evento.
- `Future<Event> updateEvent(...)`
  - Aggiorna campi evento (nome, descrizione,...).
- `Future<void> deleteEvent(String eventId)`
  - Soft delete da evento (aggiorna campo deleted_at).
- `Future<EventSettings?> getEventSettings(String eventId)`
  - Ritorna impostazioni 1:1 collegate a evento.
- `Future<EventSettings> upsertEventSettings({...})`
  - Crea/aggiorna impostazioni evento (max partecipanti, limiti, orari, etc).
- `Future<List<Map<String, dynamic>>> getEventStaff(String eventId)`
  - Staff collegato all’evento (incluso join con ruoli e dati user).
- `Future<void> assignStaffToEvent({required String eventId, required String staffUserId, required int roleId})`
  - Assegna uno user staff ad un evento con ruolo specifico.
- `Future<void> removeStaffFromEvent({required String eventId, required String staffUserId})`
  - Rimuove membro staff.
- `Stream<Event> streamEvent(String eventId)`
  - Streaming realtime eventi.

**Modelli Coinvolti:**
- `Event`, `EventSettings`, `Role`, `StaffUser`

---

### AuthGuard / AuthMiddleware
Widget e middleware Flutter/dart per controllare autenticazione e verifica email utente:

- `AuthGuard(child, fallback)` — Mostra contenuto solo se autenticato.
- `AuthMiddleware.checkAuth(context)` — Redirect a /login se non autenticato.
- `AuthMiddleware.checkEmailVerified(context)` — Controllo e redirect se email non confermata.

---

### DeepLinkHandler
Gestione centralizzata dei deep link di Supabase Auth (callback email, reset password, verifica ecc.):

- `initialize(BuildContext context)` — Listener stato auth; navigation automatica.
- `handleDeepLink(BuildContext context, Uri uri)` — Gestione manuale di link.
- Private: handler per signedIn/signedOut/passwordRecovery.

---

### ParticipationService
Gestione partecipazioni a eventi, CRUD completo e statistiche:

- `getEventParticipations(eventId)` — List dettagli partecipazione evento (join persona, ruolo ecc).
- `getParticipationById(id)` — Cerca una partecipazione.
- `createParticipation({personId, eventId, statusId, ...})` — Inserisce relazione.
- `updateParticipationStatus({participationId, newStatusId})` — Aggiorna stato.
- `getParticipationStats(participationId)` — Dettagli/calcoli su drink, sanzioni, spesa...
- `checkInParticipant(participationId, checkedInStatusId)` — Aggiorna direttamente lo stato.
- `streamEventParticipations(eventId)` — Realtime join.

---

### PersonService
Gestione CRUD anagrafica utenti invitati (`person`).

- `getPersonById(personId)` — Cerca.
- `createPerson(...dati...)` — Inserisce.
- `updatePerson(...dati...)` — Aggiorna.
- `searchPersons(query)` — Ritorna lista corrispondenze (anche parziali su nome/email).
- `deletePerson(personId)` — Soft delete (is_active a false + cancella logical timestamp).

---

### StaffUserService
Gestione CRUD staff user e assegnazione eventi, ruoli, statistiche:

- `getCurrentStaffUser(), getStaffUserById(userId)` — Profilo staff corrente/a ID.
- `getAllStaffUsers()` — Solo staff attivi.
- `updateStaffUser(...)` — Aggiorna dati profili.
- `uploadProfileImage(...file...)` — Carica avatar, persiste path.
- `deleteProfileImage(...path...)` — Elimina avatar.
- `deactivateStaffUser(userId), reactivateStaffUser(userId)` — Soft delete/reactivate.
- `searchStaffUsers(query)` — Ricerca su nome/email.
- `getStaffUserEvents(userId)` — Eventi assegnati.
- `hasEventRole({userId, eventId, roleName})` — Check ruolo.
- `isAdmin()` — Check admin globale.
- `getStaffUserStats(userId)` — Statistiche su eventi, transazioni fatte.
- `streamCurrentStaffUser()` — Stream realtime.

---

### AuthService
Gestione Auth (login, signup, sessioni, reset/verify, metadati):

- `signUp({email, password, firstName, lastName, dateOfBirth, phone, redirectTo})` — Nuovo utente staff, trigger crea anche su staff_user.
- `signIn({email, password})`, `signInWithMagicLink({email, redirectTo})`
- `signOut()`
- `resetPassword({email, redirectTo})`, `updatePassword({newPassword})` — Gestione recovery.
- `resendVerificationEmail({email, redirectTo})`
- `updateUserMetadata({...})`, `updateEmail({newEmail})`
- `verifyOtp({email, token, type})`
- `isEmailVerified` (getter bool)
- `userId` (getter String?)
- `isAuthenticated` (getter bool)
- `handleDeepLink(Uri uri)` — Handler custom.
- `refreshSession()`, `deleteAccount()` (nota: delete personalizzata, richiede edge function lato Supabase)

---

### SupabaseConfig
Classe di avvio/configurazione client per Supabase (`Supabase.initialize`).
- Campi statici: url, anon key, redirect.
- Metodo: `initialize()` — chiamata una tantum in bootstrap app.
- Getter: `client` globale.

---

### TransactionService
Gestione delle transazioni economico/logistiche/prenotazioni (drink, ticket ecc).
- `getParticipationTransactions(participationId)`
- `createTransaction({participationId, transactionTypeId, ...})`
- `updateTransaction({transactionId, ...})`
- `deleteTransaction(transactionId)`
- `getEventTransactionSummary(eventId)`
- `streamParticipationTransactions(participationId)`

---

## Models
Tutti i modelli sono coerenti alle tabelle SQL qui elencate (vedi anche allegato `Supabase 3.0.sql`):

- **Event**
- **EventSettings**
- **Menu**
- **MenuItem**
- **Participation**
- **Person**
- **Role**
- **StaffUser**
- **Transaction**

Per ogni modello: Costruttore, campi pubblici, factory `fromJson(Map<String,dynamic>)`, metodo `toJson()`.

---

## Collegamento con Database
Le classi sono mappate su tabelle PostgreSQL definite in `Supabase 3.0.sql`. Ogni azione/metodo utilizza query dirette verso la struttura originale (es. insert, update, select, con mapping 1:1 tra chiave e campo model).

- Riferimento regole, constraint, vincoli, trigger esposti nel file SQL (RLS, trigger, funzioni di business, politiche di accesso).
- Ogni servizio fa match diretto con una o più tabelle/views e usa il Supabase Dart API/Flutter Client.

**Esempio relazione**
- `StaffUser` = tabella `staff_user`
- `Participation` = tabella `participation` + join con `person`, `role`, `participation_status`
- `Transaction` = tabella `transaction` + join con tipo, user, menu_item
- `Event` = tabella `event`
- `EventSettings` = tabella `event_settings`

Per il dettaglio degli schemi e delle relazioni, consultare `Supabase 3.0.sql` allegato.

---

## Nota finale
Per info dettagliate su ogni metodo, consultare i commenti inline del codice. Questo file documenta tutte le funzionalità principali e la mappatura stretta tra i servizi Supabase, i modelli Dart/Flutter e lo schema SQL descritto.
