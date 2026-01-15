// Test fixture: Should PASS - Proper error handling
// This file handles specific Prisma error codes

import { prisma } from '@/lib/prisma'
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library'

export async function createUser(data: { email: string; name: string }) {
  try {
    const user = await prisma.user.create({ data })
    return user
  } catch (e) {
    // GOOD: Check specific error codes
    if (e instanceof PrismaClientKnownRequestError) {
      if (e.code === 'P2002') {
        const field = (e.meta?.target as string[])?.[0] ?? 'field'
        throw new Error(`A user with this ${field} already exists`)
      }
      if (e.code === 'P2003') {
        throw new Error('Referenced record does not exist')
      }
    }
    throw e
  }
}

export async function updatePost(id: string, data: { title: string }) {
  try {
    const post = await prisma.post.update({
      where: { id },
      data
    })
    return post
  } catch (e) {
    if (e instanceof PrismaClientKnownRequestError) {
      if (e.code === 'P2025') {
        throw new Error('Post not found')
      }
    }
    throw e
  }
}
