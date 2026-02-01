
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const secretPath = path.resolve(__dirname, '../.env.secret');

if (!fs.existsSync(secretPath)) {
    console.error('Error: .env.secret file not found!');
    process.exit(1);
}

const envContent = fs.readFileSync(secretPath, 'utf-8');
const env = {};
envContent.split('\n').forEach(line => {
    const [key, value] = line.split('=');
    if (key && value) {
        env[key.trim()] = value.trim();
    }
});

const SUPABASE_URL = env['VERIFY_SB_URL'];
const SUPABASE_SERVICE_KEY = env['VERIFY_SB_SERVICE_KEY'];

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function runInvestigation() {
    console.log('Investigating entries for 2026-01-31 (Test-Installer)...');

    // 1. Get User
    let { data: users } = await supabase
        .from('user_settings')
        .select('user_id, display_name')
        .eq('display_name', 'Test-Installer');

    if (!users || users.length === 0) {
        // Fallback or exit
        console.warn("User 'Test-Installer' not exact match, searching like...");
        ({ data: users } = await supabase.from('user_settings').select('user_id, display_name').ilike('display_name', '%Test-Installer%'));
    }

    if (!users || users.length === 0) {
        console.error("User not found.");
        return;
    }

    const user = users[0];
    console.log(`Found User: ${user.display_name} (${user.user_id})`);

    const DATE = '2026-01-31';

    // 2. Fetch Raw Entries
    const { data: entries, error } = await supabase
        .from('time_entries')
        .select('*')
        .eq('user_id', user.user_id)
        .eq('date', DATE);

    if (error) {
        console.error('Error fetching entries:', error);
        return;
    }

    console.log(`\n--- Raw Time Entries for ${DATE} ---`);
    entries.forEach(e => {
        const status = e.is_deleted ? '[DELETED]' : '[ACTIVE]';
        console.log(`${status} ID: ${e.id}`);
        console.log(`   Type: ${e.type} | Client: ${e.client_name}`);
        console.log(`   Time: ${e.start_time} - ${e.end_time}`);
        console.log(`   Hours Field: ${e.hours}`);
        console.log(`   Surcharge: ${e.surcharge}%`);
        console.log(`   Calc Duration: ${e.calc_duration_minutes} min`);
        console.log(`   Calc Surcharge: ${e.calc_surcharge_hours} h`);
        console.log('------------------------------------------------');
    });

    // 3. Fetch View Data
    const { data: viewData, error: viewError } = await supabase
        .from('view_daily_summary')
        .select('*')
        .eq('user_id', user.user_id)
        .eq('date', DATE)
        .maybeSingle();

    console.log(`\n--- View Daily Summary for ${DATE} ---`);
    if (viewData) {
        console.log(`Total Work Minutes: ${viewData.total_work_minutes} (${viewData.total_work_minutes / 60} h)`);
        console.log(`Total Surcharge Hours: ${viewData.total_surcharge_hours}`);
        console.log(`Vacation: ${viewData.vacation_hours} h`);
        console.log(`Sick: ${viewData.sick_hours} h`);
        console.log(`Total Effective Minutes (New): ${viewData.total_effective_minutes} (${viewData.total_effective_minutes / 60} h)`);
    } else {
        console.log("No View Data found.");
    }

    // 4. Calculate Expected
    const activeEntries = entries.filter(e => !e.is_deleted);
    const workMinutes = activeEntries
        .filter(e => ['work', 'company', 'office', 'warehouse', 'car', 'emergency_service'].includes(e.type))
        .reduce((sum, e) => sum + (e.calc_duration_minutes || 0), 0);
    const breakMinutes = activeEntries
        .filter(e => e.type === 'break')
        .reduce((sum, e) => sum + (e.calc_duration_minutes || 0), 0);

    const netWork = workMinutes - breakMinutes;
    const surchargeHours = activeEntries.reduce((sum, e) => sum + (e.calc_surcharge_hours || 0), 0);

    console.log(`\n--- Manual Cross-Check ---`);
    console.log(`Net Work (Active): ${netWork} min (${netWork / 60} h)`);
    console.log(`Surcharge (Active): ${surchargeHours} h`);
    console.log(`Sum (Net Work + Surcharge): ${(netWork / 60) + surchargeHours} h`);
}

runInvestigation();
