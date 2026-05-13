import { PrismaClient } from '@prisma/client'
import bcrypt from 'bcryptjs'

const prisma = new PrismaClient()

async function main() {
  // Seed game modes
  const modes = [
    { slug: 'pi',      nameNo: 'Pi',             nameEn: 'Pi Mode',         sortOrder: 0 },
    { slug: 'math',    nameNo: 'Regning',         nameEn: 'Math',            sortOrder: 1 },
    { slug: 'chem',    nameNo: 'Kjemi',           nameEn: 'Chemistry',       sortOrder: 2 },
    { slug: 'geo',     nameNo: 'Geografi',        nameEn: 'Geography',       sortOrder: 3 },
    { slug: 'brain',   nameNo: 'Hjernetrim',      nameEn: 'Brain Training',  sortOrder: 4 },
    { slug: 'science', nameNo: 'Naturvitenskap',  nameEn: 'Science',         sortOrder: 5 },
    { slug: 'history', nameNo: 'Historie',        nameEn: 'History',         sortOrder: 6 },
    { slug: 'physics', nameNo: 'Fysikk',          nameEn: 'Physics',         sortOrder: 7 },
    { slug: 'sport',   nameNo: 'Sport',           nameEn: 'Sports',          sortOrder: 8 },
    { slug: 'grammar', nameNo: 'Grammatikk',      nameEn: 'Grammar',         sortOrder: 9 },
  ]

  for (const mode of modes) {
    await prisma.gameMode.upsert({
      where: { slug: mode.slug },
      update: { name: mode.nameNo, nameNo: mode.nameNo, nameEn: mode.nameEn, sortOrder: mode.sortOrder },
      create: { ...mode, name: mode.nameNo, isActive: true },
    })
  }

  // Seed admin user
  const existing = await prisma.adminUser.findUnique({ where: { username: 'admin' } })
  if (!existing) {
    const passwordHash = await bcrypt.hash('change-me-in-production', 12)
    await prisma.adminUser.create({
      data: { username: 'admin', passwordHash, role: 'admin' },
    })
    console.log('Admin user created — change the password immediately!')
  }

  console.log('Seed complete.')
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
