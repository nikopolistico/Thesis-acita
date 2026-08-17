-- ============================================================
-- Admin-managed panelist accounts: register + update.
-- (Delete and view already exist: admin_delete_panelist,
-- admin_list_panelists from 0002_rpc_functions.sql)
-- ============================================================

CREATE OR REPLACE FUNCTION register_panelist(
    p_full_name TEXT,
    p_email     TEXT,
    p_password  TEXT,
    p_position  TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_role_id BIGINT;
    v_user_id BIGINT;
    v_panelist panelist_information;
BEGIN
    SELECT id INTO v_role_id FROM roles WHERE role_name = 'panelist';
    IF v_role_id IS NULL THEN
        RAISE EXCEPTION 'Panelist role is not configured';
    END IF;

    INSERT INTO users_credentials (role_id, email, password)
    VALUES (v_role_id, p_email, crypt(p_password, gen_salt('bf')))
    RETURNING id INTO v_user_id;

    INSERT INTO panelist_information (user_id, full_name, position)
    VALUES (v_user_id, p_full_name, p_position)
    RETURNING * INTO v_panelist;

    RETURN to_jsonb(v_panelist) || jsonb_build_object('email', p_email, 'expertise', '[]'::jsonb);
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Email is already registered';
END;
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

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
