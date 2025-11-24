-- ================================================
-- NOTIFICATION SYSTEM - DATABASE SCHEMA
-- ================================================

-- Table for storing notifications
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    staff_user_id UUID REFERENCES staff_user(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,  -- 'warning', 'drink_limit', 'event_start', 'event_end', 'sync'
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    data JSONB,  -- Dati aggiuntivi specifici per tipo
    is_read BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE notifications IS 'Notifiche in-app per eventi e azioni';
COMMENT ON COLUMN notifications.type IS 'Tipo: warning, drink_limit, event_start, event_end, sync';
COMMENT ON COLUMN notifications.data IS 'Dati aggiuntivi in formato JSON';

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_event ON notifications(event_id);
CREATE INDEX IF NOT EXISTS idx_notifications_staff_user ON notifications(staff_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);

-- Trigger per updated_at se necessario
CREATE TRIGGER update_notifications_updated_at 
    BEFORE UPDATE ON notifications
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
