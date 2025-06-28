# 🔧 Risoluzione Problema Database - Tabelle Duplicate

## ❌ Problema Identificato
Il database Supabase ha tabelle duplicate:
- `Event` (con E maiuscola) 
- `events` (minuscolo)

Questo causa confusione e errori nell'app.

## ✅ Soluzione

### Passo 1: Pulire il Database
Eseguire nel **SQL Editor di Supabase** in questo ordine:

1. **Prima**: Eseguire `supabase_cleanup.sql`
   ```sql
   -- Elimina tutte le tabelle duplicate e conflitti
   ```

2. **Dopo**: Eseguire `supabase_schema_setup.sql`
   ```sql
   -- Crea lo schema pulito e corretto
   ```

### Passo 2: Verificare il Risultato
Dopo l'esecuzione, il database dovrebbe avere solo:
- ✅ `auth.users` (Supabase nativo)
- ✅ `public.profiles` 
- ✅ `public.events` (minuscolo)
- ✅ `public.guests`

### Passo 3: Test dell'App
1. Riavviare l'app Flutter
2. Testare la creazione di un nuovo evento
3. Verificare che i dati vengano salvati correttamente

## 🔄 Modifiche al Codice

### Model Event Aggiornato
- ❌ Rimosso: `guestIds` (non più necessario)
- ✅ Aggiunto: `maxGuests`, `status`, `hostId`
- ✅ Nuovo: `toSupabaseJson()` per compatibilità database
- ✅ Nuovo: `fromSupabaseJson()` per parsing risposta

### Widget RegisterAsHostButton
- ✅ Aggiornato per usare nuovo modello Event
- ✅ Compatibile con schema database corretto
- ✅ Gestione errori migliorata

### Files Hive Rigenerati
- ✅ `event.g.dart` aggiornato con nuovi campi
- ✅ Compatibilità con nuova struttura dati

## 🎯 Risultato Finale
Dopo queste modifiche:
1. ✅ Una sola tabella `events` nel database
2. ✅ Modello Event allineato con schema DB
3. ✅ App funzionante senza errori
4. ✅ Creazione eventi funzionale

## ⚠️ Note Importanti
- **Backup**: Se hai dati importanti in `Event`, fare backup prima della pulizia
- **Ordine**: Eseguire SEMPRE `cleanup.sql` PRIMA di `schema_setup.sql`
- **Test**: Testare la creazione eventi dopo le modifiche 