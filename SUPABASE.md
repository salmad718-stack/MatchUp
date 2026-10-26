# Match Up - Supabase

## Architecture
- Site statique HTML/CSS/JS, publié sur Vercel (preset "Other", pas de commande de build).
- Supabase : base PostgreSQL, authentification (e-mail + mot de passe), RLS.
- Le navigateur utilise seulement l'URL du projet et la clé publique (sb_publishable_...), dans `config.js`.
- Aucune clé secrète / service_role dans le code.

## Fichiers
- `config.js` : URL + clé publique.
- `supabase-client.js` : crée le client Supabase partagé (`sb`).
- `services.js` : lit la table `services` (page Services).
- `auth.js` : inscription et connexion. `compte.js` : profil, abonnement démo, espace admin.
- `signup.html`, `login.html`, `compte.html` : pages de compte.

## Scripts SQL (dans l'ordre, dans SQL Editor)
1. `matchup_supabase.sql` : tables, trigger profil, RLS, 3 services.
2. `matchup_step2_subscriptions_admin.sql` : fonctions `is_admin()` et `create_demo_subscription()`, politiques admin.
3. `matchup_step3_make_admin.sql` : donne le rôle admin à UN compte existant (remplacer VOTRE-UUID).

## Sécurité
- RLS activée sur toutes les tables.
- Le rôle (`profiles.role`) n'est pas modifiable par le client (aucune politique UPDATE).
- L'abonnement est créé par la fonction SQL : prix, statut et propriétaire sont fixés par la base.
- Les messages de contact ne sont lisibles que par un admin.

## Authentification (Supabase > Authentication > URL Configuration)
- Local : ajouter `http://localhost:8000` dans les Redirect URLs.
- Après Vercel : mettre l'URL `https://....vercel.app` dans Site URL et Redirect URLs.

## Tests à faire (à compléter avec vos résultats)
| Profil | Vérifications | Résultat |
|---|---|---|
| Visiteur | Voit les services ; ne lit aucun message ni abonnement | |
| Client A | Crée un compte, demande un abonnement, le voit dans Compte | |
| Client B | Ne voit jamais l'abonnement de A ; ne devient pas admin | |
| Admin | Voit les messages de contact | |

## URL publiée
(à compléter après le déploiement sur Vercel)
