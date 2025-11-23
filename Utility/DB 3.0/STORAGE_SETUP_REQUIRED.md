# ISTRUZIONI URGENTI: Configurazione Bucket StaffProfiles

## Problema
HTTP 400 quando si carica immagine da:
`https://tzrjlnvdeqmmlnivoszq.supabase.co/storage/v1/object/public/StaffProfiles/...`

L'upload funziona, ma l'immagine non è accessibile.

## Soluzione: Configurare Storage in Supabase Dashboard

### OPZIONE 1: Rendere Bucket Pubblico (Consigliato) ⭐

1. Vai a **Supabase Dashboard** → **Storage**
2. Trova bucket **StaffProfiles**
3. Se non esiste, **CREALO**:
   - Click "New Bucket"
   - Nome: `StaffProfiles`
   - **✅ Spunta "Public bucket"**
   - Create
4. Se esiste ma è privato:
   - Click sui 3 puntini del bucket
   - Settings
   - **✅ Spunta "Public bucket"**
   - Save

### OPZIONE 2: Applicare RLS Policies (Solo se bucket deve restare privato)

1. Vai a **Storage** → **Policies**
2. Esegui questo SQL nella sezione **SQL Editor**:

```sql
-- Policy per SELECT (visualizzazione pubblica)
CREATE POLICY "Public Access to StaffProfiles"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'StaffProfiles');

-- Policy per INSERT (solo nella propria cartella)
CREATE POLICY "Users upload to own folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'StaffProfiles' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy per UPDATE (solo propri file)
CREATE POLICY "Users update own files"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'StaffProfiles' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy per DELETE (solo propri file)
CREATE POLICY "Users delete own files"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'StaffProfiles' AND
  (storage.foldername(name))[1] = auth.uid()::text
);
```

## Verifica

Dopo aver configurato, testa l'URL direttamente nel browser:
```
https://tzrjlnvdeqmmlnivoszq.supabase.co/storage/v1/object/public/StaffProfiles/50bcb927-5902-4dea-8a48-985eba01007f/1763939235890.jpg
```

✅ Dovrebbe mostrare l'immagine
❌ Se 400: bucket non pubblico o policies mancanti

## Raccomandazione

**Usa OPZIONE 1** (bucket pubblico) perché:
- Le immagini profilo sono visibili a tutti gli utenti dell'app
- Più semplice da gestire
- Performance migliori (no RLS check su ogni richiesta)
- Le policies RLS controllano solo upload/modifica/delete
