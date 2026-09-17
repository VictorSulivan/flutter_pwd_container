import 'package:flutter/material.dart';

import '../../services/password_generator.dart';
import '../../theme/app_theme.dart';
import 'safe_vault_chrome.dart';

class PasswordGeneratorPanel extends StatefulWidget {
  const PasswordGeneratorPanel({
    super.key,
    required this.onGenerated,
    this.generator,
  });

  final ValueChanged<String> onGenerated;
  final PasswordGenerator? generator;

  @override
  State<PasswordGeneratorPanel> createState() => _PasswordGeneratorPanelState();
}

class _PasswordGeneratorPanelState extends State<PasswordGeneratorPanel> {
  PasswordGeneratorOptions _options = const PasswordGeneratorOptions();
  String? _error;

  void _generate() {
    try {
      final password = (widget.generator ?? PasswordGenerator()).generate(
        _options,
      );
      setState(() {
        _error = null;
      });
      widget.onGenerated(password);
    } on PasswordGeneratorException catch (error) {
      setState(() {
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Longueur',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            Expanded(
              child: Slider(
                min: PasswordGeneratorOptions.minLength.toDouble(),
                max: PasswordGeneratorOptions.maxLength.toDouble(),
                divisions:
                    PasswordGeneratorOptions.maxLength -
                    PasswordGeneratorOptions.minLength,
                value: _options.length.toDouble(),
                label: '${_options.length}',
                onChanged: (value) {
                  setState(() {
                    _options = _options.copyWith(length: value.round());
                  });
                },
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '${_options.length}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        _CharsetSwitch(
          label: 'Majuscules',
          value: _options.upper,
          onChanged: (value) {
            setState(() {
              _options = _options.copyWith(upper: value);
            });
          },
        ),
        _CharsetSwitch(
          label: 'Minuscules',
          value: _options.lower,
          onChanged: (value) {
            setState(() {
              _options = _options.copyWith(lower: value);
            });
          },
        ),
        _CharsetSwitch(
          label: 'Chiffres',
          value: _options.digits,
          onChanged: (value) {
            setState(() {
              _options = _options.copyWith(digits: value);
            });
          },
        ),
        _CharsetSwitch(
          label: 'Symboles',
          value: _options.symbols,
          onChanged: (value) {
            setState(() {
              _options = _options.copyWith(symbols: value);
            });
          },
        ),
        const SizedBox(height: 8),
        SafeVaultPrimaryButton(
          onPressed: _generate,
          icon: const Icon(Icons.casino_outlined, size: 20),
          label: 'Générer',
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class _CharsetSwitch extends StatelessWidget {
  const _CharsetSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
