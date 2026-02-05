import { createClient } from '@supabase/supabase-js';

// Cloud Supabase Konfiguration (Migration)
const supabaseUrl = 'https://knawmxkyvzrmrjmgckht.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtuYXdteGt5dnpybXJqbWdja2h0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk4NzgyNjAsImV4cCI6MjA4NTQ1NDI2MH0.u1-Yvu3z8PcMwpTq75kW7krWSN4TdnpWmkaXvcQWgHw';

export const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
    }
});

export const isSupabaseConfigured = true;
