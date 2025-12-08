# Analisi Funzionalità Mancanti - Fester 3.0

Di seguito un elenco delle funzionalità mancanti o incomplete identificate dopo un'analisi del codice sorgente attuale.

## 1. Gestione Eventi e Dashboard
- **Mappe e Geolocalizzazione**:
  - Manca l'integrazione con Google Maps o simili per selezionare la posizione dell'evento in `EventSettingsScreen`. Attualmente è solo un campo di testo.
  - Manca la visualizzazione della mappa per gli ospiti.
- **Statistiche Avanzate**:
  - `EventStatisticsScreen` è presente ma potrebbe mancare di grafici dettagliati (es. affluenza per ora, consumo drink per fascia oraria).
- **Notifiche**:
  - Sebbene ci sia un servizio, manca una UI dedicata per visualizzare lo storico delle notifiche in-app (`NotificationsScreen` da verificare se completa).

## 2. Gestione Ospiti (Guest Management)
- **Importazione Massiva**:
  - Manca la possibilità di importare ospiti da contatti rubrica o file CSV/Excel.
- **Validazione Avanzata**:
  - Controllo duplicati (email/telefono) in tempo reale durante l'inserimento manuale.
- **Biglietteria/QR Code**:
  - Manca la generazione e l'invio via email del QR Code all'ospite (il codice per scansionare c'è, ma non il flusso di invio).

## 3. Gestione Menu
- **Immagini**:
  - Manca la possibilità di caricare foto per i singoli prodotti del menu.
- **Allergeni e Diete**:
  - Non ci sono campi per specificare allergeni, o flag per "Vegano", "Vegetariano", "Gluten Free".
- **Categorie**:
  - La gestione è limitata ai "Transaction Types". Manca una gestione categorie personalizzata (es. "Antipasti", "Cocktail", "Birre").

## 4. Gestione Staff
- **Creazione Profilo Completa**:
  - L'aggiunta staff è limitata a email e ruolo. Manca un flusso per invitare utenti non ancora registrati o completare il loro profilo (foto, bio) lato admin.
- **Permessi Granulari**:
  - I permessi sono hardcoded (`admin` o `staff3`). Manca un sistema di gestione ruoli e permessi dinamico o più strutturato.

## 5. UI/UX e Onboarding
- **Onboarding**:
  - Manca un tutorial o una schermata di benvenuto per i nuovi utenti che spieghi come creare il primo evento.
- **Stati Vuoti (Empty States)**:
  - Alcune schermate potrebbero beneficiare di illustrazioni o guide quando non ci sono dati (es. lista staff vuota, menu vuoto).
- **Feedback Errori**:
  - La gestione errori è basata su `ScaffoldMessenger` (Snackbar). Un sistema di dialoghi o toast più robusto per errori critici sarebbe preferibile.

## 6. Aspetti Tecnici
- **Supporto Offline**:
  - Non sembra esserci una strategia di caching locale per permettere l'uso dell'app senza connessione (fondamentale per eventi in zone con poca rete).
- **Test**:
  - Assenza di test unitari o di widget nel progetto.
- **Aggiornamenti in Tempo Reale**:
  - L'uso di Stream è presente in alcuni servizi, ma va verificato se copre tutte le liste critiche (es. lista ordini in cucina, se prevista).

## 7. Altro
- **Export Dati**:
  - `EventExportScreen` esiste, ma va verificato se supporta tutti i formati richiesti (PDF, Excel completo).
- **Profilo Utente**:
  - La modifica del proprio profilo (password, email) sembra delegata a servizi ma la UI potrebbe essere basica.
