import { PrismaClient } from '@prisma/client';

// N1: Raw query with string interpolation
async function badQuery(userId: string) {
  const prisma = new PrismaClient();
  return prisma.$queryRaw`SELECT * FROM users WHERE id = ${userId}`;
}

// N2: No transaction for multiple writes
async function badWrites() {
  const prisma = new PrismaClient();
  await prisma.user.create({ data: { email: 'a@b.com' } });
  await prisma.post.create({ data: { title: 'test' } });
}
