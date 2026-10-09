interface RequestBody {
  panelId: number
  expertise: string
}

export default defineEventHandler(async (event) => {
  const body = await readBody<RequestBody>(event)

  if (!body?.panelId || !body?.expertise?.trim())
    throw createError({ statusCode: 400, statusMessage: 'panelId and expertise are required' })

  const supabase = useSupabaseAdmin()

  const { data: row, error: insertError } = await supabase.rpc('add_panel_expertise', {
    p_panel_id: body.panelId,
    p_expertise: body.expertise,
  })
  if (insertError)
    throw createError({ statusCode: 500, statusMessage: insertError.message })

  try {
    const embedding = await embedText(body.expertise)
    const { error: embedError } = await supabase.rpc('set_expertise_embedding', {
      p_exs_id: row.exs_id,
      p_embedding: embedding,
    })
    if (embedError)
      throw new Error(embedError.message)
  }
  catch (e) {
    // Roll back so an un-embedded tag never lingers unmatched.
    await supabase.rpc('remove_panel_expertise', { p_exs_id: row.exs_id })
    throw createError({ statusCode: 500, statusMessage: e instanceof Error ? e.message : 'Embedding failed' })
  }

  return { ...row, expertise_embedding: null }
})
