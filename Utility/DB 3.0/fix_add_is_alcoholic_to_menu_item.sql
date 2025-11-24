-- ============================================
-- FIX: Aggiunta colonna is_alcoholic a menu_item
-- ============================================

-- Aggiungi la colonna is_alcoholic alla tabella menu_item
ALTER TABLE menu_item
ADD COLUMN IF NOT EXISTS is_alcoholic BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN menu_item.is_alcoholic IS 'Indica se il prodotto contiene alcol (per bevande)';

-- Crea un indice per query ottimizzate su bevande alcoliche
CREATE INDEX IF NOT EXISTS idx_menu_item_alcoholic ON menu_item(is_alcoholic) WHERE is_alcoholic = TRUE;
