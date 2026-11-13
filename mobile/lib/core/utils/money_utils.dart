/// SpendWise Monetary Precision Utilities (Dart)
///
/// FINANCIAL DATA RULE:
/// Never use Dart `double` for monetary calculations or storage.
/// All money is stored and computed in integer minor units (paise: ₹1.00 = 100 paise).
class MoneyUtils {
  const MoneyUtils._();

  static const int paisePerRupee = 100;

  /// Parses a user-entered rupee string (e.g., "125.50" or "500") into integer paise
  /// without using `double.parse`.
  static int parseRupeesToPaise(String input) {
    final cleaned = input.replaceAll(',', '').replaceAll('₹', '').trim();
    final regex = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!regex.hasMatch(cleaned)) {
      throw FormatException('Invalid monetary amount: "$input"');
    }

    final parts = cleaned.split('.');
    final wholeRupees = int.parse(parts[0]);
    final fracStr = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
    final paisePart = int.parse(fracStr);

    final totalPaise = wholeRupees * paisePerRupee + paisePart;
    if (totalPaise <= 0) {
      throw const FormatException('Amount must be greater than zero');
    }
    return totalPaise;
  }

  /// Safely attempts to parse a rupee string into integer paise, returning null on invalid input.
  static int? tryParseRupeesToPaise(String input) {
    try {
      return parseRupeesToPaise(input);
    } catch (_) {
      return null;
    }
  }

  /// Formats integer paise into Indian Rupee format (e.g., 12550 -> "₹125.50", 15000000 -> "₹1,50,000.00")
  /// using pure integer division and string formatting.
  static String formatPaise(
    int amountPaise, {
    String symbol = '₹',
    bool includeDecimals = true,
  }) {
    final isNegative = amountPaise < 0;
    final absPaise = isNegative ? -amountPaise : amountPaise;
    final rupees = absPaise ~/ paisePerRupee;
    final paise = absPaise % paisePerRupee;

    final formattedRupees = _formatIndianNumberSystem(rupees);
    final sign = isNegative ? '-' : '';

    if (!includeDecimals && paise == 0) {
      return '$sign$symbol$formattedRupees';
    }
    final paiseStr = paise.toString().padLeft(2, '0');
    return '$sign$symbol$formattedRupees.$paiseStr';
  }

  /// Formats a positive integer using the Indian numbering system (e.g., 1234567 -> "12,34,567").
  static String _formatIndianNumberSystem(int number) {
    final digits = number.toString();
    if (digits.length <= 3) {
      return digits;
    }
    final lastThree = digits.substring(digits.length - 3);
    var remaining = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (remaining.length > 2) {
      groups.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      groups.insert(0, remaining);
    }
    return '${groups.join(',')},$lastThree';
  }

  /// Calculates integer utilization percentage (0..100+) using integer math.
  static int calculatePercentage(int numeratorPaise, int denominatorPaise) {
    if (denominatorPaise <= 0 || numeratorPaise <= 0) {
      return 0;
    }
    return ((numeratorPaise * 100) + (denominatorPaise ~/ 2)) ~/ denominatorPaise;
  }
}
