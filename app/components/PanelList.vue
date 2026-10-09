<script setup lang="ts">
import { Clock, Crown, UserRound } from '@lucide/vue'
import { Badge } from '@/components/ui/badge'
import type { ThesisPanelMember } from '~/types/database'

const props = defineProps<{ panel: ThesisPanelMember[] }>()

const chair = computed(() => props.panel.find(p => p.role === 'chair') ?? null)
const members = computed(() => props.panel.filter(p => p.role === 'member'))
</script>

<template>
  <div v-if="panel.length === 0" class="flex items-center gap-2 text-sm text-muted-foreground">
    <Clock class="size-4" />
    Awaiting panel assignment. This updates automatically once matching panelists are found.
  </div>
  <ul v-else class="divide-y">
    <li v-if="chair" class="flex items-center gap-3 py-2.5 first:pt-0">
      <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-accent text-accent-foreground">
        <Crown class="size-4" />
      </span>
      <div class="min-w-0 flex-1">
        <p class="truncate text-sm font-medium">{{ chair.full_name }}</p>
        <p class="truncate text-xs text-muted-foreground">{{ chair.position ?? 'Panel chair' }}</p>
      </div>
      <Badge class="bg-accent text-accent-foreground">Chair</Badge>
    </li>
    <li v-for="member in members" :key="member.panel_id" class="flex items-center gap-3 py-2.5 last:pb-0">
      <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-secondary text-secondary-foreground">
        <UserRound class="size-4" />
      </span>
      <div class="min-w-0 flex-1">
        <p class="truncate text-sm font-medium">{{ member.full_name }}</p>
        <p class="truncate text-xs text-muted-foreground">{{ member.position ?? 'Panel member' }}</p>
      </div>
      <Badge variant="outline">Member</Badge>
    </li>
    <li v-if="!chair || members.length < 2" class="flex items-center gap-2 py-2.5 text-sm text-muted-foreground">
      <Clock class="size-4 shrink-0" />
      {{ !chair ? 'Chair' : `${2 - members.length} member${2 - members.length > 1 ? 's' : ''}` }} still pending.
    </li>
  </ul>
</template>
