-- Mission 1: transactional, invoker-rights import endpoint.
-- Prerequisite: file_slug column, scoped index, and active-admin Storage policies.
-- Run only after review, in the same Kontrios project as HQ.
BEGIN;

CREATE OR REPLACE FUNCTION public.commit_vocabulary_import(p_rows jsonb)
RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  r jsonb;
  v_type text;
  v_theme uuid;
  v_language text;
  v_category text;
  v_difficulty text;
  v_slug text;
  v_term text;
  v_definition text;
  v_term_key text;
  v_definition_key text;
  v_path text;
  v_image text;
  v_audio text;
  v_position integer;
  v_ids uuid[];
  v_existing public.lesson_vocabulary%ROWTYPE;
  v_count integer := 0;
  v_public_prefix constant text :=
    'https://ibofeppwhmyxaychgcjq.supabase.co/storage/v1/object/public/vocabulary_assets/';
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'Active administrator required' USING ERRCODE = '42501';
  END IF;
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'Expected JSON array';
  END IF;
  IF jsonb_array_length(p_rows) NOT BETWEEN 1 AND 25 THEN
    RAISE EXCEPTION 'Batch must contain 1–25 records';
  END IF;

  -- Serialise competing import chunks; uniqueness index remains a final guard.
  PERFORM pg_advisory_xact_lock(128526, 1);
  -- Legacy manual inserts/edits also take conflicting row-exclusive locks.
  LOCK TABLE public.lesson_vocabulary IN SHARE ROW EXCLUSIVE MODE;

  FOR r IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
    IF jsonb_typeof(r) <> 'object' THEN RAISE EXCEPTION 'Invalid record'; END IF;
    v_type := r->>'content_type';
    v_term := btrim(r->>'term');
    v_definition := btrim(r->>'definition');
    v_term_key := lower(normalize(v_term, NFC));
    v_definition_key := lower(normalize(v_definition, NFC));
    v_slug := nullif(btrim(r->>'file_slug'), '');
    v_theme := NULL;
    v_language := NULL;
    v_category := NULL;
    v_difficulty := NULL;
    v_image := NULL;
    v_audio := NULL;
    IF v_type IS NULL OR v_type NOT IN ('language','adventure')
       OR nullif(v_term,'') IS NULL OR nullif(v_definition,'') IS NULL THEN
      RAISE EXCEPTION 'Content type, term and definition are required';
    END IF;

    IF v_type = 'language' THEN
      v_theme := (r->>'theme_id')::uuid;
      SELECT l.code INTO v_language
      FROM public.language_themes t
      JOIN public.language_type l ON l.id = t.language_type_id
      WHERE t.id = v_theme;
      IF v_language IS NULL OR v_language IS DISTINCT FROM r->>'language_code'
         OR v_slug IS NULL OR length(v_slug) > 180
         OR v_slug !~ '^[a-z0-9]+(_[a-z0-9]+)*$'
         OR left(v_slug, length(v_language)+1) <> v_language||'_' THEN
        RAISE EXCEPTION 'Invalid theme, language or slug: %', v_term;
      END IF;
      IF EXISTS (
        SELECT 1 FROM public.lesson_vocabulary v
        WHERE v.content_type='language' AND v.file_slug=v_slug
          AND (lower(normalize(btrim(v.term), NFC)) <> v_term_key
            OR lower(normalize(btrim(v.definition), NFC)) <> v_definition_key)
      ) THEN
        RAISE EXCEPTION 'Slug already belongs to a different identity: %', v_slug;
      END IF;
    ELSE
      v_category := r->>'category';
      v_difficulty := r->>'difficulty';
      IF v_category IS NULL OR v_category NOT IN ('History','Food','Places','Sports')
         OR v_difficulty IS NULL OR v_difficulty NOT IN ('easy','medium','hard')
         OR v_slug IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid Adventure scope';
      END IF;
    END IF;

    -- Derive public URL only from an exact object in the approved bucket.
    -- No arbitrary external URL or unapproved path enters this endpoint.
    v_path := nullif(r->>'image_path','');
    IF v_path IS NOT NULL THEN
      IF v_path !~ '^images/[a-z0-9]+(_[a-z0-9]+)*[.](png|jpg|jpeg|webp)$'
         OR NOT EXISTS (
           SELECT 1 FROM storage.objects o
           WHERE o.bucket_id='vocabulary_assets' AND o.name=v_path
             AND o.metadata->>'mimetype' = CASE
               WHEN v_path LIKE '%.png' THEN 'image/png'
               WHEN v_path LIKE '%.webp' THEN 'image/webp'
               ELSE 'image/jpeg' END
             AND CASE WHEN coalesce(o.metadata->>'size','') ~ '^[0-9]+$'
                      THEN (o.metadata->>'size')::numeric BETWEEN 1 AND 5242880
                      ELSE false END
         ) THEN
        RAISE EXCEPTION 'Invalid or missing image: %', v_path;
      END IF;
      v_image := v_public_prefix || v_path;
    END IF;
    v_path := nullif(r->>'audio_path','');
    IF v_path IS NOT NULL THEN
      IF v_path !~ '^audio/[a-z0-9_]+/[a-z0-9]+(_[a-z0-9]+)*[.]mp3$'
         OR (v_type='language' AND v_path <> 'audio/'||v_language||'/'||v_slug||'.mp3')
         OR NOT EXISTS (
           SELECT 1 FROM storage.objects o
           WHERE o.bucket_id='vocabulary_assets' AND o.name=v_path
             AND o.metadata->>'mimetype'='audio/mpeg'
             AND CASE WHEN coalesce(o.metadata->>'size','') ~ '^[0-9]+$'
                      THEN (o.metadata->>'size')::numeric BETWEEN 1 AND 10485760
                      ELSE false END
         ) THEN
        RAISE EXCEPTION 'Invalid or missing audio: %', v_path;
      END IF;
      v_audio := v_public_prefix || v_path;
    END IF;

    SELECT array_agg(v.id) INTO v_ids
    FROM public.lesson_vocabulary v
    WHERE v.content_type=v_type
      AND ((v_type='language' AND v.theme_id=v_theme)
        OR (v_type='adventure' AND v.category=v_category AND v.difficulty=v_difficulty))
      AND ((v_slug IS NOT NULL AND v.file_slug=v_slug)
        OR (lower(normalize(btrim(v.term), NFC))=v_term_key
            AND lower(normalize(btrim(v.definition), NFC))=v_definition_key));

    IF coalesce(cardinality(v_ids),0)>1 THEN
      RAISE EXCEPTION 'Ambiguous existing record: %', v_term;
    ELSIF coalesce(cardinality(v_ids),0)=1 THEN
      SELECT * INTO STRICT v_existing FROM public.lesson_vocabulary WHERE id=v_ids[1] FOR UPDATE;
      IF lower(normalize(btrim(v_existing.term), NFC)) <> v_term_key
         OR lower(normalize(btrim(v_existing.definition), NFC)) <> v_definition_key
         OR (v_existing.file_slug IS NOT NULL AND v_existing.file_slug IS DISTINCT FROM v_slug)
         OR (v_image IS NOT NULL AND nullif(btrim(v_existing.image_url),'') IS NOT NULL
             AND v_existing.image_url <> v_image)
         OR (v_audio IS NOT NULL AND nullif(btrim(v_existing.audio_url),'') IS NOT NULL
             AND v_existing.audio_url <> v_audio) THEN
        RAISE EXCEPTION 'Existing record conflict; explicit correction required: %', v_term;
      END IF;
      -- Only fill missing references, never overwrite verified content.
      UPDATE public.lesson_vocabulary SET
        file_slug=coalesce(file_slug,v_slug),
        image_url=CASE WHEN nullif(btrim(image_url),'') IS NULL AND v_image IS NOT NULL THEN v_image ELSE image_url END,
        audio_url=CASE WHEN nullif(btrim(audio_url),'') IS NULL AND v_audio IS NOT NULL THEN v_audio ELSE audio_url END
      WHERE id=v_existing.id
        AND ((file_slug IS NULL AND v_slug IS NOT NULL)
          OR (nullif(btrim(image_url),'') IS NULL AND v_image IS NOT NULL)
          OR (nullif(btrim(audio_url),'') IS NULL AND v_audio IS NOT NULL));
    ELSE
      SELECT coalesce(max(v.position),0)+1 INTO v_position
      FROM public.lesson_vocabulary v
      WHERE v.content_type=v_type
        AND ((v_type='language' AND v.theme_id=v_theme)
          OR (v_type='adventure' AND v.category=v_category AND v.difficulty=v_difficulty));
      IF nullif(r->>'position','') IS NOT NULL THEN
        v_position := (r->>'position')::integer;
        IF v_position < 1 THEN RAISE EXCEPTION 'Invalid position'; END IF;
      END IF;
      INSERT INTO public.lesson_vocabulary (
        content_type,theme_id,category,difficulty,term,definition,pronunciation,example,emoji,
        position,file_slug,image_url,audio_url
      ) VALUES (
        v_type,v_theme,v_category,v_difficulty,v_term,v_definition,
        nullif(r->>'pronunciation',''),nullif(r->>'example',''),nullif(r->>'emoji',''),
        v_position,v_slug,v_image,v_audio
      );
    END IF;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$function$;

REVOKE ALL ON FUNCTION public.commit_vocabulary_import(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.commit_vocabulary_import(jsonb) TO authenticated;
COMMIT;
