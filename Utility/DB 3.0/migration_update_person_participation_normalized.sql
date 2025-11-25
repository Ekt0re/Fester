-- Migration: Update person/participation with normalized gruppo/sottogruppo
-- Date: 2025-11-25
-- Description: Creates gruppo and sottogruppo tables, updates person to use FKs

-- Create gruppo table
CREATE TABLE IF NOT EXISTS gruppo (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    event_id UUID NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(name, event_id)
);

-- Create sottogruppo table
CREATE TABLE IF NOT EXISTS sottogruppo (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    gruppo_id INT NOT NULL REFERENCES gruppo(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(name, gruppo_id)
);

-- Drop old columns from person if they exist (from previous migration)
ALTER TABLE person DROP COLUMN IF EXISTS gruppo;
ALTER TABLE person DROP COLUMN IF EXISTS sottogruppo;

-- Add new columns to person table
ALTER TABLE person
ADD COLUMN IF NOT EXISTS codice_fiscale VARCHAR(16),
ADD COLUMN IF NOT EXISTS indirizzo TEXT,
ADD COLUMN IF NOT EXISTS gruppo_id INT REFERENCES gruppo(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS sottogruppo_id INT REFERENCES sottogruppo(id) ON DELETE SET NULL;

-- Add new fields to participation table
ALTER TABLE participation
ADD COLUMN IF NOT EXISTS local_id INTEGER,
ADD COLUMN IF NOT EXISTS invited_by UUID;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_person_gruppo_id ON person(gruppo_id);
CREATE INDEX IF NOT EXISTS idx_person_sottogruppo_id ON person(sottogruppo_id);
CREATE INDEX IF NOT EXISTS idx_person_codice_fiscale ON person(codice_fiscale);
CREATE INDEX IF NOT EXISTS idx_participation_local_id ON participation(local_id);
CREATE INDEX IF NOT EXISTS idx_participation_invited_by ON participation(invited_by);
CREATE INDEX IF NOT EXISTS idx_gruppo_event_id ON gruppo(event_id);
CREATE INDEX IF NOT EXISTS idx_sottogruppo_gruppo_id ON sottogruppo(gruppo_id);

-- Add comments
COMMENT ON TABLE gruppo IS 'Groups for organizing event participants';
COMMENT ON TABLE sottogruppo IS 'Subgroups within groups';
COMMENT ON COLUMN person.codice_fiscale IS 'Italian fiscal code';
COMMENT ON COLUMN person.indirizzo IS 'Full address';
COMMENT ON COLUMN person.gruppo_id IS 'Reference to gruppo table';
COMMENT ON COLUMN person.sottogruppo_id IS 'Reference to sottogruppo table';
COMMENT ON COLUMN participation.local_id IS 'Local sequential ID for the participation';
COMMENT ON COLUMN participation.invited_by IS 'Person or staff who invited this participant';
