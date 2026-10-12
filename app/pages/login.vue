<script setup lang="ts">
import { AlertCircle, Eye, EyeOff, Loader2 } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import type { AuthUser } from '~/composables/useAuthUser'

const email = ref('')
const password = ref('')
const role = ref('')
const showPassword = ref(false)
const isSubmitting = ref(false)
const errorMessage = ref('')

const roles = [
  { value: 'student', label: 'Student' },
  { value: 'admin', label: 'Administrator' },
]

const roleNameByValue: Record<string, string> = {
  student: 'student',
  admin: 'admin',
}

const dashboardByRole: Record<string, string> = {
  student: '/dashboard/student',
  admin: '/dashboard/admin',
}

const authUser = useAuthUser()

async function handleSubmit() {
  errorMessage.value = ''
  isSubmitting.value = true
  try {
    const user = await $fetch<AuthUser>('/api/auth/login', {
      method: 'POST',
      body: {
        email: email.value,
        password: password.value,
        role: roleNameByValue[role.value],
      },
    })
    authUser.value = user
    await navigateTo(dashboardByRole[user.role])
  }
  catch (error: any) {
    errorMessage.value = error?.data?.statusMessage ?? 'Something went wrong. Please try again.'
  }
  finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <AuthShell
    heading="Sign in"
    intro="Use the email and role you registered with."
    aside-title="Your thesis panel, matched to your topic."
    aside-text="Students submit a title and see their panel. Chairpersons keep panelist expertise up to date."
    :aside-items="['Title matching', 'Chair and members', 'Per-program lists']"
  >
    <form class="flex flex-col gap-5" @submit.prevent="handleSubmit">
      <Transition name="pop">
      <div v-if="errorMessage" role="alert" class="flex items-start gap-2 rounded-md border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
        <AlertCircle class="mt-0.5 size-4 shrink-0" />
        <span>{{ errorMessage }}</span>
      </div>
      </Transition>

      <div class="flex flex-col gap-2">
        <Label for="email">Email</Label>
        <Input id="email" v-model="email" type="email" placeholder="you@carsu.edu.ph" autocomplete="email" class="h-10" required />
      </div>

      <div class="flex flex-col gap-2">
        <Label for="password">Password</Label>
        <div class="relative">
          <Input
            id="password"
            v-model="password"
            :type="showPassword ? 'text' : 'password'"
            autocomplete="current-password"
            class="h-10 pr-10"
            required
          />
          <button
            type="button"
            class="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
            :aria-label="showPassword ? 'Hide password' : 'Show password'"
            @click="showPassword = !showPassword"
          >
            <EyeOff v-if="showPassword" class="size-4" />
            <Eye v-else class="size-4" />
          </button>
        </div>
      </div>

      <div class="flex flex-col gap-2">
        <Label for="role">I am a</Label>
        <Select v-model="role" required>
          <SelectTrigger id="role" class="h-10 w-full">
            <SelectValue placeholder="Choose your role" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem v-for="option in roles" :key="option.value" :value="option.value">
              {{ option.label }}
            </SelectItem>
          </SelectContent>
        </Select>
      </div>

      <Button type="submit" size="lg" class="mt-1 w-full" :disabled="isSubmitting">
        <Loader2 v-if="isSubmitting" class="size-4 animate-spin" />
        {{ isSubmitting ? 'Signing in...' : 'Sign in' }}
      </Button>
    </form>

    <p class="mt-6 text-sm text-muted-foreground">
      No account yet?
      <NuxtLink to="/register" class="font-medium text-primary underline-offset-4 hover:underline">
        Create a student account
      </NuxtLink>
    </p>
  </AuthShell>
</template>
