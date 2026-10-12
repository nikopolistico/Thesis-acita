-- A thesis is often done by a pair who share one account.
-- partner_name is the second member's name; NULL when working alone.

ALTER TABLE student ADD COLUMN IF NOT EXISTS partner_name VARCHAR(50);

DROP FUNCTION IF EXISTS register_student(TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION register_student(
    p_full_name    TEXT,
    p_email        TEXT,
    p_program      TEXT,
    p_course       TEXT,
    p_password     TEXT,
    p_partner_name TEXT DEFAULT NULL
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

    INSERT INTO student (user_id, student_name, partner_name, program, course)
    VALUES (v_user_id, p_full_name, NULLIF(trim(p_partner_name), ''), p_program, p_course);

    RETURN jsonb_build_object('id', v_user_id, 'email', p_email, 'role', 'student');
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Email is already registered';
END;
$$;

CREATE OR REPLACE FUNCTION admin_list_students(p_program TEXT)
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(s), '[]'::jsonb)
    FROM (
        SELECT
            st.stu_id, st.user_id, st.student_name, st.partner_name, st.program, st.course, st.created_at,
            uc.email,
            t.thesis_id, t.title, t.link,
            adv.full_name AS adviser_name,
            (
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'role', ap.role,
                    'full_name', p.full_name,
                    'position', p.position
                )), '[]'::jsonb)
                FROM assigned_panelist ap
                JOIN panelist p ON p.panel_id = ap.panel_id
                WHERE ap.thesis_id = t.thesis_id
            ) AS panel
        FROM student st
        JOIN users_credentials uc ON uc.id = st.user_id
        LEFT JOIN thesis t ON t.stu_id = st.stu_id
        LEFT JOIN panelist adv ON adv.panel_id = t.adviser_id
        WHERE lower(trim(st.program)) = lower(trim(p_program))
        ORDER BY st.created_at DESC
    ) s;
$$;
