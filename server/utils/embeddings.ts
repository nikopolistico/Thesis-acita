import { pipeline } from '@huggingface/transformers'

type FeatureExtractionPipeline = Awaited<ReturnType<typeof pipeline<'feature-extraction'>>>

let extractorPromise: Promise<FeatureExtractionPipeline> | null = null

function getExtractor() {
  if (!extractorPromise)
    extractorPromise = pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2')
  return extractorPromise
}

/**
 * Embeds text into a 384-dim vector using a local, in-process
 * ONNX build of all-MiniLM-L6-v2 (no external API) — matches the
 * `vector(384)` columns in the DB. The model (~90MB) downloads and
 * caches on disk the first time this runs.
 */
export async function embedText(text: string): Promise<number[]> {
  const extractor = await getExtractor()
  const output = await extractor(text, { pooling: 'mean', normalize: true })
  return Array.from(output.data as Float32Array)
}
