// ============================================
// SUPABASE CONFIGURATION
// ============================================

const SUPABASE_CONFIG = {
    url: 'https://govbpayonsbfwrfxzbgq.supabase.co',
    anonKey: 'sb_publishable_Bg4FZF-KFlpRfX4Oqt9V4A_oWtvysow'
};

// App Configuration
const APP_CONFIG = {
    appName: 'Confident Creator',
    version: '1.0.0',
    sessionPollInterval: 2000, // 2 seconds for QR polling
    sessionTimeout: 300000, // 5 minutes
    defaultTeleprompterSpeed: 50, // pixels per second
};

// Export for use in other modules
window.SUPABASE_CONFIG = SUPABASE_CONFIG;
window.APP_CONFIG = APP_CONFIG;
