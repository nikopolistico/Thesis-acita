<script setup lang="ts">
import {
  AlertCircle,
  ArrowLeft,
  CheckCircle2,
  Eye,
  EyeOff,
  GraduationCap,
  Loader2,
  Lock,
  Mail,
  User,
} from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import type { AuthUser } from '~/composables/useAuthUser'

const fullName = ref('')
const email = ref('')
const program = ref('')
const password = ref('')
const confirmPassword = ref('')
const showPassword = ref(false)
const showConfirmPassword = ref(false)
const isSubmitting = ref(false)
const errorMessage = ref('')

const highlights = [
  'Upload your thesis title, document link, and adviser in one place',
  'Update your submission anytime from your dashboard',
  'Get Grok-suggested expertise areas for your topic instantly',
]

async function handleSubmit() {
  errorMessage.value = ''

  if (!email.value.toLowerCase().endsWith('@carsu.edu.ph')) {
    errorMessage.value = 'Please use your @carsu.edu.ph email address.'
    return
  }

  if (password.value !== confirmPassword.value) {
    errorMessage.value = 'Passwords do not match.'
    return
  }

  isSubmitting.value = true
  try {
    const user = await $fetch<AuthUser>('/api/auth/register', {
      method: 'POST',
      body: {
        fullName: fullName.value,
        email: email.value,
        program: program.value,
        password: password.value,
      },
    })
    useAuthUser().value = user
    await navigateTo('/dashboard/student')
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
          Create your student account.
        </h1>
        <p class="mt-4 text-primary-foreground/80 text-pretty">
          Register once, then submit your thesis title, link, and adviser from your dashboard.
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
            Create an account
          </h2>
          <p class="mt-2 text-sm text-muted-foreground">
            Fill in your details to get started.
          </p>
        </div>

        <form class="flex flex-col gap-5" @submit.prevent="handleSubmit">
          <div v-if="errorMessage" class="flex items-start gap-2 rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
            <AlertCircle class="mt-0.5 size-4 shrink-0" />
            <span>{{ errorMessage }}</span>
          </div>

          <div class="flex flex-col gap-2">
            <Label for="full-name">Full name</Label>
            <div class="relative">
              <User class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                id="full-name"
                v-model="fullName"
                type="text"
                placeholder="Juan Dela Cruz"
                autocomplete="name"
                class="h-10 pl-9"
                required
              />
            </div>
          </div>

          <div class="flex flex-col gap-2">
            <Label for="email">Email</Label>
            <div class="relative">
              <Mail class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                id="email"
                v-model="email"
                type="email"
                placeholder="you@carsu.edu.ph"
                autocomplete="email"
                pattern=".+@carsu\.edu\.ph$"
                title="Use your @carsu.edu.ph email address"
                class="h-10 pl-9"
                required
              />
            </div>
            <p class="text-xs text-muted-foreground">
              Must be a @carsu.edu.ph email address.
            </p>
          </div>

          <div class="flex flex-col gap-2">
            <Label for="program">Program</Label>
            <div class="relative">
              <GraduationCap class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                id="program"
                v-model="program"
                type="text"
                placeholder="e.g. BS Computer Science"
                class="h-10 pl-9"
                required
              />
            </div>
          </div>

          <div class="flex flex-col gap-2">
            <Label for="password">Password</Label>
            <div class="relative">
              <Lock class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                id="password"
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                placeholder="••••••••"
                autocomplete="new-password"
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
            <Label for="confirm-password">Confirm password</Label>
            <div class="relative">
              <Lock class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                id="confirm-password"
                v-model="confirmPassword"
                :type="showConfirmPassword ? 'text' : 'password'"
                placeholder="••••••••"
                autocomplete="new-password"
                class="h-10 px-9"
                required
              />
              <button
                type="button"
                class="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                :aria-label="showConfirmPassword ? 'Hide password' : 'Show password'"
                @click="showConfirmPassword = !showConfirmPassword"
              >
                <EyeOff v-if="showConfirmPassword" class="size-4" />
                <Eye v-else class="size-4" />
              </button>
            </div>
          </div>

          <Button type="submit" size="lg" class="mt-2 w-full" :disabled="isSubmitting">
            <Loader2 v-if="isSubmitting" class="size-4 animate-spin" />
            {{ isSubmitting ? 'Creating account...' : 'Create account' }}
          </Button>
        </form>

        <p class="mt-6 text-center text-sm text-muted-foreground">
          Already have an account?
          <NuxtLink to="/login" class="font-medium text-primary hover:underline">
            Sign in
          </NuxtLink>
        </p>
      </div>
    </div>
  </div>
</template>
