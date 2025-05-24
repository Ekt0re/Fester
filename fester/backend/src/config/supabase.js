const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

// Client pubblico (per operazioni frontend)
const supabaseClient = createClient(supabaseUrl, supabaseAnonKey);

// Client con privilegi elevati (solo per operazioni backend)
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

module.exports = { supabaseClient, supabaseAdmin }; 