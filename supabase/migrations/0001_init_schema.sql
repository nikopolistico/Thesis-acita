-- ============================================================
-- Thesis Title/Link/Adviser Submission System — Database
-- Schema + RPC functions (PostgreSQL / Supabase)
--
-- Two login roles: student and admin. Each admin is a
-- program chairperson — scoped to one program (e.g. "BS
-- Computer Science") — and only ever sees/manages that
-- program's students and panelists. Admin accounts are
-- provisioned by hand (see the seed block at the bottom of this
-- file, which creates the first chairperson for BS Information
-- Technology), not through the app.
--
-- A student registers, then submits their thesis title, a link
-- to their document, and their adviser's name. Submitting (or
-- updating) a thesis triggers an AI expertise recommendation
-- (top 5 areas) on the client, which is fed into
-- auto_assign_panel() to automatically staff the thesis's panel
-- — 1 chair + 2 members — from that program's panelists, ranked
-- by how well their tagged expertise overlaps those areas.
-- Panelists are plain records the chairperson manages (name,
-- position, expertise tags) — they have no login of their own.
--
-- This file is a full reset: it drops every table this schema
-- owns (including retired ones) and rebuilds everything from
-- scratch, so it's safe to paste into the Supabase SQL editor at
-- any point during development.
-- SECURITY DEFINER: functions run with the privileges of their
-- owner, bypassing RLS. Access control lives in the app layer
-- (session cookie + route middleware).
-- ============================================================

-- ============================================================
-- 0. DROP EVERYTHING (clean slate, includes tables from earlier,
--    retired versions of this schema)
-- ============================================================
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS panel_assignments CASCADE;
DROP TABLE IF EXISTS panel_expertise CASCADE;
DROP TABLE IF EXISTS thesis_schedule CASCADE;
DROP TABLE IF EXISTS thesis_title CASCADE;
DROP TABLE IF EXISTS panelist_information CASCADE;
DROP TABLE IF EXISTS student_information CASCADE;
DROP TABLE IF EXISTS admin_information CASCADE;
DROP TABLE IF EXISTS users_credentials CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- Functions whose argument list is changing (count OR just
-- parameter names — Postgres treats a renamed IN parameter as a
-- conflict, not something CREATE OR REPLACE can update in
-- place), or that are being removed outright, need an explicit
-- drop. CASCADE from the table drops above only removes
-- functions whose signature depends on a dropped table's row
-- type; these return/accept plain scalars so they survive it.
DROP FUNCTION IF EXISTS admin_list_students();
DROP FUNCTION IF EXISTS admin_list_panelists();
DROP FUNCTION IF EXISTS get_panelist_assignments(BIGINT);
DROP FUNCTION IF EXISTS get_panelist_profile(BIGINT);
DROP FUNCTION IF EXISTS register_panelist(TEXT, TEXT, TEXT, TEXT);

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. ROLES (for RBAC)
-- ============================================================
CREATE TABLE roles (
    id          BIGSERIAL PRIMARY KEY,
    role_name   TEXT NOT NULL UNIQUE,      -- 'admin', 'student'
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. USERS_CREDENTIALS (login/auth table)
-- ============================================================
CREATE TABLE users_credentials (
    id          BIGSERIAL PRIMARY KEY,
    role_id     BIGINT NOT NULL REFERENCES roles(id),
    email       TEXT NOT NULL UNIQUE,
    password    TEXT NOT NULL,             -- store hashed password only
    status      TEXT NOT NULL DEFAULT 'active', -- active / disabled
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 3. ADMIN_INFORMATION (program chairperson profile — each
--    admin is scoped to exactly one program)
-- ============================================================
CREATE TABLE admin_information (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users_credentials(id) ON DELETE CASCADE,
    full_name   TEXT NOT NULL,
    position    TEXT,
    program     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 4. STUDENT_INFORMATION
-- ============================================================
CREATE TABLE student_information (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users_credentials(id) ON DELETE CASCADE,
    full_name   TEXT NOT NULL,
    program     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 5. THESIS_TITLE (one submission per student: title, link,
--    and adviser name)
-- ============================================================
CREATE TABLE thesis_title (
    id            BIGSERIAL PRIMARY KEY,
    student_id    BIGINT NOT NULL UNIQUE REFERENCES student_information(id) ON DELETE CASCADE,
    title         TEXT NOT NULL,
    link          TEXT,
    adviser_name  TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 6. PANELIST_INFORMATION (plain record, no login — managed
--    entirely by the program's chairperson)
-- ============================================================
CREATE TABLE panelist_information (
    id          BIGSERIAL PRIMARY KEY,
    full_name   TEXT NOT NULL,
    position    TEXT,
    email       TEXT,
    program     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 7. PANEL_EXPERTISE (tags a chairperson assigns to a panelist;
--    these are matched against the AI's recommended areas)
-- ============================================================
CREATE TABLE panel_expertise (
    id              BIGSERIAL PRIMARY KEY,
    panelist_id     BIGINT NOT NULL REFERENCES panelist_information(id) ON DELETE CASCADE,
    expertise_area  TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (panelist_id, expertise_area)
);

-- ============================================================
-- 8. PANEL_ASSIGNMENTS (one thesis has at most 1 chair + 2
--    members; auto-assigned, visible to the student and their
--    program's chairperson)
-- ============================================================
CREATE TABLE panel_assignments (
    id              BIGSERIAL PRIMARY KEY,
    thesis_id       BIGINT NOT NULL REFERENCES thesis_title(id) ON DELETE CASCADE,
    panelist_id     BIGINT NOT NULL REFERENCES panelist_information(id) ON DELETE CASCADE,
    role_in_panel   TEXT NOT NULL CHECK (role_in_panel IN ('chair', 'member')),
    status          TEXT NOT NULL DEFAULT 'assigned',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (thesis_id, panelist_id)
);

-- Only one chair per thesis (member cap of 2 is enforced by
-- auto_assign_panel, the only writer of this table).
CREATE UNIQUE INDEX panel_assignments_one_chair_per_thesis
    ON panel_assignments (thesis_id) WHERE role_in_panel = 'chair';

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

CREATE OR REPLACE FUNCTION get_student_thesis(p_student_id BIGINT)
RETURNS thesis_title
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT * FROM thesis_title WHERE student_id = p_student_id;
$$;

CREATE OR REPLACE FUNCTION submit_student_thesis(
    p_student_id   BIGINT,
    p_title        TEXT,
    p_link         TEXT,
    p_adviser_name TEXT
) RETURNS thesis_title
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    INSERT INTO thesis_title (student_id, title, link, adviser_name)
    VALUES (p_student_id, p_title, p_link, p_adviser_name)
    ON CONFLICT (student_id)
    DO UPDATE SET title = excluded.title, link = excluded.link, adviser_name = excluded.adviser_name
    RETURNING *;
$$;

-- ============================================================
-- PANEL (per-thesis view, shared by student and admin)
-- ============================================================

CREATE OR REPLACE FUNCTION get_thesis_panel(p_thesis_id BIGINT)
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', pa.id,
        'role_in_panel', pa.role_in_panel,
        'status', pa.status,
        'panelist_id', pi.id,
        'full_name', pi.full_name,
        'position', pi.position
    ) ORDER BY (pa.role_in_panel = 'chair') DESC, pa.id), '[]'::jsonb)
    FROM panel_assignments pa
    JOIN panelist_information pi ON pi.id = pa.panelist_id
    WHERE pa.thesis_id = p_thesis_id;
$$;

-- ============================================================
-- AUTOMATION: derive the thesis's program from its student,
-- then rank that program's untapped panelists by overlap with
-- the given expertise areas (case-insensitive substring match in
-- either direction), then fill chair -> member -> member from
-- the top. Existing assignments are never touched, so calling
-- this again only tops up open slots.
-- ============================================================

CREATE OR REPLACE FUNCTION auto_assign_panel(
    p_thesis_id         BIGINT,
    p_expertise_areas   TEXT[]
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_has_chair     BOOLEAN;
    v_member_count  INT;
    v_program       TEXT;
    v_candidate     RECORD;
BEGIN
    IF p_expertise_areas IS NULL OR array_length(p_expertise_areas, 1) IS NULL THEN
        RETURN get_thesis_panel(p_thesis_id);
    END IF;

    SELECT si.program INTO v_program
    FROM thesis_title tt
    JOIN student_information si ON si.id = tt.student_id
    WHERE tt.id = p_thesis_id;

    SELECT
        COALESCE(bool_or(role_in_panel = 'chair'), FALSE),
        COALESCE(count(*) FILTER (WHERE role_in_panel = 'member'), 0)
    INTO v_has_chair, v_member_count
    FROM panel_assignments
    WHERE thesis_id = p_thesis_id;

    IF v_has_chair AND v_member_count >= 2 THEN
        RETURN get_thesis_panel(p_thesis_id);
    END IF;

    FOR v_candidate IN
        SELECT pi.id, count(DISTINCT m.ea) AS match_count
        FROM panelist_information pi
        JOIN panel_expertise pe ON pe.panelist_id = pi.id
        CROSS JOIN unnest(p_expertise_areas) AS m(ea)
        WHERE (pe.expertise_area ILIKE '%' || m.ea || '%' OR m.ea ILIKE '%' || pe.expertise_area || '%')
          AND lower(trim(pi.program)) = lower(trim(coalesce(v_program, '')))
          AND pi.id NOT IN (SELECT panelist_id FROM panel_assignments WHERE thesis_id = p_thesis_id)
        GROUP BY pi.id
        ORDER BY
            match_count DESC,
            (SELECT count(*) FROM panel_assignments pa2 WHERE pa2.panelist_id = pi.id) ASC,
            pi.id ASC
    LOOP
        IF NOT v_has_chair THEN
            INSERT INTO panel_assignments (thesis_id, panelist_id, role_in_panel)
            VALUES (p_thesis_id, v_candidate.id, 'chair');
            v_has_chair := TRUE;
        ELSIF v_member_count < 2 THEN
            INSERT INTO panel_assignments (thesis_id, panelist_id, role_in_panel)
            VALUES (p_thesis_id, v_candidate.id, 'member');
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
RETURNS admin_information
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT * FROM admin_information WHERE user_id = p_user_id;
$$;

CREATE OR REPLACE FUNCTION admin_list_students(p_program TEXT)
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(s), '[]'::jsonb)
    FROM (
        SELECT
            si.id, si.user_id, si.full_name, si.program, si.created_at,
            uc.email,
            tt.id AS thesis_id, tt.title, tt.link, tt.adviser_name,
            (
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'role_in_panel', pa.role_in_panel,
                    'status', pa.status,
                    'full_name', pi.full_name,
                    'position', pi.position
                )), '[]'::jsonb)
                FROM panel_assignments pa
                JOIN panelist_information pi ON pi.id = pa.panelist_id
                WHERE pa.thesis_id = tt.id
            ) AS panel
        FROM student_information si
        JOIN users_credentials uc ON uc.id = si.user_id
        LEFT JOIN thesis_title tt ON tt.student_id = si.id
        WHERE lower(trim(si.program)) = lower(trim(p_program))
        ORDER BY si.created_at DESC
    ) s;
$$;

CREATE OR REPLACE FUNCTION admin_list_panelists(p_program TEXT)
RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(jsonb_agg(p), '[]'::jsonb)
    FROM (
        SELECT
            pi.id, pi.full_name, pi.position, pi.email, pi.program, pi.created_at,
            (
                SELECT COALESCE(jsonb_agg(jsonb_build_object('id', pe.id, 'expertise_area', pe.expertise_area)), '[]'::jsonb)
                FROM panel_expertise pe WHERE pe.panelist_id = pi.id
            ) AS expertise,
            (
                SELECT count(*) FROM panel_assignments pa WHERE pa.panelist_id = pi.id
            )::int AS assignment_count
        FROM panelist_information pi
        WHERE lower(trim(pi.program)) = lower(trim(p_program))
        ORDER BY pi.created_at DESC
    ) p;
$$;

CREATE OR REPLACE FUNCTION register_panelist(
    p_full_name TEXT,
    p_email     TEXT,
    p_position  TEXT,
    p_program   TEXT
) RETURNS JSONB
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    INSERT INTO panelist_information (full_name, email, position, program)
    VALUES (p_full_name, p_email, p_position, p_program)
    RETURNING to_jsonb(panelist_information) || jsonb_build_object('expertise', '[]'::jsonb, 'assignment_count', 0);
$$;

CREATE OR REPLACE FUNCTION admin_update_panelist(
    p_panelist_id BIGINT,
    p_full_name   TEXT,
    p_position    TEXT
) RETURNS panelist_information
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row panelist_information;
BEGIN
    UPDATE panelist_information
    SET full_name = p_full_name, position = p_position
    WHERE id = p_panelist_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Panelist not found';
    END IF;

    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION admin_delete_panelist(p_panelist_id BIGINT)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    DELETE FROM panelist_information WHERE id = p_panelist_id;
$$;

CREATE OR REPLACE FUNCTION add_panel_expertise(p_panelist_id BIGINT, p_expertise_area TEXT)
RETURNS panel_expertise
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    INSERT INTO panel_expertise (panelist_id, expertise_area)
    VALUES (p_panelist_id, trim(p_expertise_area))
    ON CONFLICT (panelist_id, expertise_area) DO UPDATE SET expertise_area = excluded.expertise_area
    RETURNING *;
$$;

CREATE OR REPLACE FUNCTION remove_panel_expertise(p_expertise_id BIGINT)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    DELETE FROM panel_expertise WHERE id = p_expertise_id;
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
    SELECT id, 'it.chair@carsu.edu.ph', crypt('ChangeMe123!', gen_salt('bf'))
    FROM new_role
    RETURNING id
)
INSERT INTO admin_information (user_id, full_name, position, program)
SELECT id, 'IT Program Chairperson', 'Program Chairperson', 'BS Information Technology'
FROM new_user;
