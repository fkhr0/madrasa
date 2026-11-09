import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/server_address.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../providers/auth_provider.dart';
import '../repo/auth_repository.dart';
import 'demo_accounts_hint.dart';
import '../../../core/l10n/language.dart';

/// School ID + password fields and the sign-in button.
/// On success the router moves to the dashboard by itself.
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverController = TextEditingController(text: AppConfig.chosenServer);

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Test builds: talk to the address typed above from now on.
    if (AppConfig.asksForServer) {
      final address = ServerAddress.clean(_serverController.text)!;
      await ServerAddress.save(address);
      ref.read(apiClientProvider).baseUrl = address;
    }

    try {
      await ref
          .read(authProvider.notifier)
          .signIn(
            schoolId: _idController.text.trim(),
            password: _passwordController.text,
          );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _serverAddress(String? value) =>
      ServerAddress.clean(value ?? '') == null
      ? tr('Write the full address, starting with https://')
      : null;

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return tr('This field is required');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Test builds only: which server (the test tunnel's address).
          if (AppConfig.asksForServer) ...[
            TextFormField(
              controller: _serverController,
              validator: _serverAddress,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: tr('Server address'),
                hintText: 'https://….trycloudflare.com',
                prefixIcon: const Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextFormField(
            controller: _idController,
            validator: _required,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: tr('School ID, email or phone'),
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: _passwordController,
            validator: _required,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: tr('Password'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),

          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => context.push(AppRoutes.forgotPassword),
              child: Text(tr('Forgot password?')),
            ),
          ),

          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: context.text.bodySmall?.copyWith(color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          FilledButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(tr('Sign in')),
          ),

          if (AppConfig.showDemoAccounts) ...[
            const SizedBox(height: AppSpacing.xl),
            DemoAccountsHint(onPick: (id) => _idController.text = id),
          ],
        ],
      ),
    );
  }
}
