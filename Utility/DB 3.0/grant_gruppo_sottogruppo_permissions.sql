-- Grant permissions for gruppo and sottogruppo tables
-- Date: 2025-11-25

-- Grant SELECT, INSERT, UPDATE, DELETE on gruppo table
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE gruppo TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE gruppo TO anon;

-- Grant SELECT, INSERT, UPDATE, DELETE on sottogruppo table
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE sottogruppo TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE sottogruppo TO anon;

-- Grant usage on sequences
GRANT USAGE, SELECT ON SEQUENCE gruppo_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE gruppo_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE sottogruppo_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE sottogruppo_id_seq TO anon;

-- Enable RLS
ALTER TABLE gruppo ENABLE ROW LEVEL SECURITY;
ALTER TABLE sottogruppo ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON gruppo;
DROP POLICY IF EXISTS "Allow read for anonymous users" ON gruppo;
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON sottogruppo;
DROP POLICY IF EXISTS "Allow read for anonymous users" ON sottogruppo;

-- Create RLS policies for gruppo
CREATE POLICY "Allow all operations for authenticated users" ON gruppo
  FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow read for anonymous users" ON gruppo
  FOR SELECT
  USING (true);

-- Create RLS policies for sottogruppo
CREATE POLICY "Allow all operations for authenticated users" ON sottogruppo
  FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow read for anonymous users" ON sottogruppo
  FOR SELECT
  USING (true);
