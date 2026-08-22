import 'package:aularaiz/domain/education/primary_grade.dart';

final class ActivityParticipant {
  ActivityParticipant({required this.studentId, required this.grade}) {
    if (studentId.trim().isEmpty) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Activity participant id cannot be empty.',
      );
    }
  }

  final String studentId;
  final PrimaryGrade grade;
}
