-- 1. Chairperson can delete a student of their own program.
--    Deleting the login row cascades to student -> thesis -> assigned_panelist,
--    which also frees that student's panelist slots.
CREATE OR REPLACE FUNCTION admin_delete_student(p_stu_id BIGINT, p_program TEXT)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    DELETE FROM users_credentials
    WHERE id = (
        SELECT user_id FROM student
        WHERE stu_id = p_stu_id
          AND lower(trim(program)) = lower(trim(p_program))
    );
$$;

-- 2. A panelist already on 5 theses is skipped by auto-assignment.
CREATE OR REPLACE FUNCTION auto_assign_panel(
    p_thesis_id       BIGINT,
    p_query_embedding extensions.vector(384)
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    c_max_assignments CONSTANT INT := 5;
    v_has_chair     BOOLEAN;
    v_member_count  INT;
    v_candidate     RECORD;
BEGIN
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
          AND p.panel_id NOT IN (SELECT panel_id FROM assigned_panelist WHERE thesis_id = p_thesis_id)
          AND p.panel_id IS DISTINCT FROM (SELECT adviser_id FROM thesis WHERE thesis_id = p_thesis_id)
          AND (SELECT count(*) FROM assigned_panelist ap WHERE ap.panel_id = p.panel_id) < c_max_assignments
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
