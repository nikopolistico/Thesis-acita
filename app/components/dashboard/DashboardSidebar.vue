<script setup lang="ts">
import { LogOut, Menu, PanelLeftClose, PanelLeftOpen, X } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'

const props = defineProps<{
  title: string
  navItems: { key: string, label: string, icon: any }[]
  active: string
  userEmail?: string
}>()

const emit = defineEmits<{
  'update:active': [key: string]
  'logout': []
}>()

const isMobileOpen = ref(false)
const isCollapsed = ref(false)
const isLogoutConfirmOpen = ref(false)

function select(key: string) {
  emit('update:active', key)
  isMobileOpen.value = false
}

function confirmLogout() {
  isLogoutConfirmOpen.value = false
  emit('logout')
}
</script>

<template>
  <div class="flex min-h-screen w-full bg-muted/30">
    <div
      v-if="isMobileOpen"
      class="fixed inset-0 z-30 bg-black/40 lg:hidden"
      @click="isMobileOpen = false"
    />

    <aside
      class="fixed inset-y-0 left-0 z-40 flex w-64 shrink-0 -translate-x-full flex-col border-r bg-background transition-all duration-200 lg:static lg:translate-x-0"
      :class="[isMobileOpen ? 'translate-x-0' : '', isCollapsed ? 'lg:w-20' : 'lg:w-64']"
    >
      <div class="flex items-center justify-between gap-2 border-b px-4 py-4">
        <NuxtLink to="/" class="flex items-center gap-2 font-semibold">
          <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-white p-1 shadow-sm ring-1 ring-border">
            <img src="~/assets/images/logo.png" alt="Caraga State University logo" class="size-full object-contain">
          </span>
          <span class="text-sm leading-tight" :class="isCollapsed && 'lg:hidden'">
            CCIS Panelist Automation Assign
          </span>
        </NuxtLink>
        <button
          type="button"
          class="shrink-0 text-muted-foreground hover:text-foreground lg:hidden"
          aria-label="Close menu"
          @click="isMobileOpen = false"
        >
          <X class="size-5" />
        </button>
      </div>

      <div class="flex items-center justify-between gap-2 border-b px-4 py-3" :class="isCollapsed && 'lg:justify-center'">
        <p class="text-xs font-medium uppercase tracking-wide text-muted-foreground" :class="isCollapsed && 'lg:hidden'">
          {{ props.title }}
        </p>
        <div class="flex items-center gap-1">
          <div :class="isCollapsed && 'lg:hidden'">
            <ThemeToggle />
          </div>
          <button
            type="button"
            class="hidden shrink-0 rounded-lg p-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground lg:inline-flex"
            :aria-label="isCollapsed ? 'Expand sidebar' : 'Collapse sidebar'"
            @click="isCollapsed = !isCollapsed"
          >
            <PanelLeftOpen v-if="isCollapsed" class="size-4" />
            <PanelLeftClose v-else class="size-4" />
          </button>
        </div>
      </div>

      <nav class="flex-1 space-y-1 overflow-y-auto p-3">
        <button
          v-for="item in navItems"
          :key="item.key"
          type="button"
          :title="item.label"
          class="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-left text-sm font-medium transition-colors"
          :class="[
            active === item.key
              ? 'bg-primary text-primary-foreground'
              : 'text-muted-foreground hover:bg-muted hover:text-foreground',
            isCollapsed && 'lg:justify-center lg:px-0',
          ]"
          @click="select(item.key)"
        >
          <component :is="item.icon" class="size-4 shrink-0" />
          <span :class="isCollapsed && 'lg:hidden'">{{ item.label }}</span>
        </button>
      </nav>

      <div class="border-t p-3">
        <p v-if="userEmail" class="truncate px-3 pb-2 text-xs text-muted-foreground" :class="isCollapsed && 'lg:hidden'">
          {{ userEmail }}
        </p>
        <Dialog v-model:open="isLogoutConfirmOpen">
          <DialogTrigger as-child>
            <button
              type="button"
              title="Log out"
              class="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-left text-sm font-medium text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
              :class="isCollapsed && 'lg:justify-center lg:px-0'"
            >
              <LogOut class="size-4 shrink-0" />
              <span :class="isCollapsed && 'lg:hidden'">Log out</span>
            </button>
          </DialogTrigger>
          <DialogContent class="max-w-sm">
            <DialogHeader>
              <DialogTitle>Log out?</DialogTitle>
              <DialogDescription>
                You'll need to sign in again to access your dashboard.
              </DialogDescription>
            </DialogHeader>
            <DialogFooter>
              <Button variant="outline" @click="isLogoutConfirmOpen = false">
                Cancel
              </Button>
              <Button variant="destructive" @click="confirmLogout">
                <LogOut class="size-4" />
                Log out
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </aside>

    <div class="flex min-w-0 flex-1 flex-col">
      <header class="flex items-center gap-3 border-b bg-background px-4 py-3 lg:hidden">
        <button
          type="button"
          class="text-muted-foreground hover:text-foreground"
          aria-label="Toggle menu"
          @click="isMobileOpen = !isMobileOpen"
        >
          <Menu v-if="!isMobileOpen" class="size-5" />
          <X v-else class="size-5" />
        </button>
        <span class="flex-1 text-sm font-semibold">{{ props.title }}</span>
        <ThemeToggle />
      </header>

      <main class="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8">
        <slot />
      </main>
    </div>
  </div>
</template>
