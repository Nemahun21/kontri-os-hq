CREATE OR REPLACE FUNCTION public.check_vocabulary_edit_draft(
  p_theme uuid, p_term text, p_definition text, p_slug text, p_paths text[], p_id uuid
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
  IF NOT EXISTS (SELECT 1 FROM public.lesson_vocabulary WHERE id=p_id AND content_type='language' AND theme_id=p_theme) THEN
    RAISE EXCEPTION 'Record missing or moved';
  END IF;
  SELECT l.code INTO v_language FROM public.language_themes t
    JOIN public.language_type l ON l.id=t.language_type_id WHERE t.id=p_theme;
  IF v_language IS NULL OR length(v_term)>500 OR length(v_definition)>2000
     OR coalesce(cardinality(p_paths),0)>8 THEN
    RAISE EXCEPTION 'Invalid draft scope or input';
  END IF;
  IF p_slug IS NOT NULL AND (length(p_slug)>180 OR p_slug !~ '^[a-z0-9]+(_[a-z0-9]+)*$'
     OR left(p_slug,length(v_language)+1)<>v_language||'_') THEN
    RAISE EXCEPTION 'Invalid draft slug';
  END IF;
  RETURN jsonb_build_object(
    'same_term', EXISTS (SELECT 1 FROM public.lesson_vocabulary v
      WHERE v.id IS DISTINCT FROM p_id AND v.content_type='language' AND v.theme_id=p_theme
      AND v_term<>'' AND lower(normalize(btrim(v.term), NFC))=v_term),
    'duplicate', EXISTS (SELECT 1 FROM public.lesson_vocabulary v
      WHERE v.id IS DISTINCT FROM p_id AND v.content_type='language' AND v.theme_id=p_theme
      AND ((p_slug IS NOT NULL AND v.file_slug=p_slug)
        OR (v_term<>'' AND v_definition<>'' AND lower(normalize(btrim(v.term), NFC))=v_term
          AND lower(normalize(btrim(v.definition), NFC))=v_definition))),
    'slug_conflict', EXISTS (SELECT 1 FROM public.lesson_vocabulary v
      WHERE v.id IS DISTINCT FROM p_id AND v.content_type='language' AND v.file_slug=p_slug
      AND (lower(normalize(btrim(v.term), NFC))<>v_term
        OR lower(normalize(btrim(v.definition), NFC))<>v_definition)),
    'reference_counts', coalesce((SELECT jsonb_object_agg(o.name,
      (SELECT count(*) FROM public.lesson_vocabulary v
       WHERE v.image_url = 'https://ibofeppwhmyxaychgcjq.supabase.co/storage/v1/object/public/vocabulary_assets/'||o.name
          OR v.audio_url = 'https://ibofeppwhmyxaychgcjq.supabase.co/storage/v1/object/public/vocabulary_assets/'||o.name))
      FROM storage.objects o WHERE o.bucket_id='vocabulary_assets' AND o.name=ANY(p_paths)
        AND (o.name ~ '^images/[^/]+$' OR
          left(o.name,length('audio/'||v_language||'/'))='audio/'||v_language||'/'
          AND substring(o.name from length('audio/'||v_language||'/')+1) !~ '/')), '{}'::jsonb),
    'existing_paths', coalesce((SELECT jsonb_agg(o.name) FROM storage.objects o
      WHERE o.bucket_id='vocabulary_assets' AND o.name=ANY(p_paths)
        AND (o.name ~ '^images/[^/]+$' OR
          left(o.name,length('audio/'||v_language||'/'))='audio/'||v_language||'/'
          AND substring(o.name from length('audio/'||v_language||'/')+1) !~ '/')), '[]'::jsonb)
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.check_vocabulary_edit_draft(uuid,text,text,text,text[],uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_vocabulary_edit_draft(uuid,text,text,text,text[],uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.hq_language_content_metrics()
RETURNS TABLE(language_id uuid, theme_id uuid, questions bigint, vocabulary bigint, images bigint, audio bigint, complete bigint)
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=''
AS $f$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_active_admin() THEN RAISE EXCEPTION 'Active administrator required' USING ERRCODE='42501'; END IF;
 RETURN QUERY
 SELECT t.language_type_id,t.id,coalesce(q.n,0),coalesce(v.n,0),coalesce(v.im,0),coalesce(v.au,0),coalesce(v.both,0)
 FROM public.language_themes t
 LEFT JOIN (SELECT x.theme_id,count(*) n FROM public.language_questions x GROUP BY x.theme_id) q ON q.theme_id=t.id
 LEFT JOIN (SELECT x.theme_id,count(*) n,
   count(*) FILTER (WHERE nullif(btrim(x.image_url),'') IS NOT NULL) im,
   count(*) FILTER (WHERE nullif(btrim(x.audio_url),'') IS NOT NULL) au,
   count(*) FILTER (WHERE nullif(btrim(x.image_url),'') IS NOT NULL AND nullif(btrim(x.audio_url),'') IS NOT NULL) both
   FROM public.lesson_vocabulary x WHERE x.content_type='language' GROUP BY x.theme_id) v ON v.theme_id=t.id;
END;
$f$;
REVOKE ALL ON FUNCTION public.hq_language_content_metrics() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hq_language_content_metrics() TO authenticated;

CREATE OR REPLACE FUNCTION public.hq_edit_vocabulary(p_id uuid,p_expected jsonb,p_draft jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $f$
DECLARE
 old public.lesson_vocabulary%ROWTYPE;
 code text; s text; term_new text; def_new text;
 im text; au text; path text;
 prefix constant text := 'https://ibofeppwhmyxaychgcjq.supabase.co/storage/v1/object/public/vocabulary_assets/';
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_active_admin() THEN RAISE EXCEPTION 'Active administrator required' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(128526,1);
 LOCK TABLE public.lesson_vocabulary IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO old FROM public.lesson_vocabulary WHERE id=p_id AND content_type='language' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Record deleted or moved'; END IF;
 IF p_expected IS NULL OR jsonb_typeof(p_expected)<>'object' OR NOT (to_jsonb(old) @> p_expected)
   OR NOT (p_expected ?& ARRAY['content_type','theme_id','category','difficulty','term','definition','pronunciation','example','emoji','file_slug','audio_url','image_url','position'])
 THEN RAISE EXCEPTION 'Record changed; reopen before saving'; END IF;
 SELECT l.code INTO code FROM public.language_themes t JOIN public.language_type l ON l.id=t.language_type_id WHERE t.id=old.theme_id;
 term_new:=btrim(p_draft->>'term'); def_new:=btrim(p_draft->>'definition'); s:=p_draft->>'file_slug';
 IF code IS NULL OR nullif(term_new,'') IS NULL OR nullif(def_new,'') IS NULL OR length(term_new)>500 OR length(def_new)>2000
   OR s IS NULL OR length(s)>180 OR s !~ '^[a-z0-9]+(_[a-z0-9]+)*$' OR left(s,length(code)+1)<>code||'_' THEN RAISE EXCEPTION 'Invalid vocabulary identity'; END IF;
 IF EXISTS(SELECT 1 FROM public.lesson_vocabulary v WHERE v.id<>p_id AND v.content_type='language' AND
   ((v.theme_id=old.theme_id AND (v.file_slug=s OR (lower(normalize(btrim(v.term),NFC))=lower(normalize(term_new,NFC)) AND lower(normalize(btrim(v.definition),NFC))=lower(normalize(def_new,NFC)))))
   OR (v.file_slug=s AND (lower(normalize(btrim(v.term),NFC))<>lower(normalize(term_new,NFC)) OR lower(normalize(btrim(v.definition),NFC))<>lower(normalize(def_new,NFC))))))
 THEN RAISE EXCEPTION 'Duplicate or slug conflict'; END IF;
 im:=old.image_url; au:=old.audio_url;
 IF p_draft ? 'image_path' THEN
   path:=p_draft->>'image_path';
   IF path IS NULL THEN im:=NULL;
   ELSIF path !~ '^images/[a-z0-9]+(_[a-z0-9]+)*[.](png|jpg|jpeg|webp)$' OR NOT EXISTS(
     SELECT 1 FROM storage.objects o WHERE o.bucket_id='vocabulary_assets' AND o.name=path
     AND o.metadata->>'mimetype'=CASE WHEN path LIKE '%.png' THEN 'image/png' WHEN path LIKE '%.webp' THEN 'image/webp' ELSE 'image/jpeg' END
     AND CASE WHEN coalesce(o.metadata->>'size','') ~ '^[0-9]+$' THEN (o.metadata->>'size')::numeric BETWEEN 1 AND 5242880 ELSE false END)
   THEN RAISE EXCEPTION 'Invalid or missing image'; ELSE im:=prefix||path; END IF;
 END IF;
 IF p_draft ? 'audio_path' THEN
   path:=p_draft->>'audio_path';
   IF path IS NULL THEN au:=NULL;
   ELSIF (path <> 'audio/'||code||'/'||s||'.mp3' AND
      (left(path,length('audio/'||code||'/'||s)) <> 'audio/'||code||'/'||s OR substring(path from length('audio/'||code||'/'||s)+1) !~ '^_v[0-9a-f]{16}[.]mp3$'))
     OR NOT EXISTS (SELECT 1 FROM storage.objects o WHERE o.bucket_id='vocabulary_assets' AND o.name=path AND o.metadata->>'mimetype'='audio/mpeg'
       AND CASE WHEN coalesce(o.metadata->>'size','') ~ '^[0-9]+$' THEN (o.metadata->>'size')::numeric BETWEEN 1 AND 10485760 ELSE false END)
   THEN RAISE EXCEPTION 'Invalid or missing audio'; ELSE au:=prefix||path; END IF;
 END IF;
 UPDATE public.lesson_vocabulary SET term=term_new,definition=def_new,file_slug=s,
   pronunciation=nullif(p_draft->>'pronunciation',''),example=nullif(p_draft->>'example',''),emoji=nullif(p_draft->>'emoji',''),image_url=im,audio_url=au
 WHERE id=p_id;
 RETURN p_id;
END;
$f$;
REVOKE ALL ON FUNCTION public.hq_edit_vocabulary(uuid,jsonb,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hq_edit_vocabulary(uuid,jsonb,jsonb) TO authenticated;
