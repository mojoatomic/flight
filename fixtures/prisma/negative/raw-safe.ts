// Prisma test fixture - Should NOT trigger violations
// These are safe patterns using parameterized queries

import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

// GOOD: Using $queryRaw with tagged template (safe)
export async function getUser(userId: string) {
  return prisma.$queryRaw`SELECT * FROM users WHERE id = ${userId}`
}

// GOOD: Using $executeRaw with tagged template (safe)
export async function deleteUser(userId: string) {
  return prisma.$executeRaw`DELETE FROM users WHERE id = ${userId}`
}

// GOOD: Using Prisma's built-in methods (always safe)
export async function findUser(userId: string) {
  return prisma.user.findUnique({
    where: { id: userId }
  })
}

// GOOD: Comments mentioning unsafe methods should not trigger
// Don't use $queryRawUnsafe or $executeRawUnsafe with user input!

// GOOD: String mentions should not trigger
const WARNING = "Never use $queryRawUnsafe with untrusted input"
