import { StorageSerializers, useSessionStorage } from '@vueuse/core'

export interface AuthUser {
  id: number
  email: string
  role: 'admin' | 'student'
}

export function useAuthUser() {
  return useSessionStorage<AuthUser | null>('auth_user', null, {
    serializer: StorageSerializers.object,
  })
}
