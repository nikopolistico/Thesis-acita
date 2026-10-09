<script setup lang="ts">
// Browser-only demo: scores by keyword overlap. The real system
// compares embeddings on the server.
interface Panelist { name: string, tags: { tag: string, words: string[] }[] }

const panelists: Panelist[] = [
  { name: 'Dr. Maria Santos', tags: [
    { tag: 'Remote sensing', words: ['satellite', 'imagery', 'remote', 'sensing', 'flood', 'land', 'drone'] },
    { tag: 'GIS and spatial analysis', words: ['gis', 'map', 'spatial', 'geographic', 'location', 'flood', 'route'] },
  ] },
  { name: 'Engr. Paolo Reyes', tags: [
    { tag: 'Computer networks', words: ['network', 'wifi', 'wireless', 'protocol', 'iot', 'traffic'] },
    { tag: 'Cybersecurity', words: ['security', 'encryption', 'attack', 'privacy', 'authentication', 'intrusion', 'phishing'] },
  ] },
  { name: 'Dr. Lina Cruz', tags: [
    { tag: 'Machine learning', words: ['learning', 'neural', 'prediction', 'classification', 'detect', 'model', 'forecast'] },
    { tag: 'Computer vision', words: ['image', 'vision', 'recognition', 'camera', 'face', 'video', 'imagery'] },
  ] },
  { name: 'Prof. Ramon Dela Pena', tags: [
    { tag: 'Web development', words: ['web', 'website', 'portal', 'online', 'platform', 'system'] },
    { tag: 'Databases', words: ['database', 'records', 'information', 'management', 'inventory', 'data'] },
  ] },
  { name: 'Dr. Ana Villanueva', tags: [
    { tag: 'Human-computer interaction', words: ['usability', 'interface', 'user', 'accessibility', 'experience', 'ux'] },
    { tag: 'Educational technology', words: ['students', 'education', 'school', 'teaching', 'elearning', 'classroom', 'learning'] },
  ] },
  { name: 'Engr. Joel Bautista', tags: [
    { tag: 'Mobile computing', words: ['mobile', 'android', 'ios', 'smartphone', 'app'] },
    { tag: 'Embedded systems', words: ['arduino', 'embedded', 'microcontroller', 'iot', 'sensor', 'hardware', 'monitoring'] },
  ] },
]

const examples = [
  'Flood-risk mapping for Butuan City using satellite imagery',
  'Mobile app for classroom attendance with face recognition',
  'Phishing detection using machine learning on campus email',
  'Arduino-based water level monitoring with SMS alerts',
]

const CUTOFF = 40
const title = ref(examples[0])

function score(words: string[], tokens: string[]) {
  const hits = words.filter(w => tokens.some(t => t === w || (t.length >= 4 && (t.startsWith(w) || w.startsWith(t))))).length
  if (hits === 0) {
    let h = 0
    for (const c of words.join('')) h = (h * 31 + c.charCodeAt(0)) % 9
    return 5 + h
  }
  return Math.min(93, 40 + 20 * hits)
}

const ranked = computed(() => {
  const tokens = title.value.toLowerCase().split(/[^a-z]+/).filter(Boolean)
  return panelists
    .flatMap(p => p.tags.map(t => ({ key: t.tag, panelist: p.name, tag: t.tag, score: score(t.words, tokens) })))
    .sort((a, b) => b.score - a.score || a.tag.localeCompare(b.tag))
})

const top = computed(() => ranked.value.slice(0, 5))

const panel = computed(() => {
  const seen = new Set<string>()
  const picked = ranked.value.filter(r => r.score >= CUTOFF && !seen.has(r.panelist) && seen.add(r.panelist)).slice(0, 3)
  return [0, 1, 2].map(i => ({
    role: i === 0 ? 'Chair' : 'Member',
    match: picked[i] ?? null,
  }))
})

const hasTitle = computed(() => title.value.trim().length > 0)
</script>

<template>
  <section class="rounded-lg border bg-card" aria-label="Try the panel matcher">
    <div class="border-b p-5">
      <label for="demo-title" class="text-sm text-muted-foreground">Try a thesis title</label>
      <textarea
        id="demo-title"
        v-model="title"
        rows="2"
        maxlength="160"
        class="mt-1.5 block w-full resize-none rounded-md border border-input bg-background px-3 py-2 font-heading text-lg font-semibold leading-snug outline-none transition-shadow focus-visible:ring-3 focus-visible:ring-ring/40"
        placeholder="Type your thesis title..."
      />
      <div class="mt-3 flex flex-wrap gap-2">
        <button
          v-for="(ex, i) in examples"
          :key="ex"
          type="button"
          class="rounded-full border px-3 py-1 text-xs transition-colors hover:border-primary hover:text-primary focus-visible:outline-2 focus-visible:outline-ring"
          :class="title === ex ? 'border-primary bg-primary/10 text-primary' : 'text-muted-foreground'"
          @click="title = ex"
        >
          Example {{ i + 1 }}
        </button>
      </div>
    </div>

    <div class="p-5">
      <p class="mb-3 text-sm text-muted-foreground">
        Closest expertise
      </p>
      <div class="relative">
        <TransitionGroup tag="ul" name="rank" class="relative space-y-3">
          <li v-for="row in top" :key="row.key" class="rank-row">
            <MatchRow :tag="row.tag" :panelist="row.panelist" :score="hasTitle ? row.score : 0" :cutoff="CUTOFF" />
          </li>
        </TransitionGroup>
        <span class="pointer-events-none absolute -bottom-1 -top-1 w-px bg-accent" :style="{ left: CUTOFF + '%' }" aria-hidden="true" />
      </div>
      <p class="mt-3 text-xs text-muted-foreground">
        The gold line is the {{ CUTOFF }}% cut-off. Weaker matches are never picked.
      </p>
    </div>

    <div class="border-t p-5">
      <p class="mb-3 text-sm text-muted-foreground">
        Assigned panel
      </p>
      <ul class="divide-y">
        <li v-for="(slot, i) in panel" :key="i" class="flex items-center gap-3 py-2 first:pt-0 last:pb-0">
          <span
            class="w-16 shrink-0 rounded-sm px-2 py-0.5 text-center text-xs font-semibold transition-colors duration-500"
            :class="slot.match && slot.role === 'Chair' ? 'bg-accent text-accent-foreground' : 'bg-secondary text-secondary-foreground'"
          >{{ slot.role }}</span>
          <Transition name="swap" mode="out-in">
            <div v-if="slot.match" :key="slot.match.panelist" class="flex min-w-0 flex-1 items-center gap-3">
              <span class="min-w-0 flex-1 truncate text-sm font-medium">{{ slot.match.panelist }}</span>
              <span class="hidden truncate text-xs text-muted-foreground sm:block">{{ slot.match.tag }}</span>
            </div>
            <span v-else key="open" class="flex-1 text-sm text-muted-foreground">Open slot. No strong match yet.</span>
          </Transition>
        </li>
      </ul>
    </div>

    <p class="border-t bg-muted/50 px-5 py-2 text-xs text-muted-foreground">
      Simplified demo with made-up panelists. The real system compares meaning, not just keywords.
    </p>
  </section>
</template>

<style scoped>
.rank-move,
.rank-enter-active,
.rank-leave-active {
  transition: transform 500ms cubic-bezier(0.2, 0.7, 0.2, 1), opacity 300ms ease;
}
.rank-enter-from,
.rank-leave-to {
  opacity: 0;
}
.rank-leave-active {
  position: absolute;
}
.swap-enter-active,
.swap-leave-active {
  transition: opacity 200ms ease, transform 250ms ease;
}
.swap-enter-from {
  opacity: 0;
  transform: translateY(4px);
}
.swap-leave-to {
  opacity: 0;
}
@media (prefers-reduced-motion: reduce) {
  .rank-move,
  .rank-enter-active,
  .rank-leave-active,
  .swap-enter-active,
  .swap-leave-active {
    transition: none;
  }
}
</style>
