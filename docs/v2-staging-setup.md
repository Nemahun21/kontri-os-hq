# Kontrios V2 — Test1 staging (development only)

**Environment:** Test1 Supabase project `eeeusvsefoxbgshouqjb`.
**Branch:** `develop/v2`. The existing `main` branch and Google Play V1 remain unchanged.

## Fail-closed configuration

The V2 application requires **both** compile-time definitions and rejects any Supabase URL other than the dedicated Test1 URL. The publishable key is intentionally not committed to GitHub.

Create a local file named `v2.staging.json` in the Flutter project root (this filename is gitignored):

```json
{
  "V2_SUPABASE_URL": "https://eeeusvsefoxbgshouqjb.supabase.co",
  "V2_SUPABASE_PUBLISHABLE_KEY": "PASTE_TEST1_PUBLISHABLE_OR_ANON_KEY_FROM_SUPABASE_DASHBOARD"
}
```

Get the Test1 project's **publishable / anon** key from Supabase Dashboard → Project Settings → API Keys. **Never** use a secret key or `service_role` credential in Flutter.

Run locally:

```bash
flutter pub get
flutter run --dart-define-from-file=v2.staging.json
```

Main App Android package is `com.nemahun21.kontrios.dev`, so V2 can be installed alongside Google Play V1. HQ Android package is also suffixed `.dev`. For HQ web testing, run on a staging-only local origin and do not reuse production pending operations. HQ automatic offline operation sync is intentionally disabled pending isolation review.

## Staging database installed (2026-11-24)

Supabase migrations:
- `v2_staging_minimal_core_schema`
- `v2_staging_vocabulary_storage`
- `v2_seed_reviewable_krio_sample`
- `v2_staging_restrict_default_privileges`

Tables: `language_type`, `language_themes`, `lesson_vocabulary`, `language_questions`, `profiles`, `admins`, `app_config`.

Seed: 1 Krio language, 6 themes, 18 sample vocabulary records (6 each easy/medium/hard), and 6 existing quiz questions. This is **sample content**, not a migration of the 158 approved Krio words.

Auth: Staging users only. A trigger creates a profile when a staging user signs up. **No production user records were copied**. There are no staging admins yet; content changes require an approved staging-admin account (admin record with `user_id` and `status='approved'`). Do not copy production admin/user credentials.

Storage: public-read `vocabulary_assets` bucket. Only approved staging admins may upload/update/delete; max size 10 MB; png/jpeg/webp and permitted audio MIME types. Existing staging bucket has zero uploaded files.

## Isolation and release gates

- Do not merge `develop/v2` into `main` or deploy to Play Store without separate approval.
- Production Supabase must not be used to test staging content.
- V2 app does not initialize production OneSignal.
- This is a minimal **Krio vocabulary vertical slice**: unrelated home/adventure/daily-content screens may not function yet because their production tables and RPCs were intentionally not copied.
- HQ Google OAuth, authentication redirects, approved staging admin access, device builds, V2 audio playback and full regression tests remain unverified.
- Preserve quiz question UUIDs/theme UUIDs for progress compatibility. App version-gate uses a staging-only `app_config`.
- Before final V2 launch, reconcile full production schema and feature dependencies and separately approve migration and release rollout.
