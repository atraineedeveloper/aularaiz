import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/dashboard/presentation/group_dashboard_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GroupDashboardScreen extends StatefulWidget {
  const GroupDashboardScreen({required this.group, super.key});

  final TeachingGroup group;

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GroupDashboardController>().load(widget.group);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GroupDashboardController>();
    final grades = widget.group.grades.toList()
      ..sort((left, right) => left.number.compareTo(right.number));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_label(context, 'Resumen del grupo', 'Class dashboard')),
            Text(
              widget.group.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _label(context, 'Actualizar', 'Refresh'),
            onPressed: controller.isLoading ? null : controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: controller.isLoading && controller.studentCount == 0
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      widget.group.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    for (final grade in grades)
                                      Chip(label: Text('${grade.number}°')),
                                    if (widget.group.shift?.trim().isNotEmpty ==
                                        true)
                                      Chip(
                                        avatar: const Icon(
                                          Icons.schedule_rounded,
                                          size: 18,
                                        ),
                                        label: Text(widget.group.shift!),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (controller.error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _label(
                                  context,
                                  'No se pudieron cargar todos los indicadores.',
                                  'Some dashboard indicators could not be loaded.',
                                ),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                _MetricCard(
                                  icon: Icons.groups_rounded,
                                  label: _label(
                                    context,
                                    'Alumnos',
                                    'Students',
                                  ),
                                  value: '${controller.studentCount}',
                                  detail: _label(
                                    context,
                                    'matriculados en el grupo',
                                    'enrolled in class',
                                  ),
                                ),
                                _MetricCard(
                                  icon: Icons.fact_check_rounded,
                                  label: _label(
                                    context,
                                    'Asistencia',
                                    'Attendance',
                                  ),
                                  value: _percent(controller.attendanceRate),
                                  detail: controller.attendanceMonth == null
                                      ? _label(
                                          context,
                                          'sin registros todavía',
                                          'no records yet',
                                        )
                                      : _label(
                                          context,
                                          '${controller.recordedAttendanceDays} días registrados',
                                          '${controller.recordedAttendanceDays} recorded days',
                                        ),
                                ),
                                _MetricCard(
                                  icon: Icons.assignment_outlined,
                                  label: _label(
                                    context,
                                    'Actividades',
                                    'Activities',
                                  ),
                                  value: '${controller.activityCount}',
                                  detail: _label(
                                    context,
                                    '${controller.projectCount} proyectos',
                                    '${controller.projectCount} projects',
                                  ),
                                ),
                                _MetricCard(
                                  icon: Icons.task_alt_rounded,
                                  label: _label(
                                    context,
                                    'Entregas',
                                    'Deliveries',
                                  ),
                                  value: _percent(controller.deliveryRate),
                                  detail: controller.deliveryDecisions == 0
                                      ? _label(
                                          context,
                                          'sin decisiones registradas',
                                          'no decisions recorded',
                                        )
                                      : _label(
                                          context,
                                          '${controller.deliveryDecisions} decisiones',
                                          '${controller.deliveryDecisions} decisions',
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _SectionCard(
                              title: _label(
                                context,
                                'Niveles de logro',
                                'Achievement levels',
                              ),
                              subtitle: controller.evaluatedCount == 0
                                  ? _label(
                                      context,
                                      'Todavía no hay actividades evaluadas con nivel de logro.',
                                      'No activities have an achievement level yet.',
                                    )
                                  : _label(
                                      context,
                                      '${controller.evaluatedCount} evaluaciones con nivel registrado.',
                                      '${controller.evaluatedCount} evaluations with an achievement level.',
                                    ),
                              child: Column(
                                children: [
                                  for (final level in AchievementLevel.values)
                                    _AchievementRow(
                                      label: _achievementLabel(context, level),
                                      count:
                                          controller.achievementCounts[level] ??
                                          0,
                                      total: controller.evaluatedCount,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _SectionCard(
                              title: _label(
                                context,
                                'Atención de asistencia',
                                'Attendance attention',
                              ),
                              subtitle: _label(
                                context,
                                'Alumnos por debajo de 80% con al menos 3 días registrados.',
                                'Students below 80% with at least 3 recorded days.',
                              ),
                              child: controller.attendanceRisks.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      child: Text(
                                        controller.attendanceRate == null
                                            ? _label(
                                                context,
                                                'Aún no hay suficiente asistencia registrada.',
                                                'There is not enough attendance data yet.',
                                              )
                                            : _label(
                                                context,
                                                'No hay alumnos bajo ese umbral en el periodo analizado.',
                                                'No students are below that threshold in the analyzed period.',
                                              ),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        for (final risk
                                            in controller.attendanceRisks)
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: CircleAvatar(
                                              child: Text(
                                                '${(risk.attendanceRate * 100).round()}',
                                              ),
                                            ),
                                            title: Text(risk.name),
                                            subtitle: Text(
                                              _label(
                                                context,
                                                '${risk.recordedDays} días registrados',
                                                '${risk.recordedDays} recorded days',
                                              ),
                                            ),
                                            trailing: Text(
                                              '${(risk.attendanceRate * 100).round()}%',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                            if (controller.attendanceMonth != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _label(
                                  context,
                                  'La asistencia usa el mes más reciente con registros: ${MaterialLocalizations.of(context).formatMonthYear(controller.attendanceMonth!)}.',
                                  'Attendance uses the most recent month with records: ${MaterialLocalizations.of(context).formatMonthYear(controller.attendanceMonth!)}.',
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final rate = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 170, child: Text(label)),
          Expanded(child: LinearProgressIndicator(value: rate)),
          const SizedBox(width: 12),
          SizedBox(
            width: 42,
            child: Text('$count', textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

String _percent(double? value) =>
    value == null ? '—' : '${(value * 100).round()}%';

String _achievementLabel(BuildContext context, AchievementLevel level) =>
    switch (level) {
      AchievementLevel.mastered => _label(context, 'Dominado', 'Mastered'),
      AchievementLevel.sufficient =>
        _label(context, 'Suficiente', 'Sufficient'),
      AchievementLevel.inProgress =>
        _label(context, 'En proceso', 'In progress'),
      AchievementLevel.requiresSupport =>
        _label(context, 'Requiere apoyo', 'Requires support'),
    };

String _label(BuildContext context, String es, String en) =>
    Localizations.localeOf(context).languageCode == 'en' ? en : es;
