import { createGroq } from '@ai-sdk/groq'
import { generateText, Output } from 'ai'
import { z } from 'zod'

const responseSchema = z.object({
  recommendedExpertise: z.array(z.string()).min(1).max(5)
    .describe('Specific fields of expertise a panelist should have to properly evaluate this thesis'),
  reasoning: z.string().describe('One sentence explaining why these areas fit the thesis topic'),
})

interface RequestBody {
  title: string
  availableExpertise?: string[]
}

export default defineEventHandler(async (event) => {
  const body = await readBody<RequestBody>(event)

  if (!body?.title) {
    throw createError({ statusCode: 400, statusMessage: 'Thesis title is required' })
  }

  const config = useRuntimeConfig()

  if (!config.groqApiKey) {
    throw createError({ statusCode: 500, statusMessage: 'AI recommendations are not configured' })
  }

  const groq = createGroq({ apiKey: config.groqApiKey })

  const availableExpertiseNote = body.availableExpertise?.length
    ? `The expertise areas already registered by panelists in this system are: ${body.availableExpertise.join(', ')}. Prefer recommending from this list when it genuinely fits; only suggest a new area if nothing on the list is a good match.`
    : 'No panelist expertise areas are registered in the system yet, so suggest the most relevant academic/technical fields from scratch.'

  try {
    const result = await generateText({
      model: groq('openai/gpt-oss-120b'),
      output: Output.object({ schema: responseSchema }),
      prompt: `A thesis defense panel needs to be assigned for the thesis titled: "${body.title}".

${availableExpertiseNote}

Recommend which panelist expertise areas are most relevant for evaluating this thesis.`,
    })

    return result.output
  }
  catch (error: any) {
    throw createError({ statusCode: 502, statusMessage: error?.message ?? 'Failed to get an AI recommendation' })
  }
})
