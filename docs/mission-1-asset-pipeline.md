# Mission 1 — HQ vocabulary asset pipeline

## Scope and status
Original scope only. No audio registry, inline references, Premium, scoring or main app changes. The founder applied and verified the file_slug backfill and Storage policies (508 language / 67 Adventure records). Do not rerun that migration.

The batch endpoint is staged in [mission-1-commit-vocabulary-import.sql](mission-1-commit-vocabulary-import.sql). It must be reviewed and applied in Supabase before publishing a batch. It uses SECURITY INVOKER, active-admin authorization, existing RLS, server-verified object paths and all-or-nothing DB chunks. No new permanent tables. Existing public URLs are retained. Direct CRUD is still governed by existing active-admin RLS.

## Manifest

```csv
language,category,theme,term,definition,pronunciation,example,file_slug,image_url,audio_url
mende,Vocabulary,Example theme,Example word,Example meaning,,,mende_example_word_example_meaning,images/drum.png,audio/mende/mende_example_word_example_meaning.mp3
```

Example only; use actual approved terms and exact existing theme names. New language rows require a valid slug at publication; existing exact records recover their stored slug if omitted. Legacy text-only files can use a proposed ASCII slug, with ambiguous collisions requiring an explicit key. Prefer the exact supplied file_slug for media production. Legacy CSV without language/theme resolves to the open language theme. Adventure retains category and difficulty scope without requiring slug. Structured TXT is comma- or tab-delimited with headers. XLSX sheets must have matching headers if combined. Optional position is for new rows only.

Storage paths: images/<approved_concept>.png (PNG/JPG/JPEG/WebP), audio/<language_code>/<file_slug>.mp3. Shared image paths are reusable across languages. No fuzzy matching. Use explicit image paths or exact canonical bucket URLs; missing audio path defaults to the exact slug. Upload limits: 5 MiB image, 10 MiB audio. File signatures are screened, not proof of cultural accuracy. Select assets with file picker; repeat selections for separate folders. Existing identical files may be reused; existing different bytes never overwritten.

## Testing
1. `flutter pub get`
2. `flutter test test/vocabulary_import_test.dart`
3. `flutter analyze`
4. `flutter run`
5. In HQ open language theme > lesson cards > bulk asset import. Select a small approved manifest and its media. Validate, inspect the preview, and publish only with founder approval. Use an existing vocabulary row for an asset-only test to avoid introducing invented content.
6. Re-select the same files and validate again; unchanged rows must not duplicate. If the app closes, reselect original manifest and media; database records and immutable Storage objects are persistent checkpoints. The app does not persist local file handles across restarts.
7. Test shared images, missing assets, conflicting bytes, incompatible worksheet headers, multiline Unicode CSV, cancellation, disallowed user, and existing linked audio preservation.
8. After small-batch verification, test a controlled 1,000-record batch using a non-production environment or explicitly approved real content. Never use fabricated bulk content in production.

The 25-row database commits are atomic, but media uploads precede the commit; an interrupted or rejected chunk may leave reusable unlinked files. No automatic deletion. Failed rows can be revalidated and retried. Review reports via Copy report.

Main app reads image_url already; consumer audio playback remains a separate mission. Native speaker and content approval remain founder responsibilities.
