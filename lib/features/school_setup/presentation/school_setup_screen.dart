import 'package:aularaiz/app/errors/friendly_error_message.dart';
import 'package:aularaiz/core/catalogs/mexico_geography_catalog.dart';
import 'package:aularaiz/core/catalogs/school_shift_catalog.dart';
import 'package:aularaiz/core/catalogs/school_year_catalog.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_leadership_role.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/school/teaching_contract.dart';
import 'package:aularaiz/domain/teacher/teaching_role.dart';
import 'package:aularaiz/features/school_setup/presentation/school_setup_controller.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SchoolSetupScreen extends StatefulWidget {
  const SchoolSetupScreen({required this.onCompleted, super.key});

  final VoidCallback onCompleted;

  @override
  State<SchoolSetupScreen> createState() => _SchoolSetupScreenState();
}

class _SchoolSetupScreenState extends State<SchoolSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _cctController = TextEditingController();
  final _localityController = TextEditingController();
  final _schoolZoneController = TextEditingController();
  final _schoolSectorController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _teacherNameController = TextEditingController();
  final _supervisorNameController = TextEditingController();
  final _leadershipNameController = TextEditingController();

  SchoolOrganization _organization = SchoolOrganization.unspecified;
  String? _stateCode;
  String? _municipality;
  String _shift = SchoolShiftCatalog.unspecified;
  final Set<PrimaryGrade> _grades = {};
  bool _showGradesError = false;
  DateTime? _contractStartsOn;
  DateTime? _contractEndsOn;
  bool _showContractError = false;
  TeachingRole _teachingRole = TeachingRole.teacher;
  SchoolLeadershipRole? _leadershipRole;
  // Tracks the teacher name mirrored into the leadership field so editing
  // the teacher name keeps the prefill in sync without clobbering edits.
  String? _syncedLeadershipName;
  late String _schoolYearLabel =
      SchoolYearCatalog.currentBasicEducation().label;

  SchoolYearPreset get _schoolYear =>
      SchoolYearCatalog.basicEducationOptions.firstWhere(
        (value) => value.label == _schoolYearLabel,
        orElse: SchoolYearCatalog.currentBasicEducation,
      );

  MexicoStateOption? get _selectedState =>
      _stateCode == null ? null : MexicoGeographyCatalog.byCode(_stateCode!);

  @override
  void dispose() {
    _schoolNameController.dispose();
    _cctController.dispose();
    _localityController.dispose();
    _schoolZoneController.dispose();
    _schoolSectorController.dispose();
    _groupNameController.dispose();
    _teacherNameController.dispose();
    _supervisorNameController.dispose();
    _leadershipNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<SchoolSetupController>();
    final selectedState = _selectedState;
    final compact = MediaQuery.sizeOf(context).width < 480;
    final largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;

    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(title: Text(l10n.setupTitle))
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Icon(
                                  Icons.school_outlined,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.setupTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.setupSubtitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _schoolNameController,
                      enabled: !controller.isSaving,
                      decoration: InputDecoration(labelText: l10n.schoolName),
                      textInputAction: TextInputAction.next,
                      validator: (value) => _required(value, l10n),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cctController,
                      enabled: !controller.isSaving,
                      decoration: InputDecoration(labelText: l10n.cct),
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      onChanged: _syncStateFromCct,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<SchoolOrganization>(
                      initialValue: _organization,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.schoolOrganization,
                      ),
                      items: SchoolOrganization.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                _organizationLabel(value, l10n),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: controller.isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _organization = value);
                              }
                            },
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 620;
                        final stateField = DropdownButtonFormField<String>(
                          key: ValueKey('state-${_stateCode ?? 'none'}'),
                          initialValue: _stateCode,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: l10n.state),
                          items: [
                            for (final state in MexicoGeographyCatalog.states)
                              DropdownMenuItem(
                                value: state.code,
                                child: Text(state.name),
                              ),
                          ],
                          onChanged: controller.isSaving
                              ? null
                              : (value) {
                                  setState(() {
                                    _stateCode = value;
                                    _municipality = null;
                                  });
                                },
                          validator: (value) =>
                              value == null ? l10n.requiredField : null,
                        );
                        final municipalityField = DropdownButtonFormField<String>(
                          key: ValueKey(
                            'municipality-${_stateCode ?? 'none'}-${_municipality ?? 'none'}',
                          ),
                          initialValue: _municipality,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.municipality,
                          ),
                          items: [
                            for (final municipality
                                in selectedState?.municipalities ??
                                    const <String>[])
                              DropdownMenuItem(
                                value: municipality,
                                child: Text(municipality),
                              ),
                          ],
                          onChanged:
                              controller.isSaving || selectedState == null
                              ? null
                              : (value) {
                                  setState(() => _municipality = value);
                                },
                          validator: (value) =>
                              value == null ? l10n.requiredField : null,
                        );

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: stateField),
                              const SizedBox(width: 16),
                              Expanded(child: municipalityField),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            stateField,
                            const SizedBox(height: 16),
                            municipalityField,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _localityController,
                      enabled: !controller.isSaving,
                      decoration: InputDecoration(labelText: l10n.locality),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 620;
                        final zoneField = TextFormField(
                          controller: _schoolZoneController,
                          enabled: !controller.isSaving,
                          decoration: InputDecoration(
                            labelText:
                                Localizations.localeOf(context).languageCode ==
                                    'en'
                                ? 'School zone'
                                : 'Zona escolar',
                          ),
                        );
                        final sectorField = TextFormField(
                          controller: _schoolSectorController,
                          enabled: !controller.isSaving,
                          decoration: InputDecoration(
                            labelText:
                                Localizations.localeOf(context).languageCode ==
                                    'en'
                                ? 'School sector'
                                : 'Sector escolar',
                          ),
                        );
                        return wide
                            ? Row(
                                children: [
                                  Expanded(child: zoneField),
                                  const SizedBox(width: 16),
                                  Expanded(child: sectorField),
                                ],
                              )
                            : Column(
                                children: [
                                  zoneField,
                                  const SizedBox(height: 16),
                                  sectorField,
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _schoolYearLabel,
                      decoration: InputDecoration(labelText: l10n.schoolYear),
                      items: [
                        for (final option
                            in SchoolYearCatalog.basicEducationOptions)
                          DropdownMenuItem(
                            value: option.label,
                            child: Text(option.label),
                          ),
                      ],
                      onChanged: controller.isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _schoolYearLabel = value);
                              }
                            },
                    ),
                    const SizedBox(height: 28),
                    Text(
                      Localizations.localeOf(context).languageCode == 'en'
                          ? 'Your class'
                          : 'Tu grupo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _groupNameController,
                      enabled: !controller.isSaving,
                      decoration: InputDecoration(labelText: l10n.groupName),
                      validator: (value) => _required(value, l10n),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _shift,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.shift),
                      items: [
                        DropdownMenuItem(
                          value: SchoolShiftCatalog.unspecified,
                          child: Text(
                            Localizations.localeOf(context).languageCode == 'en'
                                ? 'Unspecified'
                                : 'Sin especificar',
                          ),
                        ),
                        for (final shift in SchoolShiftCatalog.officialValues)
                          DropdownMenuItem(value: shift, child: Text(shift)),
                      ],
                      onChanged: controller.isSaving
                          ? null
                          : (value) {
                              if (value != null) setState(() => _shift = value);
                            },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.contractDates,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: controller.isSaving
                              ? null
                              : () => _pickContractDate(start: true),
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            '${l10n.contractStartDate}: '
                            '${_contractDateLabel(context, _contractStartsOn)}',
                          ),
                        ),
                        if (_contractStartsOn != null)
                          TextButton(
                            onPressed: controller.isSaving
                                ? null
                                : () => setState(() {
                                    _contractStartsOn = null;
                                    _showContractError = false;
                                  }),
                            child: Text(
                              Localizations.localeOf(context).languageCode ==
                                      'en'
                                  ? 'Clear start'
                                  : 'Quitar inicio',
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: controller.isSaving
                              ? null
                              : () => _pickContractDate(start: false),
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            '${l10n.contractEndDate}: '
                            '${_contractDateLabel(context, _contractEndsOn)}',
                          ),
                        ),
                        if (_contractEndsOn != null)
                          TextButton(
                            onPressed: controller.isSaving
                                ? null
                                : () => setState(() {
                                    _contractEndsOn = null;
                                    _showContractError = false;
                                  }),
                            child: Text(
                              Localizations.localeOf(context).languageCode ==
                                      'en'
                                  ? 'Clear end'
                                  : 'Quitar fin',
                            ),
                          ),
                      ],
                    ),
                    if (_showContractError) ...[
                      const SizedBox(height: 8),
                      Text(
                        _contractErrorMessage(context),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      l10n.grades,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final grade in PrimaryGrade.values)
                          FilterChip(
                            label: Text('${grade.number}°'),
                            selected: _grades.contains(grade),
                            onSelected: controller.isSaving
                                ? null
                                : (selected) {
                                    setState(() {
                                      selected
                                          ? _grades.add(grade)
                                          : _grades.remove(grade);
                                      _showGradesError = false;
                                    });
                                  },
                          ),
                      ],
                    ),
                    if (_showGradesError) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.selectAtLeastOneGrade,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Text(
                      Localizations.localeOf(context).languageCode == 'en'
                          ? 'Teacher profile and school authorities'
                          : 'Perfil docente y autoridades escolares',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 620;
                        final english =
                            Localizations.localeOf(context).languageCode ==
                            'en';
                        final teacherNameField = TextFormField(
                          controller: _teacherNameController,
                          enabled: !controller.isSaving,
                          decoration: InputDecoration(
                            labelText: english
                                ? 'Teacher full name'
                                : 'Nombre completo del docente',
                          ),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onChanged: _onTeacherNameChanged,
                          validator: (value) => _required(value, l10n),
                        );
                        final teachingRoleField =
                            DropdownButtonFormField<TeachingRole>(
                              initialValue: _teachingRole,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: english
                                    ? 'Teacher role'
                                    : 'Función del docente',
                              ),
                              items: [
                                for (final role in TeachingRole.values)
                                  DropdownMenuItem(
                                    value: role,
                                    child: Text(
                                      _teachingRoleLabel(role, english),
                                    ),
                                  ),
                              ],
                              onChanged: controller.isSaving
                                  ? null
                                  : _onTeachingRoleChanged,
                            );
                        return wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: teacherNameField),
                                  const SizedBox(width: 16),
                                  Expanded(child: teachingRoleField),
                                ],
                              )
                            : Column(
                                children: [
                                  teacherNameField,
                                  const SizedBox(height: 16),
                                  teachingRoleField,
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildAuthorityFields(context, controller.isSaving),
                    if (controller.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        friendlyErrorMessage(
                          context,
                          controller.error,
                          fallback: l10n.setupSaveError,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (compact || largeText)
                      FilledButton(
                        onPressed: controller.isSaving ? null : _submit,
                        child: controller.isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l10n.saveAndContinue,
                                textAlign: TextAlign.center,
                              ),
                      )
                    else
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: controller.isSaving ? null : _submit,
                          icon: controller.isSaving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: Text(l10n.saveAndContinue),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorityFields(BuildContext context, bool disabled) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;
        final supervisorField = TextFormField(
          controller: _supervisorNameController,
          enabled: !disabled,
          decoration: InputDecoration(
            labelText: english
                ? 'School supervisor (optional)'
                : 'Supervisor(a) escolar (opcional)',
          ),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        );
        final leadershipNameField = TextFormField(
          controller: _leadershipNameController,
          enabled: !disabled,
          decoration: InputDecoration(
            labelText: english
                ? 'School leadership (optional)'
                : 'Responsable de dirección (opcional)',
          ),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        );
        final leadershipRoleField =
            DropdownButtonFormField<SchoolLeadershipRole?>(
              initialValue: _leadershipRole,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: english ? 'Leadership role' : 'Función de dirección',
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(english ? 'Unspecified' : 'Sin especificar'),
                ),
                for (final role in SchoolLeadershipRole.values)
                  DropdownMenuItem(
                    value: role,
                    child: Text(_leadershipRoleLabel(role, english)),
                  ),
              ],
              onChanged: disabled
                  ? null
                  : (value) => setState(() => _leadershipRole = value),
            );

        if (wide) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: supervisorField),
                  const SizedBox(width: 16),
                  Expanded(child: leadershipNameField),
                ],
              ),
              const SizedBox(height: 16),
              leadershipRoleField,
            ],
          );
        }

        return Column(
          children: [
            supervisorField,
            const SizedBox(height: 16),
            leadershipNameField,
            const SizedBox(height: 16),
            leadershipRoleField,
          ],
        );
      },
    );
  }

  void _onTeachingRoleChanged(TeachingRole? value) {
    if (value == null) return;
    setState(() {
      _teachingRole = value;
      if (value.hasLeadership) {
        // Preselect the matching leadership role and mirror the teacher
        // name into the editable leadership field when it is still empty.
        _leadershipRole = value.leadershipRole;
        final teacherName = _teacherNameController.text.trim();
        if (teacherName.isNotEmpty &&
            _leadershipNameController.text.trim().isEmpty) {
          _leadershipNameController.text = teacherName;
          _syncedLeadershipName = teacherName;
        }
      }
    });
  }

  void _onTeacherNameChanged(String value) {
    if (!_teachingRole.hasLeadership) return;
    final current = _leadershipNameController.text.trim();
    final synced = _syncedLeadershipName;
    final mirrorsTeacherName =
        current.isEmpty || (synced != null && current == synced);
    if (!mirrorsTeacherName) return;
    final teacherName = value.trim();
    if (teacherName.isEmpty) return;
    _leadershipNameController.text = teacherName;
    _syncedLeadershipName = teacherName;
  }

  String _teachingRoleLabel(TeachingRole role, bool english) {
    return switch (role) {
      TeachingRole.teacher =>
        english ? 'Group teacher' : 'Docente frente a grupo',
      TeachingRole.teacherWithLeadership =>
        english
            ? 'Teacher with leadership duties'
            : 'Docente con funciones de dirección',
      TeachingRole.principal => english ? 'Principal' : 'Director(a)',
      TeachingRole.actingPrincipal =>
        english ? 'Acting principal' : 'Encargado(a) de dirección',
    };
  }

  String _leadershipRoleLabel(SchoolLeadershipRole role, bool english) {
    return switch (role) {
      SchoolLeadershipRole.principal => english ? 'Principal' : 'Director(a)',
      SchoolLeadershipRole.teacherWithLeadership =>
        english
            ? 'Teacher with leadership duties'
            : 'Docente con funciones de dirección',
      SchoolLeadershipRole.actingPrincipal =>
        english ? 'Acting principal' : 'Encargado(a) de dirección',
    };
  }

  void _syncStateFromCct(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.length < 2) return;

    final candidate = MexicoGeographyCatalog.byCode(normalized.substring(0, 2));
    if (candidate == null || candidate.code == _stateCode) return;

    setState(() {
      _stateCode = candidate.code;
      _municipality = null;
    });
  }

  Future<void> _pickContractDate({required bool start}) async {
    final current = start ? _contractStartsOn : _contractEndsOn;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? _contractStartsOn ?? _schoolYear.startsOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;

    setState(() {
      if (start) {
        _contractStartsOn = picked;
      } else {
        _contractEndsOn = picked;
      }
      _showContractError = false;
    });
  }

  String _contractDateLabel(BuildContext context, DateTime? date) {
    if (date == null) {
      return AppLocalizations.of(context).selectDate;
    }
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  bool get _contractIsIncomplete =>
      (_contractStartsOn == null) != (_contractEndsOn == null);

  bool get _contractIsReversed =>
      _contractStartsOn != null &&
      _contractEndsOn != null &&
      _contractEndsOn!.isBefore(_contractStartsOn!);

  String _contractErrorMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _contractIsReversed
        ? l10n.invalidDateRange
        : l10n.contractIncomplete;
  }

  String? _required(String? value, AppLocalizations l10n) {
    return value == null || value.trim().isEmpty ? l10n.requiredField : null;
  }

  Future<void> _submit() async {
    setState(() {
      _showGradesError = _grades.isEmpty;
      _showContractError = _contractIsIncomplete || _contractIsReversed;
    });
    if (!_formKey.currentState!.validate() ||
        _grades.isEmpty ||
        _showContractError) {
      return;
    }

    final state = _selectedState;
    final municipality = _municipality;
    if (state == null || municipality == null) return;

    final contractStart = _contractStartsOn;
    final contractEnd = _contractEndsOn;
    final contract = contractStart != null && contractEnd != null
        ? TeachingContract(startsOn: contractStart, endsOn: contractEnd)
        : null;

    final schoolYear = _schoolYear;
    final saved = await context.read<SchoolSetupController>().save(
      schoolName: _schoolNameController.text,
      cct: _cctController.text.trim().toUpperCase(),
      organization: _organization,
      state: state.name,
      municipality: municipality,
      locality: _localityController.text,
      schoolZone: _schoolZoneController.text,
      schoolSector: _schoolSectorController.text,
      supervisorName: _supervisorNameController.text,
      leadershipName: _leadershipNameController.text,
      leadershipRole: _leadershipRole,
      schoolYearLabel: schoolYear.label,
      startsOn: schoolYear.startsOn,
      endsOn: schoolYear.endsOn,
      groupName: _groupNameController.text.trim(),
      grades: Set<PrimaryGrade>.of(_grades),
      shift: SchoolShiftCatalog.persistenceValue(_shift),
      contract: contract,
      teachingRole: _teachingRole,
      teacherName: _teacherNameController.text,
    );

    if (saved && mounted) {
      widget.onCompleted();
    }
  }

  String _organizationLabel(
    SchoolOrganization organization,
    AppLocalizations l10n,
  ) {
    return switch (organization) {
      SchoolOrganization.unspecified => l10n.organizationUnspecified,
      SchoolOrganization.unitary => l10n.organizationUnitary,
      SchoolOrganization.twoTeacher => l10n.organizationTwoTeacher,
      SchoolOrganization.threeTeacher => l10n.organizationThreeTeacher,
      SchoolOrganization.fourTeacher => l10n.organizationFourTeacher,
      SchoolOrganization.fiveTeacher => l10n.organizationFiveTeacher,
      SchoolOrganization.complete => l10n.organizationComplete,
    };
  }
}
