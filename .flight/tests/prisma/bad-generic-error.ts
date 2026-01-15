// Test fixture: Should FAIL N4 - Generic error handling
// This file catches errors without checking Prisma error codes

import { prisma } from '@/lib/prisma'

export async function createUser(data: { email: string; name: string }) {
  try {
    // This mutation needs specific error handling
    const user = await prisma.user.create({ data })
    return user
  } catch (e) {
    // BAD: Generic error - loses context about what actually failed
    throw new Error('Database error')
  }
}
