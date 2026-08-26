interface LoginBody {
  email: string
  password: string
  role: 'student' | 'admin'
}

export default defineEventHandler(async (event) => {
  const body = await readBody<LoginBody>(event)

  if (!body?.email || !body?.password || !body?.role) {
    throw createError({ statusCode: 400, statusMessage: 'Email, password, and role are required' })
  }

  const supabase = useSupabaseAdmin()

  const { data, error } = await supabase.rpc('login_user', {
    p_email: body.email,
    p_password: body.password,
    p_role: body.role,
  })

  if (error) {
    if (error.message?.includes('disabled')) {
      throw createError({ statusCode: 403, statusMessage: error.message })
    }
    throw createError({ statusCode: 401, statusMessage: 'Invalid email or password' })
  }

  return data
})
