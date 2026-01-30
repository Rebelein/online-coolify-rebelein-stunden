import { createClient } from '@supabase/supabase-js';

// Self-Hosted Supabase Konfiguration (gemäß Benutzer-Input)
const supabaseUrl = 'https://supabase-stunden.rebeleinapp.de';
const supabaseKey = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc2NTE0MTc0MCwiZXhwIjo0OTIwODE1MzQwLCJyb2xlIjoiYW5vbiJ9._IWYbPcLUlaS1fvLo_Rowt4VqAD18d24OaARL_T0Hvw';

export const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
    }
});

export const isSupabaseConfigured = true;
