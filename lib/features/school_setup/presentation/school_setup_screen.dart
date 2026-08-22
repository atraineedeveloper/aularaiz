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
  final _stateController = TextEditingController();
  final _municipalityController = TextEditingController();
  final _localityController = TextEditingController();
  final _schoolYearController = TextEditingController();

  SchoolOrganization _organization = SchoolOrganization.unspecified;
  DateTime? _startsOn;
  DateTime? _endsOn;
  bool _showDateError = false;

  @override
  void dispose() {
    _schoolNameController.dispose();
    _cctController.dispose();
    _stateController.dispose();
    _municipalityController.dispose();
    _localityController.dispose();
    _schoolYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<SchoolSetupController>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
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
                      decoration: InputDecoration(labelText: l10n.schoolName),
                      textInputAction: TextInputAction.next,
                      validator: (value) => _required(value, l10n),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cctController,
                      decoration: InputDecoration(labelText: l10n.cct),
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<SchoolOrganization>(
                      initialValue: _organization,
                      decoration: InputDecoration(
                        labelText: l10n.schoolOrganization,
                      ),
                      items: SchoolOrganization.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_organizationLabel(value, l10n)),
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
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 218,
                          child: TextFormField(
                            controller: _stateController,
                            decoration: InputDecoration(labelText: l10n.state),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        SizedBox(
                          width: 218,
                          child: TextFormField(
                            controller: _municipalityController,
                            decoration: InputDecoration(
                              labelText: l10n.municipality,
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        SizedBox(
                          width: 218,
                          child: TextFormField(
                            controller: _localityController,
                            decoration: InputDecoration(
                              labelText: l10n.locality,
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.schoolYear,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _schoolYearController,
                      decoration: InputDecoration(
                        labelText: l10n.schoolYear,
                        hintText: l10n.schoolYearExample,
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (value) => _required(value, l10n),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _DateField(
                          label: l10n.startDate,
                          date: _startsOn,
                          enabled: !controller.isSaving,
                          onPressed: () => _selectStartDate(context),
                        ),
                        _DateField(
                          label: l10n.endDate,
                          date: _endsOn,
                          enabled: !controller.isSaving,
                          onPressed: () => _selectEndDate(context),
                        ),
                      ],
                    ),
                    if (_showDateError) ...[
                      const SizedBox(height: 8),
                      Text(
                        _dateErrorMessage(l10n),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
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

  String? _required(String? value, AppLocalizations l10n) {
    return value == null || value.trim().isEmpty ? l10n.requiredField : null;
  }

  String _dateErrorMessage(AppLocalizations l10n) {
    if (_startsOn != null && _endsOn != null && _endsOn!.isBefore(_startsOn!)) {
      return l10n.invalidDateRange;
    }
    return l10n.requiredField;
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startsOn ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (selected != null) {
      setState(() {
        _startsOn = selected;
        _showDateError = false;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endsOn ?? _startsOn ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (selected != null) {
      setState(() {
        _endsOn = selected;
        _showDateError = false;
      });
    }
  }

  Future<void> _submit() async {
    final datesValid = _startsOn != null &&
        _endsOn != null &&
        !_endsOn!.isBefore(_startsOn!);
    setState(() => _showDateError = !datesValid);

    if (!_formKey.currentState!.validate() || !datesValid) return;

    final saved = await context.read<SchoolSetupController>().save(
      schoolName: _schoolNameController.text,
      cct: _cctController.text,
      organization: _organization,
      state: _stateController.text,
      municipality: _municipalityController.text,
      locality: _localityController.text,
      schoolYearLabel: _schoolYearController.text,
      startsOn: _startsOn!,
      endsOn: _endsOn!,
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

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final DateTime? date;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final value = date == null
        ? AppLocalizations.of(context).selectDate
        : localizations.formatMediumDate(date!);

    return SizedBox(
      width: 260,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: const Icon(Icons.calendar_today_outlined),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('$label: $value'),
          ),
        ),
      ),
    );
  }
}
