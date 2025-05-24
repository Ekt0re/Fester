## Struttura UI e Frontend di Fester (Flutter)

Crea la seguente struttura dell'applicazione con una grafica modern , accativante ed intuitiva

### Autenticazione

**Schermate:**
- `LoginPage`
- `RegisterPage`
- `ForgotPasswordPage`
- `ProfilePage`

**BLoC:**
- `AuthBloc`
- `AuthState`: `Unauthenticated`, `Authenticated`, `AuthLoading`, `AuthError`
- `AuthEvent`: `LoginRequested`, `RegisterRequested`, `LogoutRequested`

**Widget:**
- `CustomTextField`
- `LoadingButton`
- `AuthFormCard`

---

### Dashboard Utente

**Schermate:**
- `HomePage` (eventi, statistiche, crea evento)

**Widget:**
- `EventCard`
- `StatBox`
- `BottomNavigationBar`

---

### Gestione Eventi

**Schermate:**
- `EventListPage`
- `EventDetailPage`
- `EventFormPage`

**BLoC:**
- `EventBloc`
- `EventState`: `EventLoading`, `EventLoaded`, `EventError`
- `EventEvent`: `FetchEvents`, `CreateEvent`, `UpdateEvent`, `DeleteEvent`

**Widget:**
- `EventTile`
- `EventForm`
- `EventFilterBar`

---

### Gestione Ospiti

**Schermate:**
- `GuestListPage`
- `GuestFormPage`
- `InvitePage`

**BLoC:**
- `GuestBloc`
- `GuestState`: `GuestLoaded`, `GuestError`, `GuestUpdating`
- `GuestEvent`: `AddGuest`, `RemoveGuest`, `UpdateGuest`, `CheckInGuest`

**Widget:**
- `GuestTile`
- `GuestForm`
- `GuestSearchBar`
- `QRPreview`

---

### Scansione QR Code

**Schermate:**
- `QRScannerPage`

**Funzioni:**
- Scan QR
- Verifica validità
- Mostra conferma check-in

**Plugin consigliati:**
- `qr_code_scanner`
- `flutter_barcode_scanner`

---

### Statistiche e Analytics

**Schermate:**
- `StatsPage`

**Widget:**
- `PieChartWidget` (es. `fl_chart`)
- `BarChartWidget`
- `TrendLineWidget`

---

### Impostazioni e Profilo

**Schermate:**
- `SettingsPage`
- `ProfilePage`
- `AccountDeletePage`

---

### Struttura Folder Flutter

```
lib/
├── blocs/
│   ├── auth/
│   ├── event/
│   ├── guest/
│   └── qr/
├── models/
├── pages/
│   ├── auth/
│   ├── events/
│   ├── guests/
│   ├── home/
│   ├── qr/
│   └── stats/
├── services/
│   └── supabase_service.dart
├── widgets/
│   ├── event/
│   ├── guest/
│   └── shared/
└── main.dart
```

---

### Prossimi Passi

- [ ] Creare modelli dati in Flutter per Supabase
- [ ] Impostare i blocchi BLoC per eventi e ospiti
- [ ] Disegnare UI iniziali: login, registrazione, home
- [ ] Implementare scansione QR
- [ ] Integrare grafici in StatsPage