enum CompatibilityInsightStrength { strong, moderate, informational }

class CompatibilityInsight {
  const CompatibilityInsight({
    required this.label,
    required this.score,
    required this.description,
    this.category,
    this.type = 'category',
    String? title,
    this.strength = CompatibilityInsightStrength.moderate,
    this.displayPriority = 100,
    this.icon = 'spark',
    this.metadata = const {},
  }) : title = title ?? label;

  final String label;
  final int score;
  final String? category;
  final String type;
  final String title;
  final String description;
  final CompatibilityInsightStrength strength;
  final int displayPriority;
  final String icon;
  final Map<String, Object?> metadata;

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'score': score,
      'category': category,
      'type': type,
      'title': title,
      'description': description,
      'strength': strength.name,
      'displayPriority': displayPriority,
      'icon': icon,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  factory CompatibilityInsight.fromMap(Map<dynamic, dynamic> map) {
    return CompatibilityInsight(
      label: map['label'] as String? ?? map['title'] as String? ?? '',
      score: map['score'] as int? ?? 0,
      category: map['category'] as String?,
      type: map['type'] as String? ?? 'category',
      title: map['title'] as String?,
      description: map['description'] as String? ?? '',
      strength: CompatibilityInsightStrength.values.firstWhere(
        (strength) => strength.name == map['strength'],
        orElse: () => CompatibilityInsightStrength.moderate,
      ),
      displayPriority: map['displayPriority'] as int? ?? 100,
      icon: map['icon'] as String? ?? 'spark',
      metadata: Map<String, Object?>.from(
        map['metadata'] as Map<dynamic, dynamic>? ?? const {},
      ),
    );
  }
}
