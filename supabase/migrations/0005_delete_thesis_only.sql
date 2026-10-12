-- Chairperson "delete" removes only the student's thesis submission
-- (and its panel assignments via cascade). The login and student
-- profile stay, so the student can sign in and submit again.
DROP FUNCTION IF EXISTS admin_delete_student(BIGINT, TEXT);

CREATE OR REPLACE FUNCTION admin_delete_thesis(p_stu_id BIGINT, p_program TEXT)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    DELETE FROM thesis
    WHERE stu_id = p_stu_id
      AND stu_id IN (
          SELECT stu_id FROM student
          WHERE lower(trim(program)) = lower(trim(p_program))
      );
$$;
