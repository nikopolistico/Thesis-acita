import type { PanelExpertise, PanelistInformation } from '~/types/database'

export interface PanelistAssignmentEntry {
  id: number
  role_in_panel: string
  status: string
  schedule_date: string
  start_time: string
  end_time: string
  venue: string | null
  thesis_title: string
  student_name: string
}

export function usePanelists() {
  const supabase = useSupabase()

  async function getProfile(userId: number): Promise<PanelistInformation | null> {
    const { data, error } = await supabase.rpc('get_panelist_profile', { p_user_id: userId })
    if (error)
      throw error
    return data
  }

  async function getAssignments(panelistId: number): Promise<PanelistAssignmentEntry[]> {
    const { data, error } = await supabase.rpc('get_panelist_assignments', { p_panelist_id: panelistId })
    if (error)
      throw error
    return data ?? []
  }

  async function getExpertise(panelistId: number): Promise<PanelExpertise[]> {
    const { data, error } = await supabase.rpc('get_panelist_expertise', { p_panelist_id: panelistId })
    if (error)
      throw error
    return data ?? []
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

  async function updateAssignmentStatus(assignmentId: number, status: 'confirmed' | 'declined'): Promise<void> {
    const { error } = await supabase.rpc('update_assignment_status', { p_assignment_id: assignmentId, p_status: status })
    if (error)
      throw error
  }

  return { getProfile, getAssignments, getExpertise, addExpertise, removeExpertise, updateAssignmentStatus }
}
