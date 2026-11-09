import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/repo/auth_repository.dart';
import '../../../core/l10n/language.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: ref.read(currentUserProvider).email,
  );
  late final _phoneController = TextEditingController(
    text: ref.read(currentUserProvider).phone,
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(authProvider.notifier)
          .updateContactInfo(
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
          );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showMessage(e.message);
      return;
    }

    if (!mounted) return;
    context.showMessage(tr('Profile updated'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Edit profile'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Center(
              child: UserAvatar(name: user.name, size: AppSizes.avatarLg),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Read-only: managed by the school.
            TextFormField(
              initialValue: user.name,
              enabled: false,
              decoration: InputDecoration(
                labelText: tr('Full name'),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr(
                'Your name is set by the school. Contact the office to change it.',
              ),
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@'))
                  ? tr('Enter a valid email')
                  : null,
              decoration: InputDecoration(
                labelText: tr('Email'),
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().length < 7)
                  ? tr('Enter a valid phone number')
                  : null,
              decoration: InputDecoration(
                labelText: tr('Phone'),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(tr('Save changes')),
            ),
          ],
        ),
      ),
    );
  }
}
