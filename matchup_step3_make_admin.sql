-- Match Up - Étape 3 : devenir administrateur
-- À exécuter UNE SEULE FOIS, APRÈS avoir créé et confirmé votre compte.
-- 1) Supabase > Authentication > Users : copiez l'UUID de votre compte.
-- 2) Remplacez VOTRE-UUID ci-dessous (gardez les apostrophes), puis exécutez.
-- Cette attribution se fait uniquement dans SQL Editor, jamais depuis le navigateur.

UPDATE public.profiles
SET role = 'admin', updated_at = now()
WHERE id = 'VOTRE-UUID';
