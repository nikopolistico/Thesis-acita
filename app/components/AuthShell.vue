<script setup lang="ts">
import { ArrowLeft } from '@lucide/vue'

defineProps<{
  heading: string
  intro: string
  asideTitle: string
  asideText: string
  asideItems: string[]
}>()
</script>

<template>
  <div class="grid min-h-screen lg:grid-cols-[0.9fr_1.1fr]">
    <aside class="hidden flex-col justify-between bg-sidebar p-10 text-sidebar-foreground lg:flex">
      <NuxtLink to="/" class="flex items-center gap-3 font-heading font-semibold">
        <span class="flex size-11 items-center justify-center rounded-full bg-white p-1.5">
          <img src="~/assets/images/logo.png" alt="Caraga State University logo" class="size-full object-contain">
        </span>
        CCIS Panelist Assign
      </NuxtLink>

      <div class="max-w-md">
        <h2 class="font-heading text-4xl font-bold leading-[1.1] text-balance">
          {{ asideTitle }}
        </h2>
        <p class="mt-4 text-sidebar-foreground/75 text-pretty">
          {{ asideText }}
        </p>
        <ul class="mt-8 flex flex-wrap gap-2">
          <li
            v-for="item in asideItems"
            :key="item"
            class="rounded-full border border-sidebar-border bg-sidebar-accent px-3 py-1 text-sm"
          >
            {{ item }}
          </li>
        </ul>
      </div>

      <p class="text-sm text-sidebar-foreground/55">
        College of Computing and Information Sciences, Caraga State University
      </p>
    </aside>

    <main class="relative flex min-h-screen flex-col justify-center px-4 py-20 sm:px-10">
      <NuxtLink
        to="/"
        class="absolute left-4 top-4 inline-flex items-center gap-1.5 text-sm font-medium text-muted-foreground hover:text-foreground sm:left-10 sm:top-6"
      >
        <ArrowLeft class="size-4" />
        Back to home
      </NuxtLink>
      <div class="absolute right-4 top-4 sm:right-10 sm:top-5">
        <ThemeToggle />
      </div>

      <div class="w-full max-w-sm">
        <h1 class="text-3xl font-bold">
          {{ heading }}
        </h1>
        <p class="mt-2 text-muted-foreground">
          {{ intro }}
        </p>
        <div class="mt-8">
          <slot />
        </div>
      </div>
    </main>
  </div>
</template>
