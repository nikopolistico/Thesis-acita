export interface AdminStudentEntry {
  id: number
  user_id: number
  full_name: string
  program: string | null
  email: string
  created_at: string
}

export interface AdminPanelistEntry {
  id: number
  user_id: number
  full_name: string
  position: string | null
  email: string
  expertise: { id: number, expertise_area: string }[]
  created_at: string
}

export interface AdminThesisTitleEntry {
  id: number
  student_id: number
  title: string
  student_name: string
  created_at: string
}

export interface AdminScheduleEntry {
  id: number
  title_id: number
  student_id: number
  schedule_date: string
  start_time: string
  end_time: string
  venue: string | null
  status: string
  thesis_title: string
  student_name: string
}

export interface AdminAssignmentEntry {
  id: number
  schedule_id: number
  panelist_id: number
  role_in_panel: string
  status: string
  panelist_name: string
  thesis_title: string
  schedule_date: string
}

export interface AdminUserEntry {
  id: number
  email: string
  role_name: string
}

export interface AdminOverviewStats {
  students: number
  panelists: number
  schedules: number
  pending_assignments: number
}

export function useAdmin() {
  const supabase = useSupabase()

  async function listStudents(): Promise<AdminStudentEntry[]> {
    const { data, error } = await supabase.rpc('admin_list_students')
    if (error)
      throw error
    return data ?? []
  }

  async function listPanelists(): Promise<AdminPanelistEntry[]> {
    const { data, error } = await supabase.rpc('admin_list_panelists')
    if (error)
      throw error
    return data ?? []
  }

  async function registerPanelist(payload: {
    fullName: string
    email: string
    password: string
    position: string
  }): Promise<AdminPanelistEntry> {
    const { data, error } = await supabase.rpc('register_panelist', {
      p_full_name: payload.fullName,
      p_email: payload.email,
      p_password: payload.password,
      p_position: payload.position,
    })
    if (error)
      throw error
    return data
  }

  async function updatePanelist(id: number, payload: { fullName: string, position: string }) {
    const { data, error } = await supabase.rpc('admin_update_panelist', {
      p_panelist_id: id,
      p_full_name: payload.fullName,
      p_position: payload.position,
    })
    if (error)
      throw error
    return data as { id: number, full_name: string, position: string | null }
  }

  async function listTitles(): Promise<AdminThesisTitleEntry[]> {
    const { data, error } = await supabase.rpc('admin_list_thesis_titles')
    if (error)
      throw error
    return data ?? []
  }

  async function listSchedules(): Promise<AdminScheduleEntry[]> {
    const { data, error } = await supabase.rpc('admin_list_schedules')
    if (error)
      throw error
    return data ?? []
  }

  async function createSchedule(payload: {
    titleId: number
    scheduleDate: string
    startTime: string
    endTime: string
    venue: string | null
  }) {
    const { data, error } = await supabase.rpc('admin_create_schedule', {
      p_title_id: payload.titleId,
      p_schedule_date: payload.scheduleDate,
      p_start_time: payload.startTime,
      p_end_time: payload.endTime,
      p_venue: payload.venue,
    })
    if (error)
      throw error
    return data
  }

  async function listAssignments(): Promise<AdminAssignmentEntry[]> {
    const { data, error } = await supabase.rpc('admin_list_assignments')
    if (error)
      throw error
    return data ?? []
  }

  async function createAssignment(payload: { scheduleId: number, panelistId: number, roleInPanel: string }) {
    const { data, error } = await supabase.rpc('admin_create_assignment', {
      p_schedule_id: payload.scheduleId,
      p_panelist_id: payload.panelistId,
      p_role_in_panel: payload.roleInPanel,
    })
    if (error)
      throw error
    return data
  }

  async function listUsers(): Promise<AdminUserEntry[]> {
    const { data, error } = await supabase.rpc('admin_list_users')
    if (error)
      throw error
    return data ?? []
  }

  async function deleteStudent(id: number): Promise<void> {
    const { error } = await supabase.rpc('admin_delete_student', { p_student_id: id })
    if (error)
      throw error
  }

  async function deletePanelist(id: number): Promise<void> {
    const { error } = await supabase.rpc('admin_delete_panelist', { p_panelist_id: id })
    if (error)
      throw error
  }

  async function overviewStats(): Promise<AdminOverviewStats> {
    const { data, error } = await supabase.rpc('admin_overview_stats')
    if (error)
      throw error
    return data
  }

  return {
    listStudents,
    listPanelists,
    registerPanelist,
    updatePanelist,
    listTitles,
    listSchedules,
    createSchedule,
    listAssignments,
    createAssignment,
    listUsers,
    deleteStudent,
    deletePanelist,
    overviewStats,
  }
}
