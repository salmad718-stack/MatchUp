-- Match Up - Étape 2 : abonnement (démo) + rôle admin
-- À exécuter dans Supabase > SQL Editor > New query, APRÈS matchup_supabase.sql.
-- Ce script peut être relancé sans supprimer de données.

-- 1) Fonction qui dit si l'utilisateur connecté est admin.
--    SECURITY DEFINER : elle lit profiles sans déclencher de boucle RLS.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = (SELECT auth.uid()) AND role = 'admin'
    );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- 2) Fonction que le site appelle pour demander un abonnement démo.
--    Le prix, la devise, le statut et le propriétaire sont fixés ICI par la base :
--    le navigateur ne peut pas les choisir. Aucun INSERT direct n'est autorisé.
CREATE OR REPLACE FUNCTION public.create_demo_subscription()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    uid UUID := (SELECT auth.uid());
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'Connexion requise';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.subscriptions
        WHERE user_id = uid AND status IN ('pending', 'active')
    ) THEN
        RAISE EXCEPTION 'Vous avez déjà une demande d''abonnement en cours';
    END IF;

    INSERT INTO public.subscriptions (user_id, plan_name, amount, currency, status)
    VALUES (uid, 'Mensuel', 5.00, 'TND', 'pending');
END;
$$;

REVOKE ALL ON FUNCTION public.create_demo_subscription() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_demo_subscription() TO authenticated;

-- 3) Politiques admin (lecture des messages et abonnements, gestion des services).
DROP POLICY IF EXISTS "Admin lit les messages" ON public.contact_messages;
CREATE POLICY "Admin lit les messages"
ON public.contact_messages FOR SELECT TO authenticated
USING (public.is_admin());

DROP POLICY IF EXISTS "Admin lit les abonnements" ON public.subscriptions;
CREATE POLICY "Admin lit les abonnements"
ON public.subscriptions FOR SELECT TO authenticated
USING (public.is_admin());

DROP POLICY IF EXISTS "Admin modifie les abonnements" ON public.subscriptions;
CREATE POLICY "Admin modifie les abonnements"
ON public.subscriptions FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admin ajoute des services" ON public.services;
CREATE POLICY "Admin ajoute des services"
ON public.services FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admin modifie les services" ON public.services;
CREATE POLICY "Admin modifie les services"
ON public.services FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admin supprime des services" ON public.services;
CREATE POLICY "Admin supprime des services"
ON public.services FOR DELETE TO authenticated
USING (public.is_admin());
