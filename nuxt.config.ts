import tailwindcss from '@tailwindcss/vite'

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  modules: [
    '@nuxt/content',
    '@nuxt/image',
  ],
  css: ['~/assets/css/tailwind.css'],
  runtimeConfig: {
    supabaseServiceRoleKey: '',
    hfToken: '',
    public: {
      supabaseUrl: '',
      supabaseAnonKey: '',
    },
  },
  components: {
    dirs: [
      { path: '~/components', extensions: ['vue'] },
    ],
  },
  vite: {
    plugins: [
      tailwindcss(),
    ],
  },
  devtools: { enabled: true },
  compatibilityDate: '2024-04-03',
})