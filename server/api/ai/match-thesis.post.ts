// A candidate is only considered a genuine fit if its expertise tag's
// cosine similarity to the thesis title is at least this close.
const MATCH_THRESHOLD = 0.4

interface RequestBody {
  thesisId: number
  title: string
}

export default defineEventHandler(async (event) => {
  const body = await readBody<RequestBody>(event)

  if (!body?.title?.trim() || !body?.thesisId)
    throw createError({ statusCode: 400, statusMessage: 'thesisId and title are required' })

  const supabase = useSupabaseAdmin()

  // 1+2. The title is the query — embed it.
  const queryEmbedding = await embedText(body.title)

  // Persist it on the thesis row (also makes it available for any
  // future re-matching without re-embedding).
  await supabase.rpc('set_thesis_embedding', { p_thesis_id: body.thesisId, p_embedding: queryEmbedding })

  // 3. Semantic search: retrieve the closest panelist expertise
  // tags across all programs by cosine similarity.
  const { data: candidates, error: matchError } = await supabase.rpc('match_panelist_expertise', {
    p_query_embedding: queryEmbedding,
    p_match_count: 10,
  })
  if (matchError)
    throw createError({ statusCode: 500, statusMessage: matchError.message })

  const candidateList = (candidates ?? []) as Array<{ full_name: string, expertise: string, similarity: number }>
  const isMatch = candidateList.some(c => c.similarity >= MATCH_THRESHOLD)

  const matchedAreas = [...new Set(candidateList.filter(c => c.similarity >= MATCH_THRESHOLD).map(c => c.expertise))]
  const response = isMatch
    ? `Found panelists whose tagged expertise closely matches this topic: ${matchedAreas.join(', ')}.`
    : 'No panelists with closely matching expertise were found yet.'

  // 4. On a good match, fill the panel from the ranked candidates.
  let panel = null
  if (isMatch) {
    const { data: panelData, error: assignError } = await supabase.rpc('auto_assign_panel', {
      p_thesis_id: body.thesisId,
      p_query_embedding: queryEmbedding,
    })
    if (assignError)
      throw createError({ statusCode: 500, statusMessage: assignError.message })
    panel = panelData
  }

  // 5. Everything the student sees.
  return { candidates: candidateList, isMatch, response, panel }
})
