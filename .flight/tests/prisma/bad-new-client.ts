// Test fixture: Should FAIL N5 - New PrismaClient per request
// This file creates new client instances in request handlers

import { PrismaClient } from '@prisma/client'

export async function GET() {
  // BAD: Creates new client per request - connection exhaustion
  const prisma = new PrismaClient()

  const users = await prisma.user.findMany()

  return Response.json(users)
}

export async function POST(request: Request) {
  // BAD: Another new client
  const prisma = new PrismaClient()

  const data = await request.json()
  const user = await prisma.user.create({ data })

  return Response.json(user)
}
