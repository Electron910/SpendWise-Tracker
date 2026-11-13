/**
 * SpendWise Financial Precision Utilities
 *
 * RULE: Never use floating-point numbers for monetary calculations.
 * All money is represented in integer minor units (paise: ₹1.00 = 100 paise).
 */

const PAISE_PER_RUPEE = 100n;

/**
 * Parses a decimal string (e.g., "125.50" or "125") or integer paise string/number/bigint
 * into a strict BigInt paise value without using IEEE-754 floating-point math.
 */
export function parseDecimalRupeesToPaise(input: string): bigint {
  const trimmed = input.trim();
  if (!/^\d+(\.\d{1,2})?$/.test(trimmed)) {
    throw new Error(`Invalid monetary decimal string: "${input}"`);
  }
  const [wholePart, fracPart = ''] = trimmed.split('.');
  const paddedFrac = fracPart.padEnd(2, '0');
  const rupees = BigInt(wholePart);
  const paise = BigInt(paddedFrac);
  const total = rupees * PAISE_PER_RUPEE + paise;
  if (total <= 0n) {
    throw new Error('Monetary amount must be greater than zero');
  }
  return total;
}

/**
 * Formats integer paise (BigInt) into a canonical decimal string (e.g. 12550n -> "125.50")
 * using purely integer division and modulo operations.
 */
export function formatPaiseToDecimalString(amountPaise: bigint): string {
  const isNegative = amountPaise < 0n;
  const absPaise = isNegative ? -amountPaise : amountPaise;
  const rupees = absPaise / PAISE_PER_RUPEE;
  const remainder = absPaise % PAISE_PER_RUPEE;
  const fracStr = remainder.toString().padStart(2, '0');
  return `${isNegative ? '-' : ''}${rupees.toString()}.${fracStr}`;
}

/**
 * Computes integer percentage in basis points (1% = 100 bps, 100% = 10000 bps)
 * and rounded whole percentage using pure BigInt arithmetic.
 */
export function calculateUtilizationPercentage(
  spentPaise: bigint,
  budgetPaise: bigint,
): { percentage: number; basisPoints: number } {
  if (budgetPaise <= 0n || spentPaise <= 0n) {
    return { percentage: 0, basisPoints: 0 };
  }
  const basisPointsBig = (spentPaise * 10000n) / budgetPaise;
  const basisPoints = Number(basisPointsBig);
  const percentage = Number((spentPaise * 100n + budgetPaise / 2n) / budgetPaise);
  return { percentage, basisPoints };
}

/**
 * Safely serializes an object containing BigInt fields into JSON-safe strings/numbers.
 */
export function serializeBigInt<T>(data: T): T {
  return JSON.parse(
    JSON.stringify(data, (_key, value) => (typeof value === 'bigint' ? value.toString() : value)),
  ) as T;
}
