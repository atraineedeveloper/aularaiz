import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/student/student_sex.dart';

enum StudentImportField {
  listNumber,
  givenNames,
  firstSurname,
  secondSurname,
  sex,
  birthDate,
  grade,
}

enum StudentImportIssueSeverity { error, warning }

enum StudentImportIssue {
  missingGivenNames(StudentImportIssueSeverity.error),
  missingFirstSurname(StudentImportIssueSeverity.error),
  invalidSex(StudentImportIssueSeverity.error),
  invalidBirthDate(StudentImportIssueSeverity.error),
  birthDateInFuture(StudentImportIssueSeverity.error),
  missingGrade(StudentImportIssueSeverity.error),
  invalidGrade(StudentImportIssueSeverity.error),
  gradeNotOffered(StudentImportIssueSeverity.error),
  missingListNumber(StudentImportIssueSeverity.error),
  invalidListNumber(StudentImportIssueSeverity.error),
  listNumberAlreadyAssigned(StudentImportIssueSeverity.error),
  duplicateListNumberInFile(StudentImportIssueSeverity.error),
  possibleDuplicateExisting(StudentImportIssueSeverity.warning);

  const StudentImportIssue(this.severity);

  final StudentImportIssueSeverity severity;
}

enum StudentImportFormatProblem {
  unsupportedFile,
  unreadableFile,
  emptyFile,
  noUsableSheet,
}

final class StudentImportFormatException implements Exception {
  const StudentImportFormatException(this.problem);

  final StudentImportFormatProblem problem;

  @override
  String toString() => 'StudentImportFormatException($problem)';
}

final class StudentImportTable {
  StudentImportTable({
    required this.sourceName,
    required List<List<Object?>> rows,
    this.sheetName,
  }) : rows = List<List<Object?>>.unmodifiable(
         rows.map((row) => List<Object?>.unmodifiable(row)),
       );

  final String sourceName;
  final String? sheetName;
  final List<List<Object?>> rows;
}

final class StudentImportMapping {
  StudentImportMapping({
    required this.headerRowIndex,
    required List<String> headers,
    required Map<StudentImportField, int?> columns,
  }) : headers = List<String>.unmodifiable(headers),
       columns = Map<StudentImportField, int?>.unmodifiable(columns);

  final int headerRowIndex;
  final List<String> headers;
  final Map<StudentImportField, int?> columns;

  int? columnFor(StudentImportField field) => columns[field];

  bool get hasRequiredFields =>
      columnFor(StudentImportField.givenNames) != null &&
      columnFor(StudentImportField.firstSurname) != null &&
      columnFor(StudentImportField.grade) != null &&
      columnFor(StudentImportField.listNumber) != null;

  StudentImportMapping withColumn(StudentImportField field, int? column) {
    return StudentImportMapping(
      headerRowIndex: headerRowIndex,
      headers: headers,
      columns: {...columns, field: column},
    );
  }
}

final class StudentImportDraft {
  const StudentImportDraft({
    required this.sourceRow,
    required this.givenNames,
    required this.firstSurname,
    required this.secondSurname,
    required this.sexText,
    required this.birthDateText,
    required this.gradeText,
    required this.listNumberText,
    this.included = true,
  });

  final int sourceRow;
  final String givenNames;
  final String firstSurname;
  final String secondSurname;
  final String sexText;
  final String birthDateText;
  final String gradeText;
  final String listNumberText;
  final bool included;

  StudentImportDraft copyWith({
    String? givenNames,
    String? firstSurname,
    String? secondSurname,
    String? sexText,
    String? birthDateText,
    String? gradeText,
    String? listNumberText,
    bool? included,
  }) {
    return StudentImportDraft(
      sourceRow: sourceRow,
      givenNames: givenNames ?? this.givenNames,
      firstSurname: firstSurname ?? this.firstSurname,
      secondSurname: secondSurname ?? this.secondSurname,
      sexText: sexText ?? this.sexText,
      birthDateText: birthDateText ?? this.birthDateText,
      gradeText: gradeText ?? this.gradeText,
      listNumberText: listNumberText ?? this.listNumberText,
      included: included ?? this.included,
    );
  }
}

final class StudentImportPreviewRow {
  StudentImportPreviewRow({
    required this.draft,
    required this.grade,
    required this.listNumber,
    required this.sex,
    required this.birthDate,
    required Set<StudentImportIssue> issues,
  }) : issues = Set<StudentImportIssue>.unmodifiable(issues);

  final StudentImportDraft draft;
  final PrimaryGrade? grade;
  final int? listNumber;
  final StudentSex? sex;
  final DateTime? birthDate;
  final Set<StudentImportIssue> issues;

  bool get hasErrors =>
      issues.any((issue) => issue.severity == StudentImportIssueSeverity.error);

  bool get hasWarnings => issues.any(
    (issue) => issue.severity == StudentImportIssueSeverity.warning,
  );

  bool get canImport =>
      draft.included && !hasErrors && grade != null && listNumber != null;
}

final class StudentImportPreview {
  StudentImportPreview({
    required this.sourceName,
    required this.sheetName,
    required List<StudentImportPreviewRow> rows,
  }) : rows = List<StudentImportPreviewRow>.unmodifiable(rows);

  final String sourceName;
  final String? sheetName;
  final List<StudentImportPreviewRow> rows;

  int get includedCount => rows.where((row) => row.draft.included).length;

  int get readyCount => rows.where((row) => row.canImport).length;

  int get errorCount =>
      rows.where((row) => row.draft.included && row.hasErrors).length;

  int get warningCount =>
      rows.where((row) => row.draft.included && row.hasWarnings).length;

  bool get canConfirm => includedCount > 0 && errorCount == 0;
}

final class StudentImportCommitRow {
  const StudentImportCommitRow({
    required this.sourceRow,
    required this.givenNames,
    required this.firstSurname,
    required this.secondSurname,
    required this.sex,
    required this.birthDate,
    required this.grade,
    required this.listNumber,
  });

  final int sourceRow;
  final String givenNames;
  final String firstSurname;
  final String? secondSurname;
  final StudentSex? sex;
  final DateTime? birthDate;
  final PrimaryGrade grade;
  final int listNumber;
}

final class StudentImportResult {
  const StudentImportResult({required this.importedCount});

  final int importedCount;
}
