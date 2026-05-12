import { PrismaClient } from '@prisma/client'
import bcrypt from 'bcryptjs'

const prisma = new PrismaClient()

async function main() {
  // Seed game modes
  const modes = [
    { slug: 'pi',       name: 'Pi-modus',      sortOrder: 0 },
    { slug: 'math',     name: 'Regning',        sortOrder: 1 },
    { slug: 'chem',     name: 'Kjemi',          sortOrder: 2 },
    { slug: 'geo',      name: 'Geografi',       sortOrder: 3 },
    { slug: 'brain',    name: 'Hjernetrim',     sortOrder: 4 },
    { slug: 'science',  name: 'Naturvitenskap', sortOrder: 5 },
    { slug: 'history',  name: 'Historie',       sortOrder: 6 },
    { slug: 'physics',  name: 'Fysikk',         sortOrder: 7 },
    { slug: 'sport',    name: 'Sport',          sortOrder: 8 },
    { slug: 'grammar',  name: 'Grammatikk',     sortOrder: 9 },
  ]

  for (const mode of modes) {
    await prisma.gameMode.upsert({
      where: { slug: mode.slug },
      update: { name: mode.name, sortOrder: mode.sortOrder },
      create: { ...mode, isActive: true },
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
