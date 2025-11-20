-- Fix RLS Policy per la tabella person (Versione Robusta)
-- Questo script rimuove PRIMA le policy se esistono già, per evitare l'errore "already exists".

-- 1. Rimuovi le policy vecchie (se presenti)
DROP POLICY IF EXISTS person_insert_staff2 ON person;

-- 2. Rimuovi le policy nuove (se per caso sono già state create parzialmente)
DROP POLICY IF EXISTS person_insert_authenticated ON person;
DROP POLICY IF EXISTS person_select_by_staff ON person;

-- 3. Crea le nuove policy permissive
CREATE POLICY person_insert_authenticated ON person 
FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY person_select_by_staff ON person 
FOR SELECT 
TO authenticated 
USING (true);
