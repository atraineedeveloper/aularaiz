import 'package:aularaiz/core/catalogs/mexico_geography_catalog.dart';
import 'package:aularaiz/core/catalogs/school_year_catalog.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
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

  SchoolOrganization _organization = SchoolOrganization.unspecified;
  String? _stateCode;
  String? _municipality;

  SchoolYearPreset get _schoolYear => SchoolYearCatalog.currentBasicEducation();

  MexicoStateOption? get _selectedState =>
      _stateCode == null ? null : MexicoGeographyCatalog.byCode(_stateCode!);

  @override
  void dispose() {
    _schoolNameController.dispose();
    _cctController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<SchoolSetupController>();
    final schoolYear = _schoolYear;
    final selectedState = _selectedState;
    final compact = MediaQuery.sizeOf(context).width < 480;
    final largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;

    return Scaffold(
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
                    Text(
                      l10n.setupTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.setupSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge,
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
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 28),
                    _SchoolYearCard(
                      schoolYear: schoolYear,
                      title: l10n.schoolYear,
                      startLabel: l10n.startDate,
                      endLabel: l10n.endDate,
                    ),
                    if (controller.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.setupSaveError,
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

  String? _required(String? value, AppLocalizations l10n) {
    return value == null || value.trim().isEmpty ? l10n.requiredField : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final state = _selectedState;
    final municipality = _municipality;
    if (state == null || municipality == null) return;

    final schoolYear = _schoolYear;
    final saved = await context.read<SchoolSetupController>().save(
      schoolName: _schoolNameController.text,
      cct: _cctController.text.trim().toUpperCase(),
      organization: _organization,
      state: state.name,
      municipality: municipality,
      locality: _localityController.text,
      schoolYearLabel: schoolYear.label,
      startsOn: schoolYear.startsOn,
      endsOn: schoolYear.endsOn,
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

class _SchoolYearCard extends StatelessWidget {
  const _SchoolYearCard({
    required this.schoolYear,
    required this.title,
    required this.startLabel,
    required this.endLabel,
  });

  final SchoolYearPreset schoolYear;
  final String title;
  final String startLabel;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    final dates = MaterialLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.school_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$title ${schoolYear.label}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('$startLabel: ${dates.formatMediumDate(schoolYear.startsOn)}'),
            const SizedBox(height: 4),
            Text('$endLabel: ${dates.formatMediumDate(schoolYear.endsOn)}'),
          ],
        ),
      ),
    );
  }
}
