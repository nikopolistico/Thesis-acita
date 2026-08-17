-- ============================================================
-- RPC functions — all app reads/writes go through these instead
-- of querying tables directly via PostgREST.
-- SECURITY DEFINER: functions run with the privileges of their
-- owner, bypassing RLS. Access control lives in the app layer
-- (session cookie + route middleware), same as before.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- AUTH
-- ============================================================

CREATE OR REPLACE FUNCTION register_student(
    p_full_name TEXT,
    p_email     TEXT,
    p_program   TEXT,
    p_password  TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_role_id BIGINT;
    v_user_id BIGINT;
BEGIN
    SELECT id INTO v_role_id FROM roles WHERE role_name = 'student';
    IF v_role_id IS NULL THEN
        RAISE EXCEPTION 'Student role is not configured';
    END IF;

    INSERT INTO users_credentials (role_id, email, password)
    VALUES (v_role_id, p_email, crypt(p_password, gen_salt('bf')))
    RETURNING id INTO v_user_id;

    INSERT INTO student_information (user_id, full_name, program)
    VALUES (v_user_id, p_full_name, p_program);

    RETURN jsonb_build_object('id', v_user_id, 'email', p_email, 'role', 'student');
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Email is already registered';
END;
$$;

CREATE OR REPLACE FUNCTION login_user(
    p_email    TEXT,
    p_password TEXT,
    p_role     TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_user RECORD;
BEGIN
    SELECT uc.id, uc.email, uc.password, uc.status, r.role_name
    INTO v_user
    FROM users_credentials uc
    JOIN roles r ON r.id = uc.role_id
    WHERE uc.email = p_email;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid email or password';
    END IF;

    IF v_user.status <> 'active' THEN
        RAISE EXCEPTION 'This account has been disabled';
    END IF;

    IF v_user.role_name <> p_role THEN
        RAISE EXCEPTION 'Invalid email or password';
    END IF;

    IF v_user.password <> crypt(p_password, v_user.password) THEN
        RAISE EXCEPTION 'Invalid email or password';
    END IF;

    RETURN jsonb_build_object('id', v_user.id, 'email', v_user.email, 'role', v_user.role_name);
END;
$$;

-- ============================================================
-- STUDENT
-- ============================================================

CREATE OR REPLACE FUNCTION get_student_profile(p_user_id BIGINT)
RETURNS student_information
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT * FROM student_information WHERE user_id = p_user_id;
$$;

CREATE OR REPLACE FUNCTION get_student_thesis_titles(p_student_id BIGINT)
RETURNS SETOF thesis_title
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT * FROM thesis_title WHERE student_id = p_student_id ORDER BY created_at DESC;
$$;

CREATE OR REPLACE FUNCTION add_thesis_title(p_student_id BIGINT, p_title TEXT)
RETURNS thesis_title
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    INSERT INTO thesis_title (student_id, title) VALUES (p_student_id, p_title) RETURNING *;
$$;

CREATE OR REPLACE FUNCTION get_student_schedules(p_student_id BIGINT)
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(s), '[]'::jsonb)
    FROM (
        SELECT
            ts.id, ts.schedule_date, ts.start_time, ts.end_time, ts.venue, ts.status,
            tt.title AS thesis_title,
            (
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'role_in_panel', pa.role_in_panel,
                    'status', pa.status,
                    'full_name', pi.full_name,
                    'position', pi.position
                )), '[]'::jsonb)
                FROM panel_assignments pa
                JOIN panelist_information pi ON pi.id = pa.panelist_id
                WHERE pa.schedule_id = ts.id
            ) AS panel
        FROM thesis_schedule ts
        JOIN thesis_title tt ON tt.id = ts.title_id
        WHERE ts.student_id = p_student_id
        ORDER BY ts.schedule_date ASC
    ) s;
$$;

-- ============================================================
-- PANELIST
-- ============================================================

CREATE OR REPLACE FUNCTION get_panelist_profile(p_user_id BIGINT)
RETURNS panelist_information
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT * FROM panelist_information WHERE user_id = p_user_id;
$$;

CREATE OR REPLACE FUNCTION get_panelist_assignments(p_panelist_id BIGINT)
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(a), '[]'::jsonb)
    FROM (
        SELECT
            pa.id, pa.role_in_panel, pa.status,
            ts.schedule_date, ts.start_time, ts.end_time, ts.venue,
            tt.title AS thesis_title,
            si.full_name AS student_name
        FROM panel_assignments pa
        JOIN thesis_schedule ts ON ts.id = pa.schedule_id
        JOIN thesis_title tt ON tt.id = ts.title_id
        JOIN student_information si ON si.id = ts.student_id
        WHERE pa.panelist_id = p_panelist_id
        ORDER BY ts.schedule_date ASC
    ) a;
$$;

CREATE OR REPLACE FUNCTION get_panelist_expertise(p_panelist_id BIGINT)
RETURNS SETOF panel_expertise
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT * FROM panel_expertise WHERE panelist_id = p_panelist_id ORDER BY created_at;
$$;

CREATE OR REPLACE FUNCTION add_panel_expertise(p_panelist_id BIGINT, p_expertise_area TEXT)
RETURNS panel_expertise
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    INSERT INTO panel_expertise (panelist_id, expertise_area) VALUES (p_panelist_id, p_expertise_area) RETURNING *;
$$;

CREATE OR REPLACE FUNCTION remove_panel_expertise(p_expertise_id BIGINT)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    DELETE FROM panel_expertise WHERE id = p_expertise_id;
$$;

CREATE OR REPLACE FUNCTION update_assignment_status(p_assignment_id BIGINT, p_status TEXT)
RETURNS panel_assignments
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_row panel_assignments;
BEGIN
    IF p_status NOT IN ('assigned', 'confirmed', 'declined') THEN
        RAISE EXCEPTION 'Invalid status value';
    END IF;

    UPDATE panel_assignments SET status = p_status WHERE id = p_assignment_id RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Assignment not found';
    END IF;

    RETURN v_row;
END;
$$;

-- ============================================================
-- NOTIFICATIONS (shared)
-- ============================================================

CREATE OR REPLACE FUNCTION get_user_notifications(p_user_id BIGINT)
RETURNS SETOF notifications
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT * FROM notifications WHERE user_id = p_user_id ORDER BY date_sent DESC;
$$;

CREATE OR REPLACE FUNCTION mark_notification_read(p_notification_id BIGINT)
RETURNS notifications
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    UPDATE notifications SET is_read = true WHERE id = p_notification_id RETURNING *;
$$;

-- ============================================================
-- ADMIN
-- ============================================================

CREATE OR REPLACE FUNCTION admin_list_students()
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(s), '[]'::jsonb)
    FROM (
        SELECT si.*, uc.email
        FROM student_information si
        JOIN users_credentials uc ON uc.id = si.user_id
        ORDER BY si.created_at DESC
    ) s;
$$;

CREATE OR REPLACE FUNCTION admin_list_panelists()
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(p), '[]'::jsonb)
    FROM (
        SELECT
            pi.*, uc.email,
            (
                SELECT COALESCE(jsonb_agg(jsonb_build_object('id', pe.id, 'expertise_area', pe.expertise_area)), '[]'::jsonb)
                FROM panel_expertise pe WHERE pe.panelist_id = pi.id
            ) AS expertise
        FROM panelist_information pi
        JOIN users_credentials uc ON uc.id = pi.user_id
        ORDER BY pi.created_at DESC
    ) p;
$$;

CREATE OR REPLACE FUNCTION admin_list_thesis_titles()
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(t), '[]'::jsonb)
    FROM (
        SELECT tt.*, si.full_name AS student_name
        FROM thesis_title tt
        JOIN student_information si ON si.id = tt.student_id
        ORDER BY tt.created_at DESC
    ) t;
$$;

CREATE OR REPLACE FUNCTION admin_list_schedules()
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(s), '[]'::jsonb)
    FROM (
        SELECT ts.*, tt.title AS thesis_title, si.full_name AS student_name
        FROM thesis_schedule ts
        JOIN thesis_title tt ON tt.id = ts.title_id
        JOIN student_information si ON si.id = ts.student_id
        ORDER BY ts.schedule_date ASC
    ) s;
$$;

CREATE OR REPLACE FUNCTION admin_create_schedule(
    p_title_id      BIGINT,
    p_schedule_date DATE,
    p_start_time    TIME,
    p_end_time      TIME,
    p_venue         TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_student_id BIGINT;
    v_schedule thesis_schedule;
BEGIN
    SELECT student_id INTO v_student_id FROM thesis_title WHERE id = p_title_id;
    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'Thesis title not found';
    END IF;

    INSERT INTO thesis_schedule (title_id, student_id, schedule_date, start_time, end_time, venue)
    VALUES (p_title_id, v_student_id, p_schedule_date, p_start_time, p_end_time, p_venue)
    RETURNING * INTO v_schedule;

    RETURN to_jsonb(v_schedule);
END;
$$;

CREATE OR REPLACE FUNCTION admin_list_assignments()
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(a), '[]'::jsonb)
    FROM (
        SELECT
            pa.*, pi.full_name AS panelist_name, tt.title AS thesis_title, ts.schedule_date
        FROM panel_assignments pa
        JOIN panelist_information pi ON pi.id = pa.panelist_id
        JOIN thesis_schedule ts ON ts.id = pa.schedule_id
        JOIN thesis_title tt ON tt.id = ts.title_id
        ORDER BY pa.created_at DESC
    ) a;
$$;

CREATE OR REPLACE FUNCTION admin_create_assignment(
    p_schedule_id   BIGINT,
    p_panelist_id   BIGINT,
    p_role_in_panel TEXT
) RETURNS panel_assignments
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    INSERT INTO panel_assignments (schedule_id, panelist_id, role_in_panel)
    VALUES (p_schedule_id, p_panelist_id, p_role_in_panel)
    RETURNING *;
$$;

CREATE OR REPLACE FUNCTION admin_list_notifications()
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(n), '[]'::jsonb)
    FROM (
        SELECT nf.*, uc.email AS recipient_email
        FROM notifications nf
        JOIN users_credentials uc ON uc.id = nf.user_id
        ORDER BY nf.date_sent DESC
    ) n;
$$;

CREATE OR REPLACE FUNCTION admin_send_notification(p_user_id BIGINT, p_message TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_notification notifications;
    v_email TEXT;
BEGIN
    INSERT INTO notifications (user_id, message) VALUES (p_user_id, p_message) RETURNING * INTO v_notification;
    SELECT email INTO v_email FROM users_credentials WHERE id = p_user_id;
    RETURN to_jsonb(v_notification) || jsonb_build_object('recipient_email', v_email);
END;
$$;

CREATE OR REPLACE FUNCTION admin_list_users()
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(u), '[]'::jsonb)
    FROM (
        SELECT uc.id, uc.email, r.role_name
        FROM users_credentials uc
        JOIN roles r ON r.id = uc.role_id
        ORDER BY uc.email
    ) u;
$$;

CREATE OR REPLACE FUNCTION admin_delete_student(p_student_id BIGINT)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    DELETE FROM student_information WHERE id = p_student_id;
$$;

CREATE OR REPLACE FUNCTION admin_delete_panelist(p_panelist_id BIGINT)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    DELETE FROM panelist_information WHERE id = p_panelist_id;
$$;

CREATE OR REPLACE FUNCTION admin_overview_stats()
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT jsonb_build_object(
        'students', (SELECT count(*) FROM student_information),
        'panelists', (SELECT count(*) FROM panelist_information),
        'schedules', (SELECT count(*) FROM thesis_schedule),
        'pending_assignments', (SELECT count(*) FROM panel_assignments WHERE status = 'assigned')
    );
$$;

-- ============================================================
-- Let the app's anon key actually call these
-- ============================================================
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
