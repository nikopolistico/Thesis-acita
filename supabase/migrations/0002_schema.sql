-- SQLBook: Code
-- ============================================================
-- Thesis Title/Link/Adviser Submission System — Database
-- Schema + RPC functions (PostgreSQL / Supabase)
--
-- Two login roles: student and admin. Each admin is a program
-- chairperson — scoped to one program (e.g. "BS Information
-- Technology") — and only ever sees/manages that program's
-- students and panelists. Admin accounts are provisioned by hand
-- (see the seed block at the bottom of this file), not through
-- the app.
--
-- Panel assignment runs as retrieval-based matching (RAG, minus
-- the "generation" step):
--
--   1. Student submits a thesis title -> the title IS the query.
--   2. The title is embedded (384-dim, computed server-side via
--      a local all-MiniLM-L6-v2) and stored on
--      thesis.title_embedding.
--   3. match_panelist_expertise() does a semantic (cosine
--      similarity) search of that query embedding against every
--      panelist's tagged expertise embeddings, scoped to the
--      thesis's program.
--   4. Candidates above a similarity threshold count as a match; on
--      a good match, auto_assign_panel() fills the thesis's panel
--      (1 chair + 2 members) from the ranked candidates.
--   5. The student sees the panel and which expertise areas matched.
--
-- This file is a full reset: it drops every table this schema
-- owns (including retired names from earlier versions) and
-- rebuilds everything from scratch, so it's the one and only file
-- that needs to be pasted into the Supabase SQL editor — at any
-- point during development.
--
-- SECURITY DEFINER: functions run with the privileges of their
-- owner, bypassing RLS. Access control lives in the app layer
-- (session cookie + route middleware).
-- ============================================================

-- ============================================================
-- 0. DROP EVERYTHING (clean slate — current tables plus retired
--    names from earlier versions of this schema)
-- ============================================================
DROP TABLE IF EXISTS assigned_panelist CASCADE;
DROP TABLE IF EXISTS thesis CASCADE;
DROP TABLE IF EXISTS expertise CASCADE;
DROP TABLE IF EXISTS panelist CASCADE;
DROP TABLE IF EXISTS student CASCADE;
DROP TABLE IF EXISTS program_chairperson CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS thesis_schedule CASCADE;
DROP TABLE IF EXISTS panel_assignments CASCADE;
DROP TABLE IF EXISTS panel_expertise CASCADE;
DROP TABLE IF EXISTS thesis_title CASCADE;
DROP TABLE IF EXISTS panelist_information CASCADE;
DROP TABLE IF EXISTS student_information CASCADE;
DROP TABLE IF EXISTS admin_information CASCADE;
DROP TABLE IF EXISTS users_credentials CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- Functions whose argument list has changed across versions (count
-- OR just parameter types) need an explicit drop — CASCADE from the
-- table drops above only removes functions whose signature depends
-- on a dropped table's row type; these return/accept plain scalars
-- or JSONB, so they survive it.
DROP FUNCTION IF EXISTS register_student(TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS register_student(TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS login_user(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS get_thesis_panel(BIGINT);
DROP FUNCTION IF EXISTS submit_student_thesis(BIGINT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS submit_student_thesis(BIGINT, TEXT, TEXT, BIGINT);
DROP FUNCTION IF EXISTS match_panelist_expertise(extensions.vector, TEXT, INT);
DROP FUNCTION IF EXISTS auto_assign_panel(BIGINT, TEXT[]);
DROP FUNCTION IF EXISTS auto_assign_panel(BIGINT, extensions.vector);
DROP FUNCTION IF EXISTS set_thesis_embedding(BIGINT, extensions.vector);
DROP FUNCTION IF EXISTS set_expertise_embedding(BIGINT, extensions.vector);
DROP FUNCTION IF EXISTS admin_list_students();
DROP FUNCTION IF EXISTS admin_list_students(TEXT);
DROP FUNCTION IF EXISTS admin_list_panelists();
DROP FUNCTION IF EXISTS admin_list_panelists(TEXT);
DROP FUNCTION IF EXISTS list_panelists_public(TEXT);
DROP FUNCTION IF EXISTS register_panelist(TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS register_panelist(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS admin_delete_panelist(BIGINT);
DROP FUNCTION IF EXISTS add_panel_expertise(BIGINT, TEXT);
DROP FUNCTION IF EXISTS remove_panel_expertise(BIGINT);
DROP FUNCTION IF EXISTS get_panelist_assignments(BIGINT);
DROP FUNCTION IF EXISTS get_panelist_profile(BIGINT);

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

-- ============================================================
-- 1. ROLES + USERS_CREDENTIALS (login/auth tables)
-- ============================================================
CREATE TABLE roles (
    id          BIGSERIAL PRIMARY KEY,
    role_name   TEXT NOT NULL UNIQUE,      -- 'admin', 'student'
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE users_credentials (
    id          BIGSERIAL PRIMARY KEY,
    role_id     BIGINT NOT NULL REFERENCES roles(id),
    email       TEXT NOT NULL UNIQUE,
    password    TEXT NOT NULL,             -- store hashed password only
    status      TEXT NOT NULL DEFAULT 'active',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. STUDENT
-- ============================================================
CREATE TABLE student (
    stu_id        BIGSERIAL PRIMARY KEY,
    user_id       BIGINT NOT NULL REFERENCES users_credentials(id) ON DELETE CASCADE,
    student_name  VARCHAR(50) NOT NULL,
    program       VARCHAR(50),
    course        VARCHAR(50),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 3. PANELIST (no login of its own — managed by the
--    chairperson)
-- ============================================================
CREATE TABLE panelist (
    panel_id    BIGSERIAL PRIMARY KEY,
    full_name   VARCHAR(50) NOT NULL,
    position    VARCHAR(50),
    program     VARCHAR(50) NOT NULL,
    status      VARCHAR(10),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 4. EXPERTISE (tags on a panelist; expertise_embedding is what
--    match_panelist_expertise() searches against)
-- ============================================================
CREATE TABLE expertise (
    exs_id                BIGSERIAL PRIMARY KEY,
    expertise             TEXT NOT NULL,
    panel_id              BIGINT NOT NULL REFERENCES panelist(panel_id) ON DELETE CASCADE,
    expertise_embedding   extensions.vector(384),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (panel_id, expertise)
);

CREATE INDEX expertise_embedding_idx ON expertise
    USING hnsw (expertise_embedding extensions.vector_cosine_ops);

-- ============================================================
-- 5. THESIS (title_embedding is the RAG query vector; adviser_id
--    references a real panelist record instead of a free-text
--    name)
-- ============================================================
CREATE TABLE thesis (
    thesis_id       BIGSERIAL PRIMARY KEY,
    title           TEXT NOT NULL,
    link            TEXT,
    title_embedding extensions.vector(384),
    adviser_id      BIGINT REFERENCES panelist(panel_id) ON DELETE SET NULL,
    stu_id          BIGINT NOT NULL UNIQUE REFERENCES student(stu_id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 6. ASSIGNED_PANELIST
-- ============================================================
CREATE TABLE assigned_panelist (
    assign_id   BIGSERIAL PRIMARY KEY,
    role        TEXT NOT NULL CHECK (role IN ('chair', 'member')),
    panel_id    BIGINT NOT NULL REFERENCES panelist(panel_id) ON DELETE CASCADE,
    thesis_id   BIGINT NOT NULL REFERENCES thesis(thesis_id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (thesis_id, panel_id)
);

CREATE UNIQUE INDEX assigned_panelist_one_chair_per_thesis
    ON assigned_panelist (thesis_id) WHERE role = 'chair';

-- ============================================================
-- 7. PROGRAM_CHAIRPERSON (the "admin" role — scoped to one
--    program)
-- ============================================================
CREATE TABLE program_chairperson (
    pgchair_id  BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users_credentials(id) ON DELETE CASCADE,
    full_name   VARCHAR(50) NOT NULL,
    program     VARCHAR(50) NOT NULL,
    position    VARCHAR(50),
    status      VARCHAR(10),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- SEED: default roles
-- ============================================================
INSERT INTO roles (role_name, description) VALUES
    ('admin', 'Program chairperson — reviews that program''s student submissions and panels'),
    ('student', 'Registers and submits thesis title, link, and adviser');

-- ============================================================
-- AUTH
-- ============================================================

CREATE OR REPLACE FUNCTION register_student(
    p_full_name TEXT,
    p_email     TEXT,
    p_program   TEXT,
    p_course    TEXT,
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

    INSERT INTO student (user_id, student_name, program, course)
    VALUES (v_user_id, p_full_name, p_program, p_course);

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
RETURNS student
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT * FROM student WHERE user_id = p_user_id;
$$;

CREATE OR REPLACE FUNCTION get_student_thesis(p_stu_id BIGINT)
RETURNS thesis
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT * FROM thesis WHERE stu_id = p_stu_id;
$$;

CREATE OR REPLACE FUNCTION submit_student_thesis(
    p_stu_id     BIGINT,
    p_title      TEXT,
    p_link       TEXT,
    p_adviser_id BIGINT
) RETURNS thesis
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_old_title TEXT;
    v_row       thesis;
BEGIN
    SELECT title INTO v_old_title FROM thesis WHERE stu_id = p_stu_id;

    INSERT INTO thesis (stu_id, title, link, adviser_id)
    VALUES (p_stu_id, p_title, p_link, p_adviser_id)
    ON CONFLICT (stu_id)
    DO UPDATE SET title = excluded.title, link = excluded.link, adviser_id = excluded.adviser_id,
                  title_embedding = CASE WHEN thesis.title IS DISTINCT FROM excluded.title
                                         THEN NULL ELSE thesis.title_embedding END
    RETURNING * INTO v_row;

    -- A new topic invalidates the old panel; it gets re-matched.
    IF v_old_title IS DISTINCT FROM p_title THEN
        DELETE FROM assigned_panelist WHERE thesis_id = v_row.thesis_id;
    END IF;

    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION set_thesis_embedding(p_thesis_id BIGINT, p_embedding extensions.vector(384))
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public, extensions AS $$
    UPDATE thesis SET title_embedding = p_embedding WHERE thesis_id = p_thesis_id;
$$;

-- ============================================================
-- PANEL (per-thesis view, shared by student and admin)
-- ============================================================

CREATE OR REPLACE FUNCTION get_thesis_panel(p_thesis_id BIGINT)
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'assign_id', ap.assign_id,
        'role', ap.role,
        'panel_id', p.panel_id,
        'full_name', p.full_name,
        'position', p.position
    ) ORDER BY (ap.role = 'chair') DESC, ap.assign_id), '[]'::jsonb)
    FROM assigned_panelist ap
    JOIN panelist p ON p.panel_id = ap.panel_id
    WHERE ap.thesis_id = p_thesis_id;
$$;

-- ============================================================
-- RAG: semantic search of the thesis title's embedding against
-- every panelist's tagged expertise embeddings (cosine
-- similarity via pgvector's <=> operator), scoped to program.
-- ============================================================

CREATE OR REPLACE FUNCTION match_panelist_expertise(
    p_query_embedding extensions.vector(384),
    p_program         TEXT,
    p_match_count     INT DEFAULT 10
) RETURNS TABLE (
    panel_id    BIGINT,
    full_name   TEXT,
    "position"  TEXT,
    expertise   TEXT,
    similarity  FLOAT
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, extensions AS $$
    SELECT p.panel_id, p.full_name, p.position, e.expertise,
           1 - (e.expertise_embedding <=> p_query_embedding) AS similarity
    FROM expertise e
    JOIN panelist p ON p.panel_id = e.panel_id
    WHERE e.expertise_embedding IS NOT NULL
      AND lower(trim(p.program)) = lower(trim(p_program))
    ORDER BY e.expertise_embedding <=> p_query_embedding
    LIMIT p_match_count;
$$;

-- ============================================================
-- AUTOMATION: rank each program's panelists by their single best
-- (lowest-distance) matching expertise tag against the thesis
-- title's embedding, then fill chair -> member -> member from
-- the top. Existing assignments are never touched, so calling
-- this again only tops up open slots.
-- ============================================================

CREATE OR REPLACE FUNCTION auto_assign_panel(
    p_thesis_id       BIGINT,
    p_query_embedding extensions.vector(384)
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_has_chair     BOOLEAN;
    v_member_count  INT;
    v_program       TEXT;
    v_candidate     RECORD;
BEGIN
    SELECT s.program INTO v_program
    FROM thesis t
    JOIN student s ON s.stu_id = t.stu_id
    WHERE t.thesis_id = p_thesis_id;

    SELECT
        COALESCE(bool_or(role = 'chair'), FALSE),
        COALESCE(count(*) FILTER (WHERE role = 'member'), 0)
    INTO v_has_chair, v_member_count
    FROM assigned_panelist
    WHERE thesis_id = p_thesis_id;

    IF v_has_chair AND v_member_count >= 2 THEN
        RETURN get_thesis_panel(p_thesis_id);
    END IF;

    FOR v_candidate IN
        SELECT p.panel_id, min(e.expertise_embedding <=> p_query_embedding) AS distance
        FROM panelist p
        JOIN expertise e ON e.panel_id = p.panel_id
        WHERE e.expertise_embedding IS NOT NULL
          AND lower(trim(p.program)) = lower(trim(coalesce(v_program, '')))
          AND p.panel_id NOT IN (SELECT panel_id FROM assigned_panelist WHERE thesis_id = p_thesis_id)
          AND p.panel_id IS DISTINCT FROM (SELECT adviser_id FROM thesis WHERE thesis_id = p_thesis_id)
        GROUP BY p.panel_id
        HAVING min(e.expertise_embedding <=> p_query_embedding) <= 0.6
        ORDER BY distance ASC, p.panel_id ASC
    LOOP
        IF NOT v_has_chair THEN
            INSERT INTO assigned_panelist (thesis_id, panel_id, role)
            VALUES (p_thesis_id, v_candidate.panel_id, 'chair');
            v_has_chair := TRUE;
        ELSIF v_member_count < 2 THEN
            INSERT INTO assigned_panelist (thesis_id, panel_id, role)
            VALUES (p_thesis_id, v_candidate.panel_id, 'member');
            v_member_count := v_member_count + 1;
        ELSE
            EXIT;
        END IF;
    END LOOP;

    RETURN get_thesis_panel(p_thesis_id);
END;
$$;

-- ============================================================
-- ADMIN (program chairperson) — every list below is scoped to
-- the calling chairperson's own program.
-- ============================================================

CREATE OR REPLACE FUNCTION get_admin_profile(p_user_id BIGINT)
RETURNS program_chairperson
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT * FROM program_chairperson WHERE user_id = p_user_id;
$$;

CREATE OR REPLACE FUNCTION admin_list_students(p_program TEXT)
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(s), '[]'::jsonb)
    FROM (
        SELECT
            st.stu_id, st.user_id, st.student_name, st.program, st.course, st.created_at,
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

CREATE OR REPLACE FUNCTION admin_list_panelists(p_program TEXT)
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(p), '[]'::jsonb)
    FROM (
        SELECT
            pl.panel_id, pl.full_name, pl.position, pl.program, pl.status, pl.created_at,
            (
                SELECT COALESCE(jsonb_agg(jsonb_build_object('exs_id', e.exs_id, 'expertise', e.expertise)), '[]'::jsonb)
                FROM expertise e WHERE e.panel_id = pl.panel_id
            ) AS expertise,
            (
                SELECT count(*) FROM assigned_panelist ap WHERE ap.panel_id = pl.panel_id
            )::int AS assignment_count
        FROM panelist pl
        WHERE lower(trim(pl.program)) = lower(trim(p_program))
        ORDER BY pl.created_at DESC
    ) p;
$$;

-- Lightweight list for the student-side adviser picker (no
-- expertise/assignment counts needed there).
CREATE OR REPLACE FUNCTION list_panelists_public(p_program TEXT)
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'panel_id', pl.panel_id, 'full_name', pl.full_name, 'position', pl.position
    ) ORDER BY pl.full_name), '[]'::jsonb)
    FROM panelist pl
    WHERE lower(trim(pl.program)) = lower(trim(p_program));
$$;

CREATE OR REPLACE FUNCTION register_panelist(
    p_full_name TEXT,
    p_position  TEXT,
    p_program   TEXT
) RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    INSERT INTO panelist (full_name, position, program)
    VALUES (p_full_name, p_position, p_program)
    RETURNING to_jsonb(panelist) || jsonb_build_object('expertise', '[]'::jsonb, 'assignment_count', 0);
$$;

CREATE OR REPLACE FUNCTION admin_update_panelist(
    p_panel_id  BIGINT,
    p_full_name TEXT,
    p_position  TEXT
) RETURNS panelist
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row panelist;
BEGIN
    UPDATE panelist
    SET full_name = p_full_name, position = p_position
    WHERE panel_id = p_panel_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Panelist not found';
    END IF;

    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION admin_delete_panelist(p_panel_id BIGINT)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    DELETE FROM panelist WHERE panel_id = p_panel_id;
$$;

CREATE OR REPLACE FUNCTION add_panel_expertise(p_panel_id BIGINT, p_expertise TEXT)
RETURNS expertise
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    INSERT INTO expertise (panel_id, expertise)
    VALUES (p_panel_id, trim(p_expertise))
    ON CONFLICT (panel_id, expertise) DO UPDATE SET expertise = excluded.expertise
    RETURNING *;
$$;

CREATE OR REPLACE FUNCTION set_expertise_embedding(p_exs_id BIGINT, p_embedding extensions.vector(384))
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public, extensions AS $$
    UPDATE expertise SET expertise_embedding = p_embedding WHERE exs_id = p_exs_id;
$$;

CREATE OR REPLACE FUNCTION remove_panel_expertise(p_exs_id BIGINT)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    DELETE FROM expertise WHERE exs_id = p_exs_id;
$$;

-- ============================================================
-- Let the app's anon key actually call these
-- ============================================================
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- ============================================================
-- SEED: program chairpersons
--
-- Admins are provisioned by hand, one per program, not through
-- the app. Copy the block below per additional program (BSCS,
-- BSIS, etc.), changing the email/password/name/program.
--
-- IMPORTANT: replace the placeholder name, email, and password
-- before real use — this is a starter account only.
-- ============================================================

WITH new_role AS (
    SELECT id FROM roles WHERE role_name = 'admin'
), new_user AS (
    INSERT INTO users_credentials (role_id, email, password)
    SELECT id, 'it.chair@carsu.edu.ph', crypt('admin16!', gen_salt('bf'))
    FROM new_role
    RETURNING id
)
INSERT INTO program_chairperson (user_id, full_name, position, program, status)
SELECT id, 'IT Program Chairperson', 'Program Chairperson', 'BS Information Technology', 'MSc'
FROM new_user;
