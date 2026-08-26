import type { AdminInformation, PanelExpertise } from '~/types/database'

export interface AdminThesisPanelMember {
  role_in_panel: 'chair' | 'member'
  status: string
  full_name: string
  position: string | null
}

export interface AdminStudentEntry {
  id: number
  user_id: number
  full_name: string
  program: string | null
  email: string
  thesis_id: number | null
  title: string | null
  link: string | null
  adviser_name: string | null
  created_at: string
  panel: AdminThesisPanelMember[]
}

export interface AdminPanelistEntry {
  id: number
  full_name: string
  position: string | null
  email: string | null
  program: string
  created_at: string
  expertise: PanelExpertise[]
  assignment_count: number
}

export function useAdmin() {
  const supabase = useSupabase()

  async function getProfile(userId: number): Promise<AdminInformation | null> {
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

  async function listPanelists(program: string): Promise<AdminPanelistEntry[]> {
    const { data, error } = await supabase.rpc('admin_list_panelists', { p_program: program })
    if (error)
      throw error
    return data ?? []
  }

  async function registerPanelist(payload: { fullName: string, email: string, position: string, program: string }): Promise<AdminPanelistEntry> {
    const { data, error } = await supabase.rpc('register_panelist', {
      p_full_name: payload.fullName,
      p_email: payload.email || null,
      p_position: payload.position || null,
      p_program: payload.program,
    })
    if (error)
      throw error
    return data
  }

  async function updatePanelist(panelistId: number, payload: { fullName: string, position: string }): Promise<void> {
    const { error } = await supabase.rpc('admin_update_panelist', {
      p_panelist_id: panelistId,
      p_full_name: payload.fullName,
      p_position: payload.position || null,
    })
    if (error)
      throw error
  }

  async function deletePanelist(panelistId: number): Promise<void> {
    const { error } = await supabase.rpc('admin_delete_panelist', { p_panelist_id: panelistId })
    if (error)
      throw error
  }

  async function addExpertise(panelistId: number, expertiseArea: string): Promise<PanelExpertise> {
    const { data, error } = await supabase.rpc('add_panel_expertise', { p_panelist_id: panelistId, p_expertise_area: expertiseArea })
    if (error)
      throw error
    return data
  }

  async function removeExpertise(expertiseId: number): Promise<void> {
    const { error } = await supabase.rpc('remove_panel_expertise', { p_expertise_id: expertiseId })
    if (error)
      throw error
  }

  return { getProfile, listStudents, listPanelists, registerPanelist, updatePanelist, deletePanelist, addExpertise, removeExpertise }
}
