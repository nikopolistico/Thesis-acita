// One-off: re-embed every expertise tag and thesis title with the
// current provider (run after switching embedding models).
// Usage: node --env-file=.env scripts/reembed.mjs
import { createClient } from '@supabase/supabase-js'

const { NUXT_PUBLIC_SUPABASE_URL, NUXT_SUPABASE_SERVICE_ROLE_KEY, NUXT_GEMINI_API_KEY } = process.env
if (!NUXT_GEMINI_API_KEY)
  throw new Error('NUXT_GEMINI_API_KEY is not set')

const supabase = createClient(NUXT_PUBLIC_SUPABASE_URL, NUXT_SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } })

async function embed(text) {
  const res = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent', {
    method: 'POST',
    headers: { 'x-goog-api-key': NUXT_GEMINI_API_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ content: { parts: [{ text }] }, taskType: 'SEMANTIC_SIMILARITY', outputDimensionality: 384 }),
  })
  if (!res.ok)
    throw new Error(`${res.status}: ${await res.text()}`)
  const vec = (await res.json()).embedding.values
  const norm = Math.hypot(...vec) || 1
  return vec.map(v => v / norm)
}

const { data: tags, error: e1 } = await supabase.from('expertise').select('exs_id, expertise')
if (e1) throw e1
for (const t of tags) {
  const { error } = await supabase.rpc('set_expertise_embedding', { p_exs_id: t.exs_id, p_embedding: await embed(t.expertise) })
  if (error) throw error
}
console.log(`re-embedded ${tags.length} expertise tags`)

const { data: theses, error: e2 } = await supabase.from('thesis').select('thesis_id, title')
if (e2) throw e2
for (const t of theses) {
  const { error } = await supabase.rpc('set_thesis_embedding', { p_thesis_id: t.thesis_id, p_embedding: await embed(t.title) })
  if (error) throw error
}
console.log(`re-embedded ${theses.length} thesis titles`)
