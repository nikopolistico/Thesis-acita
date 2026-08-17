<script setup lang="ts">
import {
  AlertCircle,
  Bell,
  BookOpen,
  CalendarClock,
  Circle,
  Clock,
  LayoutDashboard,
  Loader2,
  MapPin,
  Plus,
  Users,
} from '@lucide/vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import type { StudentScheduleEntry } from '~/composables/useStudents'
import type { Notification, StudentInformation, ThesisTitle } from '~/types/database'

definePageMeta({ middleware: 'dashboard', role: 'student' })

const navItems = [
  { key: 'overview', label: 'Overview', icon: LayoutDashboard },
  { key: 'thesis', label: 'My Thesis', icon: BookOpen },
  { key: 'schedule', label: 'My Schedule', icon: CalendarClock },
  { key: 'notifications', label: 'Notifications', icon: Bell },
]

const active = ref('overview')
const authUser = useAuthUser()
const students = useStudents()
const notificationsApi = useNotifications()

const isLoading = ref(true)
const errorMessage = ref('')
const profile = ref<StudentInformation | null>(null)
const titles = ref<ThesisTitle[]>([])
const schedules = ref<StudentScheduleEntry[]>([])
const notifications = ref<Notification[]>([])

const newTitle = ref('')
const isAddingTitle = ref(false)

async function loadData() {
  if (!authUser.value)
    return
  isLoading.value = true
  errorMessage.value = ''
  try {
    profile.value = await students.getProfile(authUser.value.id)

    if (profile.value) {
      titles.value = await students.getThesisTitles(profile.value.id)
      schedules.value = await students.getSchedules(profile.value.id)
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

async function addTitle() {
  if (!profile.value || !newTitle.value.trim())
    return
  isAddingTitle.value = true
  try {
    const created = await students.addThesisTitle(profile.value.id, newTitle.value.trim())
    titles.value.push(created)
    newTitle.value = ''
  }
  catch (error: any) {
    errorMessage.value = error?.message ?? 'Failed to add thesis title.'
  }
  finally {
    isAddingTitle.value = false
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

const upcomingSchedule = computed(() => schedules.value[0])
const unreadCount = computed(() => notifications.value.filter(n => !n.is_read).length)

const overviewChartData = computed(() => [
  { label: 'Thesis Titles', value: titles.value.length },
  { label: 'Defenses', value: schedules.value.length },
  { label: 'Unread', value: unreadCount.value },
])

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
        <h1 class="text-2xl font-bold tracking-tight">
          Welcome back, {{ profile.full_name }}
        </h1>
        <div class="grid gap-4 sm:grid-cols-3">
          <Card>
            <CardHeader class="pb-2">
              <CardTitle class="text-sm font-medium text-muted-foreground">
                Thesis Titles
              </CardTitle>
            </CardHeader>
            <CardContent class="text-2xl font-bold">
              {{ titles.length }}
            </CardContent>
          </Card>
          <Card>
            <CardHeader class="pb-2">
              <CardTitle class="text-sm font-medium text-muted-foreground">
                Scheduled Defenses
              </CardTitle>
            </CardHeader>
            <CardContent class="text-2xl font-bold">
              {{ schedules.length }}
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
            <CardTitle class="text-base">My activity</CardTitle>
          </CardHeader>
          <CardContent>
            <DashboardBarChart :data="overviewChartData" />
          </CardContent>
        </Card>

        <Card v-if="upcomingSchedule">
          <CardHeader>
            <CardTitle>Next Defense</CardTitle>
          </CardHeader>
          <CardContent class="space-y-2 text-sm">
            <p class="font-medium">
              {{ upcomingSchedule.thesis_title }}
            </p>
            <p class="flex items-center gap-1.5 text-muted-foreground">
              <CalendarClock class="size-4" />
              {{ upcomingSchedule.schedule_date }} · {{ upcomingSchedule.start_time }}–{{ upcomingSchedule.end_time }}
            </p>
            <p v-if="upcomingSchedule.venue" class="flex items-center gap-1.5 text-muted-foreground">
              <MapPin class="size-4" />
              {{ upcomingSchedule.venue }}
            </p>
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
              Add a thesis title
            </CardTitle>
          </CardHeader>
          <CardContent>
            <form class="flex flex-col gap-3 sm:flex-row" @submit.prevent="addTitle">
              <div class="flex-1">
                <Label for="new-title" class="sr-only">Thesis title</Label>
                <Input id="new-title" v-model="newTitle" placeholder="e.g. Expertise-Based Panel Assignment System" required />
              </div>
              <Button type="submit" :disabled="isAddingTitle">
                <Loader2 v-if="isAddingTitle" class="size-4 animate-spin" />
                <Plus v-else class="size-4" />
                Add
              </Button>
            </form>
          </CardContent>
        </Card>

        <div v-if="titles.length === 0" class="text-sm text-muted-foreground">
          You haven't added a thesis title yet.
        </div>
        <ul v-else class="space-y-2">
          <li v-for="title in titles" :key="title.id" class="rounded-lg border bg-background p-4 text-sm">
            {{ title.title }}
          </li>
        </ul>
      </section>

      <section v-else-if="active === 'schedule'" class="space-y-6">
        <h1 class="text-2xl font-bold tracking-tight">
          My Schedule
        </h1>

        <div v-if="schedules.length === 0" class="text-sm text-muted-foreground">
          No defense has been scheduled for you yet.
        </div>
        <div v-else class="space-y-4">
          <Card v-for="schedule in schedules" :key="schedule.id">
            <CardHeader class="flex flex-row items-start justify-between gap-4 space-y-0">
              <div>
                <CardTitle class="text-base">
                  {{ schedule.thesis_title }}
                </CardTitle>
                <p class="mt-1 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-muted-foreground">
                  <span class="flex items-center gap-1.5">
                    <CalendarClock class="size-4" />
                    {{ schedule.schedule_date }}
                  </span>
                  <span class="flex items-center gap-1.5">
                    <Clock class="size-4" />
                    {{ schedule.start_time }}–{{ schedule.end_time }}
                  </span>
                  <span v-if="schedule.venue" class="flex items-center gap-1.5">
                    <MapPin class="size-4" />
                    {{ schedule.venue }}
                  </span>
                </p>
              </div>
              <Badge variant="secondary" class="capitalize">
                {{ schedule.status }}
              </Badge>
            </CardHeader>
            <CardContent v-if="schedule.panel?.length">
              <p class="mb-2 flex items-center gap-1.5 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                <Users class="size-3.5" />
                Panel
              </p>
              <ul class="space-y-1.5">
                <li v-for="(assignment, i) in schedule.panel" :key="i" class="flex items-center justify-between text-sm">
                  <span>
                    {{ assignment.full_name }}
                    <span class="text-muted-foreground">— {{ assignment.role_in_panel }}</span>
                  </span>
                  <Badge variant="outline" class="capitalize">
                    {{ assignment.status }}
                  </Badge>
                </li>
              </ul>
            </CardContent>
          </Card>
        </div>
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
