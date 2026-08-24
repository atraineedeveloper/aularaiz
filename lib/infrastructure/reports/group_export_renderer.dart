import 'dart:convert';
import 'dart:typed_data';

import 'package:aularaiz/application/reports/group_export_models.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

enum GroupExportFormat { csv, xlsx }

enum GroupExportDataset {
  context,
  students,
  attendance,
  projects,
  activities,
  evaluation,
  followUp,
}

final class GroupExportRenderer {
  const GroupExportRenderer({required this.english});

  final bool english;

  Uint8List renderCsv(
    GroupExportData data, {
    required GroupExportDataset dataset,
  }) {
    final rows = _datasetRows(data, dataset)
        .map(
          (row) => row
              .map<Object?>(
                (value) => value is String ? _formulaSafe(value) : value,
              )
              .toList(growable: false),
        )
        .toList(growable: false);
    final encoded = const CsvEncoder(
      fieldDelimiter: ',',
      lineDelimiter: '\r\n',
      addBom: true,
    ).convert(rows);
    return Uint8List.fromList(utf8.encode(encoded));
  }

  Uint8List renderXlsx(GroupExportData data) {
    final workbook = Excel.createExcel();
    final contextName = _sheetName(GroupExportDataset.context);
    workbook.rename('Sheet1', contextName);

    final datasets = <GroupExportDataset>[
      GroupExportDataset.context,
      GroupExportDataset.students,
      GroupExportDataset.attendance,
      GroupExportDataset.projects,
      GroupExportDataset.activities,
      GroupExportDataset.evaluation,
      if (data.includeSensitiveFollowUp) GroupExportDataset.followUp,
    ];

    for (final dataset in datasets) {
      final sheet = workbook[_sheetName(dataset)];
      for (final row in _datasetRows(data, dataset)) {
        sheet.appendRow(
          row
              .map<CellValue?>((value) => _cellValue(value))
              .toList(growable: false),
        );
      }
    }
    workbook.setDefaultSheet(contextName);

    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('Could not encode XLSX group export.');
    }
    return Uint8List.fromList(bytes);
  }

  List<List<Object?>> _datasetRows(
    GroupExportData data,
    GroupExportDataset dataset,
  ) {
    return switch (dataset) {
      GroupExportDataset.context => _contextRows(data.context),
      GroupExportDataset.students => _studentRows(data),
      GroupExportDataset.attendance => _attendanceRows(data),
      GroupExportDataset.projects => _projectRows(data),
      GroupExportDataset.activities => _activityRows(data),
      GroupExportDataset.evaluation => _evaluationRows(data),
      GroupExportDataset.followUp => _followUpRows(data),
    };
  }

  List<List<Object?>> _contextRows(GroupExportContextData context) {
    return <List<Object?>>[
      [english ? 'Field' : 'Campo', english ? 'Value' : 'Valor'],
      [english ? 'School' : 'Escuela', context.schoolName],
      ['CCT', context.cct ?? ''],
      [english ? 'State' : 'Entidad', context.state ?? ''],
      [
        english ? 'Municipality' : 'Municipio / alcaldía',
        context.municipality ?? '',
      ],
      [english ? 'Locality' : 'Localidad', context.locality ?? ''],
      [
        english ? 'School organization' : 'Organización escolar',
        _schoolOrganizationLabel(context.schoolOrganization),
      ],
      [english ? 'School year' : 'Ciclo escolar', context.schoolYearLabel],
      [english ? 'Group' : 'Grupo', context.groupName],
      [english ? 'Shift' : 'Turno', context.shift ?? ''],
      [
        english ? 'Grades served' : 'Grados atendidos',
        context.grades.map((grade) => '$grade°').join(', '),
      ],
      [
        english ? 'Modality' : 'Modalidad',
        context.isMultigrade
            ? (english ? 'Multigrade' : 'Multigrado')
            : (english ? 'Single grade' : 'Unigrado'),
      ],
      [
        english ? 'NEM phases' : 'Fases NEM',
        context.phases.map(_phaseLabel).join(', '),
      ],
      [
        english ? 'Entry time' : 'Hora de entrada',
        _timeLabel(context.startsAtMinutes),
      ],
      [
        english ? 'Exit time' : 'Hora de salida',
        _timeLabel(context.endsAtMinutes),
      ],
      [
        english ? 'Reference month' : 'Mes de referencia',
        '${context.referenceMonth.year}-${context.referenceMonth.month.toString().padLeft(2, '0')}',
      ],
    ];
  }

  List<List<Object?>> _studentRows(GroupExportData data) {
    final headers = english
        ? <Object?>[
            'List number',
            'Student',
            'First surname',
            'Second surname',
            'Given names',
            'Grade',
            'Birth date',
            'Age',
            'Sex',
            'Admission date',
            'Withdrawal date',
            'Status',
          ]
        : <Object?>[
            'N. de lista',
            'Alumno',
            'Primer apellido',
            'Segundo apellido',
            'Nombres',
            'Grado',
            'Fecha de nacimiento',
            'Edad',
            'Fecha de ingreso',
            'Sexo',
            'Fecha de baja',
            'Estado',
          ];
    if (!english) {
      final admission = headers.removeAt(8);
      headers.insert(9, admission);
    }
    if (data.includeSensitiveFollowUp) {
      headers.addAll(
        english
            ? ['Strengths', 'Difficulties', 'Supports and adjustments']
            : ['Fortalezas', 'Dificultades', 'Apoyos y ajustes'],
      );
    }

    final rows = <List<Object?>>[headers];
    for (final student in data.students) {
      final values = <Object?>[
        student.listNumber,
        student.displayName,
        student.firstSurname,
        student.secondSurname ?? '',
        student.givenNames,
        student.grade,
        _date(student.birthDate),
        student.age,
        _sexLabel(student.sex),
        _date(student.enrollmentStartsOn),
        _date(student.enrollmentEndsOn),
        student.isActive
            ? (english ? 'Active' : 'Activo')
            : (english ? 'Inactive' : 'Inactivo'),
      ];
      if (data.includeSensitiveFollowUp) {
        values.addAll([
          student.strengths ?? '',
          student.difficulties ?? '',
          student.supports ?? '',
        ]);
      }
      rows.add(values);
    }
    return rows;
  }

  List<List<Object?>> _attendanceRows(GroupExportData data) {
    final rows = <List<Object?>>[
      english
          ? ['Date', 'List number', 'Student', 'Grade', 'Attendance status']
          : ['Fecha', 'N. de lista', 'Alumno', 'Grado', 'Estado de asistencia'],
    ];
    for (final row in data.attendance) {
      rows.add([
        _date(row.date),
        row.listNumber,
        row.studentName,
        row.grade,
        _attendanceStatusLabel(row.status),
      ]);
    }
    return rows;
  }

  List<List<Object?>> _projectRows(GroupExportData data) {
    final rows = <List<Object?>>[
      english
          ? [
              'Project',
              'Lifecycle',
              'NEM methodology',
              'Target grades',
              'Articulating axes',
            ]
          : [
              'Proyecto',
              'Estado',
              'Metodología NEM',
              'Grados destinatarios',
              'Ejes articuladores',
            ],
    ];
    for (final row in data.projects) {
      rows.add([
        row.title,
        _projectLifecycleLabel(row.lifecycle),
        _methodologyLabel(row.methodology),
        row.targetGrades.map((grade) => '$grade°').join(', '),
        row.articulatingAxes.map(_axisLabel).join(', '),
      ]);
    }
    return rows;
  }

  List<List<Object?>> _activityRows(GroupExportData data) {
    final rows = <List<Object?>>[
      english
          ? [
              'Project',
              'Identifier',
              'Activity',
              'Date',
              'Formative field',
              'Target grades',
              'Applicable students',
            ]
          : [
              'Proyecto',
              'Identificador',
              'Actividad',
              'Fecha',
              'Campo formativo',
              'Grados destinatarios',
              'Alumnos aplicables',
            ],
    ];
    for (final row in data.activities) {
      rows.add([
        row.projectTitle,
        row.identifier,
        row.title,
        _date(row.occursOn),
        _formativeFieldLabel(row.formativeField),
        row.targetGrades.map((grade) => '$grade°').join(', '),
        row.participantCount,
      ]);
    }
    return rows;
  }

  List<List<Object?>> _evaluationRows(GroupExportData data) {
    final headers = english
        ? <Object?>[
            'Project',
            'Activity',
            'Date',
            'List number',
            'Student',
            'Grade',
            'Result',
            'Delivery status',
            'Achievement level',
          ]
        : <Object?>[
            'Proyecto',
            'Actividad',
            'Fecha',
            'N. de lista',
            'Alumno',
            'Grado',
            'Resultado',
            'Estado de entrega',
            'Nivel de logro',
          ];
    if (data.includeSensitiveFollowUp) {
      headers.add(english ? 'Observation' : 'Observación');
    }

    final rows = <List<Object?>>[headers];
    for (final row in data.evaluations) {
      final values = <Object?>[
        row.projectTitle,
        '${row.activityIdentifier} · ${row.activityTitle}',
        _date(row.activityDate),
        row.listNumber,
        row.studentName,
        row.grade,
        _evaluationResultLabel(row.resultState, row.achievement),
        _deliveryStatusLabel(row.deliveryStatus),
        _achievementLabel(row.achievement),
      ];
      if (data.includeSensitiveFollowUp) {
        values.add(row.observation ?? '');
      }
      rows.add(values);
    }
    return rows;
  }

  List<List<Object?>> _followUpRows(GroupExportData data) {
    final rows = <List<Object?>>[
      english
          ? ['Date', 'List number', 'Student', 'Grade', 'Type', 'Text']
          : ['Fecha', 'N. de lista', 'Alumno', 'Grado', 'Tipo', 'Texto'],
    ];
    for (final row in data.followUp) {
      rows.add([
        _date(row.occurredAt.toLocal()),
        row.listNumber,
        row.studentName,
        row.grade,
        _followUpKindLabel(row.kind),
        row.text,
      ]);
    }
    return rows;
  }

  String datasetLabel(GroupExportDataset dataset) {
    return switch (dataset) {
      GroupExportDataset.context => english ? 'Context' : 'Contexto',
      GroupExportDataset.students => english ? 'Students' : 'Alumnos',
      GroupExportDataset.attendance => english ? 'Attendance' : 'Asistencia',
      GroupExportDataset.projects => english ? 'Projects' : 'Proyectos',
      GroupExportDataset.activities => english ? 'Activities' : 'Actividades',
      GroupExportDataset.evaluation => english ? 'Evaluation' : 'Evaluación',
      GroupExportDataset.followUp => english ? 'Follow-up' : 'Seguimiento',
    };
  }

  String _sheetName(GroupExportDataset dataset) {
    final label = datasetLabel(dataset);
    return dataset == GroupExportDataset.evaluation && !english
        ? 'Evaluacion'
        : label;
  }

  CellValue? _cellValue(Object? value) {
    return switch (value) {
      final int value => IntCellValue(value),
      final double value => DoubleCellValue(value),
      final String value => TextCellValue(value),
      null => null,
      _ => TextCellValue(value.toString()),
    };
  }

  String _date(DateTime? value) {
    if (value == null) return '';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _timeLabel(int? minutes) {
    if (minutes == null) return '';
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  String _sexLabel(String? value) {
    return switch (value) {
      'male' => english ? 'Male' : 'Masculino',
      'female' => english ? 'Female' : 'Femenino',
      _ => '',
    };
  }

  String _schoolOrganizationLabel(String value) {
    return switch (value) {
      'unitary' => english ? 'One-teacher' : 'Unitaria',
      'twoTeacher' => english ? 'Two-teacher' : 'Bidocente',
      'threeTeacher' => english ? 'Three-teacher' : 'Tridocente',
      'fourTeacher' => english ? 'Four-teacher' : 'Tetradocente',
      'fiveTeacher' => english ? 'Five-teacher' : 'Pentadocente',
      'complete' => english ? 'Complete organization' : 'Organización completa',
      _ => english ? 'Unspecified' : 'Sin especificar',
    };
  }

  String _phaseLabel(String value) {
    return switch (value) {
      'phase3' => english ? 'Phase 3' : 'Fase 3',
      'phase4' => english ? 'Phase 4' : 'Fase 4',
      'phase5' => english ? 'Phase 5' : 'Fase 5',
      _ => value,
    };
  }

  String _attendanceStatusLabel(String value) {
    return switch (value) {
      'present' => english ? 'Present' : 'Presente',
      'absent' => english ? 'Absent' : 'Ausente',
      'late' => english ? 'Late' : 'Retardo',
      'justifiedAbsence' => english ? 'Justified absence' : 'Falta justificada',
      _ => value,
    };
  }

  String _projectLifecycleLabel(String value) {
    return switch (value) {
      'draft' => english ? 'Draft' : 'Borrador',
      'inProgress' => english ? 'In progress' : 'En curso',
      'completed' => english ? 'Completed' : 'Completado',
      _ => value,
    };
  }

  String _methodologyLabel(String value) {
    return switch (value) {
      'communityProjects' =>
        english
            ? 'Community project-based learning'
            : 'Aprendizaje basado en proyectos comunitarios',
      'inquirySteam' =>
        english
            ? 'Inquiry-based STEAM learning'
            : 'Aprendizaje basado en indagación STEAM',
      'problemBasedLearning' =>
        english ? 'Problem-based learning' : 'Aprendizaje basado en problemas',
      'serviceLearning' =>
        english ? 'Service learning' : 'Aprendizaje servicio',
      _ => english ? 'Unspecified' : 'Sin especificar',
    };
  }

  String _axisLabel(String value) {
    return switch (value) {
      'inclusion' => english ? 'Inclusion' : 'Inclusión',
      'criticalThinking' =>
        english ? 'Critical thinking' : 'Pensamiento crítico',
      'criticalInterculturality' =>
        english ? 'Critical interculturality' : 'Interculturalidad crítica',
      'genderEquality' => english ? 'Gender equality' : 'Igualdad de género',
      'healthyLife' => english ? 'Healthy life' : 'Vida saludable',
      'culturesThroughReadingAndWriting' =>
        english ? 'Cultures through reading and writing' : 'Apropiación de las culturas a través de la lectura y la escritura',
      'artsAndAestheticExperiences' =>
        english
            ? 'Arts and aesthetic experiences'
            : 'Artes y experiencias estéticas',
      _ => value,
    };
  }

  String _formativeFieldLabel(String value) {
    return switch (value) {
      'languages' => english ? 'Languages' : 'Lenguajes',
      'knowledgeAndScientificThought' =>
        english
            ? 'Knowledge and scientific thought'
            : 'Saberes y pensamiento científico',
      'ethicsNatureAndSocieties' =>
        english
            ? 'Ethics, nature and societies'
            : 'Ética, naturaleza y sociedades',
      'humanAndCommunity' =>
        english ? 'Human and community' : 'De lo humano y lo comunitario',
      _ => english ? 'Unspecified' : 'Sin especificar',
    };
  }

  String _deliveryStatusLabel(String value) {
    return switch (value) {
      'pending' => english ? 'Pending' : 'Pendiente',
      'delivered' => english ? 'Delivered' : 'Entregada',
      'notDelivered' => english ? 'Not delivered' : 'No entregada',
      _ => value,
    };
  }

  String _achievementLabel(String? value) {
    return switch (value) {
      'mastered' => english ? 'Mastered' : 'Domina',
      'sufficient' => english ? 'Sufficient' : 'Suficiente',
      'inProgress' => english ? 'In progress' : 'En proceso',
      'requiresSupport' => english ? 'Requires support' : 'Requiere apoyo',
      _ => '',
    };
  }

  String _evaluationResultLabel(String state, String? achievement) {
    if (state == 'deliveredAndEvaluated' && achievement != null) {
      return _achievementLabel(achievement);
    }
    return switch (state) {
      'pendingDeliveryDecision' => english ? 'Pending' : 'Pendiente',
      'deliveredAwaitingEvaluation' =>
        english
            ? 'Delivered, awaiting evaluation'
            : 'Entregada, pendiente de evaluar',
      'notDelivered' => english ? 'Not delivered' : 'No entregada',
      'deliveredAndEvaluated' => english ? 'Evaluated' : 'Evaluada',
      _ => state,
    };
  }

  String _followUpKindLabel(String value) {
    return switch (value) {
      'observation' => english ? 'Observation' : 'Observación',
      'familyAgreement' => english ? 'Family agreement' : 'Acuerdo familiar',
      _ => value,
    };
  }

  String _formulaSafe(String value) {
    final trimmed = value.trimLeft();
    if (trimmed.isEmpty) return value;
    return switch (trimmed.codeUnitAt(0)) {
      0x3D || 0x2B || 0x2D || 0x40 => "'$value",
      _ => value,
    };
  }
}
