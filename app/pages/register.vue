<script setup lang="ts">
import { AlertCircle, Eye, EyeOff, Loader2 } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import type { AuthUser } from '~/composables/useAuthUser'

const fullName = ref('')
const email = ref('')
const program = ref('')
const course = ref('')
const password = ref('')
const confirmPassword = ref('')
const showPassword = ref(false)
const showConfirmPassword = ref(false)
const isSubmitting = ref(false)
const errorMessage = ref('')

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
        course: course.value,
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
  <AuthShell
    heading="Create a student account"
    intro="Register once, then submit your thesis from your dashboard."
    aside-title="Submit your title. Get your panel."
    aside-text="Your thesis title is compared with each panelist's expertise, and the best matches become your chair and members."
    :aside-items="['Edit anytime', 'Matched by expertise', 'Adviser excluded']"
  >
    <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
      <div v-if="errorMessage" role="alert" class="flex items-start gap-2 rounded-md border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
        <AlertCircle class="mt-0.5 size-4 shrink-0" />
        <span>{{ errorMessage }}</span>
      </div>

      <div class="flex flex-col gap-2">
        <Label for="full-name">Full name</Label>
        <Input id="full-name" v-model="fullName" type="text" autocomplete="name" required placeholder="Juan Dela Cruz" class="h-10" />
      </div>

      <div class="flex flex-col gap-2">
        <Label for="email">Email</Label>
        <Input id="email" v-model="email" type="email" autocomplete="email" pattern=".+@carsu\.edu\.ph$" title="Use your @carsu.edu.ph email address" required placeholder="you@carsu.edu.ph" class="h-10" />
        <p class="text-xs text-muted-foreground">Must end in @carsu.edu.ph.</p>
      </div>

      <div class="flex flex-col gap-2">
        <Label for="program">Program</Label>
        <Input id="program" v-model="program" type="text" required placeholder="BS Computer Science" class="h-10" />
      </div>

      <div class="flex flex-col gap-2">
        <Label for="course">Course and section (optional)</Label>
        <Input id="course" v-model="course" type="text" placeholder="IT - 401" class="h-10" />
      </div>

      <div class="flex flex-col gap-2">
        <Label for="password">Password</Label>
        <div class="relative">
          <Input id="password" v-model="password" :type="showPassword ? 'text' : 'password'" autocomplete="new-password" class="h-10 pr-10" required />
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
          <Input id="confirm-password" v-model="confirmPassword" :type="showConfirmPassword ? 'text' : 'password'" autocomplete="new-password" class="h-10 pr-10" required />
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

      <Button type="submit" size="lg" class="mt-1 w-full" :disabled="isSubmitting">
        <Loader2 v-if="isSubmitting" class="size-4 animate-spin" />
        {{ isSubmitting ? 'Creating account...' : 'Create account' }}
      </Button>
    </form>

    <p class="mt-6 text-sm text-muted-foreground">
      Already registered?
      <NuxtLink to="/login" class="font-medium text-primary underline-offset-4 hover:underline">
        Sign in
      </NuxtLink>
    </p>
  </AuthShell>
</template>
