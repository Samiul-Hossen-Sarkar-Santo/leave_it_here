class ReflectionCache {
  ReflectionCache({
    required this.breakdownId,
    required this.highlights,
    required this.journalWatermark,
    required this.winsPerBreakdown,
  });

  final String breakdownId;
  final List<String> highlights;
  final String journalWatermark;
  final int winsPerBreakdown;

  Map<String, dynamic> toJson() => {
    'breakdownId': breakdownId,
    'highlights': highlights,
    'journalWatermark': journalWatermark,
    'winsPerBreakdown': winsPerBreakdown,
  };

  factory ReflectionCache.fromJson(Map<String, dynamic> json) {
    return ReflectionCache(
      breakdownId: json['breakdownId'] as String,
      highlights: (json['highlights'] as List<dynamic>).cast<String>(),
      journalWatermark: json['journalWatermark'] as String,
      winsPerBreakdown: json['winsPerBreakdown'] as int,
    );
  }
}
