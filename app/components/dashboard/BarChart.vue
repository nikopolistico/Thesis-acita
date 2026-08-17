<script setup lang="ts">
interface BarDatum {
  label: string
  value: number
}

const props = withDefaults(defineProps<{
  data: BarDatum[]
  height?: number
}>(), {
  height: 180,
})

const colors = ['var(--chart-1)', 'var(--chart-2)', 'var(--chart-3)', 'var(--chart-4)']

const maxValue = computed(() => Math.max(1, ...props.data.map(d => d.value)))
const trackHeight = computed(() => props.height - 40)

function barHeight(value: number) {
  if (value <= 0)
    return 0
  return Math.max(3, Math.round((value / maxValue.value) * trackHeight.value))
}
</script>

<template>
  <div class="w-full">
    <div class="flex items-end justify-between gap-3 sm:gap-6" :style="{ height: `${height}px` }">
      <div
        v-for="(item, i) in data"
        :key="item.label"
        tabindex="0"
        class="group relative flex h-full flex-1 flex-col items-center justify-end gap-1.5 rounded-md outline-none focus-visible:ring-2 focus-visible:ring-ring"
        :aria-label="`${item.label}: ${item.value}`"
      >
        <div
          role="tooltip"
          class="pointer-events-none absolute -top-1 left-1/2 z-10 -translate-x-1/2 -translate-y-full whitespace-nowrap rounded-md bg-popover px-2.5 py-1.5 text-xs text-popover-foreground opacity-0 shadow-md ring-1 ring-foreground/10 transition-opacity group-hover:opacity-100 group-focus-visible:opacity-100"
        >
          <span class="font-semibold">{{ item.value }}</span>
          <span class="text-muted-foreground"> · {{ item.label }}</span>
        </div>

        <span class="text-sm font-semibold tabular-nums">{{ item.value }}</span>

        <div
          class="w-full max-w-6 rounded-t-[4px] transition-[filter] duration-150 group-hover:brightness-110 group-focus-visible:brightness-110"
          :style="{ height: `${barHeight(item.value)}px`, backgroundColor: colors[i % colors.length] }"
        />

        <span class="w-full truncate text-center text-xs text-muted-foreground">{{ item.label }}</span>
      </div>
    </div>
    <div class="mt-1 border-t border-border" />

    <table class="sr-only">
      <caption>Chart data</caption>
      <thead>
        <tr>
          <th scope="col">Category</th>
          <th scope="col">Value</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="item in data" :key="item.label">
          <td>{{ item.label }}</td>
          <td>{{ item.value }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
