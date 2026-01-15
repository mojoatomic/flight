// Test fixture: Should FAIL N2 - $queryRawUnsafe usage
// This file simulates SQL injection vulnerability

import { prisma } from '@/lib/prisma'

export async function getUserById(userId: string) {
  // BAD: SQL injection vulnerability
  const user = await prisma.$queryRawUnsafe(
    `SELECT * FROM users WHERE id = '${userId}'`
  )

  return user
}

export async function deletePost(postId: string) {
  // BAD: Another SQL injection vulnerability
  await prisma.$executeRawUnsafe(
    `DELETE FROM posts WHERE id = ${postId}`
  )
}
