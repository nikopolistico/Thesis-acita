export interface Role {
  id: number
  role_name: 'admin' | 'student'
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
  program: string
  created_at: string
}

export interface StudentInformation {
  id: number
  user_id: number
  full_name: string
  program: string | null
  created_at: string
}

export interface ThesisTitle {
  id: number
  student_id: number
  title: string
  link: string | null
  adviser_name: string | null
  created_at: string
}

export interface PanelistInformation {
  id: number
  full_name: string
  position: string | null
  email: string | null
  program: string
  created_at: string
}

export interface PanelExpertise {
  id: number
  panelist_id: number
  expertise_area: string
  created_at: string
}

export interface ThesisPanelMember {
  id: number
  role_in_panel: 'chair' | 'member'
  status: string
  panelist_id: number
  full_name: string
  position: string | null
}
