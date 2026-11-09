import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/icon_box.dart';
import '../providers/auth_provider.dart';
import '../../../core/l10n/language.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    await ref
        .read(authRepositoryProvider)
        .requestPasswordReset(_controller.text.trim());
    if (mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: _sent ? _buildSent(context) : _buildForm(context),
        ),
      ),
    );
  }

  List<Widget> _buildForm(BuildContext context) {
    return [
      Text(tr('Reset your password'), style: context.text.headlineSmall),
      const SizedBox(height: AppSpacing.sm),
      Text(
        tr(
          'Enter your school ID, email or phone number. Your school office will be asked to give you a new password.',
        ),
        style: context.text.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.xl),
      TextField(
        controller: _controller,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          hintText: tr('School ID, email or phone'),
          prefixIcon: Icon(Icons.alternate_email),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      FilledButton(
        onPressed: _isLoading ? null : _send,
        child: _isLoading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(tr('Ask my school office')),
      ),
    ];
  }

  List<Widget> _buildSent(BuildContext context) {
    return [
      const SizedBox(height: AppSpacing.xxl),
      const Center(
        child: IconBox(
          icon: Icons.mark_email_read_outlined,
          color: AppColors.success,
          size: 72,
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      Text(
        tr('Request sent'),
        style: context.text.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        tr(
          'If an account matches {0}, your school office was asked to give you a new password. They will contact you.',
          [_controller.text.trim()],
        ),
        style: context.text.bodyMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.xxl),
      OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(tr('Back to sign in')),
      ),
    ];
  }
}
