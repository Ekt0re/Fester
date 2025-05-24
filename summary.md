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