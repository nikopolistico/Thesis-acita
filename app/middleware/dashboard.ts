export default defineNuxtRouteMiddleware((to) => {
  if (import.meta.server)
    return

  const authUser = useAuthUser()
  const requiredRole = to.meta.role as string | undefined

  if (!authUser.value)
    return navigateTo('/login')

  if (requiredRole && authUser.value.role !== requiredRole)
    return navigateTo('/login')
})
