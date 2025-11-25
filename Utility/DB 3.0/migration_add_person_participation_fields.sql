-- Migration: Add new fields to person and participation tables
-- Date: 2025-11-25
-- Description: Adds codice_fiscale, indirizzo, sottogruppo, gruppo to person table
--              and local_id to participation table

-- Add new fields to person table
ALTER TABLE person
ADD COLUMN IF NOT EXISTS codice_fiscale VARCHAR(16),
ADD COLUMN IF NOT EXISTS indirizzo TEXT,
ADD COLUMN IF NOT EXISTS sottogruppo VARCHAR(255),
ADD COLUMN IF NOT EXISTS gruppo VARCHAR(255);

-- Add new field to participation table  
ALTER TABLE participation
ADD COLUMN IF NOT EXISTS local_id INTEGER;

-- Optional: Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_person_gruppo ON person(gruppo);
CREATE INDEX IF NOT EXISTS idx_person_sottogruppo ON person(sottogruppo);
CREATE INDEX IF NOT EXISTS idx_person_codice_fiscale ON person(codice_fiscale);
CREATE INDEX IF NOT EXISTS idx_participation_local_id ON participation(local_id);

-- Add comments to document the new fields
COMMENT ON COLUMN person.codice_fiscale IS 'Italian fiscal code';
COMMENT ON COLUMN person.indirizzo IS 'Full address';
COMMENT ON COLUMN person.sottogruppo IS 'Sub-group identifier';
COMMENT ON COLUMN person.gruppo IS 'Group identifier';
COMMENT ON COLUMN participation.local_id IS 'Local sequential ID for the participation';
