import 'package:aularaiz/l10n/generated/app_localizations.dart';

extension ReportsLocalization on AppLocalizations {
  bool get _reportsEnglish => localeName.startsWith('en');

  String get reportsTitle => _reportsEnglish ? 'Reports' : 'Reportes';
  String get openReports => _reportsEnglish ? 'Reports' : 'Reportes';
  String get reportsMonth =>
      _reportsEnglish ? 'Report month' : 'Mes del reporte';
  String get reportsPreviousMonth =>
      _reportsEnglish ? 'Previous month' : 'Mes anterior';
  String get reportsNextMonth =>
      _reportsEnglish ? 'Next month' : 'Mes siguiente';
  String get reportsGroupTitle =>
      _reportsEnglish ? 'Group report and export' : 'Reporte y exportación grupal';
  String get reportsGroupDescription => _reportsEnglish
      ? 'Attendance and formative evaluation summary. Export the same monthly data to PDF, CSV, or Excel.'
      : 'Resumen de asistencia y evaluación formativa. Exporta los mismos datos mensuales a PDF, CSV o Excel.';
  String get reportsIndividualTitle =>
      _reportsEnglish ? 'Individual reports' : 'Reportes individuales';
  String get reportsIndividualDescription => _reportsEnglish
      ? 'Generate one PDF for a student in this month.'
      : 'Genera un PDF de un alumno para este mes.';
  String get reportsGeneratePdf =>
      _reportsEnglish ? 'Generate PDF' : 'Generar PDF';
  String get reportsExportCsv => _reportsEnglish ? 'Export CSV' : 'Exportar CSV';
  String get reportsExportXlsx =>
      _reportsEnglish ? 'Export Excel' : 'Exportar Excel';
  String get reportsExportSafeNote => _reportsEnglish
      ? 'CSV neutralizes spreadsheet formulas. XLSX stores imported text as literal text.'
      : 'CSV neutraliza fórmulas de hoja de cálculo. XLSX guarda los textos como texto literal.';
  String get reportsSensitiveTitle => _reportsEnglish
      ? 'Include sensitive follow-up'
      : 'Incluir seguimiento sensible';
  String get reportsSensitiveDescription => _reportsEnglish
      ? 'Adds strengths, difficulties and supports to group exports, plus evaluation observations and chronological follow-up to individual PDFs. Off by default.'
      : 'Agrega fortalezas, dificultades y apoyos a las exportaciones grupales, además de observaciones de evaluación y seguimiento cronológico a los PDF individuales. Está desactivado por defecto.';
  String get reportsSensitiveConfirmTitle => _reportsEnglish
      ? 'Include sensitive information?'
      : '¿Incluir información sensible?';
  String get reportsSensitiveConfirmBody => _reportsEnglish
      ? 'The generated file becomes an external copy outside AulaRaíz control. Only enable this when the destination and recipient are appropriate.'
      : 'El archivo generado se convierte en una copia externa fuera del control de AulaRaíz. Actívalo solo cuando el destino y la persona receptora sean adecuados.';
  String get reportsExternalCopyWarning => _reportsEnglish
      ? 'Saving or sharing creates a new copy outside AulaRaíz control. Sensitive information stays excluded unless you explicitly enable it.'
      : 'Guardar o compartir crea una nueva copia fuera del control de AulaRaíz. La información sensible permanece excluida salvo que la habilites explícitamente.';
  String get reportsNoStudents => _reportsEnglish
      ? 'There are no students with enrollment history for this month.'
      : 'No hay alumnos con historial de inscripción durante este mes.';
  String get reportsPublished => _reportsEnglish
      ? 'File published successfully.'
      : 'Archivo publicado correctamente.';
  String get reportsCancelled =>
      _reportsEnglish ? 'Operation cancelled.' : 'Operación cancelada.';
  String get reportsError => _reportsEnglish
      ? 'The file could not be generated or published.'
      : 'No se pudo generar o publicar el archivo.';
  String get reportsInclude => _reportsEnglish ? 'Include' : 'Incluir';
  String get reportsKeepExcluded =>
      _reportsEnglish ? 'Keep excluded' : 'Mantener excluido';
  String get reportsAttendance => _reportsEnglish ? 'Attendance' : 'Asistencia';
  String get reportsEvaluated => _reportsEnglish ? 'Evaluated' : 'Evaluadas';
  String get reportsDelivered => _reportsEnglish ? 'Delivered' : 'Entregadas';
  String get reportsStudents => _reportsEnglish ? 'students' : 'alumnos';
}
