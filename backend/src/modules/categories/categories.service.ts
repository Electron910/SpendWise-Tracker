import { Category, TransactionType } from '@prisma/client';
import { prisma } from '../../config/database';
import { AppError } from '../../utils/appError';
import { DEFAULT_SYSTEM_CATEGORIES } from '../auth/defaultCategories';

export class CategoriesService {
  static async ensureUserCategories(userId: string): Promise<void> {
    const existingCount = await prisma.category.count({
      where: { userId, isDeleted: false },
    });
    if (existingCount === 0) {
      await prisma.category.createMany({
        data: DEFAULT_SYSTEM_CATEGORIES.map((cat) => ({
          userId,
          name: cat.name,
          type: cat.type,
          icon: cat.icon,
          colorHex: cat.colorHex,
          isSystem: true,
        })),
        skipDuplicates: true,
      });
    }
  }

  static async listCategories(userId: string, type?: TransactionType): Promise<Category[]> {
    await this.ensureUserCategories(userId);
    return prisma.category.findMany({
      where: {
        userId,
        isDeleted: false,
        ...(type ? { type } : {}),
      },
      orderBy: [{ isSystem: 'desc' }, { name: 'asc' }],
    });
  }

  static async createCategory(
    userId: string,
    input: {
      id?: string;
      name: string;
      type: TransactionType;
      icon: string;
      colorHex: string;
    },
  ): Promise<Category> {
    const trimmedName = input.name.trim();

    const existing = await prisma.category.findFirst({
      where: {
        userId,
        name: { equals: trimmedName, mode: 'insensitive' },
        type: input.type,
      },
    });

    if (existing && !existing.isDeleted) {
      throw new AppError(
        `A ${input.type.toLowerCase()} category named "${trimmedName}" already exists`,
        409,
        'CATEGORY_ALREADY_EXISTS',
      );
    }

    if (existing && existing.isDeleted) {
      return prisma.category.update({
        where: { id: existing.id },
        data: {
          name: trimmedName,
          icon: input.icon,
          colorHex: input.colorHex.toUpperCase(),
          isDeleted: false,
          deletedAt: null,
          version: { increment: 1 },
        },
      });
    }

    return prisma.category.create({
      data: {
        ...(input.id ? { id: input.id } : {}),
        userId,
        name: trimmedName,
        type: input.type,
        icon: input.icon,
        colorHex: input.colorHex.toUpperCase(),
        isSystem: false,
      },
    });
  }

  static async updateCategory(
    userId: string,
    categoryId: string,
    input: { name?: string; icon?: string; colorHex?: string },
  ): Promise<Category> {
    const category = await prisma.category.findFirst({
      where: { id: categoryId, userId, isDeleted: false },
    });

    if (!category) {
      throw new AppError('Category not found', 404, 'CATEGORY_NOT_FOUND');
    }

    if (input.name && input.name.trim().toLowerCase() !== category.name.toLowerCase()) {
      const duplicate = await prisma.category.findFirst({
        where: {
          userId,
          type: category.type,
          name: { equals: input.name.trim(), mode: 'insensitive' },
          isDeleted: false,
          id: { not: categoryId },
        },
      });
      if (duplicate) {
        throw new AppError(
          'Another category with this name already exists',
          409,
          'CATEGORY_ALREADY_EXISTS',
        );
      }
    }

    return prisma.category.update({
      where: { id: categoryId },
      data: {
        ...(input.name ? { name: input.name.trim() } : {}),
        ...(input.icon ? { icon: input.icon.trim() } : {}),
        ...(input.colorHex ? { colorHex: input.colorHex.toUpperCase() } : {}),
        version: { increment: 1 },
      },
    });
  }

  static async deleteCategory(userId: string, categoryId: string): Promise<void> {
    const category = await prisma.category.findFirst({
      where: { id: categoryId, userId, isDeleted: false },
    });

    if (!category) {
      throw new AppError('Category not found', 404, 'CATEGORY_NOT_FOUND');
    }

    if (category.isSystem) {
      throw new AppError(
        'Default system categories cannot be deleted',
        400,
        'SYSTEM_CATEGORY_PROTECTED',
      );
    }

    const activeTransactions = await prisma.transaction.count({
      where: { userId, categoryId, isDeleted: false },
    });

    if (activeTransactions > 0) {
      throw new AppError(
        'Cannot delete category while it is assigned to active transactions',
        400,
        'CATEGORY_IN_USE',
      );
    }

    await prisma.category.update({
      where: { id: categoryId },
      data: {
        isDeleted: true,
        deletedAt: new Date(),
        version: { increment: 1 },
      },
    });
  }
}
