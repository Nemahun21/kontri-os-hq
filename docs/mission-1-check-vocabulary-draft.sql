CREATE OR REPLACE FUNCTION public.check_vocabulary_draft(
  p_theme uuid, p_term text, p_definition text, p_slug text, p_paths text[]
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = ''
AS $function$
DECLARE
  v_term text := lower(normalize(btrim(coalesce(p_term,'')), NFC));
  v_definition text := lower(normalize(btrim(coalesce(p_definition,'')), NFC));
  v_language text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'Active administrator required' USING ERRCODE='42501';
  END IF;
  SELECT l.code INTO v_language FROM public.language_themes t
    JOIN public.language_type l ON l.id=t.language_type_id WHERE t.id=p_theme;
  IF v_language IS NULL OR length(v_term)>500 OR length(v_definition)>2000
     OR coalesce(cardinality(p_paths),0)>4 THEN
    RAISE EXCEPTION 'Invalid draft scope or input';
  END IF;
  IF p_slug IS NOT NULL AND (length(p_slug)>180 OR p_slug !~ '^[a-z0-9]+(_[a-z0-9]+)*$'
     OR left(p_slug,length(v_language)+1)<>v_language||'_') THEN
    RAISE EXCEPTION 'Invalid draft slug';
  END IF;
  RETURN jsonb_build_object(
    'same_term', EXISTS (SELECT 1 FROM public.lesson_vocabulary v
      WHERE v.content_type='language' AND v.theme_id=p_theme
      AND v_term<>'' AND lower(normalize(btrim(v.term), NFC))=v_term),
    'duplicate', EXISTS (SELECT 1 FROM public.lesson_vocabulary v
      WHERE v.content_type='language' AND v.theme_id=p_theme
      AND ((p_slug IS NOT NULL AND v.file_slug=p_slug)
        OR (v_term<>'' AND v_definition<>'' AND lower(normalize(btrim(v.term), NFC))=v_term
          AND lower(normalize(btrim(v.definition), NFC))=v_definition))),
    'slug_conflict', EXISTS (SELECT 1 FROM public.lesson_vocabulary v
      WHERE v.content_type='language' AND v.file_slug=p_slug
      AND (lower(normalize(btrim(v.term), NFC))<>v_term
        OR lower(normalize(btrim(v.definition), NFC))<>v_definition)),
    'existing_paths', coalesce((SELECT jsonb_agg(o.name) FROM storage.objects o
      WHERE o.bucket_id='vocabulary_assets' AND o.name=ANY(p_paths)
        AND (o.name ~ '^images/[^/]+$' OR
          left(o.name,length('audio/'||v_language||'/'))='audio/'||v_language||'/'
          AND substring(o.name from length('audio/'||v_language||'/')+1) !~ '/')), '[]'::jsonb)
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.check_vocabulary_draft(uuid,text,text,text,text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_vocabulary_draft(uuid,text,text,text,text[]) TO authenticated;
