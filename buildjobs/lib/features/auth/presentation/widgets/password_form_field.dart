import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Botón de ojo para mostrar/ocultar contraseña.
class PasswordVisibilityToggle extends StatelessWidget {
  const PasswordVisibilityToggle({
    super.key,
    required this.obscured,
    required this.onToggle,
    this.iconSize = 22,
  });

  final bool obscured;
  final VoidCallback onToggle;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onToggle,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppTheme.textSecondary,
        size: iconSize,
      ),
      tooltip: obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
    );
  }
}

/// Campo de contraseña con ojo (login, recuperar contraseña, etc.).
class PasswordFormField extends StatefulWidget {
  const PasswordFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.autofillHints = const [AutofillHints.password],
    this.onFieldSubmitted,
    this.prefixIcon = Icons.lock_outline,
  });

  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final void Function(String)? onFieldSubmitted;
  final IconData prefixIcon;

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      style: const TextStyle(fontSize: 16),
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      obscureText: _obscured,
      enableSuggestions: false,
      autocorrect: false,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: Icon(widget.prefixIcon),
        suffixIcon: PasswordVisibilityToggle(
          obscured: _obscured,
          onToggle: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}
