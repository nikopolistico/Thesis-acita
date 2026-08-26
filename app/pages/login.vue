<script setup lang="ts">
import {
  AlertCircle,
  ArrowLeft,
  CheckCircle2,
  Eye,
  EyeOff,
  Loader2,
  Lock,
  Mail,
  UserRound,
} from '@lucide/vue'
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

const highlights = [
  'Submit your thesis title, link, and adviser in one place',
  'Track your submission status at a glance',
  'One dashboard per program chairperson and their students',
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
  <div class="grid min-h-screen lg:grid-cols-2">
    <div class="relative hidden flex-col justify-between overflow-hidden bg-primary p-10 text-primary-foreground lg:flex">
      <div
        class="pointer-events-none absolute inset-0 opacity-20"
        style="background-image: radial-gradient(circle, currentColor 1.5px, transparent 1.5px); background-size: 24px 24px;"
      />
      <div class="absolute -right-24 -top-24 size-96 rounded-full bg-white/10 blur-3xl" />
      <div class="absolute -bottom-32 -left-16 size-96 rounded-full bg-black/10 blur-3xl" />

      <NuxtLink to="/" class="relative z-10 flex items-center gap-2 font-semibold">
        <span class="flex size-12 items-center justify-center rounded-full bg-white p-1.5 shadow-sm">
          <img src="~/assets/images/logo.png" alt="Caraga State University logo" class="size-full object-contain">
        </span>
        CCIS Panelist Automation Assign
      </NuxtLink>

      <div class="relative z-10 max-w-md">
        <h1 class="text-3xl font-bold tracking-tight text-balance">
          Coordinate thesis defenses without the chaos.
        </h1>
        <p class="mt-4 text-primary-foreground/80 text-pretty">
          Sign in to manage schedules, panel assignments, and defense outcomes in one place.
        </p>
        <ul class="mt-8 space-y-3">
          <li v-for="item in highlights" :key="item" class="flex items-start gap-2.5 text-sm">
            <CheckCircle2 class="mt-0.5 size-4 shrink-0" />
            <span class="text-primary-foreground/90">{{ item }}</span>
          </li>
        </ul>
      </div>

      <p class="relative z-10 text-xs text-primary-foreground/60">
        &copy; {{ new Date().getFullYear() }} CCIS Thesis Defense Scheduling System
      </p>
    </div>

    <div class="relative flex min-h-screen flex-col items-center justify-center gap-8 px-4 py-12 sm:px-6">
      <NuxtLink
        to="/"
        class="absolute left-4 top-4 inline-flex items-center gap-1.5 text-sm font-medium text-muted-foreground hover:text-foreground sm:left-6 sm:top-6"
      >
        <ArrowLeft class="size-4" />
        Back
      </NuxtLink>
      <div class="absolute right-4 top-4 sm:right-6 sm:top-6">
        <ThemeToggle />
      </div>

      <NuxtLink to="/" class="flex items-center gap-2 font-semibold lg:hidden">
        <span class="flex size-10 items-center justify-center rounded-full bg-white p-1 shadow-sm ring-1 ring-border">
          <img src="~/assets/images/logo.png" alt="Caraga State University logo" class="size-full object-contain">
        </span>
        CCIS Panelist Automation Assign
      </NuxtLink>

      <div class="mx-auto w-full max-w-sm">
        <div class="mb-8 text-center">
          <h2 class="text-2xl font-bold tracking-tight">
            Welcome back
          </h2>
          <p class="mt-2 text-sm text-muted-foreground">
            Enter your credentials to access your account.
          </p>
        </div>

        <form class="flex flex-col gap-5" @submit.prevent="handleSubmit">
          <div v-if="errorMessage" class="flex items-start gap-2 rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
            <AlertCircle class="mt-0.5 size-4 shrink-0" />
            <span>{{ errorMessage }}</span>
          </div>

          <div class="flex flex-col gap-2">
            <Label for="email">Email</Label>
            <div class="relative">
              <Mail class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                id="email"
                v-model="email"
                type="email"
                placeholder="you@example.com"
                autocomplete="email"
                class="h-10 pl-9"
                required
              />
            </div>
          </div>

          <div class="flex flex-col gap-2">
            <div class="flex items-center justify-between">
              <Label for="password">Password</Label>
              <a href="#" class="text-xs font-medium text-primary hover:underline">Forgot password?</a>
            </div>
            <div class="relative">
              <Lock class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                id="password"
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                placeholder="••••••••"
                autocomplete="current-password"
                class="h-10 px-9"
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
            <Label for="role">Role</Label>
            <Select v-model="role" required>
              <SelectTrigger id="role" class="h-10 w-full">
                <div class="flex items-center gap-2">
                  <UserRound class="size-4 text-muted-foreground" />
                  <SelectValue placeholder="Select your role" />
                </div>
              </SelectTrigger>
              <SelectContent>
                <SelectItem v-for="option in roles" :key="option.value" :value="option.value">
                  {{ option.label }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>

          <Button type="submit" size="lg" class="mt-2 w-full" :disabled="isSubmitting">
            <Loader2 v-if="isSubmitting" class="size-4 animate-spin" />
            {{ isSubmitting ? 'Signing in...' : 'Sign in' }}
          </Button>
        </form>

        <p class="mt-6 text-center text-sm text-muted-foreground">
          Don't have an account?
          <NuxtLink to="/register" class="font-medium text-primary hover:underline">
            Register
          </NuxtLink>
        </p>
      </div>
    </div>
  </div>
</template>
