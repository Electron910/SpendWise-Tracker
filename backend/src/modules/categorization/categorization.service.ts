import { TransactionType } from '@prisma/client';
import { prisma } from '../../config/database';
import { AppError } from '../../utils/appError';
import { CategoriesService } from '../categories/categories.service';
import { DEFAULT_CATEGORIZATION_RULES } from './defaultRules';

export interface CategorizationResult {
  matched: boolean;
  categoryId: string;
  categoryName: string;
  confidence: number;
  matchedPattern: string | null;
  source: 'USER_CORRECTION' | 'USER_RULE' | 'BUILT_IN_RULE' | 'DEFAULT_FALLBACK';
  explanation: string;
}

export class CategorizationService {
  /**
   * Normalizes merchant and description strings by uppercasing, stripping punctuation,
   * and collapsing repeated whitespace so rules match deterministically.
   */
  static normalizeText(input: string): string {
    return input
        .toUpperCase()
        .replace(/[^A-Z0-9\s]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
  }

  static matchesPattern(normalizedText: string, pattern: string, matchType: string): boolean {
    const normalizedPattern = this.normalizeText(pattern);
    if (!normalizedPattern || !normalizedText) return false;

    if (matchType === 'EXACT') {
      return normalizedText === normalizedPattern;
    }
    if (matchType === 'STARTS_WITH') {
      return normalizedText.startsWith(normalizedPattern);
    }
    return normalizedText.includes(normalizedPattern);
  }

  static async classify(
    userId: string,
    input: {
      merchant?: string | null;
      description?: string | null;
      type: TransactionType;
    },
  ): Promise<CategorizationResult> {
    await CategoriesService.ensureUserCategories(userId);

    const categories = await prisma.category.findMany({
      where: {
        userId,
        type: input.type,
        isDeleted: false,
      },
    });

    const combinedRaw = `${input.merchant ?? ''} ${input.description ?? ''}`.trim();
    const normalizedCombined = this.normalizeText(combinedRaw);
    const normalizedMerchant = this.normalizeText(input.merchant ?? '');

    // 1. Evaluate User-Defined Rules & Learned User Corrections first (highest priority)
    const userRules = await prisma.categorizationRule.findMany({
      where: {
        userId,
        transactionType: input.type,
        isDeleted: false,
      },
      include: { category: true },
      orderBy: [{ isUserCorrection: 'desc' }, { priority: 'desc' }, { updatedAt: 'desc' }],
    });

    for (const rule of userRules) {
      if (
        this.matchesPattern(normalizedMerchant, rule.pattern, rule.matchType) ||
        this.matchesPattern(normalizedCombined, rule.pattern, rule.matchType)
      ) {
        const source = rule.isUserCorrection ? 'USER_CORRECTION' : 'USER_RULE';
        return {
          matched: true,
          categoryId: rule.category.id,
          categoryName: rule.category.name,
          confidence: rule.confidence,
          matchedPattern: rule.pattern,
          source,
          explanation: rule.isUserCorrection
              ? `Matched your learned preference for "${rule.pattern}" -> ${rule.category.name}`
              : `Matched custom rule "${rule.pattern}" -> ${rule.category.name}`,
        };
      }
    }

    // 2. Evaluate Deterministic Built-In Merchant & Keyword Rules
    const builtInCandidates = DEFAULT_CATEGORIZATION_RULES.filter(
      (r) => r.transactionType === input.type,
    ).sort((a, b) => b.priority - a.priority);

    for (const rule of builtInCandidates) {
      if (
        this.matchesPattern(normalizedMerchant, rule.pattern, 'CONTAINS') ||
        this.matchesPattern(normalizedCombined, rule.pattern, 'CONTAINS')
      ) {
        const targetCategory = categories.find(
          (c) => c.name.toLowerCase() === rule.categoryName.toLowerCase(),
        );
        if (targetCategory) {
          return {
            matched: true,
            categoryId: targetCategory.id,
            categoryName: targetCategory.name,
            confidence: rule.confidence,
            matchedPattern: rule.pattern,
            source: 'BUILT_IN_RULE',
            explanation: `Keyword "${rule.pattern}" maps to ${targetCategory.name}`,
          };
        }
      }
    }

    // 3. Fallback to "Other" (or first available category)
    const fallback =
      categories.find((c) => c.name.toLowerCase() === 'other') ?? categories[0];

    return {
      matched: false,
      categoryId: fallback.id,
      categoryName: fallback.name,
      confidence: 40,
      matchedPattern: null,
      source: 'DEFAULT_FALLBACK',
      explanation: `No rule matched; defaulted to ${fallback.name}`,
    };
  }

  static async listUserRules(userId: string) {
    return prisma.categorizationRule.findMany({
      where: { userId, isDeleted: false },
      include: {
        category: {
          select: {
            id: true,
            name: true,
            type: true,
            icon: true,
            colorHex: true,
          },
        },
      },
      orderBy: [{ isUserCorrection: 'desc' }, { priority: 'desc' }, { createdAt: 'desc' }],
    });
  }

  static async upsertRule(
    userId: string,
    input: {
      categoryId: string;
      transactionType: TransactionType;
      pattern: string;
      matchType?: string;
      confidence?: number;
      priority?: number;
      isUserCorrection?: boolean;
    },
  ) {
    const category = await prisma.category.findFirst({
      where: {
        id: input.categoryId,
        userId,
        isDeleted: false,
      },
    });

    if (!category) {
      throw new AppError('Category not found', 404, 'CATEGORY_NOT_FOUND');
    }

    if (category.type !== input.transactionType) {
      throw new AppError(
        `Category "${category.name}" does not match transaction type ${input.transactionType}`,
        400,
        'CATEGORY_TYPE_MISMATCH',
      );
    }

    const normalizedPattern = this.normalizeText(input.pattern);
    if (normalizedPattern.length < 2) {
      throw new AppError('Rule pattern must contain at least 2 alphanumeric characters', 400);
    }

    return prisma.categorizationRule.upsert({
      where: {
        userId_pattern_transactionType: {
          userId,
          pattern: normalizedPattern,
          transactionType: input.transactionType,
        },
      },
      update: {
        categoryId: input.categoryId,
        matchType: input.matchType ?? 'CONTAINS',
        confidence: input.confidence ?? (input.isUserCorrection ? 99 : 95),
        priority: input.priority ?? (input.isUserCorrection ? 250 : 200),
        isUserCorrection: input.isUserCorrection ?? false,
        isDeleted: false,
        deletedAt: null,
        version: { increment: 1 },
      },
      create: {
        userId,
        categoryId: input.categoryId,
        transactionType: input.transactionType,
        pattern: normalizedPattern,
        matchType: input.matchType ?? 'CONTAINS',
        confidence: input.confidence ?? (input.isUserCorrection ? 99 : 95),
        priority: input.priority ?? (input.isUserCorrection ? 250 : 200),
        isUserCorrection: input.isUserCorrection ?? false,
      },
      include: {
        category: {
          select: {
            id: true,
            name: true,
            type: true,
            icon: true,
            colorHex: true,
          },
        },
      },
    });
  }

  static async deleteRule(userId: string, ruleId: string): Promise<void> {
    const existing = await prisma.categorizationRule.findFirst({
      where: { id: ruleId, userId, isDeleted: false },
    });

    if (!existing) {
      throw new AppError('Categorization rule not found', 404, 'RULE_NOT_FOUND');
    }

    await prisma.categorizationRule.update({
      where: { id: ruleId },
      data: {
        isDeleted: true,
        deletedAt: new Date(),
        version: { increment: 1 },
      },
    });
  }
}
