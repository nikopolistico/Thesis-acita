<script setup lang="ts">
import {
  AlertCircle,
  ArrowRight,
  Check,
  BookOpen,
  CheckCircle2,
  Clock,
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
import type { PanelistOption, ThesisMatchResult } from '~/composables/useStudents'
import type { Student, ThesisPanelMember, Thesis as ThesisType } from '~/types/database'

definePageMeta({ middleware: 'dashboard', role: 'student' })

const navItems = [
  { key: 'overview', label: 'Overview', icon: LayoutDashboard },
  { key: 'thesis', label: 'My Thesis', icon: BookOpen },
]

const active = ref('overview')
const authUser = useAuthUser()
const students = useStudents()

const isLoading = ref(true)
const ready = ref(false)
const errorMessage = ref('')
const successMessage = ref('')
const profile = ref<Student | null>(null)
const thesis = ref<ThesisType | null>(null)
const panel = ref<ThesisPanelMember[]>([])
const panelistOptions = ref<PanelistOption[]>([])

const adviserName = computed(() => panelistOptions.value.find(p => p.panel_id === thesis.value?.adviser_id)?.full_name ?? '')

const panelComplete = computed(() =>
  panel.value.some(p => p.role === 'chair') && panel.value.filter(p => p.role === 'member').length >= 2)

const steps = computed(() => {
  const done = [true, hasThesis.value, hasThesis.value && panelComplete.value]
  const current = done.findIndex(d => !d)
  return [
    { label: 'Account created', hint: 'You are signed in', done: done[0], current: current === 0 },
    { label: 'Thesis submitted', hint: done[1] ? 'Title, link and adviser on file' : 'Add them in My Thesis', done: done[1], current: current === 1 },
    { label: 'Panel assigned', hint: done[2] ? 'Chair and two members' : done[1] ? 'Waiting for matching panelists' : 'Starts after you submit', done: done[2], current: current === 2 },
  ]
})

const form = ref({ title: '', link: '', adviserId: null as number | null })
const isSaving = ref(false)
const isConfirmOpen = ref(false)
const isEditingThesis = ref(false)

// A thesis row can exist with a blank title (e.g. an old
// whitespace-only submission) — treat that the same as "nothing
// submitted yet" so the upload form shows instead of a dead-end
// empty summary.
const hasThesis = computed(() => !!thesis.value?.title?.trim())
const showThesisForm = computed(() => !hasThesis.value || isEditingThesis.value)

const matchResult = ref<ThesisMatchResult | null>(null)
const isMatching = ref(false)
const matchError = ref('')

async function loadData() {
  if (!authUser.value)
    return
  isLoading.value = true
  errorMessage.value = ''
  try {
    profile.value = await students.getProfile(authUser.value.id)

    if (profile.value) {
      if (profile.value.program)
        panelistOptions.value = await students.listPanelists(profile.value.program)

      thesis.value = await students.getThesis(profile.value.stu_id)
      if (thesis.value) {
        form.value = {
          title: thesis.value.title,
          link: thesis.value.link ?? '',
          adviserId: thesis.value.adviser_id,
        }
        panel.value = await students.getPanel(thesis.value.thesis_id)
      }
    }
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to load your dashboard data.'
  }
  finally {
    isLoading.value = false
    await nextTick()
    requestAnimationFrame(() => {
      ready.value = true
    })
  }
}

function startEdit() {
  if (thesis.value) {
    form.value = {
      title: thesis.value.title,
      link: thesis.value.link ?? '',
      adviserId: thesis.value.adviser_id,
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
      adviserId: thesis.value.adviser_id,
    }
  }
  isEditingThesis.value = false
}

function handleSubmit() {
  errorMessage.value = ''
  if (!form.value.title.trim() || !form.value.link.trim() || !form.value.adviserId) {
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
  const adviserId = form.value.adviserId
  if (!title || !link || !adviserId) {
    errorMessage.value = 'Please fill in all fields before uploading.'
    return
  }
  isSaving.value = true
  errorMessage.value = ''
  successMessage.value = ''
  matchResult.value = null
  matchError.value = ''
  const previousTitle = thesis.value?.title
  try {
    thesis.value = await students.submitThesis(profile.value.stu_id, { title, link, adviserId })
    successMessage.value = 'Your thesis submission has been saved.'
    isEditingThesis.value = false
    // A changed title wipes the old panel in the DB; re-read it.
    panel.value = await students.getPanel(thesis.value.thesis_id)
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to save your thesis submission.'
    isSaving.value = false
    return
  }
  isSaving.value = false

  // Only re-match when the title changed or the panel is incomplete.
  const needsMatch = previousTitle !== thesis.value.title || panel.value.length < 3
  if (!needsMatch)
    return

  // RAG: embed the title (the query), semantically search panelist
  // expertise, and auto-assign the panel on a match.
  isMatching.value = true
  try {
    matchResult.value = await students.matchThesis(thesis.value.thesis_id, thesis.value.title, profile.value.program ?? '')
    if (matchResult.value.panel)
      panel.value = matchResult.value.panel
  }
  catch (error: any) {
    matchError.value = error?.data?.statusMessage ?? 'Failed to match your thesis to a panel.'
  }
  finally {
    isMatching.value = false
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
      <section v-if="active === 'overview'" class="space-y-8">
        <div>
          <h1 class="text-2xl font-bold">
            Welcome, {{ profile.student_name }}
          </h1>
          <p class="text-sm text-muted-foreground">
            {{ profile.program }}{{ profile.course ? ` · ${profile.course}` : '' }}
          </p>
        </div>

        <ol class="grid gap-4 sm:grid-cols-3" aria-label="Your progress">
          <li v-for="(step, i) in steps" :key="step.label" class="relative pt-3">
            <span class="absolute inset-x-0 top-0 h-0.5 bg-border" aria-hidden="true" />
            <span
              class="absolute inset-x-0 top-0 h-0.5 origin-left transition-transform duration-700 ease-out motion-reduce:transition-none"
              :class="[step.done ? 'bg-primary' : 'bg-accent', ready && (step.done || step.current) ? 'scale-x-100' : 'scale-x-0']"
              :style="{ transitionDelay: i * 350 + 'ms' }"
              aria-hidden="true"
            />
            <div class="flex items-center gap-2">
              <span
                class="flex size-5 items-center justify-center rounded-full text-xs font-semibold transition-colors duration-500"
                :class="step.done ? 'bg-primary text-primary-foreground' : step.current ? 'bg-accent text-accent-foreground' : 'bg-muted text-muted-foreground'"
              >
                <Check v-if="step.done" class="size-3" />
                <template v-else>{{ i + 1 }}</template>
              </span>
              <span class="font-heading text-sm font-semibold" :class="!step.done && !step.current && 'text-muted-foreground'">{{ step.label }}</span>
            </div>
            <p class="mt-1 pl-7 text-xs text-muted-foreground">{{ step.hint }}</p>
          </li>
        </ol>

        <div class="grid gap-6 lg:grid-cols-5">
          <div class="rounded-lg border bg-card lg:col-span-3">
            <div class="flex items-center justify-between gap-3 border-b px-5 py-3">
              <h2 class="font-heading font-semibold">Your thesis</h2>
              <Button v-if="hasThesis" variant="outline" size="sm" @click="active = 'thesis'; startEdit()">
                <Pencil class="size-3.5" />
                Edit
              </Button>
            </div>
            <div class="p-5">
              <dl v-if="hasThesis" class="space-y-4">
                <div>
                  <dt class="text-sm text-muted-foreground">Title</dt>
                  <dd class="mt-0.5 font-heading text-lg font-semibold leading-snug text-balance">{{ thesis.title }}</dd>
                </div>
                <div class="grid gap-4 sm:grid-cols-2">
                  <div>
                    <dt class="text-sm text-muted-foreground">Adviser</dt>
                    <dd class="mt-0.5">{{ adviserName || '—' }}</dd>
                  </div>
                  <div v-if="thesis.link" class="min-w-0">
                    <dt class="text-sm text-muted-foreground">Document</dt>
                    <dd class="mt-0.5 truncate">
                      <a :href="thesis.link" target="_blank" rel="noopener" class="inline-flex items-center gap-1.5 text-primary hover:underline">
                        <LinkIcon class="size-3.5 shrink-0" />
                        <span class="truncate">{{ thesis.link }}</span>
                      </a>
                    </dd>
                  </div>
                </div>
              </dl>
              <div v-else class="py-4 text-center">
                <p class="text-muted-foreground">You have not submitted your thesis yet.</p>
                <Button class="mt-4" @click="active = 'thesis'">
                  Submit your thesis
                  <ArrowRight class="size-4" />
                </Button>
              </div>
            </div>
          </div>

          <div class="rounded-lg border bg-card lg:col-span-2">
            <div class="border-b px-5 py-3">
              <h2 class="font-heading font-semibold">Thesis panel</h2>
            </div>
            <div class="p-5">
              <p v-if="!hasThesis" class="text-sm text-muted-foreground">
                Your panel is assigned after you submit a title.
              </p>
              <PanelList v-else :panel="panel" />
            </div>
          </div>
        </div>
      </section>

      <section v-else-if="active === 'thesis'" class="space-y-6">
        <h1 class="text-2xl font-bold">
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
                <Label for="adviser-id">Adviser</Label>
                <select
                  id="adviser-id"
                  v-model="form.adviserId"
                  required
                  class="border-input flex h-9 w-full rounded-md border bg-transparent px-3 py-1 text-sm shadow-xs outline-none"
                >
                  <option :value="null" disabled>Select your adviser</option>
                  <option v-for="p in panelistOptions" :key="p.panel_id" :value="p.panel_id">
                    {{ p.full_name }}{{ p.position ? ` — ${p.position}` : '' }}
                  </option>
                </select>
                <p v-if="panelistOptions.length === 0" class="text-xs text-muted-foreground">
                  No panelists are registered for your program yet — contact your chairperson.
                </p>
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
                <dt class="text-sm text-muted-foreground">Thesis title</dt>
                <dd class="mt-1 text-sm font-semibold">{{ thesis.title }}</dd>
              </div>
              <div>
                <dt class="flex items-center gap-1.5 text-sm text-muted-foreground">
                  <UserRound class="size-3.5" />
                  Adviser
                </dt>
                <dd class="mt-1 text-sm">{{ adviserName || '—' }}</dd>
              </div>
              <div v-if="thesis.link">
                <dt class="flex items-center gap-1.5 text-sm text-muted-foreground">
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

        <Card v-if="hasThesis">
          <CardHeader>
            <CardTitle class="text-base">Assigned panel</CardTitle>
          </CardHeader>
          <CardContent>
            <PanelList :panel="panel" />
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
              <p class="text-muted-foreground">
                Adviser: {{ panelistOptions.find(p => p.panel_id === form.adviserId)?.full_name ?? '—' }}
              </p>
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

        <Card v-if="isMatching || matchError || matchResult">
          <CardHeader>
            <CardTitle class="flex items-center gap-1.5 text-base">
              <Sparkles class="size-4" />
              AI panel match
            </CardTitle>
          </CardHeader>
          <CardContent class="space-y-3">
            <div v-if="isMatching" class="flex items-center gap-2 text-sm text-muted-foreground">
              <Loader2 class="size-4 animate-spin" />
              Searching for panelists whose expertise fits this thesis...
            </div>
            <div v-else-if="matchError" class="flex items-start gap-2 text-sm text-destructive">
              <AlertCircle class="mt-0.5 size-4 shrink-0" />
              <span>{{ matchError }}</span>
            </div>
            <template v-else-if="matchResult">
              <div class="flex flex-wrap gap-1.5">
                <Badge v-for="c in matchResult.candidates" :key="c.expertise" variant="secondary">
                  {{ c.expertise }} ({{ (c.similarity * 100).toFixed(0) }}%)
                </Badge>
              </div>
              <p class="text-sm text-muted-foreground">
                {{ matchResult.response }}
              </p>
            </template>
          </CardContent>
        </Card>
      </section>
    </template>
  </DashboardSidebar>
</template>
