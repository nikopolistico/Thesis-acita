<script setup lang="ts">
import {
  AlertCircle,
  Bell,
  CalendarClock,
  CheckCircle2,
  Circle,
  ClipboardList,
  Clock,
  LayoutDashboard,
  Lightbulb,
  Loader2,
  MapPin,
  Plus,
  Trash2,
  XCircle,
} from '@lucide/vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import type { PanelistAssignmentEntry } from '~/composables/usePanelists'
import type { Notification, PanelExpertise, PanelistInformation } from '~/types/database'

definePageMeta({ middleware: 'dashboard', role: 'panelist' })

const navItems = [
  { key: 'overview', label: 'Overview', icon: LayoutDashboard },
  { key: 'assignments', label: 'My Assignments', icon: ClipboardList },
  { key: 'expertise', label: 'My Expertise', icon: Lightbulb },
  { key: 'notifications', label: 'Notifications', icon: Bell },
]

const active = ref('overview')
const authUser = useAuthUser()
const panelists = usePanelists()
const notificationsApi = useNotifications()

const isLoading = ref(true)
const errorMessage = ref('')
const profile = ref<PanelistInformation | null>(null)
const assignments = ref<PanelistAssignmentEntry[]>([])
const expertise = ref<PanelExpertise[]>([])
const notifications = ref<Notification[]>([])

const newExpertise = ref('')
const isAddingExpertise = ref(false)
const updatingAssignmentId = ref<number | null>(null)

async function loadData() {
  if (!authUser.value)
    return
  isLoading.value = true
  errorMessage.value = ''
  try {
    profile.value = await panelists.getProfile(authUser.value.id)

    if (profile.value) {
      assignments.value = await panelists.getAssignments(profile.value.id)
      expertise.value = await panelists.getExpertise(profile.value.id)
    }

    notifications.value = await notificationsApi.list(authUser.value.id)
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to load your dashboard data.'
  }
  finally {
    isLoading.value = false
  }
}

async function addExpertise() {
  if (!profile.value || !newExpertise.value.trim())
    return
  isAddingExpertise.value = true
  try {
    const created = await panelists.addExpertise(profile.value.id, newExpertise.value.trim())
    expertise.value.push(created)
    newExpertise.value = ''
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to add expertise area.'
  }
  finally {
    isAddingExpertise.value = false
  }
}

async function removeExpertise(id: number) {
  try {
    await panelists.removeExpertise(id)
    expertise.value = expertise.value.filter(item => item.id !== id)
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to remove expertise area.'
  }
}

async function setAssignmentStatus(assignment: PanelistAssignmentEntry, status: 'confirmed' | 'declined') {
  updatingAssignmentId.value = assignment.id
  try {
    await panelists.updateAssignmentStatus(assignment.id, status)
    assignment.status = status
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to update assignment.'
  }
  finally {
    updatingAssignmentId.value = null
  }
}

async function markAsRead(notification: Notification) {
  if (notification.is_read)
    return
  await notificationsApi.markRead(notification.id)
  notification.is_read = true
}

async function logout() {
  authUser.value = null
  await navigateTo('/login')
}

const pendingCount = computed(() => assignments.value.filter(a => a.status === 'assigned').length)
const unreadCount = computed(() => notifications.value.filter(n => !n.is_read).length)

const assignmentStatusChartData = computed(() => [
  { label: 'Assigned', value: assignments.value.filter(a => a.status === 'assigned').length },
  { label: 'Confirmed', value: assignments.value.filter(a => a.status === 'confirmed').length },
  { label: 'Declined', value: assignments.value.filter(a => a.status === 'declined').length },
])

onMounted(loadData)
</script>

<template>
  <DashboardSidebar
    title="Panelist Dashboard"
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
        We couldn't find your panelist profile yet. Please contact an administrator.
      </p>
    </template>

    <template v-else>
      <section v-if="active === 'overview'" class="space-y-6">
        <h1 class="text-2xl font-bold tracking-tight">
          Welcome back, {{ profile.full_name }}
        </h1>
        <div class="grid gap-4 sm:grid-cols-3">
          <Card>
            <CardHeader class="pb-2">
              <CardTitle class="text-sm font-medium text-muted-foreground">
                Total Assignments
              </CardTitle>
            </CardHeader>
            <CardContent class="text-2xl font-bold">
              {{ assignments.length }}
            </CardContent>
          </Card>
          <Card>
            <CardHeader class="pb-2">
              <CardTitle class="text-sm font-medium text-muted-foreground">
                Awaiting Response
              </CardTitle>
            </CardHeader>
            <CardContent class="text-2xl font-bold">
              {{ pendingCount }}
            </CardContent>
          </Card>
          <Card>
            <CardHeader class="pb-2">
              <CardTitle class="text-sm font-medium text-muted-foreground">
                Unread Notifications
              </CardTitle>
            </CardHeader>
            <CardContent class="text-2xl font-bold">
              {{ unreadCount }}
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle class="text-base">Assignments by status</CardTitle>
          </CardHeader>
          <CardContent>
            <DashboardBarChart :data="assignmentStatusChartData" />
          </CardContent>
        </Card>
      </section>

      <section v-else-if="active === 'assignments'" class="space-y-6">
        <h1 class="text-2xl font-bold tracking-tight">
          My Assignments
        </h1>

        <div v-if="assignments.length === 0" class="text-sm text-muted-foreground">
          You have no panel assignments yet.
        </div>
        <div v-else class="space-y-4">
          <Card v-for="assignment in assignments" :key="assignment.id">
            <CardHeader class="flex flex-row items-start justify-between gap-4 space-y-0">
              <div>
                <CardTitle class="text-base">
                  {{ assignment.thesis_title }}
                </CardTitle>
                <p class="mt-1 text-sm text-muted-foreground">
                  {{ assignment.student_name }} · role: {{ assignment.role_in_panel }}
                </p>
                <p class="mt-1 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-muted-foreground">
                  <span class="flex items-center gap-1.5">
                    <CalendarClock class="size-4" />
                    {{ assignment.schedule_date }}
                  </span>
                  <span class="flex items-center gap-1.5">
                    <Clock class="size-4" />
                    {{ assignment.start_time }}–{{ assignment.end_time }}
                  </span>
                  <span v-if="assignment.venue" class="flex items-center gap-1.5">
                    <MapPin class="size-4" />
                    {{ assignment.venue }}
                  </span>
                </p>
              </div>
              <Badge variant="secondary" class="shrink-0 capitalize">
                {{ assignment.status }}
              </Badge>
            </CardHeader>
            <CardContent v-if="assignment.status === 'assigned'" class="flex gap-2">
              <Button size="sm" :disabled="updatingAssignmentId === assignment.id" @click="setAssignmentStatus(assignment, 'confirmed')">
                <CheckCircle2 class="size-4" />
                Confirm
              </Button>
              <Button size="sm" variant="outline" :disabled="updatingAssignmentId === assignment.id" @click="setAssignmentStatus(assignment, 'declined')">
                <XCircle class="size-4" />
                Decline
              </Button>
            </CardContent>
          </Card>
        </div>
      </section>

      <section v-else-if="active === 'expertise'" class="space-y-6">
        <h1 class="text-2xl font-bold tracking-tight">
          My Expertise
        </h1>

        <Card>
          <CardHeader>
            <CardTitle class="text-base">
              Add an area of expertise
            </CardTitle>
          </CardHeader>
          <CardContent>
            <form class="flex flex-col gap-3 sm:flex-row" @submit.prevent="addExpertise">
              <div class="flex-1">
                <Label for="new-expertise" class="sr-only">Expertise area</Label>
                <Input id="new-expertise" v-model="newExpertise" placeholder="e.g. Machine Learning" required />
              </div>
              <Button type="submit" :disabled="isAddingExpertise">
                <Loader2 v-if="isAddingExpertise" class="size-4 animate-spin" />
                <Plus v-else class="size-4" />
                Add
              </Button>
            </form>
          </CardContent>
        </Card>

        <div v-if="expertise.length === 0" class="text-sm text-muted-foreground">
          You haven't added any expertise areas yet.
        </div>
        <ul v-else class="flex flex-wrap gap-2">
          <li v-for="item in expertise" :key="item.id">
            <Badge variant="secondary" class="gap-1.5 py-1.5 pl-3 pr-2 text-sm">
              {{ item.expertise_area }}
              <button type="button" class="text-muted-foreground hover:text-destructive" @click="removeExpertise(item.id)">
                <Trash2 class="size-3.5" />
              </button>
            </Badge>
          </li>
        </ul>
      </section>

      <section v-else-if="active === 'notifications'" class="space-y-6">
        <h1 class="text-2xl font-bold tracking-tight">
          Notifications
        </h1>

        <div v-if="notifications.length === 0" class="text-sm text-muted-foreground">
          You have no notifications.
        </div>
        <ul v-else class="space-y-2">
          <li
            v-for="notification in notifications"
            :key="notification.id"
            class="flex items-start gap-3 rounded-lg border bg-background p-4 text-sm"
            :class="{ 'bg-muted/40': notification.is_read }"
          >
            <Circle class="mt-1 size-2 shrink-0" :class="notification.is_read ? 'fill-transparent text-muted-foreground' : 'fill-primary text-primary'" />
            <div class="flex-1">
              <p>{{ notification.message }}</p>
              <p class="mt-1 text-xs text-muted-foreground">
                {{ new Date(notification.date_sent).toLocaleString() }}
              </p>
            </div>
            <Button v-if="!notification.is_read" variant="ghost" size="sm" @click="markAsRead(notification)">
              Mark read
            </Button>
          </li>
        </ul>
      </section>
    </template>
  </DashboardSidebar>
</template>
