interface RegisterBody {
  fullName: string
  email: string
  program: string
  password: string
}

export default defineEventHandler(async (event) => {
  const body = await readBody<RegisterBody>(event)

  if (!body?.fullName || !body?.email || !body?.password) {
    throw createError({ statusCode: 400, statusMessage: 'Full name, email, and password are required' })
  }

  if (!body.email.toLowerCase().endsWith('@carsu.edu.ph')) {
    throw createError({ statusCode: 400, statusMessage: 'Students must register using a @carsu.edu.ph email address' })
  }

  const supabase = useSupabaseAdmin()

  const { data, error } = await supabase.rpc('register_student', {
    p_full_name: body.fullName,
    p_email: body.email,
    p_program: body.program || null,
    p_password: body.password,
  })

  if (error) {
    if (error.message?.includes('already registered')) {
      throw createError({ statusCode: 409, statusMessage: 'Email is already registered' })
    }
    throw createError({ statusCode: 500, statusMessage: error.message || 'Failed to create account' })
  }

  return data
})
