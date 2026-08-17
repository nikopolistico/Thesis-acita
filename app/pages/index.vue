<script setup lang="ts">
import {
  ArrowRight,
  Briefcase,
  Building2,
  CalendarClock,
  CalendarX2,
  ClipboardCheck,
  ClockAlert,
  FileSpreadsheet,
  GraduationCap,
  TriangleAlert,
  UserCheck,
  UserX,
  UsersRound,
} from '@lucide/vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'

const painPoints = [
  { icon: CalendarX2, text: 'Overlapping and conflicting defense schedules' },
  { icon: FileSpreadsheet, text: 'Coordination relies on spreadsheets, printed postings, and informal messages' },
  { icon: UserX, text: 'Panel members assigned by availability rather than actual expertise' },
  { icon: ClockAlert, text: 'Topic-evaluator mismatches lead to delays and rescheduling' },
]

const objectives = [
  {
    icon: CalendarClock,
    title: 'Automate Thesis Scheduling',
    description: 'Build a web platform that automates thesis defense scheduling, replacing manual spreadsheets and printed schedules.',
  },
  {
    icon: UsersRound,
    title: 'Expertise-Based Panel Assignment',
    description: 'Integrate automatic panel assignment that matches each thesis title to faculty expertise, not just availability.',
  },
  {
    icon: ClipboardCheck,
    title: 'Evaluate Usability with SUS',
    description: 'Measure the platform’s usability using the System Usability Scale (SUS) to validate it for real users.',
  },
]

const stakeholders = [
  { icon: GraduationCap, title: 'Students', description: 'Receive clear, conflict-free defense schedules communicated well ahead of time.' },
  { icon: UserCheck, title: 'Faculty & Panelists', description: 'Get organized assignments matched to their actual research and technical expertise.' },
  { icon: Briefcase, title: 'Administrators', description: 'Spend far less time manually coordinating schedules and resolving conflicts.' },
  { icon: Building2, title: 'The Institution', description: 'Supports CCIS’s digital transformation with a scalable, data-driven scheduling process.' },
]
</script>

<template>
  <div>
    <header class="border-b">
      <div class="mx-auto flex max-w-6xl items-center justify-between px-4 py-4 sm:px-6">
        <div class="flex items-center gap-2 font-semibold">
          <img src="~/assets/images/logo.png" alt="Caraga State University logo" class="size-8">
          CCIS Thesis Scheduler
        </div>
        <nav class="hidden items-center gap-6 text-sm text-muted-foreground sm:flex">
          <a href="#problem" class="hover:text-foreground">Problem</a>
          <a href="#objectives" class="hover:text-foreground">Objectives</a>
          <a href="#significance" class="hover:text-foreground">Significance</a>
        </nav>
        <div class="flex items-center gap-2">
          <ThemeToggle />
          <Button as-child variant="outline">
            <NuxtLink to="/login">Sign In</NuxtLink>
          </Button>
        </div>
      </div>
    </header>

    <section class="mx-auto max-w-4xl px-4 py-24 text-center sm:px-6 sm:py-32">
      <Badge variant="secondary" class="mb-4">CCIS Thesis Defense System</Badge>
      <h1 class="text-4xl font-bold tracking-tight text-balance sm:text-6xl">
        Automated Thesis Scheduling &amp; Expertise-Matched Panel Assignment
      </h1>
      <p class="mx-auto mt-6 max-w-2xl text-lg text-muted-foreground text-pretty">
        A web platform for the College of Computing and Information Sciences that replaces manual, spreadsheet-driven coordination with automated scheduling and panel assignments matched to faculty expertise.
      </p>
      <div class="mt-10 flex flex-wrap items-center justify-center gap-4">
        <Button as-child size="lg">
          <a href="#objectives">
            See the Objectives
            <ArrowRight class="size-4" />
          </a>
        </Button>
        <Button as-child size="lg" variant="outline">
          <a href="#problem">The Problem</a>
        </Button>
      </div>
    </section>

    <section id="problem" class="border-t bg-muted/40">
      <div class="mx-auto grid max-w-6xl gap-12 px-4 py-20 sm:px-6 lg:grid-cols-2 lg:items-center">
        <div>
          <Badge variant="outline" class="mb-4 gap-1.5">
            <TriangleAlert class="size-3.5 text-destructive" />
            The Problem
          </Badge>
          <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">
            Manual scheduling can't keep up with CCIS thesis defenses
          </h2>
          <p class="mt-4 text-muted-foreground text-pretty">
            CCIS currently schedules thesis defenses manually using spreadsheets, printed schedules, and informal communication. As defenses pile up, this process breaks down into conflicts, overlapping slots, and delays — and panelists often end up assigned by who's free rather than who's the right fit for the topic.
          </p>
        </div>
        <ul class="space-y-4">
          <li v-for="point in painPoints" :key="point.text" class="flex items-start gap-3 rounded-lg border bg-background p-4">
            <component :is="point.icon" class="mt-0.5 size-5 shrink-0 text-destructive" />
            <span class="text-sm sm:text-base">{{ point.text }}</span>
          </li>
        </ul>
      </div>
    </section>

    <section id="objectives" class="mx-auto max-w-6xl px-4 py-20 sm:px-6">
      <div class="mx-auto max-w-2xl text-center">
        <Badge variant="secondary" class="mb-4">Objectives</Badge>
        <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">
          What the platform is built to do
        </h2>
        <p class="mt-4 text-muted-foreground text-pretty">
          Three goals guide the design and evaluation of the system.
        </p>
      </div>
      <div class="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <Card v-for="objective in objectives" :key="objective.title">
          <CardHeader>
            <div class="mb-3 flex size-10 items-center justify-center rounded-lg bg-primary/10">
              <component :is="objective.icon" class="size-5 text-primary" />
            </div>
            <CardTitle>{{ objective.title }}</CardTitle>
            <CardDescription>{{ objective.description }}</CardDescription>
          </CardHeader>
        </Card>
      </div>
    </section>

    <section id="significance" class="border-t bg-muted/40">
      <div class="mx-auto max-w-6xl px-4 py-20 sm:px-6">
        <div class="mx-auto max-w-2xl text-center">
          <Badge variant="secondary" class="mb-4">Significance</Badge>
          <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">
            Built for everyone in the thesis defense process
          </h2>
          <p class="mt-4 text-muted-foreground text-pretty">
            Automating scheduling and panel assignment creates value across the whole department.
          </p>
        </div>
        <div class="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          <Card v-for="person in stakeholders" :key="person.title">
            <CardContent class="pt-4 text-center">
              <div class="mx-auto mb-3 flex size-10 items-center justify-center rounded-lg bg-primary/10">
                <component :is="person.icon" class="size-5 text-primary" />
              </div>
              <CardTitle class="mb-1.5">{{ person.title }}</CardTitle>
              <CardDescription>{{ person.description }}</CardDescription>
            </CardContent>
          </Card>
        </div>
      </div>
    </section>

    <section class="mx-auto max-w-6xl px-4 py-20 sm:px-6">
      <div class="flex flex-col items-center gap-6 rounded-2xl bg-primary px-8 py-16 text-center text-primary-foreground">
        <h2 class="text-3xl font-bold tracking-tight sm:text-4xl">
          Ready to modernize thesis defense scheduling?
        </h2>
        <p class="max-w-xl text-primary-foreground/80 text-pretty">
          Help CCIS move from spreadsheets to a coordinated, expertise-aware scheduling system.
        </p>
        <Button as-child size="lg" variant="secondary">
          <NuxtLink to="/register">
            Get Started
            <ArrowRight class="size-4" />
          </NuxtLink>
        </Button>
      </div>
    </section>

    <footer class="border-t py-8">
      <div class="mx-auto max-w-6xl px-4 text-center text-sm text-muted-foreground sm:px-6">
        &copy; {{ new Date().getFullYear() }} CCIS Thesis Defense Scheduling System
      </div>
    </footer>
  </div>
</template>
