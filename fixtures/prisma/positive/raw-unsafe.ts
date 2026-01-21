// Prisma test fixture - SHOULD trigger N2 violations
// These are SQL injection vulnerabilities

import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

// BAD: Using $queryRawUnsafe with user input
export async function getUser(userId: string) {
  return prisma.$queryRawUnsafe(`SELECT * FROM users WHERE id = '${userId}'`)
}

// BAD: Using $executeRawUnsafe with user input
export async function deleteUser(userId: string) {
  return prisma.$executeRawUnsafe(`DELETE FROM users WHERE id = '${userId}'`)
}

// BAD: Even with template literal, this is unsafe
export async function searchUsers(query: string) {
  const result = await prisma.$queryRawUnsafe(
    `SELECT * FROM users WHERE name LIKE '%${query}%'`
  )
  return result
}
