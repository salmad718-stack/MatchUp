// Client Supabase partagé par les pages Services, Connexion, Inscription et Compte.
// Il utilise uniquement l'URL et la clé PUBLIQUE de config.js (jamais de clé secrète ici).
const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
