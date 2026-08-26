<script setup lang="ts">
import {
  AlertCircle,
  BookOpen,
  CheckCircle2,
  Clock,
  Crown,
  LayoutDashboard,
  Link as LinkIcon,
  Loader2,
  Pencil,
  Save,
  Sparkles,
  Upload,
  UserRound,
} from '@lucide/vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardAction, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import type { ExpertiseRecommendation } from '~/composables/useStudents'
import type { StudentInformation, ThesisPanelMember, ThesisTitle } from '~/types/database'

definePageMeta({ middleware: 'dashboard', role: 'student' })

const navItems = [
  { key: 'overview', label: 'Overview', icon: LayoutDashboard },
  { key: 'thesis', label: 'My Thesis', icon: BookOpen },
]

const active = ref('overview')
const authUser = useAuthUser()
const students = useStudents()

const isLoading = ref(true)
const errorMessage = ref('')
const successMessage = ref('')
const profile = ref<StudentInformation | null>(null)
const thesis = ref<ThesisTitle | null>(null)
const panel = ref<ThesisPanelMember[]>([])

const panelChair = computed(() => panel.value.find(p => p.role_in_panel === 'chair') ?? null)
const panelMembers = computed(() => panel.value.filter(p => p.role_in_panel === 'member'))

const form = ref({ title: '', link: '', adviserName: '' })
const isSaving = ref(false)
const isConfirmOpen = ref(false)
const isEditingThesis = ref(false)

// A thesis row can exist with a blank title (e.g. an old
// whitespace-only submission) — treat that the same as "nothing
// submitted yet" so the upload form shows instead of a dead-end
// empty summary.
const hasThesis = computed(() => !!thesis.value?.title?.trim())
const showThesisForm = computed(() => !hasThesis.value || isEditingThesis.value)

const aiRecommendation = ref<ExpertiseRecommendation | null>(null)
const isLoadingRecommendation = ref(false)
const aiRecommendationError = ref('')

async function loadData() {
  if (!authUser.value)
    return
  isLoading.value = true
  errorMessage.value = ''
  try {
    profile.value = await students.getProfile(authUser.value.id)

    if (profile.value) {
      thesis.value = await students.getThesis(profile.value.id)
      if (thesis.value) {
        form.value = {
          title: thesis.value.title,
          link: thesis.value.link ?? '',
          adviserName: thesis.value.adviser_name ?? '',
        }
        panel.value = await students.getPanel(thesis.value.id)
      }
    }
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to load your dashboard data.'
  }
  finally {
    isLoading.value = false
  }
}

function startEdit() {
  if (thesis.value) {
    form.value = {
      title: thesis.value.title,
      link: thesis.value.link ?? '',
      adviserName: thesis.value.adviser_name ?? '',
    }
  }
  successMessage.value = ''
  isEditingThesis.value = true
}

function cancelEdit() {
  if (thesis.value) {
    form.value = {
      title: thesis.value.title,
      link: thesis.value.link ?? '',
      adviserName: thesis.value.adviser_name ?? '',
    }
  }
  isEditingThesis.value = false
}

function handleSubmit() {
  errorMessage.value = ''
  if (!form.value.title.trim() || !form.value.link.trim() || !form.value.adviserName.trim()) {
    errorMessage.value = 'Please fill in all fields before uploading.'
    return
  }
  if (hasThesis.value) {
    isConfirmOpen.value = true
    return
  }
  saveThesis()
}

function confirmSaveThesis() {
  isConfirmOpen.value = false
  saveThesis()
}

async function saveThesis() {
  if (!profile.value)
    return
  const title = form.value.title.trim()
  const link = form.value.link.trim()
  const adviserName = form.value.adviserName.trim()
  if (!title || !link || !adviserName) {
    errorMessage.value = 'Please fill in all fields before uploading.'
    return
  }
  isSaving.value = true
  errorMessage.value = ''
  successMessage.value = ''
  aiRecommendation.value = null
  aiRecommendationError.value = ''
  try {
    thesis.value = await students.submitThesis(profile.value.id, { title, link, adviserName })
    successMessage.value = 'Your thesis submission has been saved.'
    isEditingThesis.value = false
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to save your thesis submission.'
    isSaving.value = false
    return
  }
  isSaving.value = false

  isLoadingRecommendation.value = true
  try {
    aiRecommendation.value = await students.recommendExpertise(thesis.value.title)
    panel.value = await students.autoAssignPanel(thesis.value.id, aiRecommendation.value.recommendedExpertise)
  }
  catch (error: any) {
    aiRecommendationError.value = error?.data?.statusMessage ?? 'Failed to get an AI recommendation.'
  }
  finally {
    isLoadingRecommendation.value = false
  }
}

async function logout() {
  authUser.value = null
  await navigateTo('/login')
}

onMounted(loadData)
</script>

<template>
  <DashboardSidebar
    title="Student Dashboard"
    :nav-items="navItems"
    :active="active"
    :user-email="authUser?.email"
    @update:active="active = $event"
    @logout="logout"
  >
    <div v-if="errorMessage" class="mb-6 flex items-start gap-2 rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
      <AlertCircle class="mt-0.5 size-4 shrink-0" />
      <span>{{ errorMessage }}</span>
    </div>

    <div v-if="isLoading" class="flex items-center gap-2 text-sm text-muted-foreground">
      <Loader2 class="size-4 animate-spin" />
      Loading your dashboard...
    </div>

    <template v-else-if="!profile">
      <p class="text-sm text-muted-foreground">
        We couldn't find your student profile yet. Please contact an administrator.
      </p>
    </template>

    <template v-else>
      <section v-if="active === 'overview'" class="space-y-6">
        <div>
          <h1 class="text-2xl font-bold tracking-tight">
            Welcome back, {{ profile.full_name }}
          </h1>
          <p class="text-sm text-muted-foreground">
            Here's a summary of your thesis submission.
          </p>
        </div>

        <Card class="overflow-hidden py-0">
          <div class="flex items-center gap-3 border-b bg-muted/30 px-6 py-4">
            <span
              class="flex size-9 shrink-0 items-center justify-center rounded-full"
              :class="hasThesis ? 'bg-primary/10 text-primary' : 'bg-accent text-accent-foreground'"
            >
              <CheckCircle2 v-if="hasThesis" class="size-5" />
              <Clock v-else class="size-5" />
            </span>
            <div class="min-w-0 flex-1">
              <CardTitle class="text-base">Thesis submission status</CardTitle>
              <p class="text-xs text-muted-foreground">
                {{ hasThesis ? 'Your details are on file' : 'Awaiting your first submission' }}
              </p>
            </div>
            <Badge :variant="hasThesis ? 'default' : 'outline'">
              {{ hasThesis ? 'Submitted' : 'Pending' }}
            </Badge>
          </div>
          <CardContent class="py-5">
            <template v-if="hasThesis">
              <dl class="grid gap-4 sm:grid-cols-2">
                <div class="sm:col-span-2">
                  <dt class="text-xs font-medium uppercase tracking-wide text-muted-foreground">Thesis title</dt>
                  <dd class="mt-1 text-sm font-semibold">{{ thesis.title }}</dd>
                </div>
                <div>
                  <dt class="flex items-center gap-1.5 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                    <UserRound class="size-3.5" />
                    Adviser
                  </dt>
                  <dd class="mt-1 text-sm">{{ thesis.adviser_name }}</dd>
                </div>
                <div v-if="thesis.link">
                  <dt class="flex items-center gap-1.5 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                    <LinkIcon class="size-3.5" />
                    Link
                  </dt>
                  <dd class="mt-1 truncate text-sm">
                    <a :href="thesis.link" target="_blank" rel="noopener" class="text-primary hover:underline">
                      {{ thesis.link }}
                    </a>
                  </dd>
                </div>
              </dl>
            </template>
            <p v-else class="text-sm text-muted-foreground">
              You haven't submitted your thesis title yet. Go to "My Thesis" to upload it.
            </p>
          </CardContent>
        </Card>

        <Card v-if="hasThesis">
          <CardHeader>
            <CardTitle class="text-base">Thesis panel</CardTitle>
          </CardHeader>
          <CardContent>
            <div v-if="panel.length === 0" class="flex items-center gap-2 text-sm text-muted-foreground">
              <Clock class="size-4" />
              Awaiting panel assignment. This updates automatically once matching panelists are found.
            </div>
            <ul v-else class="divide-y">
              <li v-if="panelChair" class="flex items-center gap-3 py-2.5 first:pt-0">
                <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                  <Crown class="size-4" />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-medium">{{ panelChair.full_name }}</p>
                  <p class="truncate text-xs text-muted-foreground">{{ panelChair.position ?? 'Panel chair' }}</p>
                </div>
                <Badge variant="default">Chair</Badge>
              </li>
              <li v-for="member in panelMembers" :key="member.id" class="flex items-center gap-3 py-2.5 last:pb-0">
                <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-accent text-accent-foreground">
                  <UserRound class="size-4" />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-medium">{{ member.full_name }}</p>
                  <p class="truncate text-xs text-muted-foreground">{{ member.position ?? 'Panel member' }}</p>
                </div>
                <Badge variant="outline">Member</Badge>
              </li>
              <li v-if="!panelChair || panelMembers.length < 2" class="flex items-center gap-2 py-2.5 text-sm text-muted-foreground">
                <Clock class="size-4 shrink-0" />
                {{ !panelChair ? 'Chair' : `${2 - panelMembers.length} member${2 - panelMembers.length > 1 ? 's' : ''}` }} still pending.
              </li>
            </ul>
          </CardContent>
        </Card>
      </section>

      <section v-else-if="active === 'thesis'" class="space-y-6">
        <h1 class="text-2xl font-bold tracking-tight">
          My Thesis
        </h1>

        <Card>
          <CardHeader>
            <CardTitle class="text-base">
              {{ !hasThesis ? 'Upload your thesis details' : isEditingThesis ? 'Update your submission' : 'Your submission' }}
            </CardTitle>
            <CardAction v-if="hasThesis && !isEditingThesis">
              <Button variant="outline" size="sm" @click="startEdit">
                <Pencil class="size-3.5" />
                Edit
              </Button>
            </CardAction>
          </CardHeader>
          <CardContent>
            <div v-if="successMessage" class="mb-4 flex items-start gap-2 rounded-lg border border-primary/30 bg-primary/10 p-3 text-sm text-primary">
              <span>{{ successMessage }}</span>
            </div>

            <form v-if="showThesisForm" class="space-y-4" @submit.prevent="handleSubmit">
              <div class="flex flex-col gap-2">
                <Label for="thesis-title">Thesis title</Label>
                <Input id="thesis-title" v-model="form.title" placeholder="e.g. Expertise-Based Panel Assignment System" required />
              </div>

              <div class="flex flex-col gap-2">
                <Label for="thesis-link">Link</Label>
                <Input id="thesis-link" v-model="form.link" type="url" placeholder="e.g. link to your document or drive folder" required />
              </div>

              <div class="flex flex-col gap-2">
                <Label for="adviser-name">Adviser name</Label>
                <Input id="adviser-name" v-model="form.adviserName" placeholder="e.g. Dr. Juan Dela Cruz" required />
              </div>

              <div class="flex items-center gap-2">
                <Button type="submit" :disabled="isSaving">
                  <Loader2 v-if="isSaving" class="size-4 animate-spin" />
                  <Save v-else-if="hasThesis" class="size-4" />
                  <Upload v-else class="size-4" />
                  {{ hasThesis ? 'Save changes' : 'Upload' }}
                </Button>
                <Button v-if="hasThesis" type="button" variant="outline" :disabled="isSaving" @click="cancelEdit">
                  Cancel
                </Button>
              </div>
            </form>

            <dl v-else-if="hasThesis" class="grid gap-4 sm:grid-cols-2">
              <div class="sm:col-span-2">
                <dt class="text-xs font-medium uppercase tracking-wide text-muted-foreground">Thesis title</dt>
                <dd class="mt-1 text-sm font-semibold">{{ thesis.title }}</dd>
              </div>
              <div>
                <dt class="flex items-center gap-1.5 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                  <UserRound class="size-3.5" />
                  Adviser
                </dt>
                <dd class="mt-1 text-sm">{{ thesis.adviser_name }}</dd>
              </div>
              <div v-if="thesis.link">
                <dt class="flex items-center gap-1.5 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                  <LinkIcon class="size-3.5" />
                  Link
                </dt>
                <dd class="mt-1 truncate text-sm">
                  <a :href="thesis.link" target="_blank" rel="noopener" class="text-primary hover:underline">
                    {{ thesis.link }}
                  </a>
                </dd>
              </div>
            </dl>
          </CardContent>
        </Card>

        <Dialog v-model:open="isConfirmOpen">
          <DialogContent class="max-w-sm">
            <DialogHeader>
              <DialogTitle>Save changes?</DialogTitle>
              <DialogDescription>
                This will overwrite your current thesis submission with the new details below.
              </DialogDescription>
            </DialogHeader>
            <div class="space-y-1.5 rounded-lg border bg-muted/40 p-3 text-sm">
              <p class="font-medium">{{ form.title }}</p>
              <p class="text-muted-foreground">Adviser: {{ form.adviserName }}</p>
            </div>
            <DialogFooter>
              <Button variant="outline" :disabled="isSaving" @click="isConfirmOpen = false">
                Cancel
              </Button>
              <Button :disabled="isSaving" @click="confirmSaveThesis">
                <Loader2 v-if="isSaving" class="size-4 animate-spin" />
                <Save v-else class="size-4" />
                Save changes
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        <Card v-if="isLoadingRecommendation || aiRecommendationError || aiRecommendation">
          <CardHeader>
            <CardTitle class="flex items-center gap-1.5 text-base">
              <Sparkles class="size-4" />
              Grok's recommended expertise
            </CardTitle>
          </CardHeader>
          <CardContent class="space-y-2">
            <div v-if="isLoadingRecommendation" class="flex items-center gap-2 text-sm text-muted-foreground">
              <Loader2 class="size-4 animate-spin" />
              Asking Grok which expertise fits this thesis...
            </div>
            <div v-else-if="aiRecommendationError" class="flex items-start gap-2 text-sm text-destructive">
              <AlertCircle class="mt-0.5 size-4 shrink-0" />
              <span>{{ aiRecommendationError }}</span>
            </div>
            <template v-else-if="aiRecommendation">
              <div class="flex flex-wrap gap-1.5">
                <Badge v-for="area in aiRecommendation.recommendedExpertise" :key="area" variant="secondary">{{ area }}</Badge>
              </div>
              <p class="text-sm text-muted-foreground">
                {{ aiRecommendation.reasoning }}
              </p>
            </template>
          </CardContent>
        </Card>
      </section>
    </template>
  </DashboardSidebar>
</template>
