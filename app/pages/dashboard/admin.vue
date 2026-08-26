<script setup lang="ts">
import {
  AlertCircle,
  CheckCircle2,
  Clock,
  Crown,
  LayoutDashboard,
  Link as LinkIcon,
  Loader2,
  Pencil,
  Plus,
  Trash2,
  UserCog,
  UserRound,
  Users,
  X,
} from '@lucide/vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import type { AdminPanelistEntry, AdminStudentEntry, AdminThesisPanelMember } from '~/composables/useAdmin'
import type { AdminInformation } from '~/types/database'

definePageMeta({ middleware: 'dashboard', role: 'admin' })

const navItems = [
  { key: 'overview', label: 'Overview', icon: LayoutDashboard },
  { key: 'students', label: 'Students', icon: Users },
  { key: 'panelists', label: 'Panelists', icon: UserCog },
]

const active = ref('overview')
const authUser = useAuthUser()
const admin = useAdmin()

const isLoading = ref(true)
const errorMessage = ref('')
const profile = ref<AdminInformation | null>(null)
const students = ref<AdminStudentEntry[]>([])
const panelists = ref<AdminPanelistEntry[]>([])

async function loadData() {
  if (!authUser.value)
    return
  isLoading.value = true
  errorMessage.value = ''
  try {
    profile.value = await admin.getProfile(authUser.value.id)
    if (profile.value) {
      const [studentRows, panelistRows] = await Promise.all([
        admin.listStudents(profile.value.program),
        admin.listPanelists(profile.value.program),
      ])
      students.value = studentRows
      panelists.value = panelistRows
    }
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to load dashboard data.'
  }
  finally {
    isLoading.value = false
  }
}

async function refreshPanelists() {
  if (!profile.value)
    return
  panelists.value = await admin.listPanelists(profile.value.program)
}

async function logout() {
  authUser.value = null
  await navigateTo('/login')
}

const submittedCount = computed(() => students.value.filter(s => s.title).length)
const pendingCount = computed(() => students.value.length - submittedCount.value)
const submissionRate = computed(() => students.value.length === 0
  ? 0
  : Math.round((submittedCount.value / students.value.length) * 100))

const overviewChartData = computed(() => [
  { label: 'Students', value: students.value.length },
  { label: 'Submitted', value: submittedCount.value },
  { label: 'Pending', value: students.value.length - submittedCount.value },
])

function panelChairName(panel: AdminThesisPanelMember[]) {
  return panel.find(p => p.role_in_panel === 'chair')?.full_name
}

function panelMemberNames(panel: AdminThesisPanelMember[]) {
  return panel.filter(p => p.role_in_panel === 'member').map(p => p.full_name)
}

// ---- Add panelist ----
const isAddOpen = ref(false)
const addForm = ref({ fullName: '', position: '', email: '' })
const addExpertiseTags = ref<string[]>([])
const addExpertiseInput = ref('')
const isSavingPanelist = ref(false)
const addError = ref('')

function addExpertiseTagToForm() {
  const value = addExpertiseInput.value.trim()
  if (value && !addExpertiseTags.value.includes(value))
    addExpertiseTags.value.push(value)
  addExpertiseInput.value = ''
}

function removeExpertiseTagFromForm(tag: string) {
  addExpertiseTags.value = addExpertiseTags.value.filter(t => t !== tag)
}

async function submitAddPanelist() {
  if (!profile.value)
    return
  addExpertiseTagToForm()
  isSavingPanelist.value = true
  addError.value = ''
  try {
    const created = await admin.registerPanelist({
      fullName: addForm.value.fullName.trim(),
      position: addForm.value.position.trim(),
      email: addForm.value.email.trim(),
      program: profile.value.program,
    })
    for (const tag of addExpertiseTags.value)
      await admin.addExpertise(created.id, tag)

    isAddOpen.value = false
    addForm.value = { fullName: '', position: '', email: '' }
    addExpertiseTags.value = []
    await refreshPanelists()
  }
  catch (error: any) {
    addError.value = error?.message ?? 'Failed to add panelist.'
  }
  finally {
    isSavingPanelist.value = false
  }
}

// ---- Edit panelist ----
const isEditOpen = ref(false)
const editTarget = ref<AdminPanelistEntry | null>(null)
const editForm = ref({ fullName: '', position: '' })
const isSavingEdit = ref(false)

function openEdit(panelist: AdminPanelistEntry) {
  editTarget.value = panelist
  editForm.value = { fullName: panelist.full_name, position: panelist.position ?? '' }
  isEditOpen.value = true
}

async function submitEditPanelist() {
  if (!editTarget.value)
    return
  isSavingEdit.value = true
  try {
    await admin.updatePanelist(editTarget.value.id, {
      fullName: editForm.value.fullName.trim(),
      position: editForm.value.position.trim(),
    })
    isEditOpen.value = false
    await refreshPanelists()
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to update panelist.'
  }
  finally {
    isSavingEdit.value = false
  }
}

// ---- Delete panelist ----
const isDeleteOpen = ref(false)
const deleteTarget = ref<AdminPanelistEntry | null>(null)
const isDeleting = ref(false)

function confirmDelete(panelist: AdminPanelistEntry) {
  deleteTarget.value = panelist
  isDeleteOpen.value = true
}

async function submitDeletePanelist() {
  if (!deleteTarget.value)
    return
  isDeleting.value = true
  try {
    await admin.deletePanelist(deleteTarget.value.id)
    isDeleteOpen.value = false
    await refreshPanelists()
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to delete panelist.'
  }
  finally {
    isDeleting.value = false
  }
}

// ---- Expertise tags ----
const newExpertise = ref<Record<number, string>>({})

async function submitAddExpertise(panelistId: number) {
  const value = (newExpertise.value[panelistId] ?? '').trim()
  if (!value)
    return
  try {
    await admin.addExpertise(panelistId, value)
    newExpertise.value[panelistId] = ''
    await refreshPanelists()
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to add expertise.'
  }
}

async function submitRemoveExpertise(expertiseId: number) {
  try {
    await admin.removeExpertise(expertiseId)
    await refreshPanelists()
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to remove expertise.'
  }
}

onMounted(loadData)
</script>

<template>
  <DashboardSidebar
    title="Chairperson Dashboard"
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
      Loading dashboard data...
    </div>

    <template v-else-if="!profile">
      <p class="text-sm text-muted-foreground">
        We couldn't find your chairperson profile yet. Please contact a system administrator.
      </p>
    </template>

    <template v-else>
      <section v-if="active === 'overview'" class="space-y-6">
        <div>
          <h1 class="text-2xl font-bold tracking-tight">
            Overview
          </h1>
          <p class="text-sm text-muted-foreground">
            {{ profile.program }} &middot; a snapshot of thesis submission activity for your program.
          </p>
        </div>

        <div class="grid gap-4 sm:grid-cols-3">
          <Card>
            <CardContent class="flex items-center gap-3">
              <span class="flex size-10 shrink-0 items-center justify-center rounded-full bg-[color-mix(in_oklch,var(--chart-2)_15%,transparent)] text-[var(--chart-2)]">
                <Users class="size-5" />
              </span>
              <div class="min-w-0">
                <p class="text-xs font-medium uppercase tracking-wide text-muted-foreground">Students</p>
                <p class="text-2xl font-bold leading-tight">{{ students.length }}</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent class="flex items-center gap-3">
              <span class="flex size-10 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                <CheckCircle2 class="size-5" />
              </span>
              <div class="min-w-0">
                <p class="text-xs font-medium uppercase tracking-wide text-muted-foreground">Submitted</p>
                <p class="text-2xl font-bold leading-tight">{{ submittedCount }}</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent class="flex items-center gap-3">
              <span class="flex size-10 shrink-0 items-center justify-center rounded-full bg-accent text-accent-foreground">
                <Clock class="size-5" />
              </span>
              <div class="min-w-0">
                <p class="text-xs font-medium uppercase tracking-wide text-muted-foreground">Pending Submission</p>
                <p class="text-2xl font-bold leading-tight">{{ pendingCount }}</p>
              </div>
            </CardContent>
          </Card>
        </div>

        <Card class="overflow-hidden py-0">
          <div class="flex items-center justify-between gap-3 border-b px-6 py-4">
            <div>
              <CardTitle class="text-base">Submission progress</CardTitle>
              <p class="text-xs text-muted-foreground">Breakdown of student thesis submissions</p>
            </div>
            <Badge variant="outline" class="tabular-nums">{{ submissionRate }}% complete</Badge>
          </div>
          <CardContent class="py-5">
            <DashboardBarChart :data="overviewChartData" />
          </CardContent>
        </Card>
      </section>

      <section v-else-if="active === 'students'" class="space-y-4">
        <div>
          <h1 class="text-2xl font-bold tracking-tight">Students</h1>
          <p class="text-sm text-muted-foreground">{{ profile.program }}</p>
        </div>
        <div v-if="students.length === 0" class="text-sm text-muted-foreground">No students registered yet.</div>
        <div v-else class="overflow-x-auto rounded-lg border bg-background">
          <table class="w-full text-sm">
            <thead class="border-b bg-muted/40 text-left text-xs uppercase tracking-wide text-muted-foreground">
              <tr>
                <th class="px-4 py-2.5 font-medium">Name</th>
                <th class="px-4 py-2.5 font-medium">Email</th>
                <th class="px-4 py-2.5 font-medium">Program</th>
                <th class="px-4 py-2.5 font-medium">Thesis Title</th>
                <th class="px-4 py-2.5 font-medium">Adviser</th>
                <th class="px-4 py-2.5 font-medium">Link</th>
                <th class="px-4 py-2.5 font-medium">Panel</th>
              </tr>
            </thead>
            <tbody class="divide-y">
              <tr v-for="student in students" :key="student.id">
                <td class="px-4 py-2.5">{{ student.full_name }}</td>
                <td class="px-4 py-2.5 text-muted-foreground">{{ student.email }}</td>
                <td class="px-4 py-2.5 text-muted-foreground">{{ student.program }}</td>
                <td class="px-4 py-2.5">
                  <span v-if="student.title">{{ student.title }}</span>
                  <Badge v-else variant="outline">Not submitted</Badge>
                </td>
                <td class="px-4 py-2.5 text-muted-foreground">{{ student.adviser_name }}</td>
                <td class="px-4 py-2.5">
                  <a v-if="student.link" :href="student.link" target="_blank" rel="noopener" class="flex items-center gap-1.5 text-primary hover:underline">
                    <LinkIcon class="size-4" />
                    View
                  </a>
                </td>
                <td class="px-4 py-2.5">
                  <div v-if="!student.title" class="text-muted-foreground">&mdash;</div>
                  <div v-else-if="student.panel.length === 0" class="text-muted-foreground">
                    <Badge variant="outline">Pending</Badge>
                  </div>
                  <div v-else class="flex flex-wrap items-center gap-1">
                    <Badge v-if="panelChairName(student.panel)" variant="default" class="gap-1">
                      <Crown class="size-3" />
                      {{ panelChairName(student.panel) }}
                    </Badge>
                    <Badge v-for="name in panelMemberNames(student.panel)" :key="name" variant="secondary">
                      {{ name }}
                    </Badge>
                    <Badge v-if="!panelChairName(student.panel) || panelMemberNames(student.panel).length < 2" variant="outline">
                      Incomplete
                    </Badge>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section v-else-if="active === 'panelists'" class="space-y-4">
        <div class="flex items-center justify-between gap-3">
          <div>
            <h1 class="text-2xl font-bold tracking-tight">Panelists</h1>
            <p class="text-sm text-muted-foreground">
              {{ profile.program }} &middot; manage panelist records and their tagged expertise areas.
            </p>
          </div>

          <Dialog v-model:open="isAddOpen">
            <DialogTrigger as-child>
              <Button>
                <Plus class="size-4" />
                Add panelist
              </Button>
            </DialogTrigger>
            <DialogContent class="max-w-sm">
              <DialogHeader>
                <DialogTitle>Add panelist</DialogTitle>
                <DialogDescription>
                  Adds a panelist record for {{ profile.program }}. Panelists don't sign in — they're managed entirely from here.
                </DialogDescription>
              </DialogHeader>
              <form class="space-y-4" @submit.prevent="submitAddPanelist">
                <div v-if="addError" class="flex items-start gap-2 rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
                  <AlertCircle class="mt-0.5 size-4 shrink-0" />
                  <span>{{ addError }}</span>
                </div>
                <div class="flex flex-col gap-2">
                  <Label for="panelist-name">Full name</Label>
                  <Input id="panelist-name" v-model="addForm.fullName" placeholder="e.g. Dr. Juan Dela Cruz" required />
                </div>
                <div class="flex flex-col gap-2">
                  <Label for="panelist-position">Position</Label>
                  <Input id="panelist-position" v-model="addForm.position" placeholder="e.g. Associate Professor" />
                </div>
                <div class="flex flex-col gap-2">
                  <Label for="panelist-expertise">Expertise areas</Label>
                  <div class="flex items-center gap-1.5">
                    <Input
                      id="panelist-expertise"
                      v-model="addExpertiseInput"
                      placeholder="e.g. Machine Learning"
                      @keydown.enter.prevent="addExpertiseTagToForm"
                    />
                    <Button type="button" size="icon" variant="outline" class="size-8 shrink-0" @click="addExpertiseTagToForm">
                      <Plus class="size-3.5" />
                    </Button>
                  </div>
                  <div v-if="addExpertiseTags.length > 0" class="flex flex-wrap gap-1.5">
                    <Badge v-for="tag in addExpertiseTags" :key="tag" variant="secondary" class="gap-1 pr-1">
                      {{ tag }}
                      <button type="button" :aria-label="`Remove ${tag}`" class="rounded-full p-0.5 hover:bg-foreground/10" @click="removeExpertiseTagFromForm(tag)">
                        <X class="size-3" />
                      </button>
                    </Badge>
                  </div>
                  <p class="text-xs text-muted-foreground">Press Enter or + to add each area.</p>
                </div>
                <div class="flex flex-col gap-2">
                  <Label for="panelist-email">Email (optional)</Label>
                  <Input id="panelist-email" v-model="addForm.email" type="email" placeholder="e.g. panelist@carsu.edu.ph" />
                </div>
                <DialogFooter>
                  <Button type="button" variant="outline" :disabled="isSavingPanelist" @click="isAddOpen = false">
                    Cancel
                  </Button>
                  <Button type="submit" :disabled="isSavingPanelist">
                    <Loader2 v-if="isSavingPanelist" class="size-4 animate-spin" />
                    Add panelist
                  </Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <div v-if="panelists.length === 0" class="text-sm text-muted-foreground">
          No panelists yet. Add one to start auto-assigning panels.
        </div>

        <div v-else class="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          <Card v-for="panelist in panelists" :key="panelist.id" class="py-0 overflow-hidden">
            <div class="flex items-start gap-3 border-b bg-muted/30 px-4 py-3.5">
              <span class="flex size-9 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                <UserRound class="size-4" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-semibold">{{ panelist.full_name }}</p>
                <p class="truncate text-xs text-muted-foreground">{{ panelist.position || 'No position set' }}</p>
              </div>
              <div class="flex shrink-0 items-center gap-1">
                <button type="button" aria-label="Edit panelist" class="rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground" @click="openEdit(panelist)">
                  <Pencil class="size-3.5" />
                </button>
                <button type="button" aria-label="Delete panelist" class="rounded-md p-1.5 text-muted-foreground hover:bg-destructive/10 hover:text-destructive" @click="confirmDelete(panelist)">
                  <Trash2 class="size-3.5" />
                </button>
              </div>
            </div>
            <CardContent class="space-y-3 py-4">
              <p v-if="panelist.email" class="truncate text-xs text-muted-foreground">{{ panelist.email }}</p>

              <div class="flex flex-wrap gap-1.5">
                <Badge v-for="tag in panelist.expertise" :key="tag.id" variant="secondary" class="gap-1 pr-1">
                  {{ tag.expertise_area }}
                  <button type="button" :aria-label="`Remove ${tag.expertise_area}`" class="rounded-full p-0.5 hover:bg-foreground/10" @click="submitRemoveExpertise(tag.id)">
                    <X class="size-3" />
                  </button>
                </Badge>
                <span v-if="panelist.expertise.length === 0" class="text-xs text-muted-foreground">No expertise tagged yet.</span>
              </div>

              <form class="flex items-center gap-1.5" @submit.prevent="submitAddExpertise(panelist.id)">
                <Input
                  v-model="newExpertise[panelist.id]"
                  placeholder="Add expertise area"
                  class="h-8 text-xs"
                />
                <Button type="submit" size="icon" variant="outline" class="size-8 shrink-0">
                  <Plus class="size-3.5" />
                </Button>
              </form>

              <p class="text-xs text-muted-foreground">
                {{ panelist.assignment_count }} panel assignment{{ panelist.assignment_count === 1 ? '' : 's' }}
              </p>
            </CardContent>
          </Card>
        </div>

        <Dialog v-model:open="isEditOpen">
          <DialogContent class="max-w-sm">
            <DialogHeader>
              <DialogTitle>Edit panelist</DialogTitle>
            </DialogHeader>
            <form class="space-y-4" @submit.prevent="submitEditPanelist">
              <div class="flex flex-col gap-2">
                <Label for="edit-panelist-name">Full name</Label>
                <Input id="edit-panelist-name" v-model="editForm.fullName" required />
              </div>
              <div class="flex flex-col gap-2">
                <Label for="edit-panelist-position">Position</Label>
                <Input id="edit-panelist-position" v-model="editForm.position" />
              </div>
              <DialogFooter>
                <Button type="button" variant="outline" :disabled="isSavingEdit" @click="isEditOpen = false">
                  Cancel
                </Button>
                <Button type="submit" :disabled="isSavingEdit">
                  <Loader2 v-if="isSavingEdit" class="size-4 animate-spin" />
                  Save changes
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>

        <Dialog v-model:open="isDeleteOpen">
          <DialogContent class="max-w-sm">
            <DialogHeader>
              <DialogTitle>Remove {{ deleteTarget?.full_name }}?</DialogTitle>
              <DialogDescription>
                This removes their panelist record and takes them off any assigned panels. This can't be undone.
              </DialogDescription>
            </DialogHeader>
            <DialogFooter>
              <Button variant="outline" :disabled="isDeleting" @click="isDeleteOpen = false">
                Cancel
              </Button>
              <Button variant="destructive" :disabled="isDeleting" @click="submitDeletePanelist">
                <Loader2 v-if="isDeleting" class="size-4 animate-spin" />
                <Trash2 v-else class="size-4" />
                Remove
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </section>
    </template>
  </DashboardSidebar>
</template>
