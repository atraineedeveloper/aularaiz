import 'package:aularaiz/application/student_import/student_import_models.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';

extension StudentImportLocalization on AppLocalizations {
  bool get _importEnglish => localeName.startsWith('en');

  String get importStudentsTitle =>
      _importEnglish ? 'Import students' : 'Importar alumnos';
  String get importStudentsDescription => _importEnglish
      ? 'Import a CSV or XLSX file, map its columns, review every row, and confirm the batch only when it is ready.'
      : 'Importa un archivo CSV o XLSX, mapea sus columnas, revisa cada fila y confirma el lote solo cuando esté listo.';
  String get importSelectFile =>
      _importEnglish ? 'Select CSV or XLSX' : 'Seleccionar CSV o XLSX';
  String get importChangeFile =>
      _importEnglish ? 'Change file' : 'Cambiar archivo';
  String get importFileHint => _importEnglish
      ? 'The file is read locally. Nothing is imported until final confirmation.'
      : 'El archivo se lee localmente. Nada se importa hasta la confirmación final.';
  String get importMappingTitle =>
      _importEnglish ? 'Column mapping' : 'Mapeo de columnas';
  String get importMappingDescription => _importEnglish
      ? 'AulaRaíz suggests mappings from common headers. Adjust any field that does not match your file.'
      : 'AulaRaíz sugiere el mapeo con encabezados comunes. Ajusta cualquier campo que no coincida con tu archivo.';
  String get importRequiredMapping => _importEnglish
      ? 'Map Names, First surname, Grade, and List number to continue.'
      : 'Mapea Nombres, Primer apellido, Grado y N. de lista para continuar.';
  String get importNotMapped => _importEnglish ? 'Not mapped' : 'Sin mapear';
  String get importPreviewTitle =>
      _importEnglish ? 'Review and correct' : 'Revisar y corregir';
  String get importPreviewDescription => _importEnglish
      ? 'Included rows with errors must be corrected or excluded. Warnings do not block confirmation.'
      : 'Las filas incluidas con errores deben corregirse o excluirse. Las advertencias no bloquean la confirmación.';
  String get importIncluded => _importEnglish ? 'Included' : 'Incluidas';
  String get importReady => _importEnglish ? 'Ready' : 'Listas';
  String get importErrors => _importEnglish ? 'With errors' : 'Con errores';
  String get importWarnings => _importEnglish ? 'Warnings' : 'Advertencias';
  String get importNoRows => _importEnglish
      ? 'No data rows were found below the mapped header.'
      : 'No se encontraron filas de datos debajo del encabezado mapeado.';
  String get importSource => _importEnglish ? 'Source' : 'Origen';
  String get importSheet => _importEnglish ? 'Sheet' : 'Hoja';
  String get importRow => _importEnglish ? 'Row' : 'Fila';
  String get importEditRow => _importEnglish ? 'Edit row' : 'Editar fila';
  String get importIncludeRow => _importEnglish ? 'Include row' : 'Incluir fila';
  String get importConfirmButton =>
      _importEnglish ? 'Import selected rows' : 'Importar filas seleccionadas';
  String get importConfirmTitle =>
      _importEnglish ? 'Confirm atomic import' : 'Confirmar importación atómica';
  String importConfirmBody(int count) => _importEnglish
      ? '$count students will be imported as one transaction. If the batch fails, none of them will be saved.'
      : 'Se importarán $count alumnos en una sola transacción. Si el lote falla, ninguno quedará guardado.';
  String importSuccess(int count) => _importEnglish
      ? '$count students imported successfully.'
      : 'Se importaron $count alumnos correctamente.';
  String get importFailed => _importEnglish
      ? 'The batch could not be imported. Review the preview and try again.'
      : 'No se pudo importar el lote. Revisa la vista previa e inténtalo de nuevo.';
  String get importFileUnsupported => _importEnglish
      ? 'Only .csv and .xlsx files are supported.'
      : 'Solo se admiten archivos .csv y .xlsx.';
  String get importFileUnreadable => _importEnglish
      ? 'The file could not be read.'
      : 'No se pudo leer el archivo.';
  String get importFileEmpty =>
      _importEnglish ? 'The file is empty.' : 'El archivo está vacío.';
  String get importNoUsableSheet => _importEnglish
      ? 'The workbook has no sheet with usable data.'
      : 'El libro no tiene una hoja con datos utilizables.';
  String get importPrivacyNote => _importEnglish
      ? 'Import files can contain personal data. AulaRaíz reads them locally and does not upload them.'
      : 'Los archivos de importación pueden contener datos personales. AulaRaíz los lee localmente y no los sube.';

  String importFieldLabel(StudentImportField field) {
    return switch (field) {
      StudentImportField.listNumber =>
        _importEnglish ? 'List number' : 'N. de lista',
      StudentImportField.givenNames => _importEnglish ? 'Names' : 'Nombres',
      StudentImportField.firstSurname =>
        _importEnglish ? 'First surname' : 'Primer apellido',
      StudentImportField.secondSurname =>
        _importEnglish ? 'Second surname' : 'Segundo apellido',
      StudentImportField.birthDate =>
        _importEnglish ? 'Birth date' : 'Fecha de nacimiento',
      StudentImportField.grade => _importEnglish ? 'Grade' : 'Grado',
    };
  }

  String importIssueLabel(StudentImportIssue issue) {
    return switch (issue) {
      StudentImportIssue.missingGivenNames =>
        _importEnglish ? 'Names are required.' : 'Los nombres son obligatorios.',
      StudentImportIssue.missingFirstSurname => _importEnglish
          ? 'First surname is required.'
          : 'El primer apellido es obligatorio.',
      StudentImportIssue.invalidBirthDate => _importEnglish
          ? 'Birth date is not valid. Use YYYY-MM-DD or DD/MM/YYYY.'
          : 'La fecha de nacimiento no es válida. Usa AAAA-MM-DD o DD/MM/AAAA.',
      StudentImportIssue.birthDateInFuture => _importEnglish
          ? 'Birth date cannot be in the future.'
          : 'La fecha de nacimiento no puede estar en el futuro.',
      StudentImportIssue.missingGrade =>
        _importEnglish ? 'Grade is required.' : 'El grado es obligatorio.',
      StudentImportIssue.invalidGrade => _importEnglish
          ? 'Grade must be from 1 to 6.'
          : 'El grado debe estar entre 1 y 6.',
      StudentImportIssue.gradeNotOffered => _importEnglish
          ? 'This group does not offer that grade.'
          : 'Este grupo no admite ese grado.',
      StudentImportIssue.missingListNumber => _importEnglish
          ? 'List number is required.'
          : 'El número de lista es obligatorio.',
      StudentImportIssue.invalidListNumber => _importEnglish
          ? 'List number must be a positive integer.'
          : 'El número de lista debe ser un entero positivo.',
      StudentImportIssue.listNumberAlreadyAssigned => _importEnglish
          ? 'That list number is already assigned in this group.'
          : 'Ese número de lista ya está asignado en este grupo.',
      StudentImportIssue.duplicateListNumberInFile => _importEnglish
          ? 'This list number is repeated among included rows.'
          : 'Este número de lista se repite entre las filas incluidas.',
      StudentImportIssue.possibleDuplicateExisting => _importEnglish
          ? 'A student with the same identity already exists in this group.'
          : 'Ya existe en el grupo un alumno con la misma identidad.',
    };
  }

  String importFormatProblem(StudentImportFormatProblem problem) {
    return switch (problem) {
      StudentImportFormatProblem.unsupportedFile => importFileUnsupported,
      StudentImportFormatProblem.unreadableFile => importFileUnreadable,
      StudentImportFormatProblem.emptyFile => importFileEmpty,
      StudentImportFormatProblem.noUsableSheet => importNoUsableSheet,
    };
  }
}
