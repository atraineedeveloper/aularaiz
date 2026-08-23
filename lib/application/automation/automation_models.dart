final class AutomationPrivacy {
  const AutomationPrivacy({this.includePersonalData = false});

  final bool includePersonalData;

  Map<String, Object?> toJson() => <String, Object?>{
    'personal_data_included': includePersonalData,
    'mode': includePersonalData ? 'explicit-opt-in' : 'minimized',
  };
}

final class AutomationEnvelope {
  AutomationEnvelope({
    required this.kind,
    required this.privacy,
    required this.data,
    DateTime? generatedAt,
  }) : generatedAt = (generatedAt ?? DateTime.now()).toUtc();

  static const String schema = 'aularaiz.automation/v1';

  final String kind;
  final AutomationPrivacy privacy;
  final Map<String, Object?> data;
  final DateTime generatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    'kind': kind,
    'generated_at': generatedAt.toIso8601String(),
    'privacy': privacy.toJson(),
    'data': data,
  };
}

final class AutomationCapabilityCatalog {
  const AutomationCapabilityCatalog._();

  static const List<Map<String, Object?>> capabilities = <Map<String, Object?>>[
    <String, Object?>{'id': 'status', 'mode': 'read', 'personal_data': false},
    <String, Object?>{'id': 'groups', 'mode': 'read', 'personal_data': false},
    <String, Object?>{
      'id': 'group-summary',
      'mode': 'read',
      'personal_data': 'opt-in',
    },
    <String, Object?>{
      'id': 'recommend',
      'mode': 'read',
      'personal_data': 'opt-in',
    },
    <String, Object?>{
      'id': 'student-note',
      'mode': 'dry-run-default',
      'personal_data': 'opt-in-output',
    },
  ];
}

final class AutomationRecommendation {
  const AutomationRecommendation({
    required this.code,
    required this.message,
    required this.evidence,
    this.targets = const <Map<String, Object?>>[],
  });

  final String code;
  final String message;
  final Map<String, Object?> evidence;
  final List<Map<String, Object?>> targets;

  Map<String, Object?> toJson({required bool includePersonalData}) {
    return <String, Object?>{
      'code': code,
      'message': message,
      'evidence': evidence,
      if (includePersonalData && targets.isNotEmpty) 'targets': targets,
    };
  }
}
