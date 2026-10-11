-- Casa Hermo Louro v0.29. Ejecutar una sola vez en Supabase SQL Editor.
-- Cambia solamente tareas del jueves PUBLICADAS y PENDIENTES; no permite modificar tareas terminadas.
CREATE OR REPLACE FUNCTION public.update_pending_thursday(
 p_session_id bigint, p_title text, p_steps text[] DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_session record; v_role text; v_step text; v_pos integer := 1;
BEGIN
 SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();
 IF v_role IS DISTINCT FROM 'adult' THEN RAISE EXCEPTION 'Solo los adultos pueden modificar el jueves'; END IF;
 SELECT s.id,s.status,s.session_type,s.week_id,w.status AS week_status,p.family_id AS session_family,
        actor.family_id AS actor_family
 INTO v_session
 FROM public.work_sessions s
 JOIN public.weeks w ON w.id=s.week_id
 JOIN public.profiles p ON p.id=s.assigned_to
 JOIN public.profiles actor ON actor.id=auth.uid()
 WHERE s.id=p_session_id FOR UPDATE OF s;
 IF NOT FOUND THEN RAISE EXCEPTION 'Sesión no encontrada'; END IF;
 IF v_session.session_family IS DISTINCT FROM v_session.actor_family THEN RAISE EXCEPTION 'Familia incorrecta'; END IF;
 IF v_session.session_type <> 'thursday' OR v_session.week_status <> 'published' OR v_session.status <> 'pending'
 THEN RAISE EXCEPTION 'Solo se puede editar el jueves publicado mientras esté pendiente'; END IF;
 IF length(btrim(coalesce(p_title,'')))=0 OR length(p_title)>150 THEN RAISE EXCEPTION 'Título no válido'; END IF;
 UPDATE public.work_sessions SET title=btrim(p_title) WHERE id=p_session_id;
 IF p_steps IS NOT NULL THEN
   IF coalesce(array_length(p_steps,1),0)>30 THEN RAISE EXCEPTION 'Demasiados pasos'; END IF;
   DELETE FROM public.session_tasks WHERE session_id=p_session_id;
   FOREACH v_step IN ARRAY p_steps LOOP
     IF length(btrim(coalesce(v_step,'')))=0 OR length(v_step)>250 THEN RAISE EXCEPTION 'Paso no válido'; END IF;
     INSERT INTO public.session_tasks(session_id,description,position) VALUES (p_session_id,btrim(v_step),v_pos);
     v_pos:=v_pos+1;
   END LOOP;
 END IF;
END; $$;
REVOKE ALL ON FUNCTION public.update_pending_thursday(bigint,text,text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_pending_thursday(bigint,text,text[]) TO authenticated;
