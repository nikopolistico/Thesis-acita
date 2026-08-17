import type { StudentInformation, ThesisTitle } from '~/types/database'

export interface StudentScheduleEntry {
  id: number
  schedule_date: string
  start_time: string
  end_time: string
  venue: string | null
  status: string
  thesis_title: string
  panel: { role_in_panel: string, status: string, full_name: string, position: string | null }[]
}

export function useStudents() {
  const supabase = useSupabase()

  async function getProfile(userId: number): Promise<StudentInformation | null> {
    const { data, error } = await supabase.rpc('get_student_profile', { p_user_id: userId })
    if (error)
      throw error
    return data
  }

  async function getThesisTitles(studentId: number): Promise<ThesisTitle[]> {
    const { data, error } = await supabase.rpc('get_student_thesis_titles', { p_student_id: studentId })
    if (error)
      throw error
    return data ?? []
  }

  async function addThesisTitle(studentId: number, title: string): Promise<ThesisTitle> {
    const { data, error } = await supabase.rpc('add_thesis_title', { p_student_id: studentId, p_title: title })
    if (error)
      throw error
    return data
  }

  async function getSchedules(studentId: number): Promise<StudentScheduleEntry[]> {
    const { data, error } = await supabase.rpc('get_student_schedules', { p_student_id: studentId })
    if (error)
      throw error
    return data ?? []
  }

  return { getProfile, getThesisTitles, addThesisTitle, getSchedules }
}
