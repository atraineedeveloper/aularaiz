import 'package:aularaiz/l10n/generated/app_localizations.dart';

extension StudentRecordLocalization on AppLocalizations {
  bool get _recordEnglish => localeName.startsWith('en');

  String get studentRecordsTitle =>
      _recordEnglish ? 'Student records' : 'Expedientes';
  String get openStudentRecords =>
      _recordEnglish ? 'Student records' : 'Expedientes';
  String get studentRecordTitle =>
      _recordEnglish ? 'Student record' : 'Expediente del alumno';
  String get studentRecordsEmpty => _recordEnglish
      ? 'There are no students with enrollment history in this group.'
      : 'No hay alumnos con historial de inscripción en este grupo.';
  String get studentRecordProfile =>
      _recordEnglish ? 'Pedagogical profile' : 'Perfil pedagógico';
  String get studentRecordStrengths =>
      _recordEnglish ? 'Strengths' : 'Fortalezas';
  String get studentRecordDifficulties =>
      _recordEnglish ? 'Difficulties' : 'Dificultades';
  String get studentRecordSupports =>
      _recordEnglish ? 'Supports and adjustments' : 'Apoyos y ajustes';
  String get studentRecordSaveProfile =>
      _recordEnglish ? 'Save profile' : 'Guardar perfil';
  String get studentRecordSaveError => _recordEnglish
      ? 'The student record could not be saved.'
      : 'No se pudo guardar el expediente.';
  String get studentRecordTimeline =>
      _recordEnglish ? 'Chronological notes' : 'Línea de tiempo';
  String get studentRecordTimelineEmpty => _recordEnglish
      ? 'No observations or family agreements have been recorded yet.'
      : 'Aún no hay observaciones ni acuerdos con la familia.';
  String get studentRecordAddObservation =>
      _recordEnglish ? 'Add observation' : 'Agregar observación';
  String get studentRecordAddAgreement =>
      _recordEnglish ? 'Add family agreement' : 'Agregar acuerdo familiar';
  String get studentRecordObservation =>
      _recordEnglish ? 'Observation' : 'Observación';
  String get studentRecordFamilyAgreement =>
      _recordEnglish ? 'Family agreement' : 'Acuerdo familiar';
  String get studentRecordEntryText => _recordEnglish ? 'Record' : 'Registro';
  String get studentRecordEntryDate => _recordEnglish ? 'Date' : 'Fecha';
  String get studentRecordEvidence =>
      _recordEnglish ? 'Related evidence' : 'Evidencia relacionada';
  String get studentRecordAttendanceEvidence =>
      _recordEnglish ? 'Attendance this month' : 'Asistencia de este mes';
  String get studentRecordEvaluationEvidence =>
      _recordEnglish ? 'Activity evaluation' : 'Evaluación de actividades';
  String get studentRecordNoAttendanceEvidence => _recordEnglish
      ? 'No attendance records for this student this month.'
      : 'No hay registros de asistencia de este alumno durante este mes.';
  String get studentRecordNoEvaluationEvidence => _recordEnglish
      ? 'No activity evaluations have been recorded for this student.'
      : 'No hay evaluaciones de actividades registradas para este alumno.';
  String get studentRecordPresent => _recordEnglish ? 'Present' : 'Presente';
  String get studentRecordAbsent => _recordEnglish ? 'Absent' : 'Ausente';
  String get studentRecordLate => _recordEnglish ? 'Late' : 'Retardo';
  String get studentRecordJustified =>
      _recordEnglish ? 'Justified absence' : 'Falta justificada';
  String get studentRecordActive => _recordEnglish ? 'Active' : 'Activo';
  String get studentRecordHistorical =>
      _recordEnglish ? 'Historical' : 'Histórico';
  String get studentRecordLoadingError => _recordEnglish
      ? 'The student record could not be loaded.'
      : 'No se pudo cargar el expediente.';
  String get literacyTitle => _recordEnglish ? 'Literacy' : 'Lectoescritura';
  String get literacyLatestAssessment =>
      _recordEnglish ? 'Latest assessment' : 'Última evaluación';
  String get literacyNoAssessment => _recordEnglish
      ? 'No literacy assessment has been recorded.'
      : 'Sin evaluación de lectoescritura registrada';
  String get literacyRegisterLevel =>
      _recordEnglish ? 'Record level' : 'Registrar nivel';
  String get literacyViewHistory =>
      _recordEnglish ? 'View history' : 'Ver historial';
  String get literacyEditAction => _recordEnglish ? 'Edit' : 'Editar';
  String get literacyDeleteAction => _recordEnglish ? 'Delete' : 'Eliminar';
  String get literacyHistory =>
      _recordEnglish ? 'Literacy history' : 'Historial de lectoescritura';
  String get literacyAssessmentDate =>
      _recordEnglish ? 'Assessment date' : 'Fecha de evaluación';
  String get literacyWritingLevel =>
      _recordEnglish ? 'Writing level' : 'Nivel de escritura';
  String get literacyReadingLevel =>
      _recordEnglish ? 'Reading level' : 'Nivel de lectura';
  String get literacyNotes => _recordEnglish ? 'Notes' : 'Observaciones';
  String get literacyNotesOptional =>
      _recordEnglish ? 'Notes (optional)' : 'Observaciones (opcional)';
  String get literacyEdit =>
      _recordEnglish ? 'Edit assessment' : 'Editar evaluación';
  String get literacyDeleteTitle => _recordEnglish
      ? 'Delete this literacy record?'
      : '¿Eliminar este registro de lectoescritura?';
  String get literacyDeleteBody => _recordEnglish
      ? 'This action will delete only this assessment. The student records will not be modified.'
      : 'Esta acción eliminará únicamente esta evaluación. Los demás registros del alumno no se modificarán.';
  String get literacyDeleteError => _recordEnglish
      ? 'The literacy assessment could not be deleted.'
      : 'No se pudo eliminar la evaluación de lectoescritura.';
  String get literacySaveError => _recordEnglish
      ? 'The literacy assessment could not be saved.'
      : 'No se pudo guardar la evaluación de lectoescritura.';
  String get writingPresyllabic =>
      _recordEnglish ? 'Presyllabic' : 'Presilábico';
  String get writingSyllabic => _recordEnglish ? 'Syllabic' : 'Silábico';
  String get writingSyllabicAlphabetic =>
      _recordEnglish ? 'Syllabic-alphabetic' : 'Silábico-alfabético';
  String get writingAlphabetic => _recordEnglish ? 'Alphabetic' : 'Alfabético';
  String get readingDoesNotRead => _recordEnglish ? 'Does not read' : 'No lee';
  String get readingSyllabic => _recordEnglish ? 'Syllabic' : 'Silábico';
  String get readingWordByWord => _recordEnglish ? 'Word by word' : 'Palábrico';
  String get readingSentence => _recordEnglish ? 'Sentence' : 'Oracional';
  String get readingFluent => _recordEnglish ? 'Fluent' : 'Fluido';
}
