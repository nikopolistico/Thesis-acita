<script setup lang="ts">
import {
  ArrowRight,
  Briefcase,
  Building2,
  ClipboardCheck,
  ClockAlert,
  FileSpreadsheet,
  GraduationCap,
  Link as LinkIcon,
  TriangleAlert,
  UploadCloud,
  UserX,
  Users,
} from '@lucide/vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'

const painPoints = [
  { icon: FileSpreadsheet, text: 'Thesis titles, document links, and adviser names scattered across spreadsheets and messages' },
  { icon: UserX, text: 'No single, up-to-date record of who is advising which thesis' },
  { icon: ClockAlert, text: 'Chairperson has to chase students individually to track submission status' },
]

const objectives = [
  {
    icon: UploadCloud,
    title: 'Simple Thesis Submission',
    description: 'Let students register and upload their thesis title, document link, and adviser name in one place.',
  },
  {
    icon: Users,
    title: 'Centralized Chairperson View',
    description: 'Give the chairperson a single dashboard listing every student and their submitted thesis details.',
  },
  {
    icon: ClipboardCheck,
    title: 'Evaluate Usability with SUS',
    description: 'Measure the platform’s usability using the System Usability Scale (SUS) to validate it for real users.',
  },
]

const stakeholders = [
  { icon: GraduationCap, title: 'Students', description: 'Submit their thesis title, link, and adviser once and update it anytime.' },
  { icon: Briefcase, title: 'The Chairperson', description: 'Sees every student’s submission status in one dashboard instead of chasing spreadsheets.' },
  { icon: Building2, title: 'The Institution', description: 'Supports CCIS’s digital transformation with a simple, centralized submission record.' },
]
</script>

<template>
  <div>
    <header class="border-b">
      <div class="mx-auto flex max-w-6xl items-center justify-between px-4 py-4 sm:px-6">
        <div class="flex items-center gap-2 font-semibold">
          <img src="~/assets/images/logo.png" alt="Caraga State University logo" class="size-8">
          CCIS Panelist Automation Assign
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
        Simple Thesis Title, Link &amp; Adviser Submission
      </h1>
      <p class="mx-auto mt-6 max-w-2xl text-lg text-muted-foreground text-pretty">
        A web platform for the College of Computing and Information Sciences where students register and upload their thesis title, document link, and adviser name, and the chairperson tracks every submission in one dashboard.
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
            Thesis submissions shouldn't live in scattered spreadsheets
          </h2>
          <p class="mt-4 text-muted-foreground text-pretty">
            CCIS currently tracks thesis titles, document links, and adviser assignments manually across spreadsheets and informal messages. As submissions pile up, the chairperson has no single, reliable place to see who has submitted what.
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
            Built for students and the chairperson
          </h2>
          <p class="mt-4 text-muted-foreground text-pretty">
            A single, centralized submission record creates value across the whole department.
          </p>
        </div>
        <div class="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
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
          Ready to centralize thesis submissions?
        </h2>
        <p class="max-w-xl text-primary-foreground/80 text-pretty">
          Help CCIS move from scattered spreadsheets to a single, reliable thesis submission record.
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
