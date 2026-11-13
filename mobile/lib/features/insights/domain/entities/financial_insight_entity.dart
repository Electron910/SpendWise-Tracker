class FinancialInsightEntity {
  final String id;
  final String type;
  final String severity; // INFO, POSITIVE, WARNING, CRITICAL
  final String title;
  final String explanation;
  final int metricPaise;
  final int? percentageValue;

  const FinancialInsightEntity({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.explanation,
    required this.metricPaise,
    this.percentageValue,
  });

  factory FinancialInsightEntity.fromJson(Map<String, dynamic> json) {
    return FinancialInsightEntity(
      id: json['id'] as String,
      type: json['type'] as String,
      severity: json['severity'] as String? ?? 'INFO',
      title: json['title'] as String,
      explanation: json['explanation'] as String,
      metricPaise: int.parse(json['metricPaise'].toString()),
      percentageValue: (json['percentageValue'] as num?)?.toInt(),
    );
  }
}
