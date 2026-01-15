// Test fixture: Should FAIL N1 - Queries without orgId
// This file simulates an API route without orgId filtering

import { prisma } from '@/lib/prisma'

export async function GET() {
  // BAD: No orgId filter - should be caught
  const posts = await prisma.post.findMany()

  // BAD: Has where but no orgId
  const published = await prisma.post.findMany({
    where: { published: true }
  })

  return Response.json({ posts, published })
}
