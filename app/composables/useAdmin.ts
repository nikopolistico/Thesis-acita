import type { ProgramChairperson } from '~/types/database'

export interface AdminThesisPanelMember {
  role: 'chair' | 'member'
  full_name: string
  position: string | null
}

export interface AdminStudentEntry {
  stu_id: number
  user_id: number
  student_name: string
  partner_name: string | null
  program: string | null
  course: string | null
  email: string
  thesis_id: number | null
  title: string | null
  link: string | null
  adviser_name: string | null
  created_at: string
  panel: AdminThesisPanelMember[]
}

export interface AdminExpertiseTag {
  exs_id: number
  expertise: string
}

export interface AdminPanelistEntry {
  panel_id: number
  full_name: string
  position: string | null
  program: string
  status: string | null
  created_at: string
  expertise: AdminExpertiseTag[]
  assignment_count: number
}

export function useAdmin() {
  const supabase = useSupabase()

  async function getProfile(userId: number): Promise<ProgramChairperson | null> {
    const { data, error } = await supabase.rpc('get_admin_profile', { p_user_id: userId })
    if (error)
      throw error
    return data
  }

  async function listStudents(program: string): Promise<AdminStudentEntry[]> {
    const { data, error } = await supabase.rpc('admin_list_students', { p_program: program })
    if (error)
      throw error
    return data ?? []
  }

  async function deleteStudent(stuId: number, program: string): Promise<void> {
    const { error } = await supabase.rpc('admin_delete_student', { p_stu_id: stuId, p_program: program })
    if (error)
      throw error
  }

  async function listPanelists(program: string): Promise<AdminPanelistEntry[]> {
    const { data, error } = await supabase.rpc('admin_list_panelists', { p_program: program })
    if (error)
      throw error
    return data ?? []
  }

  async function registerPanelist(payload: { fullName: string, position: string, program: string }): Promise<AdminPanelistEntry> {
    const { data, error } = await supabase.rpc('register_panelist', {
      p_full_name: payload.fullName,
      p_position: payload.position || null,
      p_program: payload.program,
    })
    if (error)
      throw error
    return data
  }

  async function updatePanelist(panelId: number, payload: { fullName: string, position: string }): Promise<void> {
    const { error } = await supabase.rpc('admin_update_panelist', {
      p_panel_id: panelId,
      p_full_name: payload.fullName,
      p_position: payload.position || null,
    })
    if (error)
      throw error
  }

  async function deletePanelist(panelId: number): Promise<void> {
    const { error } = await supabase.rpc('admin_delete_panelist', { p_panel_id: panelId })
    if (error)
      throw error
  }

  async function addExpertise(panelId: number, expertise: string): Promise<AdminExpertiseTag> {
    return $fetch<AdminExpertiseTag>('/api/admin/add-expertise', {
      method: 'POST',
      body: { panelId, expertise },
    })
  }

  async function removeExpertise(exsId: number): Promise<void> {
    const { error } = await supabase.rpc('remove_panel_expertise', { p_exs_id: exsId })
    if (error)
      throw error
  }

  return { getProfile, listStudents, deleteStudent, listPanelists, registerPanelist, updatePanelist, deletePanelist, addExpertise, removeExpertise }
}
