<script setup lang="ts">
import { useIntersectionObserver, useWindowScroll } from '@vueuse/core'
import { Button } from '@/components/ui/button'

const { y } = useWindowScroll()
const scrolled = computed(() => y.value > 8)

const steps = [
  {
    title: 'Submit your thesis',
    text: 'Enter your title, a link to your document and your adviser. You can edit them later.',
  },
  {
    title: 'Your title meets panelist expertise',
    text: 'Each panelist has expertise tags. The system scores how close every tag is to your title.',
  },
  {
    title: 'The panel fills itself',
    text: 'The best matches become chair and members. Your adviser is never picked, and weak matches are skipped.',
  },
]

const stepsEl = ref<HTMLElement | null>(null)
const stepsVisible = ref(false)
useIntersectionObserver(stepsEl, ([entry]) => {
  if (entry?.isIntersecting)
    stepsVisible.value = true
}, { threshold: 0.35 })

const audiences = [
  {
    key: 'student',
    label: 'Students',
    points: [
      'Register with your @carsu.edu.ph email.',
      'Submit or update your title, link and adviser.',
      'See your chair and members as soon as matching finishes.',
      'Change your title and the panel is matched again.',
    ],
  },
  {
    key: 'admin',
    label: 'Chairpersons',
    points: [
      'See every student in your program and who has submitted.',
      'Register panelists and tag their areas of expertise.',
      'Each new tag is embedded right away, so it counts in the next match.',
      'Keep tags specific. Better tags give better matches.',
    ],
  },
]
const audience = ref(audiences[0].key)
const current = computed(() => audiences.find(a => a.key === audience.value) ?? audiences[0])
</script>

<template>
  <div>
    <header
      class="sticky top-0 z-30 border-b bg-background/85 backdrop-blur transition-colors duration-300"
      :class="scrolled ? 'border-border' : 'border-transparent'"
    >
      <div class="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3 sm:px-6">
        <NuxtLink to="/" class="flex items-center gap-2.5 font-heading font-semibold">
          <img src="~/assets/images/logo.png" alt="Caraga State University logo" class="size-8">
          CCIS Panelist Assign
        </NuxtLink>
        <nav class="hidden items-center gap-6 text-sm text-muted-foreground md:flex" aria-label="Sections">
          <a href="#try" class="transition-colors hover:text-foreground">Try it</a>
          <a href="#how" class="transition-colors hover:text-foreground">How it works</a>
          <a href="#who" class="transition-colors hover:text-foreground">Who it's for</a>
        </nav>
        <div class="flex items-center gap-2">
          <ThemeToggle />
          <Button as-child variant="ghost" class="hidden sm:inline-flex">
            <NuxtLink to="/login">Sign in</NuxtLink>
          </Button>
          <Button as-child>
            <NuxtLink to="/register">Create account</NuxtLink>
          </Button>
        </div>
      </div>
    </header>

    <section id="try" class="mx-auto grid max-w-6xl gap-12 px-4 py-14 sm:px-6 sm:py-20 lg:grid-cols-[0.9fr_1.1fr] lg:items-start">
      <div class="lg:sticky lg:top-28">
        <h1 class="max-w-xl text-4xl font-bold leading-[1.05] text-balance sm:text-6xl">
          Your thesis title finds its own panel.
        </h1>
        <p class="mt-6 max-w-lg text-lg text-muted-foreground text-pretty">
          Submit your title and adviser. The system ranks CCIS panelists by how closely their expertise matches your topic, then fills the chair and two member slots for you.
        </p>
        <p class="mt-4 max-w-lg text-muted-foreground text-pretty">
          Type any title on the right to watch it happen.
        </p>
        <div class="mt-8 flex flex-wrap gap-3">
          <Button as-child size="lg">
            <NuxtLink to="/register">Create student account</NuxtLink>
          </Button>
          <Button as-child size="lg" variant="outline">
            <a href="#how">See how it works</a>
          </Button>
        </div>
      </div>

      <LandingMatcher />
    </section>

    <section id="how" class="border-t bg-card">
      <div class="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-24">
        <h2 class="max-w-xl text-3xl font-bold text-balance sm:text-4xl">
          How a panel gets assigned
        </h2>
        <ol ref="stepsEl" class="relative mt-12 grid gap-x-10 gap-y-10 md:grid-cols-3">
          <!-- progress line draws once when the steps scroll into view -->
          <span class="absolute left-0 right-0 top-0 hidden h-0.5 bg-border md:block" aria-hidden="true" />
          <span
            class="absolute left-0 right-0 top-0 hidden h-0.5 origin-left bg-primary transition-transform duration-[1600ms] ease-out motion-reduce:transition-none md:block"
            :class="stepsVisible ? 'scale-x-100' : 'scale-x-0'"
            aria-hidden="true"
          />
          <li
            v-for="(step, i) in steps"
            :key="step.title"
            class="relative pt-6 transition-[opacity,transform] duration-700 ease-out motion-reduce:transition-none"
            :class="stepsVisible ? 'translate-y-0 opacity-100' : 'translate-y-2 opacity-40'"
            :style="{ transitionDelay: i * 450 + 'ms' }"
          >
            <span
              class="absolute -top-[7px] left-0 size-4 rounded-full border-2 border-primary bg-card transition-colors duration-500"
              :class="stepsVisible && 'bg-primary'"
              :style="{ transitionDelay: i * 450 + 'ms' }"
              aria-hidden="true"
            />
            <p class="font-heading text-sm font-semibold text-primary">
              Step {{ i + 1 }}
            </p>
            <h3 class="mt-1 text-xl font-semibold text-balance">
              {{ step.title }}
            </h3>
            <p class="mt-2 max-w-sm text-muted-foreground text-pretty">
              {{ step.text }}
            </p>
          </li>
        </ol>
      </div>
    </section>

    <section id="who" class="mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-24">
      <h2 class="max-w-xl text-3xl font-bold text-balance sm:text-4xl">
        What you can do
      </h2>
      <div class="mt-8 inline-flex rounded-md border bg-muted p-1" role="tablist" aria-label="Choose a role">
        <button
          v-for="a in audiences"
          :id="`tab-${a.key}`"
          :key="a.key"
          type="button"
          role="tab"
          :aria-selected="audience === a.key"
          aria-controls="audience-panel"
          class="rounded-sm px-4 py-1.5 text-sm font-medium transition-[background-color,color,box-shadow] duration-200 focus-visible:outline-2 focus-visible:outline-ring"
          :class="audience === a.key ? 'bg-card text-foreground ring-1 ring-border' : 'text-muted-foreground hover:text-foreground'"
          @click="audience = a.key"
        >
          {{ a.label }}
        </button>
      </div>
      <div id="audience-panel" role="tabpanel" :aria-labelledby="`tab-${audience}`" class="mt-6 min-h-44">
        <Transition name="fade" mode="out-in">
          <ul :key="audience" class="max-w-xl space-y-3">
            <li v-for="point in current.points" :key="point" class="flex gap-3 text-lg">
              <span class="mt-2.5 size-1.5 shrink-0 rounded-full bg-accent ring-1 ring-primary/30" aria-hidden="true" />
              <span class="text-pretty">{{ point }}</span>
            </li>
          </ul>
        </Transition>
      </div>
    </section>

    <section class="border-t bg-sidebar text-sidebar-foreground">
      <div class="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-6 px-4 py-14 sm:px-6">
        <h2 class="max-w-lg text-3xl font-bold text-balance sm:text-4xl">
          Ready to see who your panel will be?
        </h2>
        <div class="flex flex-wrap gap-3">
          <Button as-child size="lg" class="bg-accent text-accent-foreground hover:bg-accent/90">
            <NuxtLink to="/register">Create student account</NuxtLink>
          </Button>
          <Button as-child size="lg" variant="outline" class="border-sidebar-border bg-transparent text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground">
            <NuxtLink to="/login">Sign in</NuxtLink>
          </Button>
        </div>
      </div>
    </section>

    <footer class="border-t py-8">
      <div class="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-2 px-4 text-sm text-muted-foreground sm:px-6">
        <span>College of Computing and Information Sciences, Caraga State University</span>
        <span>&copy; {{ new Date().getFullYear() }}</span>
      </div>
    </footer>
  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 180ms ease, transform 220ms ease;
}
.fade-enter-from {
  opacity: 0;
  transform: translateY(6px);
}
.fade-leave-to {
  opacity: 0;
}
@media (prefers-reduced-motion: reduce) {
  .fade-enter-active,
  .fade-leave-active {
    transition: none;
  }
}
</style>
