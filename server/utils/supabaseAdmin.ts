import { createClient, type SupabaseClient } from '@supabase/supabase-js'

let client: SupabaseClient | null = null

export function useSupabaseAdmin(): SupabaseClient {
  if (!client) {
    const config = useRuntimeConfig()
    client = createClient(config.public.supabaseUrl, config.supabaseServiceRoleKey, {
      auth: { persistSession: false },
    })
  }
  return client
}
