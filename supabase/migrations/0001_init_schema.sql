-- ============================================================
-- Web-Based Thesis Scheduling System with Expertise-Based
-- Panel Assignment — Database Schema (PostgreSQL / Supabase)
-- ============================================================

-- Drop tables if re-running during development
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

-- ============================================================
-- 1. ROLES (for RBAC)
-- ============================================================
CREATE TABLE roles (
    id          BIGSERIAL PRIMARY KEY,
    role_name   TEXT NOT NULL UNIQUE,      -- 'admin', 'panelist', 'student'
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
-- 3. ADMIN_INFORMATION (profile only, no expertise)
-- ============================================================
CREATE TABLE admin_information (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users_credentials(id) ON DELETE CASCADE,
    full_name   TEXT NOT NULL,
    position    TEXT,
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
-- 5. PANELIST_INFORMATION (profile only, no title_id here anymore)
-- ============================================================
CREATE TABLE panelist_information (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users_credentials(id) ON DELETE CASCADE,
    full_name   TEXT NOT NULL,
    position    TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 6. PANEL_EXPERTISE (one-to-many: a panelist can have several
--    areas of specialization — supports expertise-based matching)
-- ============================================================
CREATE TABLE panel_expertise (
    id              BIGSERIAL PRIMARY KEY,
    panelist_id     BIGINT NOT NULL REFERENCES panelist_information(id) ON DELETE CASCADE,
    expertise_area  TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 7. THESIS_TITLE (separated from schedule, one thesis can be
--    rescheduled without duplicating the title record)
-- ============================================================
CREATE TABLE thesis_title (
    id          BIGSERIAL PRIMARY KEY,
    student_id  BIGINT NOT NULL REFERENCES student_information(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 8. THESIS_SCHEDULE
-- ============================================================
CREATE TABLE thesis_schedule (
    id              BIGSERIAL PRIMARY KEY,
    title_id        BIGINT NOT NULL REFERENCES thesis_title(id) ON DELETE CASCADE,
    student_id      BIGINT NOT NULL REFERENCES student_information(id) ON DELETE CASCADE,
    schedule_date   DATE NOT NULL,
    start_time      TIME NOT NULL,
    end_time        TIME NOT NULL,
    venue           TEXT,
    status          TEXT NOT NULL DEFAULT 'pending', -- pending / scheduled / completed / cancelled
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 9. PANEL_ASSIGNMENTS (junction table: schedule <-> panelist)
-- ============================================================
CREATE TABLE panel_assignments (
    id              BIGSERIAL PRIMARY KEY,
    schedule_id     BIGINT NOT NULL REFERENCES thesis_schedule(id) ON DELETE CASCADE,
    panelist_id     BIGINT NOT NULL REFERENCES panelist_information(id) ON DELETE CASCADE,
    role_in_panel   TEXT NOT NULL DEFAULT 'member', -- chair / member / adviser
    status          TEXT NOT NULL DEFAULT 'assigned', -- assigned / confirmed / declined
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (schedule_id, panelist_id)
);

-- ============================================================
-- 10. NOTIFICATIONS
-- ============================================================
CREATE TABLE notifications (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users_credentials(id) ON DELETE CASCADE,
    message     TEXT NOT NULL,
    is_read     BOOLEAN NOT NULL DEFAULT false,
    date_sent   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- SEED: default roles
-- ============================================================
INSERT INTO roles (role_name, description) VALUES
    ('admin', 'Manages schedules, panel assignments, and user accounts'),
    ('panelist', 'Evaluates thesis defenses based on assigned expertise'),
    ('student', 'Views thesis schedules and assigned panel members');

-- ============================================================
-- Helpful indexes
-- ============================================================
CREATE INDEX idx_panel_expertise_panelist ON panel_expertise(panelist_id);
CREATE INDEX idx_schedule_student ON thesis_schedule(student_id);
CREATE INDEX idx_assignments_schedule ON panel_assignments(schedule_id);
CREATE INDEX idx_assignments_panelist ON panel_assignments(panelist_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
