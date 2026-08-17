export interface Role {
  id: number
  role_name: 'admin' | 'panelist' | 'student'
  description: string | null
  created_at: string
}

export interface UserCredential {
  id: number
  role_id: number
  email: string
  password: string
  status: 'active' | 'disabled'
  created_at: string
}

export interface AdminInformation {
  id: number
  user_id: number
  full_name: string
  position: string | null
  created_at: string
}

export interface StudentInformation {
  id: number
  user_id: number
  full_name: string
  program: string | null
  created_at: string
}

export interface PanelistInformation {
  id: number
  user_id: number
  full_name: string
  position: string | null
  created_at: string
}

export interface PanelExpertise {
  id: number
  panelist_id: number
  expertise_area: string
  created_at: string
}

export interface ThesisTitle {
  id: number
  student_id: number
  title: string
  created_at: string
}

export interface ThesisSchedule {
  id: number
  title_id: number
  student_id: number
  schedule_date: string
  start_time: string
  end_time: string
  venue: string | null
  status: 'pending' | 'scheduled' | 'completed' | 'cancelled'
  created_at: string
}

export interface PanelAssignment {
  id: number
  schedule_id: number
  panelist_id: number
  role_in_panel: 'chair' | 'member' | 'adviser'
  status: 'assigned' | 'confirmed' | 'declined'
  created_at: string
}

export interface Notification {
  id: number
  user_id: number
  message: string
  is_read: boolean
  date_sent: string
}
