# Fester - Stato di Implementazione

## Panoramica
Fester è un'applicazione per la gestione di eventi implementata secondo i requisiti specificati. L'applicazione consente agli utenti di creare e gestire eventi, invitare ospiti, monitorare le presenze tramite QR code e visualizzare statistiche.

## Componenti

### Backend (Node.js/Express)
- [x] Configurazione di base del server Express
- [x] Integrazione con Supabase (database e autenticazione)
- [x] API per l'autenticazione (login, registrazione, gestione profilo)
- [x] API per la gestione degli eventi (CRUD)
- [x] API per la gestione degli ospiti (CRUD)
- [x] API per il check-in tramite QR code
- [x] Middleware per l'autenticazione JWT
- [x] Gestione degli errori
- [x] Validazione input
- [x] Utilizzo di variabili di ambiente (.env)
- [ ] Test delle API

### Frontend (Flutter)
- [x] Configurazione di base dell'app Flutter
- [x] Integrazione con Supabase
- [x] BLoC per la gestione dello stato
- [x] Routing con go_router
- [x] Schermate di autenticazione (login, registrazione)
- [x] Schermata principale (dashboard)
- [x] Schermata di dettaglio evento
- [x] Schermata di creazione/modifica evento
- [x] Schermata di gestione degli ospiti
- [x] Schermata di scansione QR code
- [x] Schermata profilo utente
- [x] Utilizzo di variabili di ambiente (.env)
- [ ] Miglioramenti UI/UX
- [ ] Test del frontend

### Database (Supabase)
- [x] Schema per utenti
- [x] Schema per eventi
- [x] Schema per ospiti
- [x] Relazioni tra le tabelle
- [x] Politiche di sicurezza
- [x] Funzioni e trigger

## Librerie utilizzate

### Backend
- Express.js (server web)
- Supabase (database e autenticazione)
- JWT (autenticazione)
- Joi (validazione)
- Cors (gestione CORS)
- Morgan (logging)
- dotenv (gestione variabili di ambiente)

### Frontend
- Flutter (framework UI)
- flutter_bloc (gestione stato)
- go_router (routing)
- dio (client HTTP)
- supabase_flutter (integrazione con Supabase)
- reactive_forms (gestione form)
- qr_flutter (generazione QR code)
- mobile_scanner (scansione QR code)
- fl_chart (grafici per statistiche)
- flutter_secure_storage (storage sicuro)
- flutter_dotenv (gestione variabili di ambiente)

## Funzionalità implementate
- [x] Autenticazione utente (registrazione, login, gestione profilo)
- [x] Creazione e gestione eventi
- [x] Aggiunta e gestione ospiti
- [x] Generazione QR code per ospiti
- [x] Check-in ospiti tramite scansione QR code
- [x] Visualizzazione statistiche evento
- [x] Dashboard con riepilogo eventi e dati
- [x] Interfaccia utente reattiva
- [x] Configurazione multi-ambiente (dev, staging, prod)

## Da completare
- [ ] Gestione delle notifiche
- [ ] Miglioramenti UX/UI
- [ ] Test completi (backend e frontend)
- [ ] Ottimizzazione delle prestazioni
- [ ] Deploy dell'applicazione

## Note tecniche
- L'applicazione segue il pattern BLoC per la gestione dello stato nel frontend
- Il backend utilizza un'architettura a livelli (routes, controllers, services, models)
- Il database è strutturato con relazioni per garantire l'integrità dei dati
- L'autenticazione è gestita tramite JWT con token di refresh
- Tutte le API sono protette con middleware di autenticazione dove necessario
- Il frontend implementa form reattivi con validazione in tempo reale
- L'applicazione utilizza variabili di ambiente (.env) per la configurazione in diversi ambienti
- Il servizio API centralizzato gestisce tutte le chiamate HTTP con Dio
- Gli elementi dell'interfaccia mostrano informazioni di debug in ambiente di sviluppo

# Riepilogo Modifiche

## Gestione ID Utente nella Creazione Eventi

### Modifiche Effettuate
- Rimosso il campo `creato_da` dai dati dell'evento nel frontend
- L'ID dell'utente viene ora gestito automaticamente dal backend attraverso il token JWT

### Motivazione
La modifica migliora la sicurezza dell'applicazione poiché:
1. Non espone l'ID dell'utente nel frontend
2. Previene la manipolazione dell'ID utente da parte del client
3. Garantisce che l'evento sia sempre associato all'utente autenticato

### Implementazione Backend
Il backend già implementa correttamente questa logica:
- Utilizza il middleware `authenticateJWT` per tutte le rotte degli eventi
- Estrae l'ID utente dal token JWT con `req.user.id`
- Applica policy di sicurezza a livello di database per garantire che solo l'utente autenticato possa creare eventi 

# Risoluzione Problema RLS per Tabella "event_users"

## Problema
L'errore "new row violates row-level security policy for table 'event_users'" si verificava durante il tentativo di aggiungere un nuovo ospite a un evento.

## Modifiche Effettuate

### 1. Modifica a `ApiService.addGuest()`
- Aggiunto controllo per verificare che l'utente corrente abbia accesso all'evento:
  ```dart
  final eventAccess = await _supabase
      .from('events')
      .select()
      .eq('id', eventId)
      .eq('creato_da', user.id);
  
  if (eventAccess.isEmpty) {
    return {
      'success': false,
      'message': 'Non hai i permessi per modificare questo evento'
    };
  }
  ```
- Rimosso il campo `is_present` che non era presente nello schema della tabella `event_users`
- Strutturato correttamente i dati per rispettare le policy RLS di Supabase

### 2. Già implementato correttamente
- La funzione `updateGuestStatus` utilizza `check_in_time` invece di `is_present` per indicare lo stato di presenza di un ospite
- Nel bloc, la funzione `_onEventGuestsRequested` determina correttamente `isPresent` basandosi sul valore di `check_in_time`

## Come Funziona Ora
- Prima di inserire o aggiornare un record nella tabella `event_users`, il sistema verifica che l'utente corrente sia il creatore dell'evento
- Gli stati di presenza degli ospiti vengono gestiti attraverso il campo `check_in_time` invece di `is_present`
- Le operazioni di upsert (insert o update) vengono gestite correttamente, verificando prima l'esistenza di record duplicati

## Policy RLS Rispettate
- insert_event_users
- update_event_users
- delete_event_users 