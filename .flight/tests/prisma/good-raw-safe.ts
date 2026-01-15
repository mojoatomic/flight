// Test fixture: Should PASS - Safe raw queries
// This file uses parameterized raw queries

import { prisma } from '@/lib/prisma'

export async function getUserById(userId: string) {
  // GOOD: Parameterized query using tagged template
  const user = await prisma.$queryRaw`
    SELECT * FROM users WHERE id = ${userId}
  `

  return user
}

export async function deletePost(postId: string) {
  // GOOD: Safe parameterized execute
  await prisma.$executeRaw`
    DELETE FROM posts WHERE id = ${postId}
  `
}
