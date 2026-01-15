// Test fixture: Should PASS - Queries with orgId
// This file simulates an API route with proper orgId filtering

import { prisma } from '@/lib/prisma'
import { auth } from '@clerk/nextjs/server'

export async function GET() {
  const { orgId } = await auth()
  if (!orgId) throw new Error('No organization')

  // GOOD: Has orgId filter
  const posts = await prisma.post.findMany({
    where: { orgId }
  })

  // GOOD: Has orgId with other filters
  const published = await prisma.post.findMany({
    where: { orgId, published: true }
  })

  return Response.json({ posts, published })
}
