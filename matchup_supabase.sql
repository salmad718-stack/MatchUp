-- Match Up - Base de données Supabase
-- À exécuter dans Supabase > SQL Editor > New query.
-- Vérifiez les politiques RLS avant d'utiliser ce schéma en production.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Profils liés aux comptes Supabase Auth
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL DEFAULT '',
    email TEXT,
    role TEXT NOT NULL DEFAULT 'candidat'
        CHECK (role IN ('etudiant', 'candidat', 'entreprise', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Crée automatiquement un profil à la création d'un compte Auth.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, email)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
        NEW.email
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Entreprises
CREATE TABLE IF NOT EXISTS public.companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    company_name TEXT NOT NULL,
    description TEXT,
    website TEXT,
    city TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Informations des candidats
CREATE TABLE IF NOT EXISTS public.candidates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    education TEXT,
    skills TEXT[] NOT NULL DEFAULT '{}',
    experience TEXT,
    cv_url TEXT,
    city TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Services/profils présentés sur le site Match Up
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    featured BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.services (title, category, description, featured)
SELECT v.title, v.category, v.description, v.featured
FROM (VALUES
    ('Ingénieure en e-commerce', 'informatique',
     'Profil présenté sur Match Up', true),
    ('Bank Account Manager', 'economie',
     'Profil présenté sur Match Up', false),
    ('Junior Database Administrator', 'informatique',
     'Profil présenté sur Match Up', false)
) AS v(title, category, description, featured)
WHERE NOT EXISTS (
    SELECT 1 FROM public.services s WHERE s.title = v.title
);

-- 5. Offres d'emploi
CREATE TABLE IF NOT EXISTS public.jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    location TEXT,
    contract_type TEXT,
    salary_min NUMERIC(12,2),
    salary_max NUMERIC(12,2),
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'published', 'closed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Candidatures
CREATE TABLE IF NOT EXISTS public.applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL REFERENCES public.candidates(id) ON DELETE CASCADE,
    cover_message TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'reviewing', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (job_id, candidate_id)
);

-- 7. Messages du formulaire de contact
CREATE TABLE IF NOT EXISTS public.contact_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('etudiant', 'candidat', 'entreprise')),
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. Abonnements
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    plan_name TEXT NOT NULL DEFAULT 'Mensuel',
    amount NUMERIC(8,2) NOT NULL DEFAULT 5.00,
    currency TEXT NOT NULL DEFAULT 'TND',
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'active', 'cancelled', 'expired')),
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. Sécurité : activer RLS sur toutes les tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- 10. Politiques RLS
-- Profils : chaque utilisateur connecté peut lire et modifier uniquement
-- son profil. Le rôle ne doit pas être modifiable par le client.
DROP POLICY IF EXISTS "Lire son profil" ON public.profiles;
CREATE POLICY "Lire son profil"
ON public.profiles FOR SELECT TO authenticated
USING (id = (SELECT auth.uid()));

-- Pas de politique UPDATE volontairement : les modifications de profil
-- doivent être ajoutées via une fonction serveur/RPC qui protège la colonne role.
-- Cela évite qu'un utilisateur s'attribue le rôle admin ou entreprise.

DROP POLICY IF EXISTS "Lire ses entreprises" ON public.companies;
CREATE POLICY "Lire ses entreprises"
ON public.companies FOR SELECT TO authenticated
USING (owner_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Créer son entreprise" ON public.companies;
CREATE POLICY "Créer son entreprise"
ON public.companies FOR INSERT TO authenticated
WITH CHECK (owner_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Modifier son entreprise" ON public.companies;
CREATE POLICY "Modifier son entreprise"
ON public.companies FOR UPDATE TO authenticated
USING (owner_id = (SELECT auth.uid()))
WITH CHECK (owner_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Lire ses données candidat" ON public.candidates;
CREATE POLICY "Lire ses données candidat"
ON public.candidates FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Créer ses données candidat" ON public.candidates;
CREATE POLICY "Créer ses données candidat"
ON public.candidates FOR INSERT TO authenticated
WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Modifier ses données candidat" ON public.candidates;
CREATE POLICY "Modifier ses données candidat"
ON public.candidates FOR UPDATE TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

-- Services : lecture publique, gestion réservée à un administrateur côté serveur.
DROP POLICY IF EXISTS "Lire les services" ON public.services;
CREATE POLICY "Lire les services"
ON public.services FOR SELECT TO anon, authenticated
USING (true);

-- Offres : les utilisateurs connectés peuvent lire les offres publiées.
DROP POLICY IF EXISTS "Lire les offres publiees" ON public.jobs;
CREATE POLICY "Lire les offres publiees"
ON public.jobs FOR SELECT TO anon, authenticated
USING (status = 'published');

DROP POLICY IF EXISTS "Entreprise lit ses offres" ON public.jobs;
CREATE POLICY "Entreprise lit ses offres"
ON public.jobs FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.companies c
        WHERE c.id = jobs.company_id AND c.owner_id = (SELECT auth.uid())
    )
);

DROP POLICY IF EXISTS "Entreprise cree ses offres" ON public.jobs;
CREATE POLICY "Entreprise cree ses offres"
ON public.jobs FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.companies c
        WHERE c.id = jobs.company_id AND c.owner_id = (SELECT auth.uid())
    )
);

DROP POLICY IF EXISTS "Entreprise modifie ses offres" ON public.jobs;
CREATE POLICY "Entreprise modifie ses offres"
ON public.jobs FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.companies c
        WHERE c.id = jobs.company_id AND c.owner_id = (SELECT auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.companies c
        WHERE c.id = jobs.company_id AND c.owner_id = (SELECT auth.uid())
    )
);

-- Candidatures : lecture/création limitées au candidat propriétaire.
DROP POLICY IF EXISTS "Lire ses candidatures" ON public.applications;
CREATE POLICY "Lire ses candidatures"
ON public.applications FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.candidates c
        WHERE c.id = applications.candidate_id AND c.user_id = (SELECT auth.uid())
    )
);

DROP POLICY IF EXISTS "Envoyer une candidature" ON public.applications;
CREATE POLICY "Envoyer une candidature"
ON public.applications FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.candidates c
        WHERE c.id = applications.candidate_id AND c.user_id = (SELECT auth.uid())
    )
);

-- Contact : insertion publique autorisée, lecture non autorisée via le client.
DROP POLICY IF EXISTS "Envoyer un message de contact" ON public.contact_messages;
CREATE POLICY "Envoyer un message de contact"
ON public.contact_messages FOR INSERT TO anon, authenticated
WITH CHECK (true);

-- Abonnements : chaque utilisateur connecté lit ses propres abonnements.
DROP POLICY IF EXISTS "Lire ses abonnements" ON public.subscriptions;
CREATE POLICY "Lire ses abonnements"
ON public.subscriptions FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()));

-- IMPORTANT :
-- 1) Vérifiez les politiques selon les besoins exacts de votre site.
-- 2) N'exposez jamais la clé secrète service_role dans le code du navigateur.
-- 3) Avant la production, testez les accès avec plusieurs comptes et rôles.
