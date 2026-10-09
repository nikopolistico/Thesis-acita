<script setup lang="ts">
import { useTransition } from '@vueuse/core'

const props = defineProps<{
  tag: string
  panelist: string
  score: number
  cutoff: number
}>()

const shown = useTransition(() => props.score, { duration: 600 })
const weak = computed(() => props.score < props.cutoff)
</script>

<template>
  <div>
    <div class="mb-1 flex items-baseline justify-between gap-3 text-sm">
      <span class="truncate" :class="weak && 'text-muted-foreground'">{{ tag }}</span>
      <span class="shrink-0 tabular-nums" :class="weak ? 'text-muted-foreground' : 'font-semibold'">{{ Math.round(shown) }}%</span>
    </div>
    <div class="h-2 rounded-full bg-muted">
      <div
        class="h-full rounded-full transition-[width,background-color] duration-700 ease-out motion-reduce:transition-none"
        :class="weak ? 'bg-muted-foreground/40' : 'bg-primary'"
        :style="{ width: score + '%' }"
      />
    </div>
  </div>
</template>
