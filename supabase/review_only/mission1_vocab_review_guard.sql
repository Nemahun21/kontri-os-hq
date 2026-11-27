-- REVIEW ONLY. Test1 only; do not execute until HQ approval.
-- All changes in one transaction. Preserve existing definer, grants, validation,
-- publication fields, locks and super-admin authorization.
BEGIN;
DO $migration$
DECLARE
  save_def text := pg_get_functiondef('public.v2_save_vocab_draft(jsonb)'::regprocedure);
  publish_def text := pg_get_functiondef('public.v2_publish_vocab_theme(uuid)'::regprocedure);
  old_save constant text := $old$INSERT INTO public.lesson_vocabulary_revisions(id,content_type,category,theme_id,term,definition,pronunciation,example,emoji,audio_url,image_url,position,created_at,updated_at,difficulty,file_slug,status)
 VALUES(v_id,'language',NULL,v_theme,v_term,v_def,nullif(btrim(p_row->>'pronunciation'),''),nullif(btrim(p_row->>'example'),''),nullif(btrim(p_row->>'emoji'),''),p_row->>'audio_url',p_row->>'image_url',v_pos,coalesce(v_old.created_at,v_base.created_at,now()),now(),v_diff,v_slug,'draft')$old$;
  new_save constant text := $new$INSERT INTO public.lesson_vocabulary_revisions(id,content_type,category,theme_id,term,definition,pronunciation,example,emoji,audio_url,image_url,position,created_at,updated_at,difficulty,file_slug,status,review_note)
 VALUES(v_id,'language',NULL,v_theme,v_term,v_def,nullif(btrim(p_row->>'pronunciation'),''),nullif(btrim(p_row->>'example'),''),nullif(btrim(p_row->>'emoji'),''),p_row->>'audio_url',p_row->>'image_url',v_pos,coalesce(v_old.created_at,v_base.created_at,now()),now(),v_diff,v_slug,'draft',CASE WHEN p_row ? 'review_note' THEN nullif(btrim(p_row->>'review_note'),'') ELSE v_old.review_note END)$new$;
  old_update constant text := $old$status='draft',updated_at=now();$old$;
  new_update constant text := $new$status='draft',review_note=excluded.review_note,updated_at=now();$new$;
  old_guard constant text := $old$IF EXISTS(SELECT 1 FROM public.lesson_vocabulary_revisions WHERE theme_id=p_theme AND status='draft') THEN RAISE EXCEPTION 'Submit all drafts before publication'; END IF;$old$;
  new_guard constant text := $new$IF EXISTS(SELECT 1 FROM public.lesson_vocabulary_revisions WHERE theme_id=p_theme AND content_type='language' AND status IN ('draft','pending_approval') AND nullif(btrim(review_note),'') IS NOT NULL) THEN RAISE EXCEPTION 'Publication blocked: resolve all vocabulary review notes first'; END IF;
 IF EXISTS(SELECT 1 FROM public.lesson_vocabulary_revisions WHERE theme_id=p_theme AND status='draft') THEN RAISE EXCEPTION 'Submit all drafts before publication'; END IF;$new$;
BEGIN
  IF strpos(save_def,old_save)=0 OR strpos(save_def,old_update)=0 OR strpos(publish_def,old_guard)=0 THEN
    RAISE EXCEPTION 'Existing RPC implementation changed; do not apply stale review patch';
  END IF;
  IF (length(save_def)-length(replace(save_def,old_save,'')))/length(old_save)<>1
     OR (length(save_def)-length(replace(save_def,old_update,'')))/length(old_update)<>1
     OR (length(publish_def)-length(replace(publish_def,old_guard,'')))/length(old_guard)<>1 THEN
    RAISE EXCEPTION 'Ambiguous RPC replacement';
  END IF;
  EXECUTE replace(replace(save_def,old_save,new_save),old_update,new_update);
  EXECUTE replace(publish_def,old_guard,new_guard);
END $migration$;
NOTIFY pgrst, 'reload schema';
COMMIT;
