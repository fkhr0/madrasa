class TransportSettingsModel {
  final int opensBeforeMinutes;

  final int closesAfterMinutes;

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
