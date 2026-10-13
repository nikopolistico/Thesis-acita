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
const isMatchOpen = ref(false)
const MATCH_MIN_MS = 1000
const SUCCESS_TOAST_MS = 5000

async function loadData() {
  if (!authUser.value)
    return
  isLoading.value = true
  errorMessage.value = ''
  try {
    profile.value = await students.getProfile(authUser.value.id)

    if (profile.value) {
      panelistOptions.value = await students.listPanelists()

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
  let saved: ThesisType
  try {
    saved = await students.submitThesis(profile.value.stu_id, { title, link, adviserId })
    thesis.value = saved
    successMessage.value = 'Your thesis submission has been saved.'
    isEditingThesis.value = false
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to save your thesis submission.'
    isSaving.value = false
    return
  }
  isSaving.value = false

  // A changed title wipes the old panel in the DB; re-read it. The save has
  // already succeeded, so a failure here must not be reported as a failed save.
  try {
    panel.value = await students.getPanel(saved.thesis_id)
  }
  catch {
    panel.value = []
  }

  // Only re-match when the title changed or the panel is incomplete.
  const needsMatch = previousTitle !== saved.title || panel.value.length < 3
  if (!needsMatch)
    return

  // RAG: embed the title (the query), semantically search panelist
  // expertise, and auto-assign the panel on a match.
  isMatching.value = true
  isMatchOpen.value = true
  // Keep the searching animation visible for at least 1s so it never flashes.
  const minDisplay = new Promise(resolve => setTimeout(resolve, MATCH_MIN_MS))
  try {
    const [result] = await Promise.all([
      students.matchThesis(saved.thesis_id, saved.title),
      minDisplay,
    ])
    matchResult.value = result
    if (result.panel)
      panel.value = result.panel
  }
  catch (error: any) {
    matchError.value = error?.data?.statusMessage ?? 'Failed to match your thesis to a panel.'
  }
  finally {
    isMatching.value = false
    isMatchOpen.value = false
  }
}

function onMatchDialogChange(open: boolean) {
  // Don't let the dialog be dismissed mid-search.
  if (!open && isMatching.value)
    return
  isMatchOpen.value = open
}

// Success toast auto-dismisses after 5 seconds.
let successTimer: ReturnType<typeof setTimeout> | undefined
watch(successMessage, (message) => {
  clearTimeout(successTimer)
  if (message)
    successTimer = setTimeout(() => (successMessage.value = ''), SUCCESS_TOAST_MS)
})
onBeforeUnmount(() => clearTimeout(successTimer))

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
    <Transition name="pop">
    <div v-if="errorMessage" class="mb-6 flex items-start gap-2 rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
      <AlertCircle class="mt-0.5 size-4 shrink-0" />
      <span>{{ errorMessage }}</span>
    </div>
    </Transition>

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
            Welcome, {{ profile.partner_name ? `${profile.student_name} and ${profile.partner_name}` : profile.student_name }}
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
              <dl v-if="thesis && hasThesis" class="space-y-4">
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
                  No panelists are registered yet — contact your chairperson.
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

            <dl v-else-if="thesis && hasThesis" class="grid gap-4 sm:grid-cols-2">
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

        <Teleport to="body">
          <Transition name="toast">
            <div
              v-if="successMessage"
              role="status"
              class="fixed right-4 top-4 z-100 flex w-[calc(100vw-2rem)] max-w-sm items-start gap-3 rounded-xl border bg-card p-4 shadow-lg"
            >
              <CheckCircle2 class="size-5 shrink-0 text-primary" />
              <div class="min-w-0 flex-1">
                <p class="text-sm">
                  {{ successMessage }}
                </p>
              </div>
              <button
                type="button"
                class="text-muted-foreground transition hover:text-foreground"
                aria-label="Dismiss"
                @click="successMessage = ''"
              >
                &times;
              </button>
              <span class="toast-progress" :style="{ animationDuration: `${SUCCESS_TOAST_MS}ms` }" />
            </div>
          </Transition>
        </Teleport>

        <!-- Modal shows only the searching animation; it closes by itself when matching finishes. -->
        <Dialog :open="isMatchOpen" @update:open="onMatchDialogChange">
          <DialogContent
            class="max-w-md [&>button]:hidden"
            @escape-key-down="$event.preventDefault()"
            @interact-outside="$event.preventDefault()"
          >
            <DialogHeader>
              <DialogTitle class="flex items-center gap-2">
                <Sparkles class="size-4" />
                AI panel match
              </DialogTitle>
              <DialogDescription>
                Finding panelists whose expertise fits your thesis.
              </DialogDescription>
            </DialogHeader>

            <div class="match-stage relative h-44 overflow-hidden rounded-lg border bg-muted/40">
              <span class="match-pulse" />
              <span class="match-pulse match-pulse-delay" />
              <div class="match-core">
                <Sparkles class="size-5" />
              </div>
              <span
                v-for="n in 6"
                :key="n"
                class="match-avatar"
                :class="`match-avatar-${n}`"
              >
                <UserRound class="size-4" />
              </span>
            </div>
            <div class="flex items-center gap-2 text-sm text-muted-foreground">
              <Loader2 class="size-4 animate-spin" />
              Searching for panelists...
            </div>
          </DialogContent>
        </Dialog>

        <!-- Organized result lives on the page, not in the modal. -->
        <Card v-if="matchError || matchResult">
          <CardHeader>
            <CardTitle class="flex items-center gap-2 text-base">
              <AlertCircle v-if="matchError" class="size-5 text-destructive" />
              <CheckCircle2 v-else class="match-done size-5 text-primary" />
              AI panel match
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div v-if="matchError" class="flex items-start gap-2 text-sm text-destructive">
              <span>{{ matchError }}</span>
            </div>
            <div v-else-if="matchResult" class="match-results space-y-4">
              <div v-if="matchResult.panel?.length" class="space-y-2">
                <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                  Assigned panel
                </h3>
                <PanelList :panel="matchResult.panel" />
              </div>

              <div v-if="matchResult.candidates.length" class="space-y-2">
                <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                  Matched expertise
                </h3>
                <div class="flex flex-wrap gap-1.5">
                  <Badge v-for="c in matchResult.candidates" :key="c.expertise" variant="secondary">
                    {{ c.expertise }} · {{ (c.similarity * 100).toFixed(0) }}%
                  </Badge>
                </div>
              </div>

              <div v-if="matchResult.response" class="space-y-2">
                <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                  Summary
                </h3>
                <p class="rounded-lg border bg-muted/40 p-3 text-sm text-muted-foreground">
                  {{ matchResult.response }}
                </p>
              </div>
              <p v-if="!matchResult.panel?.length" class="text-sm text-muted-foreground">
                No panel could be assigned from the available expertise.
              </p>
            </div>
          </CardContent>
        </Card>
      </section>
    </template>
  </DashboardSidebar>
</template>

<style scoped>
.match-core {
  position: absolute;
  left: 50%;
  top: 50%;
  display: grid;
  place-items: center;
  width: 2.75rem;
  height: 2.75rem;
  margin: -1.375rem 0 0 -1.375rem;
  border-radius: 9999px;
  background: var(--primary);
  color: var(--primary-foreground);
  z-index: 2;
  animation: match-bob 1.6s ease-in-out infinite;
}

.match-pulse {
  position: absolute;
  left: 50%;
  top: 50%;
  width: 2.75rem;
  height: 2.75rem;
  margin: -1.375rem 0 0 -1.375rem;
  border-radius: 9999px;
  border: 2px solid var(--primary);
  opacity: 0;
  animation: match-pulse 2.4s ease-out infinite;
}
.match-pulse-delay { animation-delay: 1.2s; }

.match-avatar {
  position: absolute;
  display: grid;
  place-items: center;
  width: 2rem;
  height: 2rem;
  border-radius: 9999px;
  background: var(--card);
  border: 1px solid var(--border);
  color: var(--muted-foreground);
  box-shadow: 0 1px 4px rgb(0 0 0 / 0.12);
  animation: match-roam 5s ease-in-out infinite;
}

/* each avatar wanders its own path at its own pace */
.match-avatar-1 { left: 8%;  top: 15%; animation-duration: 4.6s; }
.match-avatar-2 { left: 80%; top: 12%; animation-duration: 5.4s; animation-delay: -1s; }
.match-avatar-3 { left: 18%; top: 62%; animation-duration: 6s;   animation-delay: -2s; }
.match-avatar-4 { left: 72%; top: 64%; animation-duration: 4.9s; animation-delay: -3s; }
.match-avatar-5 { left: 42%; top: 6%;  animation-duration: 5.7s; animation-delay: -0.5s; }
.match-avatar-6 { left: 55%; top: 74%; animation-duration: 6.3s; animation-delay: -4s; }

@keyframes match-roam {
  0%   { transform: translate(0, 0) scale(1); }
  25%  { transform: translate(26px, 14px) scale(1.08); color: var(--primary); }
  50%  { transform: translate(-14px, 28px) scale(0.95); }
  75%  { transform: translate(-28px, -10px) scale(1.06); color: var(--primary); }
  100% { transform: translate(0, 0) scale(1); }
}

@keyframes match-bob {
  0%, 100% { transform: scale(1); }
  50%      { transform: scale(1.12); }
}

@keyframes match-pulse {
  0%   { transform: scale(1); opacity: 0.55; }
  100% { transform: scale(4.5); opacity: 0; }
}

/* results fade in one block after another, check icon pops */
.match-results > * { animation: match-rise 0.4s ease-out both; }
.match-results > *:nth-child(2) { animation-delay: 0.1s; }
.match-results > *:nth-child(3) { animation-delay: 0.2s; }
.match-done { animation: match-pop 0.5s cubic-bezier(0.34, 1.56, 0.64, 1) both; }

@keyframes match-rise {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}
@keyframes match-pop {
  from { transform: scale(0); }
  to   { transform: scale(1); }
}

/* success toast */
.toast-enter-active, .toast-leave-active { transition: opacity 0.25s ease, transform 0.25s ease; }
.toast-enter-from, .toast-leave-to { opacity: 0; transform: translateX(16px); }
.toast-progress {
  position: absolute;
  left: 0;
  bottom: 0;
  height: 3px;
  width: 100%;
  border-radius: 0 0 0.75rem 0.75rem;
  background: var(--primary);
  transform-origin: left;
  animation: toast-countdown 5s linear forwards; /* overridden inline from SUCCESS_TOAST_MS */
}
@keyframes toast-countdown {
  from { transform: scaleX(1); }
  to   { transform: scaleX(0); }
}

@media (prefers-reduced-motion: reduce) {
  .match-avatar, .match-core, .match-pulse, .match-results > *, .match-done, .toast-progress { animation: none; }
}
</style>
