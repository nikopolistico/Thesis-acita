/**
 * Embeds text into a 384-dim vector with all-MiniLM-L6-v2 via the
 * Hugging Face Inference API — matches the `vector(384)` columns in
 * the DB. A local ONNX model can't run on Vercel serverless (read-only
 * disk, size limits, cold starts), so it's called remotely instead.
 */
export async function embedText(text: string): Promise<number[]> {
  const { hfToken } = useRuntimeConfig()
  if (!hfToken)
    throw new Error('NUXT_HF_TOKEN is not set')

  const res = await fetch(
    'https://router.huggingface.co/hf-inference/models/sentence-transformers/all-MiniLM-L6-v2/pipeline/feature-extraction',
    {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${hfToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ inputs: text, options: { wait_for_model: true } }),
    },
  )
  if (!res.ok)
    throw new Error(`Embedding request failed (${res.status}): ${await res.text()}`)

  const vec = (await res.json()) as number[]
  if (!Array.isArray(vec) || vec.length !== 384)
    throw new Error('Unexpected embedding response')

  const norm = Math.hypot(...vec) || 1
  return vec.map(v => v / norm)
}
