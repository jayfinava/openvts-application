import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/open_vts_colors.dart';
import '../../core/theme/open_vts_spacing.dart';
import '../../core/theme/open_vts_typography.dart';

Color _textSecondaryColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? OpenVtsColors.darkTextSecondary
      : OpenVtsColors.textSecondary;
}

Color _textPrimaryColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? OpenVtsColors.darkTextPrimary
      : OpenVtsColors.textPrimary;
}

class OpenVtsTextField extends StatelessWidget {
  const OpenVtsTextField({
    required this.label,
    this.controller,
    this.hintText,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.prefixIcon,
    this.suffixIcon,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: OpenVtsTypography.label.copyWith(
            color: _textSecondaryColor(context),
          ),
        ),
        const SizedBox(height: OpenVtsSpacing.xs),
        TextFormField(
          style: TextStyle(color: _textPrimaryColor(context)),
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(
                    prefixIcon,
                    size: 20,
                    color: _textSecondaryColor(context),
                  ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
