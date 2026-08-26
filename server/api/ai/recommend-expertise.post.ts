import { createGroq } from '@ai-sdk/groq'
import { generateText, Output } from 'ai'
import { z } from 'zod'

const responseSchema = z.object({
  recommendedExpertise: z.array(z.string()).length(5)
    .describe('The top 5 specific fields of expertise most relevant to evaluating and advising this thesis title'),
  reasoning: z.string().describe('One to two sentences explaining why these expertise areas fit the thesis topic'),
})

interface RequestBody {
  title: string
}

export default defineEventHandler(async (event) => {
  const body = await readBody<RequestBody>(event)

  if (!body?.title?.trim()) {
    throw createError({ statusCode: 400, statusMessage: 'Thesis title is required' })
  }

  const config = useRuntimeConfig()

  if (!config.groqApiKey) {
    throw createError({ statusCode: 500, statusMessage: 'AI recommendations are not configured' })
  }

  const groq = createGroq({ apiKey: config.groqApiKey })

  try {
    const result = await generateText({
      model: groq('openai/gpt-oss-120b'),
      output: Output.object({ schema: responseSchema }),
      prompt: `A thesis titled "${body.title}" has just been submitted.

Analyze the topic and recommend the top 5 specific fields of expertise a reader, adviser, or evaluator should have to properly understand and assess this thesis.`,
    })

    return result.output
  }
  catch (error: any) {
    throw createError({ statusCode: 502, statusMessage: error?.message ?? 'Failed to get an AI recommendation' })
  }
})
