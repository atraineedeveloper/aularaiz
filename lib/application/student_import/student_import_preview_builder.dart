import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/school_year_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/student_import/student_import_models.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/enrollment_policy.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student/student_sex.dart';

final class StudentImportPreviewBuilder {
  StudentImportPreviewBuilder({
    required SchoolYearRepository schoolYearRepository,
    required EnrollmentRepository enrollmentRepository,
    required StudentRepository studentRepository,
  }) : _schoolYearRepository = schoolYearRepository,
       _enrollmentRepository = enrollmentRepository,
       _studentRepository = studentRepository;

  final SchoolYearRepository _schoolYearRepository;
  final EnrollmentRepository _enrollmentRepository;
  final StudentRepository _studentRepository;

  Future<StudentImportPreview> build({
    required TeachingGroup group,
    required String sourceName,
    required String? sheetName,
    required List<StudentImportDraft> drafts,
  }) async {
    final schoolYear = await _schoolYearRepository.findById(group.schoolYearId);
    if (schoolYear == null) {
      throw StateError('School year does not exist.');
    }

    final existingEnrollments = await _enrollmentRepository.findByGroupId(
      group.id,
    );
    final existingStudents = <Student>[];
    final seenStudentIds = <String>{};
    for (final enrollment in existingEnrollments) {
      if (!seenStudentIds.add(enrollment.studentId)) continue;
      final student = await _studentRepository.findById(enrollment.studentId);
      if (student != null) existingStudents.add(student);
    }
    final existingIdentityKeys = existingStudents
        .map(_identityKeyForStudent)
        .toSet();

    final parsed = <_ParsedDraft>[];
    for (final draft in drafts) {
      parsed.add(_parseDraft(draft));
    }

    final includedListNumberCounts = <int, int>{};
    for (final row in parsed) {
      final listNumber = row.listNumber;
      if (!row.draft.included || listNumber == null || listNumber <= 0) {
        continue;
      }
      includedListNumberCounts.update(
        listNumber,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final previewRows = <StudentImportPreviewRow>[];
    for (final row in parsed) {
      final issues = <StudentImportIssue>{...row.issues};
      final grade = row.grade;
      final listNumber = row.listNumber;

      if (grade != null && listNumber != null && listNumber > 0) {
        final candidate = Enrollment(
          id: 'preview-enrollment-${row.draft.sourceRow}',
          studentId: 'preview-student-${row.draft.sourceRow}',
          groupId: group.id,
          grade: grade,
          listNumber: listNumber,
          startsOn: schoolYear.startsOn,
        );
        final violations = EnrollmentPolicy.validate(
          candidate: candidate,
          group: group,
          schoolYear: schoolYear,
          existingStudentEnrollments: const <Enrollment>[],
          existingGroupEnrollments: existingEnrollments,
        );
        if (violations.contains(EnrollmentViolation.gradeNotOffered)) {
          issues.add(StudentImportIssue.gradeNotOffered);
        }
        if (violations.contains(
          EnrollmentViolation.listNumberAlreadyAssigned,
        )) {
          issues.add(StudentImportIssue.listNumberAlreadyAssigned);
        }
      }

      if (row.draft.included &&
          listNumber != null &&
          (includedListNumberCounts[listNumber] ?? 0) > 1) {
        issues.add(StudentImportIssue.duplicateListNumberInFile);
      }

      if (_hasIdentity(row) &&
          existingIdentityKeys.contains(_identityKeyForParsed(row))) {
        issues.add(StudentImportIssue.possibleDuplicateExisting);
      }

      previewRows.add(
        StudentImportPreviewRow(
          draft: row.draft,
          grade: grade,
          listNumber: listNumber,
          sex: row.sex,
          birthDate: row.birthDate,
          issues: issues,
        ),
      );
    }

    return StudentImportPreview(
      sourceName: sourceName,
      sheetName: sheetName,
      rows: previewRows,
    );
  }

  _ParsedDraft _parseDraft(StudentImportDraft draft) {
    final issues = <StudentImportIssue>{};
    final givenNames = draft.givenNames.trim();
    final firstSurname = draft.firstSurname.trim();
    final sexText = draft.sexText.trim();
    final gradeText = draft.gradeText.trim();
    final listNumberText = draft.listNumberText.trim();
    final birthDateText = draft.birthDateText.trim();

    if (givenNames.isEmpty) issues.add(StudentImportIssue.missingGivenNames);
    if (firstSurname.isEmpty) {
      issues.add(StudentImportIssue.missingFirstSurname);
    }

    StudentSex? sex;
    if (sexText.isNotEmpty) {
      sex = _parseSex(sexText);
      if (sex == null) issues.add(StudentImportIssue.invalidSex);
    }

    PrimaryGrade? grade;
    if (gradeText.isEmpty) {
      issues.add(StudentImportIssue.missingGrade);
    } else {
      grade = _parseGrade(gradeText);
      if (grade == null) issues.add(StudentImportIssue.invalidGrade);
    }

    int? listNumber;
    if (listNumberText.isEmpty) {
      issues.add(StudentImportIssue.missingListNumber);
    } else {
      listNumber = int.tryParse(listNumberText);
      if (listNumber == null || listNumber <= 0) {
        issues.add(StudentImportIssue.invalidListNumber);
      }
    }

    DateTime? birthDate;
    if (birthDateText.isNotEmpty) {
      birthDate = _parseDate(birthDateText);
      if (birthDate == null) {
        issues.add(StudentImportIssue.invalidBirthDate);
      } else {
        final today = DateTime.now();
        final normalizedToday = DateTime(today.year, today.month, today.day);
        if (birthDate.isAfter(normalizedToday)) {
          issues.add(StudentImportIssue.birthDateInFuture);
        }
      }
    }

    return _ParsedDraft(
      draft: draft,
      grade: grade,
      listNumber: listNumber,
      sex: sex,
      birthDate: birthDate,
      issues: issues,
    );
  }

  StudentSex? _parseSex(String value) {
    return switch (_normalize(value)) {
      'm' || 'masculino' || 'hombre' || 'male' => StudentSex.male,
      'f' || 'femenino' || 'mujer' || 'female' => StudentSex.female,
      _ => null,
    };
  }

  PrimaryGrade? _parseGrade(String value) {
    final normalized = _normalize(value);
    final numeric = RegExp(r'(^|\s)([1-6])($|\s)').firstMatch(normalized);
    if (numeric != null) {
      return PrimaryGrade.fromNumber(int.parse(numeric.group(2)!));
    }

    const words = <String, int>{
      'primero': 1,
      'primer': 1,
      'first': 1,
      'segundo': 2,
      'second': 2,
      'tercero': 3,
      'tercer': 3,
      'third': 3,
      'cuarto': 4,
      'fourth': 4,
      'quinto': 5,
      'fifth': 5,
      'sexto': 6,
      'sixth': 6,
    };
    for (final entry in words.entries) {
      if (normalized == entry.key || normalized.startsWith('${entry.key} ')) {
        return PrimaryGrade.fromNumber(entry.value);
      }
    }
    return null;
  }

  DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    final iso = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$')
        .firstMatch(trimmed);
    if (iso != null) {
      return _safeDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final dmy = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$')
        .firstMatch(trimmed);
    if (dmy != null) {
      return _safeDate(
        int.parse(dmy.group(3)!),
        int.parse(dmy.group(2)!),
        int.parse(dmy.group(1)!),
      );
    }
    return null;
  }

  DateTime? _safeDate(int year, int month, int day) {
    if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return value;
  }

  bool _hasIdentity(_ParsedDraft row) {
    return row.draft.givenNames.trim().isNotEmpty &&
        row.draft.firstSurname.trim().isNotEmpty;
  }

  String _identityKeyForStudent(Student student) {
    return _identityKey(
      givenNames: student.givenNames,
      firstSurname: student.firstSurname,
      secondSurname: student.secondSurname,
      birthDate: student.birthDate,
    );
  }

  String _identityKeyForParsed(_ParsedDraft row) {
    return _identityKey(
      givenNames: row.draft.givenNames,
      firstSurname: row.draft.firstSurname,
      secondSurname: row.draft.secondSurname,
      birthDate: row.birthDate,
    );
  }

  String _identityKey({
    required String givenNames,
    required String firstSurname,
    required String? secondSurname,
    required DateTime? birthDate,
  }) {
    final birth = birthDate == null
        ? ''
        : '${birthDate.year.toString().padLeft(4, '0')}-'
              '${birthDate.month.toString().padLeft(2, '0')}-'
              '${birthDate.day.toString().padLeft(2, '0')}';
    return '${_normalize(givenNames)}|${_normalize(firstSurname)}|'
        '${_normalize(secondSurname ?? '')}|$birth';
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp('[áàäâã]'), 'a')
        .replaceAll(RegExp('[éèëê]'), 'e')
        .replaceAll(RegExp('[íìïî]'), 'i')
        .replaceAll(RegExp('[óòöôõ]'), 'o')
        .replaceAll(RegExp('[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

final class _ParsedDraft {
  _ParsedDraft({
    required this.draft,
    required this.grade,
    required this.listNumber,
    required this.sex,
    required this.birthDate,
    required this.issues,
  });

  final StudentImportDraft draft;
  final PrimaryGrade? grade;
  final int? listNumber;
  final StudentSex? sex;
  final DateTime? birthDate;
  final Set<StudentImportIssue> issues;
}
