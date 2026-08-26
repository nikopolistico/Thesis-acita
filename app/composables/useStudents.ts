import type { StudentInformation, ThesisPanelMember, ThesisTitle } from '~/types/database'

export interface ExpertiseRecommendation {
  recommendedExpertise: string[]
  reasoning: string
}

export function useStudents() {
  const supabase = useSupabase()

  async function getProfile(userId: number): Promise<StudentInformation | null> {
    const { data, error } = await supabase.rpc('get_student_profile', { p_user_id: userId })
    if (error)
      throw error
    return data
  }

  async function getThesis(studentId: number): Promise<ThesisTitle | null> {
    const { data, error } = await supabase.rpc('get_student_thesis', { p_student_id: studentId })
    if (error)
      throw error
    return data
  }

  async function submitThesis(studentId: number, payload: { title: string, link: string, adviserName: string }): Promise<ThesisTitle> {
    const { data, error } = await supabase.rpc('submit_student_thesis', {
      p_student_id: studentId,
      p_title: payload.title,
      p_link: payload.link,
      p_adviser_name: payload.adviserName,
    })
    if (error)
      throw error
    return data
  }

  async function recommendExpertise(title: string): Promise<ExpertiseRecommendation> {
    return $fetch<ExpertiseRecommendation>('/api/ai/recommend-expertise', {
      method: 'POST',
      body: { title },
    })
  }

  async function getPanel(thesisId: number): Promise<ThesisPanelMember[]> {
    const { data, error } = await supabase.rpc('get_thesis_panel', { p_thesis_id: thesisId })
    if (error)
      throw error
    return data ?? []
  }

  async function autoAssignPanel(thesisId: number, expertiseAreas: string[]): Promise<ThesisPanelMember[]> {
    const { data, error } = await supabase.rpc('auto_assign_panel', {
      p_thesis_id: thesisId,
      p_expertise_areas: expertiseAreas,
    })
    if (error)
      throw error
    return data ?? []
  }

  return { getProfile, getThesis, submitThesis, recommendExpertise, getPanel, autoAssignPanel }
}
