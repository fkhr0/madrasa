import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/context_extensions.dart';
import '../../academics/providers/academics_provider.dart';
import '../../auth/models/user_model.dart';
import '../models/new_account_model.dart';
import '../providers/people_provider.dart';
import '../widgets/credentials_sheet.dart';
import '../widgets/role_chips.dart';
import '../../../core/l10n/language.dart';

/// Creates an account, or edits one when [personId] is given.
class AddPersonPage extends ConsumerStatefulWidget {
  final String? personId;

  const AddPersonPage({super.key, this.personId});

  @override
  ConsumerState<AddPersonPage> createState() => _AddPersonPageState();
}

class _AddPersonPageState extends ConsumerState<AddPersonPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  late UserRole _role = ref.read(peopleRoleProvider);
  String? _className;
  String? _subjectName;
  final Set<String> _childIds = {};
  bool _isSaving = false;

  /// The account being edited, once loaded.
  UserModel? _editing;

  bool get _isNew => widget.personId == null;

  /// Fills the form with the account, once.
  void _fill(UserModel user) {
    _editing = user;
    _role = user.role;
    _name.text = user.name;
    _email.text = user.email;
    _phone.text = user.phone;
    _className = user.className;
    _subjectName = user.subjectName;
    _childIds.addAll(user.children.map((c) => c.id));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == UserRole.parent && _childIds.isEmpty) {
      context.showMessage(tr('Link at least one child to the parent account'));
      return;
    }

    final account = NewAccountModel(
      role: _role,
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      className: _role == UserRole.student ? _className : null,
      subjectName: _role == UserRole.teacher ? _subjectName : null,
      childIds: _role == UserRole.parent ? _childIds.toList() : const [],
    );
    final actions = ref.read(peopleActionsProvider);

    setState(() => _isSaving = true);
    try {
      if (_editing case final user?) {
        await actions.update(user, account);
        if (!mounted) return;
        context.showMessage(tr('Saved'));
        Navigator.of(context).pop();
        return;
      }

      final credentials = await actions.create(account);
      if (!mounted) return;
      await showCredentialsSheet(
        context,
        credentials,
        title: tr('Account created'),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.personId;
    if (id != null && _editing == null) {
      final person = ref.watch(personByIdProvider(id)).valueOrNull;
      if (person == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      _fill(person);
    }

    final classes = ref.watch(schoolClassesProvider).valueOrNull ?? [];
    final subjects = ref.watch(schoolSubjectsProvider).valueOrNull ?? [];
    final students =
        ref.watch(peopleByRoleProvider(UserRole.student)).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew
              ? tr('New account')
              : tr('Edit {0}', [_role.label.toLowerCase()]),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            if (_isNew)
              RoleChips(
                selected: _role,
                onSelected: (r) => setState(() => _role = r),
              )
            else
              Text(
                '${_editing!.id} · ${_role.label}',
                style: context.text.bodySmall,
              ),
            const SizedBox(height: AppSpacing.xl),

            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().split(' ').length < 2)
                  ? tr('Enter the full name')
                  : null,
              decoration: InputDecoration(
                labelText: tr('Full name'),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              // Families and the office call drivers, so they need a phone.
              validator: (v) =>
                  _role == UserRole.driver && (v == null || v.trim().isEmpty)
                  ? tr('Drivers need a phone number')
                  : null,
              decoration: InputDecoration(
                labelText: _role == UserRole.driver
                    ? tr('Phone')
                    : tr('Phone (optional)'),
                hintText: tr('+964 7XX XXX XXXX'),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            if (_role == UserRole.driver)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  tr(
                    'After creating the account, choose their bus in More › Transport › the line › Edit.',
                  ),
                  style: context.text.bodySmall,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: tr('Email (optional)'),
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---------- Role-specific fields ----------
            if (_role == UserRole.student)
              DropdownButtonFormField<String>(
                // The app's card look, not the default grey strip.
                dropdownColor: context.palette.card,

                borderRadius: BorderRadius.circular(AppRadius.md),

                menuMaxHeight: 360,
                isExpanded: true,
                initialValue: _className,
                validator: (v) => v == null ? tr('Choose a class') : null,
                decoration: InputDecoration(
                  labelText: tr('Class'),
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                items: [
                  for (final name in _withCurrent(
                    classes.map((c) => c.name),
                    _className,
                  ))
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() => _className = v),
              ),

            if (_role == UserRole.teacher)
              DropdownButtonFormField<String>(
                // The app's card look, not the default grey strip.
                dropdownColor: context.palette.card,

                borderRadius: BorderRadius.circular(AppRadius.md),

                menuMaxHeight: 360,
                isExpanded: true,
                initialValue: _subjectName,
                validator: (v) => v == null ? tr('Choose a subject') : null,
                decoration: InputDecoration(
                  labelText: tr('Main subject'),
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
                items: [
                  // The school's own subjects (Academic › Subjects).
                  for (final name in _withCurrent(
                    subjects.map((s) => s.name),
                    _subjectName,
                  ))
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() => _subjectName = v),
              ),

            if (_role == UserRole.parent) ...[
              Text(tr('Children'), style: context.text.titleSmall),
              Text(
                tr(
                  'The parent will see grades, attendance and messages of the children you link.',
                ),
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in students)
                    FilterChip(
                      label: Text(s.name),
                      selected: _childIds.contains(s.id),
                      onSelected: (on) => setState(
                        () => on ? _childIds.add(s.id) : _childIds.remove(s.id),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isNew ? tr('Create account') : tr('Save changes')),
            ),
            if (_isNew) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                tr(
                  'An ID and a temporary password are generated automatically.',
                ),
                style: context.text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The choices, plus the person's current value if it is no longer in
  /// the list (a class or subject renamed or deleted since).
  static List<String> _withCurrent(Iterable<String> names, String? current) {
    final list = names.toList();
    if (current != null && !list.contains(current)) list.add(current);
    return list;
  }
}
