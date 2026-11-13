import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/repo/auth_repository.dart';
import '../widgets/password_field.dart';
import '../../../core/l10n/language.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _isSaving = false;
  String? _error;

  static const _minLength = 8;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref
          .read(authProvider.notifier)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
          );
      if (!mounted) return;
      context.showMessage(tr('Password changed'));
      // After a first sign-in there is no page behind this one.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstTime = ref.watch(authProvider)?.mustChangePassword ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          firstTime ? tr('Choose your password') : tr('Change password'),
        ),
        // After a first sign-in this is the only way forward.
        automaticallyImplyLeading: !firstTime,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            if (firstTime) ...[
              Text(
                tr(
                  'You signed in with a temporary password from the school. Choose your own password to continue, one only you know.',
                ),
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            PasswordField(
              controller: _current,
              label: firstTime
                  ? tr('Temporary password')
                  : tr('Current password'),
              validator: (v) => (v == null || v.isEmpty)
                  ? tr('This field is required')
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _new,
              label: tr('New password'),
              validator: (v) => (v == null || v.length < _minLength)
                  ? tr('Use at least {0} characters', [_minLength])
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _confirm,
              label: tr('Repeat new password'),
              validator: (v) =>
                  v != _new.text ? tr('The passwords do not match') : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr(
                'At least {0} characters. Mixing letters and numbers makes it stronger.',
                [_minLength],
              ),
              style: context.text.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: context.text.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
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
                  : Text(tr('Change password')),
            ),
          ],
        ),
      ),
    );
  }
}
