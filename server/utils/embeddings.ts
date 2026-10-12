/**
 * Embeds text into a 384-dim vector with Google's gemini-embedding-001
 * (output truncated to 384 to match the `vector(384)` columns in the
 * DB). Called remotely because a local ONNX model can't run on Vercel
 * serverless.
 */
export async function embedText(text: string): Promise<number[]> {
  const { geminiApiKey } = useRuntimeConfig()
  if (!geminiApiKey)
    throw new Error('NUXT_GEMINI_API_KEY is not set')

  const res = await fetch(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent',
    {
      method: 'POST',
      headers: { 'x-goog-api-key': geminiApiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        content: { parts: [{ text }] },
        taskType: 'SEMANTIC_SIMILARITY',
        outputDimensionality: 384,
      }),
    },
  )
  if (!res.ok)
    throw new Error(`Embedding request failed (${res.status}): ${await res.text()}`)

  const vec = ((await res.json()) as { embedding?: { values?: number[] } }).embedding?.values
  if (!Array.isArray(vec) || vec.length !== 384)
    throw new Error('Unexpected embedding response')

  // Truncated Gemini embeddings aren't unit length; cosine search expects it.
  const norm = Math.hypot(...vec) || 1
  return vec.map(v => v / norm)
}
