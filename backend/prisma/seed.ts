import bcrypt from 'bcryptjs';
import { prisma } from '../src/config/database';
import { DEFAULT_SYSTEM_CATEGORIES } from '../src/modules/auth/defaultCategories';

export const DEMO_USER_EMAIL = 'demo@spendwise.app';
export const DEMO_USER_PASSWORD = 'DemoPassword123';

async function main() {
  console.log('Seeding SpendWise demo account & system categories...');

  const passwordHash = await bcrypt.hash(DEMO_USER_PASSWORD, 10);

  const demoUser = await prisma.user.upsert({
    where: { email: DEMO_USER_EMAIL },
    update: {
      fullName: 'Aarav Sharma (Demo)',
      isDemoAccount: true,
      currency: 'INR',
    },
    create: {
      email: DEMO_USER_EMAIL,
      passwordHash,
      fullName: 'Aarav Sharma (Demo)',
      isDemoAccount: true,
      currency: 'INR',
    },
  });

  for (const cat of DEFAULT_SYSTEM_CATEGORIES) {
    await prisma.category.upsert({
      where: {
        userId_name_type: {
          userId: demoUser.id,
          name: cat.name,
          type: cat.type,
        },
      },
      update: {
        icon: cat.icon,
        colorHex: cat.colorHex,
        isSystem: true,
      },
      create: {
        userId: demoUser.id,
        name: cat.name,
        type: cat.type,
        icon: cat.icon,
        colorHex: cat.colorHex,
        isSystem: true,
      },
    });
  }

  console.log(`Seeded demo account: ${DEMO_USER_EMAIL} / ${DEMO_USER_PASSWORD}`);
}

main()
  .catch((err) => {
    console.error('Seed failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
