import type { Notification } from '~/types/database'

export interface AdminNotificationEntry extends Notification {
  recipient_email: string
}

export function useNotifications() {
  const supabase = useSupabase()

  async function list(userId: number): Promise<Notification[]> {
    const { data, error } = await supabase.rpc('get_user_notifications', { p_user_id: userId })
    if (error)
      throw error
    return data ?? []
  }

  async function markRead(notificationId: number): Promise<void> {
    const { error } = await supabase.rpc('mark_notification_read', { p_notification_id: notificationId })
    if (error)
      throw error
  }

  async function adminList(): Promise<AdminNotificationEntry[]> {
    const { data, error } = await supabase.rpc('admin_list_notifications')
    if (error)
      throw error
    return data ?? []
  }

  async function adminSend(userId: number, message: string): Promise<AdminNotificationEntry> {
    const { data, error } = await supabase.rpc('admin_send_notification', { p_user_id: userId, p_message: message })
    if (error)
      throw error
    return data
  }

  return { list, markRead, adminList, adminSend }
}
