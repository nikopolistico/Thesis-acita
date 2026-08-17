<script setup lang="ts">
import {
  AlertCircle,
  Bell,
  BookOpen,
  CalendarClock,
  Check,
  ClipboardList,
  Loader2,
  LayoutDashboard,
  Pencil,
  Plus,
  Sparkles,
  Trash2,
  UserCog,
  Users,
  X,
} from '@lucide/vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import type {
  AdminAssignmentEntry,
  AdminPanelistEntry,
  AdminScheduleEntry,
  AdminStudentEntry,
  AdminThesisTitleEntry,
  AdminUserEntry,
} from '~/composables/useAdmin'
import type { AdminNotificationEntry } from '~/composables/useNotifications'

definePageMeta({ middleware: 'dashboard', role: 'admin' })

const navItems = [
  { key: 'overview', label: 'Overview', icon: LayoutDashboard },
  { key: 'students', label: 'Students', icon: Users },
  { key: 'panelists', label: 'Panelists', icon: UserCog },
  { key: 'titles', label: 'Thesis Titles', icon: BookOpen },
  { key: 'schedules', label: 'Schedules', icon: CalendarClock },
  { key: 'assignments', label: 'Panel Assignments', icon: ClipboardList },
  { key: 'notifications', label: 'Notifications', icon: Bell },
]

const active = ref('overview')
const authUser = useAuthUser()
const admin = useAdmin()
const notificationsApi = useNotifications()
const panelistsApi = usePanelists()

const isLoading = ref(true)
const errorMessage = ref('')

const students = ref<AdminStudentEntry[]>([])
const panelists = ref<AdminPanelistEntry[]>([])
const titles = ref<AdminThesisTitleEntry[]>([])
const schedules = ref<AdminScheduleEntry[]>([])
const assignments = ref<AdminAssignmentEntry[]>([])
const notifications = ref<AdminNotificationEntry[]>([])
const users = ref<AdminUserEntry[]>([])

const newSchedule = ref({ titleId: '', scheduleDate: '', startTime: '', endTime: '', venue: '' })
const newAssignment = ref({ scheduleId: '', panelistId: '', roleInPanel: 'member' })
const assignmentExpertiseFilter = ref('')
const aiRecommendation = ref<{ recommendedExpertise: string[], reasoning: string } | null>(null)
const isLoadingRecommendation = ref(false)
const aiRecommendationError = ref('')
const newNotification = ref({ userId: '', message: '' })
const newPanelist = ref({ fullName: '', email: '', password: '', position: '', expertise: '' })
const isSubmittingSchedule = ref(false)
const isSubmittingAssignment = ref(false)
const isSubmittingNotification = ref(false)
const isRegisteringPanelist = ref(false)
const isRegisterPanelistOpen = ref(false)
const isCreateScheduleOpen = ref(false)
const isCreateAssignmentOpen = ref(false)
const isSendNotificationOpen = ref(false)

const editingPanelistId = ref<number | null>(null)
const editPanelistForm = ref({ fullName: '', position: '' })
const isUpdatingPanelist = ref(false)

const newExpertiseByPanelist = ref<Record<number, string>>({})
const isAddingExpertiseFor = ref<number | null>(null)

async function loadData() {
  isLoading.value = true
  errorMessage.value = ''
  try {
    const [studentRows, panelistRows, titleRows, scheduleRows, assignmentRows, notificationRows, userRows] = await Promise.all([
      admin.listStudents(),
      admin.listPanelists(),
      admin.listTitles(),
      admin.listSchedules(),
      admin.listAssignments(),
      notificationsApi.adminList(),
      admin.listUsers(),
    ])

    students.value = studentRows
    panelists.value = panelistRows
    titles.value = titleRows
    schedules.value = scheduleRows
    assignments.value = assignmentRows
    notifications.value = notificationRows
    users.value = userRows
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to load dashboard data.'
  }
  finally {
    isLoading.value = false
  }
}

async function createSchedule() {
  const title = titles.value.find(t => String(t.id) === newSchedule.value.titleId)
  if (!title)
    return
  isSubmittingSchedule.value = true
  try {
    const created = await admin.createSchedule({
      titleId: title.id,
      scheduleDate: newSchedule.value.scheduleDate,
      startTime: newSchedule.value.startTime,
      endTime: newSchedule.value.endTime,
      venue: newSchedule.value.venue || null,
    })
    schedules.value.unshift({ ...created, thesis_title: title.title, student_name: title.student_name })
    newSchedule.value = { titleId: '', scheduleDate: '', startTime: '', endTime: '', venue: '' }
    isCreateScheduleOpen.value = false
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to create schedule.'
  }
  finally {
    isSubmittingSchedule.value = false
  }
}

async function createAssignment() {
  const schedule = schedules.value.find(s => String(s.id) === newAssignment.value.scheduleId)
  const panelist = panelists.value.find(p => String(p.id) === newAssignment.value.panelistId)
  if (!schedule || !panelist)
    return
  isSubmittingAssignment.value = true
  try {
    const created = await admin.createAssignment({
      scheduleId: schedule.id,
      panelistId: panelist.id,
      roleInPanel: newAssignment.value.roleInPanel,
    })
    assignments.value.unshift({
      ...created,
      thesis_title: schedule.thesis_title,
      schedule_date: schedule.schedule_date,
      panelist_name: panelist.full_name,
    })
    newAssignment.value = { scheduleId: '', panelistId: '', roleInPanel: 'member' }
    assignmentExpertiseFilter.value = ''
    aiRecommendation.value = null
    isCreateAssignmentOpen.value = false
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to create panel assignment.'
  }
  finally {
    isSubmittingAssignment.value = false
  }
}

async function sendNotification() {
  const recipient = users.value.find(u => String(u.id) === newNotification.value.userId)
  if (!recipient || !newNotification.value.message.trim())
    return
  isSubmittingNotification.value = true
  try {
    const created = await notificationsApi.adminSend(recipient.id, newNotification.value.message.trim())
    notifications.value.unshift(created)
    newNotification.value = { userId: '', message: '' }
    isSendNotificationOpen.value = false
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to send notification.'
  }
  finally {
    isSubmittingNotification.value = false
  }
}

async function deleteStudent(id: number) {
  if (!confirm('Remove this student profile?'))
    return
  await admin.deleteStudent(id)
  students.value = students.value.filter(s => s.id !== id)
}

async function deletePanelist(id: number) {
  if (!confirm('Remove this panelist profile?'))
    return
  await admin.deletePanelist(id)
  panelists.value = panelists.value.filter(p => p.id !== id)
}

async function registerPanelist() {
  isRegisteringPanelist.value = true
  try {
    const created = await admin.registerPanelist({
      fullName: newPanelist.value.fullName,
      email: newPanelist.value.email,
      password: newPanelist.value.password,
      position: newPanelist.value.position,
    })

    const areas = newPanelist.value.expertise.split(',').map(a => a.trim()).filter(Boolean)
    for (const area of areas) {
      const item = await panelistsApi.addExpertise(created.id, area)
      created.expertise.push(item)
    }

    panelists.value.unshift(created)
    newPanelist.value = { fullName: '', email: '', password: '', position: '', expertise: '' }
    isRegisterPanelistOpen.value = false
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to register panelist.'
  }
  finally {
    isRegisteringPanelist.value = false
  }
}

async function addExpertiseToPanelist(panelist: AdminPanelistEntry) {
  const area = (newExpertiseByPanelist.value[panelist.id] ?? '').trim()
  if (!area)
    return
  isAddingExpertiseFor.value = panelist.id
  try {
    const item = await panelistsApi.addExpertise(panelist.id, area)
    panelist.expertise.push(item)
    newExpertiseByPanelist.value[panelist.id] = ''
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to add expertise area.'
  }
  finally {
    isAddingExpertiseFor.value = null
  }
}

async function removeExpertiseFromPanelist(panelist: AdminPanelistEntry, expertiseId: number) {
  try {
    await panelistsApi.removeExpertise(expertiseId)
    panelist.expertise = panelist.expertise.filter(item => item.id !== expertiseId)
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to remove expertise area.'
  }
}

function startEditPanelist(panelist: AdminPanelistEntry) {
  editingPanelistId.value = panelist.id
  editPanelistForm.value = { fullName: panelist.full_name, position: panelist.position ?? '' }
}

function cancelEditPanelist() {
  editingPanelistId.value = null
}

async function saveEditPanelist(id: number) {
  isUpdatingPanelist.value = true
  try {
    const updated = await admin.updatePanelist(id, {
      fullName: editPanelistForm.value.fullName,
      position: editPanelistForm.value.position,
    })
    const target = panelists.value.find(p => p.id === id)
    if (target) {
      target.full_name = updated.full_name
      target.position = updated.position
    }
    editingPanelistId.value = null
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to update panelist.'
  }
  finally {
    isUpdatingPanelist.value = false
  }
}

async function logout() {
  authUser.value = null
  await navigateTo('/login')
}

const pendingAssignments = computed(() => assignments.value.filter(a => a.status === 'assigned').length)

const overviewChartData = computed(() => [
  { label: 'Students', value: students.value.length },
  { label: 'Panelists', value: panelists.value.length },
  { label: 'Schedules', value: schedules.value.length },
  { label: 'Pending', value: pendingAssignments.value },
])

const allExpertiseAreas = computed(() => {
  const areas = new Set<string>()
  for (const panelist of panelists.value) {
    for (const item of panelist.expertise ?? [])
      areas.add(item.expertise_area)
  }
  return [...areas].sort((a, b) => a.localeCompare(b))
})

const assignablePanelists = computed(() => {
  if (!assignmentExpertiseFilter.value)
    return panelists.value
  return panelists.value.filter(p =>
    p.expertise?.some(item => item.expertise_area === assignmentExpertiseFilter.value),
  )
})

watch(assignmentExpertiseFilter, () => {
  if (!assignablePanelists.value.some(p => String(p.id) === newAssignment.value.panelistId))
    newAssignment.value.panelistId = ''
})

watch(() => newAssignment.value.scheduleId, async (scheduleId) => {
  aiRecommendation.value = null
  aiRecommendationError.value = ''

  if (!scheduleId)
    return

  const schedule = schedules.value.find(s => String(s.id) === scheduleId)
  if (!schedule)
    return

  isLoadingRecommendation.value = true
  try {
    aiRecommendation.value = await $fetch('/api/ai/recommend-expertise', {
      method: 'POST',
      body: {
        title: schedule.thesis_title,
        availableExpertise: allExpertiseAreas.value,
      },
    })
  }
  catch (error: any) {
    aiRecommendationError.value = error?.data?.statusMessage ?? 'Failed to get an AI recommendation.'
  }
  finally {
    isLoadingRecommendation.value = false
  }
})

function applyRecommendedExpertise(area: string) {
  assignmentExpertiseFilter.value = area
}

onMounted(loadData)
</script>

<template>
  <DashboardSidebar
    title="Admin Dashboard"
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

    <template v-else>
      <section v-if="active === 'overview'" class="space-y-6">
        <h1 class="text-2xl font-bold tracking-tight">
          Overview
        </h1>
        <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardHeader class="pb-2">
              <CardTitle class="text-sm font-medium text-muted-foreground">Students</CardTitle>
            </CardHeader>
            <CardContent class="text-2xl font-bold">{{ students.length }}</CardContent>
          </Card>
          <Card>
            <CardHeader class="pb-2">
              <CardTitle class="text-sm font-medium text-muted-foreground">Panelists</CardTitle>
            </CardHeader>
            <CardContent class="text-2xl font-bold">{{ panelists.length }}</CardContent>
          </Card>
          <Card>
            <CardHeader class="pb-2">
              <CardTitle class="text-sm font-medium text-muted-foreground">Scheduled Defenses</CardTitle>
            </CardHeader>
            <CardContent class="text-2xl font-bold">{{ schedules.length }}</CardContent>
          </Card>
          <Card>
            <CardHeader class="pb-2">
              <CardTitle class="text-sm font-medium text-muted-foreground">Pending Assignments</CardTitle>
            </CardHeader>
            <CardContent class="text-2xl font-bold">{{ pendingAssignments }}</CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle class="text-base">Records by category</CardTitle>
          </CardHeader>
          <CardContent>
            <DashboardBarChart :data="overviewChartData" />
          </CardContent>
        </Card>
      </section>

      <section v-else-if="active === 'students'" class="space-y-4">
        <h1 class="text-2xl font-bold tracking-tight">Students</h1>
        <div v-if="students.length === 0" class="text-sm text-muted-foreground">No students registered yet.</div>
        <div v-else class="overflow-x-auto rounded-lg border bg-background">
          <table class="w-full text-sm">
            <thead class="border-b bg-muted/40 text-left text-xs uppercase tracking-wide text-muted-foreground">
              <tr>
                <th class="px-4 py-2.5 font-medium">Name</th>
                <th class="px-4 py-2.5 font-medium">Email</th>
                <th class="px-4 py-2.5 font-medium">Program</th>
                <th class="px-4 py-2.5" />
              </tr>
            </thead>
            <tbody class="divide-y">
              <tr v-for="student in students" :key="student.id">
                <td class="px-4 py-2.5">{{ student.full_name }}</td>
                <td class="px-4 py-2.5 text-muted-foreground">{{ student.email }}</td>
                <td class="px-4 py-2.5 text-muted-foreground">{{ student.program }}</td>
                <td class="px-4 py-2.5 text-right">
                  <button type="button" class="text-muted-foreground hover:text-destructive" @click="deleteStudent(student.id)">
                    <Trash2 class="size-4" />
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section v-else-if="active === 'panelists'" class="space-y-6">
        <div class="flex items-center justify-between gap-4">
          <h1 class="text-2xl font-bold tracking-tight">Panelists</h1>

          <Dialog v-model:open="isRegisterPanelistOpen">
            <DialogTrigger as-child>
              <Button>
                <Plus class="size-4" />
                Register panelist
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Register a panelist</DialogTitle>
                <DialogDescription>
                  Creates a login account and profile for a new panelist.
                </DialogDescription>
              </DialogHeader>
              <form class="grid gap-3 sm:grid-cols-2" @submit.prevent="registerPanelist">
                <div>
                  <Label for="panelist-name">Full name</Label>
                  <Input id="panelist-name" v-model="newPanelist.fullName" placeholder="Juan Dela Cruz" required class="mt-1.5" />
                </div>
                <div>
                  <Label for="panelist-position">Position</Label>
                  <Input id="panelist-position" v-model="newPanelist.position" placeholder="e.g. Associate Professor" class="mt-1.5" />
                </div>
                <div>
                  <Label for="panelist-email">Email</Label>
                  <Input id="panelist-email" v-model="newPanelist.email" type="email" placeholder="you@example.com" required class="mt-1.5" />
                </div>
                <div>
                  <Label for="panelist-password">Temporary password</Label>
                  <Input id="panelist-password" v-model="newPanelist.password" type="password" required class="mt-1.5" />
                </div>
                <div class="sm:col-span-2">
                  <Label for="panelist-expertise">Expertise (comma-separated)</Label>
                  <Input id="panelist-expertise" v-model="newPanelist.expertise" placeholder="e.g. Machine Learning, Data Science" class="mt-1.5" />
                </div>
                <Button type="submit" class="sm:col-span-2" :disabled="isRegisteringPanelist">
                  <Loader2 v-if="isRegisteringPanelist" class="size-4 animate-spin" />
                  <Plus v-else class="size-4" />
                  Register panelist
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <div v-if="panelists.length === 0" class="text-sm text-muted-foreground">No panelists registered yet.</div>
        <div v-else class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Card v-for="panelist in panelists" :key="panelist.id">
            <template v-if="editingPanelistId === panelist.id">
              <CardContent class="space-y-3 pt-6">
                <div class="space-y-3">
                  <div>
                    <Label :for="`edit-name-${panelist.id}`">Full name</Label>
                    <Input :id="`edit-name-${panelist.id}`" v-model="editPanelistForm.fullName" class="mt-1.5" />
                  </div>
                  <div>
                    <Label :for="`edit-position-${panelist.id}`">Position</Label>
                    <Input :id="`edit-position-${panelist.id}`" v-model="editPanelistForm.position" class="mt-1.5" />
                  </div>
                </div>
                <div class="flex gap-2">
                  <Button size="sm" :disabled="isUpdatingPanelist" @click="saveEditPanelist(panelist.id)">
                    <Check class="size-4" />
                    Save
                  </Button>
                  <Button size="sm" variant="outline" :disabled="isUpdatingPanelist" @click="cancelEditPanelist">
                    <X class="size-4" />
                    Cancel
                  </Button>
                </div>
              </CardContent>
            </template>
            <template v-else>
              <CardHeader class="flex flex-row items-start justify-between gap-2 space-y-0 pb-2">
                <CardTitle class="text-base leading-tight">{{ panelist.full_name }}</CardTitle>
                <div class="flex shrink-0 gap-2">
                  <button type="button" class="text-muted-foreground hover:text-foreground" @click="startEditPanelist(panelist)">
                    <Pencil class="size-4" />
                  </button>
                  <button type="button" class="text-muted-foreground hover:text-destructive" @click="deletePanelist(panelist.id)">
                    <Trash2 class="size-4" />
                  </button>
                </div>
              </CardHeader>
              <CardContent class="space-y-3">
                <div class="space-y-0.5 text-sm text-muted-foreground">
                  <p class="truncate">{{ panelist.email }}</p>
                  <p v-if="panelist.position">{{ panelist.position }}</p>
                </div>
                <div v-if="panelist.expertise?.length" class="flex flex-wrap gap-1.5">
                  <Badge v-for="item in panelist.expertise" :key="item.id" variant="secondary" class="gap-1.5 py-1.5 pl-3 pr-2 text-sm">
                    {{ item.expertise_area }}
                    <button type="button" class="text-muted-foreground hover:text-destructive" @click="removeExpertiseFromPanelist(panelist, item.id)">
                      <X class="size-3.5" />
                    </button>
                  </Badge>
                </div>
                <form class="flex gap-2" @submit.prevent="addExpertiseToPanelist(panelist)">
                  <Input
                    v-model="newExpertiseByPanelist[panelist.id]"
                    placeholder="Add expertise"
                    class="h-9 flex-1"
                  />
                  <Button type="submit" size="sm" variant="outline" :disabled="isAddingExpertiseFor === panelist.id">
                    <Loader2 v-if="isAddingExpertiseFor === panelist.id" class="size-4 animate-spin" />
                    <Plus v-else class="size-4" />
                  </Button>
                </form>
              </CardContent>
            </template>
          </Card>
        </div>
      </section>

      <section v-else-if="active === 'titles'" class="space-y-4">
        <h1 class="text-2xl font-bold tracking-tight">Thesis Titles</h1>
        <div v-if="titles.length === 0" class="text-sm text-muted-foreground">No thesis titles submitted yet.</div>
        <ul v-else class="space-y-2">
          <li v-for="title in titles" :key="title.id" class="rounded-lg border bg-background p-4 text-sm">
            <p class="font-medium">{{ title.title }}</p>
            <p class="mt-1 text-muted-foreground">{{ title.student_name }}</p>
          </li>
        </ul>
      </section>

      <section v-else-if="active === 'schedules'" class="space-y-6">
        <div class="flex items-center justify-between gap-4">
          <h1 class="text-2xl font-bold tracking-tight">Schedules</h1>

          <Dialog v-model:open="isCreateScheduleOpen">
            <DialogTrigger as-child>
              <Button>
                <Plus class="size-4" />
                Create schedule
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create a defense schedule</DialogTitle>
                <DialogDescription>
                  Assigns a date, time, and venue to a submitted thesis title.
                </DialogDescription>
              </DialogHeader>
              <form class="grid gap-3 sm:grid-cols-2" @submit.prevent="createSchedule">
                <div class="sm:col-span-2">
                  <Label for="schedule-title">Thesis title</Label>
                  <select id="schedule-title" v-model="newSchedule.titleId" required class="mt-1.5 h-10 w-full rounded-md border border-input bg-background px-3 text-sm">
                    <option value="" disabled>Select a thesis title</option>
                    <option v-for="title in titles" :key="title.id" :value="String(title.id)">
                      {{ title.title }} — {{ title.student_name }}
                    </option>
                  </select>
                </div>
                <div>
                  <Label for="schedule-date">Date</Label>
                  <Input id="schedule-date" v-model="newSchedule.scheduleDate" type="date" required class="mt-1.5" />
                </div>
                <div>
                  <Label for="schedule-venue">Venue</Label>
                  <Input id="schedule-venue" v-model="newSchedule.venue" placeholder="e.g. CCIS Conference Room" class="mt-1.5" />
                </div>
                <div>
                  <Label for="schedule-start">Start time</Label>
                  <Input id="schedule-start" v-model="newSchedule.startTime" type="time" required class="mt-1.5" />
                </div>
                <div>
                  <Label for="schedule-end">End time</Label>
                  <Input id="schedule-end" v-model="newSchedule.endTime" type="time" required class="mt-1.5" />
                </div>
                <Button type="submit" class="sm:col-span-2" :disabled="isSubmittingSchedule">
                  <Loader2 v-if="isSubmittingSchedule" class="size-4 animate-spin" />
                  <Plus v-else class="size-4" />
                  Create schedule
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <div v-if="schedules.length === 0" class="text-sm text-muted-foreground">No schedules created yet.</div>
        <div v-else class="overflow-x-auto rounded-lg border bg-background">
          <table class="w-full text-sm">
            <thead class="border-b bg-muted/40 text-left text-xs uppercase tracking-wide text-muted-foreground">
              <tr>
                <th class="px-4 py-2.5 font-medium">Thesis</th>
                <th class="px-4 py-2.5 font-medium">Student</th>
                <th class="px-4 py-2.5 font-medium">Date</th>
                <th class="px-4 py-2.5 font-medium">Time</th>
                <th class="px-4 py-2.5 font-medium">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y">
              <tr v-for="schedule in schedules" :key="schedule.id">
                <td class="px-4 py-2.5">{{ schedule.thesis_title }}</td>
                <td class="px-4 py-2.5 text-muted-foreground">{{ schedule.student_name }}</td>
                <td class="px-4 py-2.5 text-muted-foreground">{{ schedule.schedule_date }}</td>
                <td class="px-4 py-2.5 text-muted-foreground">{{ schedule.start_time }}–{{ schedule.end_time }}</td>
                <td class="px-4 py-2.5">
                  <Badge variant="secondary" class="capitalize">{{ schedule.status }}</Badge>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section v-else-if="active === 'assignments'" class="space-y-6">
        <div class="flex items-center justify-between gap-4">
          <h1 class="text-2xl font-bold tracking-tight">Panel Assignments</h1>

          <Dialog v-model:open="isCreateAssignmentOpen">
            <DialogTrigger as-child>
              <Button>
                <Plus class="size-4" />
                Assign
              </Button>
            </DialogTrigger>
            <DialogContent class="sm:max-w-2xl">
              <DialogHeader>
                <DialogTitle>Assign a panelist</DialogTitle>
                <DialogDescription>
                  Adds a panelist to a scheduled defense.
                </DialogDescription>
              </DialogHeader>
              <form class="grid gap-3 sm:grid-cols-3" @submit.prevent="createAssignment">
                <div class="sm:col-span-3">
                  <Label for="assignment-schedule">Schedule</Label>
                  <select id="assignment-schedule" v-model="newAssignment.scheduleId" required class="mt-1.5 h-10 w-full rounded-md border border-input bg-background px-3 text-sm">
                    <option value="" disabled>Select a schedule</option>
                    <option v-for="schedule in schedules" :key="schedule.id" :value="String(schedule.id)">
                      {{ schedule.thesis_title }} — {{ schedule.schedule_date }}
                    </option>
                  </select>
                </div>

                <div v-if="isLoadingRecommendation" class="sm:col-span-3 flex items-center gap-2 rounded-lg border bg-muted/40 p-3 text-sm text-muted-foreground">
                  <Loader2 class="size-4 animate-spin" />
                  Asking Grok which expertise fits this thesis...
                </div>
                <div v-else-if="aiRecommendationError" class="sm:col-span-3 flex items-start gap-2 rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
                  <AlertCircle class="mt-0.5 size-4 shrink-0" />
                  <span>{{ aiRecommendationError }}</span>
                </div>
                <div v-else-if="aiRecommendation" class="sm:col-span-3 space-y-2 rounded-lg border bg-muted/40 p-3">
                  <p class="flex items-center gap-1.5 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                    <Sparkles class="size-3.5" />
                    Grok recommends
                  </p>
                  <div class="flex flex-wrap gap-1.5">
                    <button
                      v-for="area in aiRecommendation.recommendedExpertise"
                      :key="area"
                      type="button"
                      @click="applyRecommendedExpertise(area)"
                    >
                      <Badge
                        variant="secondary"
                        class="cursor-pointer transition-colors hover:bg-primary hover:text-primary-foreground"
                        :class="{ 'bg-primary text-primary-foreground': assignmentExpertiseFilter === area }"
                      >
                        {{ area }}
                      </Badge>
                    </button>
                  </div>
                  <p class="text-sm text-muted-foreground">
                    {{ aiRecommendation.reasoning }}
                  </p>
                </div>

                <div class="sm:col-span-3">
                  <Label for="assignment-expertise">Filter by expertise</Label>
                  <select id="assignment-expertise" v-model="assignmentExpertiseFilter" class="mt-1.5 h-10 w-full rounded-md border border-input bg-background px-3 text-sm">
                    <option value="">All expertise areas</option>
                    <option v-for="area in allExpertiseAreas" :key="area" :value="area">
                      {{ area }}
                    </option>
                  </select>
                </div>
                <div class="sm:col-span-2">
                  <Label for="assignment-panelist">Panelist</Label>
                  <select id="assignment-panelist" v-model="newAssignment.panelistId" required class="mt-1.5 h-10 w-full rounded-md border border-input bg-background px-3 text-sm">
                    <option value="" disabled>
                      {{ assignablePanelists.length === 0 ? 'No panelists with this expertise' : 'Select a panelist' }}
                    </option>
                    <option v-for="panelist in assignablePanelists" :key="panelist.id" :value="String(panelist.id)">
                      {{ panelist.full_name }}<template v-if="panelist.expertise?.length"> — {{ panelist.expertise.map(e => e.expertise_area).join(', ') }}</template>
                    </option>
                  </select>
                </div>
                <div>
                  <Label for="assignment-role">Role</Label>
                  <select id="assignment-role" v-model="newAssignment.roleInPanel" class="mt-1.5 h-10 w-full rounded-md border border-input bg-background px-3 text-sm">
                    <option value="chair">Chair</option>
                    <option value="member">Member</option>
                    <option value="adviser">Adviser</option>
                  </select>
                </div>
                <Button type="submit" class="sm:col-span-3" :disabled="isSubmittingAssignment">
                  <Loader2 v-if="isSubmittingAssignment" class="size-4 animate-spin" />
                  <Plus v-else class="size-4" />
                  Assign
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <div v-if="assignments.length === 0" class="text-sm text-muted-foreground">No panel assignments yet.</div>
        <ul v-else class="space-y-2">
          <li v-for="assignment in assignments" :key="assignment.id" class="flex items-center justify-between rounded-lg border bg-background p-4 text-sm">
            <span>
              {{ assignment.panelist_name }} → {{ assignment.thesis_title }}
              <span class="text-muted-foreground">({{ assignment.role_in_panel }})</span>
            </span>
            <Badge variant="outline" class="capitalize">{{ assignment.status }}</Badge>
          </li>
        </ul>
      </section>

      <section v-else-if="active === 'notifications'" class="space-y-6">
        <div class="flex items-center justify-between gap-4">
          <h1 class="text-2xl font-bold tracking-tight">Notifications</h1>

          <Dialog v-model:open="isSendNotificationOpen">
            <DialogTrigger as-child>
              <Button>
                <Plus class="size-4" />
                Send notification
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Send a notification</DialogTitle>
                <DialogDescription>
                  Sends a message to a specific student, panelist, or admin.
                </DialogDescription>
              </DialogHeader>
              <form class="grid gap-3 sm:grid-cols-2" @submit.prevent="sendNotification">
                <div class="sm:col-span-2">
                  <Label for="notification-user">Recipient</Label>
                  <select id="notification-user" v-model="newNotification.userId" required class="mt-1.5 h-10 w-full rounded-md border border-input bg-background px-3 text-sm">
                    <option value="" disabled>Select a user</option>
                    <option v-for="user in users" :key="user.id" :value="String(user.id)">
                      {{ user.email }} ({{ user.role_name }})
                    </option>
                  </select>
                </div>
                <div class="sm:col-span-2">
                  <Label for="notification-message">Message</Label>
                  <Input id="notification-message" v-model="newNotification.message" placeholder="e.g. Your defense has been rescheduled." class="mt-1.5" required />
                </div>
                <Button type="submit" class="sm:col-span-2" :disabled="isSubmittingNotification">
                  <Loader2 v-if="isSubmittingNotification" class="size-4 animate-spin" />
                  <Plus v-else class="size-4" />
                  Send
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <div v-if="notifications.length === 0" class="text-sm text-muted-foreground">No notifications sent yet.</div>
        <ul v-else class="space-y-2">
          <li v-for="notification in notifications" :key="notification.id" class="rounded-lg border bg-background p-4 text-sm">
            <p>{{ notification.message }}</p>
            <p class="mt-1 text-xs text-muted-foreground">
              To {{ notification.recipient_email }} · {{ new Date(notification.date_sent).toLocaleString() }}
            </p>
          </li>
        </ul>
      </section>
    </template>
  </DashboardSidebar>
</template>
