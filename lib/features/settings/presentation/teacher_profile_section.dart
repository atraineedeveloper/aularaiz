import 'package:aularaiz/application/contracts/teacher_profile_repository.dart';
import 'package:aularaiz/application/teacher/save_teacher_profile.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// "Mi perfil docente" preferences section.
///
/// Edits the single local teacher profile of this installation. The profile
/// is installation-scoped: changing it never affects school assignments, and
/// creating a new school keeps it intact.
class TeacherProfileSection extends StatefulWidget {
  const TeacherProfileSection({super.key});

  @override
  State<TeacherProfileSection> createState() => _TeacherProfileSectionState();
}

class _TeacherProfileSectionState extends State<TeacherProfileSection> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _loaded = false;
  bool _isSaving = false;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await context.read<TeacherProfileRepository>().load();
      if (!mounted) return;
      setState(() {
        if (profile != null) {
          _nameController.text = profile.fullName;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await context
          .read<SaveTeacherProfile>()
          .call(fullName: _nameController.text);
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'en'
                ? 'Teacher profile saved.'
                : 'Perfil docente guardado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final english = Localizations.localeOf(context).languageCode == 'en';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.badge_outlined,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        english ? 'My teacher profile' : 'Mi perfil docente',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        english
                            ? 'Your name stays on this device. It is used for'
                                  ' your group reports and is not tied to one'
                                  ' school, so it survives contract changes.'
                            : 'Tu nombre se guarda solo en este dispositivo. Se'
                                  ' usa en los reportes de tus grupos y no'
                                  ' pertenece a una escuela, así que se'
                                  ' conserva cuando cambias de contrato.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _nameController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: english
                      ? 'Teacher full name'
                      : 'Nombre completo del docente',
                  helperText: english
                      ? 'Only the name is stored. No CURP, RFC or phone.'
                      : 'Solo se guarda el nombre. Sin CURP, RFC ni teléfono.',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    value == null || value.trim().isEmpty
                    ? l10n.requiredField
                    : null,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                english
                    ? 'The profile could not be saved. Try again.'
                    : 'No se pudo guardar el perfil. Inténtalo de nuevo.',
                style: TextStyle(color: scheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
