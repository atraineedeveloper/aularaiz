/// Formats only the already privacy-filtered envelope, without reading data.
String renderAgentOutput(Map<String, Object?> envelope) {
  final output = StringBuffer();
  final kind = envelope['kind'];
  final data = envelope['data'];
  output.writeln('AulaRaíz · ${_label('$kind')}');
  if (kind == 'help') {
    output.writeln('Uso: aula <comando> [opciones]');
    output.writeln(
      'Salida legible por defecto. Para agentes y scripts: --format json',
    );
    output.writeln(
      'Las modificaciones se simulan; añade --apply para guardarlas.',
    );
    output.writeln('--pretty aplica sangría solo junto con --format json.');
  }
  if (data is Map) {
    if (kind == 'error') {
      output.writeln(
        'Error [${_text(data['code'])}]: ${_text(data['message'])}',
      );
      output.writeln('Consulta aula --help para ver los comandos y opciones.');
    } else {
      if (data['dry_run'] == true) {
        output.writeln('Simulación: no se guardaron cambios.');
      }
      if (data['applied'] == true) output.writeln('Cambio guardado.');
      _writeMap(output, data);
    }
  }
  return output.toString().trimRight();
}

void _writeMap(
  StringBuffer output,
  Map<dynamic, dynamic> values, [
  String indent = '',
]) {
  for (final entry in values.entries) {
    if (entry.key == 'usage') continue;
    final value = entry.value;
    final label = _label('${entry.key}');
    if (value is Map) {
      output.writeln('$indent$label:');
      _writeMap(output, value, '$indent  ');
    } else if (value is List &&
        value.isNotEmpty &&
        value.every((v) => v is Map)) {
      output.writeln('\n$indent$label');
      final rows = value.cast<Map<dynamic, dynamic>>();
      final keys = {for (final row in rows) ...row.keys}.toList();
      // Nested records and wide tables use labeled blocks to preserve every
      // value, including full IDs, without clipping terminal output.
      final cells = [
        keys.map((k) => _label('$k')).toList(),
        for (final row in rows) keys.map((k) => _text(row[k])).toList(),
      ];
      final widths = [
        for (var i = 0; i < keys.length; i++)
          cells.map((r) => r[i].runes.length).reduce((a, b) => a > b ? a : b),
      ];
      final nested = rows.any(
        (r) => r.values.any(
          (v) => v is Map || (v is List && v.any((item) => item is Map)),
        ),
      );
      if (nested || widths.fold<int>(0, (a, b) => a + b + 2) > 100) {
        for (var i = 0; i < rows.length; i++) {
          output.writeln('$indent— ${i + 1} —');
          _writeMap(output, rows[i], '$indent  ');
        }
      } else {
        for (var i = 0; i < cells.length; i++) {
          output.writeln(
            indent +
                [
                  for (var j = 0; j < keys.length; j++)
                    cells[i][j] + ' ' * (widths[j] - cells[i][j].runes.length),
                ].join('  ').trimRight(),
          );
          if (i == 0) {
            output.writeln(indent + widths.map((w) => '-' * w).join('  '));
          }
        }
      }
      output.writeln('$indent${rows.length} registro(s)');
    } else {
      output.writeln('$indent$label: ${_text(value)}');
    }
  }
}

String _text(Object? value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Sí' : 'No';
  if (value is List) {
    return value.isEmpty ? 'Sin registros' : value.map(_text).join(', ');
  }
  return '$value'.replaceAll(RegExp(r'[\x00-\x1f\x7f-\x9f]'), ' ');
}

String _label(String key) =>
    const {
      'help': 'Ayuda',
      'error': 'Error',
      'status': 'Estado',
      'schools': 'Escuelas',
      'groups': 'Grupos',
      'students': 'Alumnos',
      'projects': 'Proyectos',
      'activities': 'Actividades',
      'name': 'Nombre',
      'title': 'Título',
      'id': 'ID',
      'school_id': 'ID escuela',
      'group_id': 'ID grupo',
      'student_id': 'ID alumno',
      'student_count': 'Alumnos',
      'active_count': 'Activos',
      'inactive_count': 'Inactivos',
      'grade': 'Grado',
      'grades': 'Grados',
      'shift': 'Turno',
      'commands': 'Comandos',
      'required': 'Obligatorio',
      'optional': 'Opcional',
      'global_options': 'Opciones generales',
      'database': 'Base de datos',
      'exists': 'Existe',
      'configured': 'Configurada',
      'profile': 'Perfil',
      'dry_run': 'Simulación',
      'applied': 'Aplicado',
    }[key] ??
    _text(key).replaceAll('_', ' ');
