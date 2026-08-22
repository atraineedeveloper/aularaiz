import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';

extension StudentRecordLocalization on AppLocalizations {
  bool get _recordEnglish => localeName.startsWith('en');

  String get studentRecordTitle =>
      _recordEnglish ? 'Student record' : 'Expediente';
  String get pedagogicalProfile =>
      _recordEnglish ? 'Pedagogical profile' : 'Perfil pedagógico';
  String get strengths => _recordEnglish ? 'Strengths' : 'Fortalezas';
  String get difficulties => _recordEnglish ? 'Difficulties' : 'Dificultades';
  String get supports => _recordEnglish ? 'Supports' : 'Apoyos';
  String get saveProfile => _recordEnglish ? 'Save profile' : 'Guardar perfil';
  String get profileSaveError => _recordEnglish
      ? 'The pedagogical profile could not be saved.'
      : 'No se pudo guardar el perfil pedagógico.';
  String get recordTimeline => _recordEnglish ? 'Timeline' : 'Historial';
  String get addRecordEntry =>
      _recordEnglish ? 'Add entry' : 'Agregar registro';
  String get entryText => _recordEnglish ? 'Notes' : 'Contenido';
  String get noRecordEntries => _recordEnglish
      ? 'There are no chronological entries yet.'
      : 'Aún no hay registros cronológicos.';
  String get recordEvidence =>
      _recordEnglish ? 'Formative evidence' : 'Evidencias formativas';
  String get totalEvidence =>
      _recordEnglish ? 'Total evidence' : 'Evidencias totales';
  String get requiresSupportEvidence =>
      _recordEnglish ? 'Requires support' : 'Requiere apoyo';
  String get masteredEvidence => _recordEnglish ? 'Mastered' : 'Domina';
  String get addEntryError => _recordEnglish
      ? 'The entry could not be saved.'
      : 'No se pudo guardar el registro.';

  String recordEntryKindLabel(StudentRecordEntryKind kind) => switch (kind) {
    StudentRecordEntryKind.observation =>
      _recordEnglish ? 'Pedagogical observation' : 'Observación pedagógica',
    StudentRecordEntryKind.familyAgreement =>
      _recordEnglish ? 'Family agreement' : 'Acuerdo con familia/tutor',
  };
}
