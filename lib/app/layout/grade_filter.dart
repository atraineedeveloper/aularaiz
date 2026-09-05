import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:flutter/material.dart';

class GradeFilter extends StatelessWidget {
  const GradeFilter({
    required this.grades,
    required this.selected,
    required this.grouped,
    required this.onGrade,
    required this.onGrouped,
    this.showGrouping = true,
    super.key,
  });
  final List<PrimaryGrade> grades;
  final PrimaryGrade? selected;
  final bool grouped;
  final ValueChanged<PrimaryGrade?> onGrade;
  final ValueChanged<bool> onGrouped;
  final bool showGrouping;

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 190,
          child: DropdownButton<int>(
            isExpanded: true,
            value: selected?.number ?? 0,
            items: [
              DropdownMenuItem(
                value: 0,
                child: Text(es ? 'Todos los grados' : 'All grades'),
              ),
              for (final grade in grades)
                DropdownMenuItem(
                  value: grade.number,
                  child: Text(
                    es ? '${grade.number}.º grado' : 'Grade ${grade.number}',
                  ),
                ),
            ],
            onChanged: (value) => onGrade(
              value == null || value == 0
                  ? null
                  : grades.firstWhere((g) => g.number == value),
            ),
          ),
        ),
        if (showGrouping)
          FilterChip(
            label: Text(es ? 'Agrupar por grado' : 'Group by grade'),
            selected: grouped,
            onSelected: onGrouped,
          ),
      ],
    );
  }
}
