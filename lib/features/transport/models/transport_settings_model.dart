/// School-wide trip rules, set by the administrator.
class TransportSettingsModel {
  /// A trip can start this many minutes before its first planned stop.
  final int opensBeforeMinutes;

  /// ...and no later than this many minutes after its last planned stop.
  final int closesAfterMinutes;

  /// TEST MODE: drivers may start any trip at any time (for demos).
  /// The app still shows what the normal rule would say.
  final bool testMode;

  const TransportSettingsModel({
    this.opensBeforeMinutes = 45,
    this.closesAfterMinutes = 60,
    this.testMode = true,
  });

  factory TransportSettingsModel.fromJson(Map<String, dynamic> json) {
    return TransportSettingsModel(
      opensBeforeMinutes: (json['opensBeforeMinutes'] as num).toInt(),
      closesAfterMinutes: (json['closesAfterMinutes'] as num).toInt(),
      testMode: json['testMode'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    'opensBeforeMinutes': opensBeforeMinutes,
    'closesAfterMinutes': closesAfterMinutes,
    'testMode': testMode,
  };

  TransportSettingsModel copyWith({
    int? opensBeforeMinutes,
    int? closesAfterMinutes,
    bool? testMode,
  }) {
    return TransportSettingsModel(
      opensBeforeMinutes: opensBeforeMinutes ?? this.opensBeforeMinutes,
      closesAfterMinutes: closesAfterMinutes ?? this.closesAfterMinutes,
      testMode: testMode ?? this.testMode,
    );
  }
}
