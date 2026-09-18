import 'dart:math';

import 'package:flutter_pwd_container/src/services/password_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('respecte la longueur demandée', () {
    final generator = PasswordGenerator(Random(1));
    expect(
      generator.generate(const PasswordGeneratorOptions(length: 24)).length,
      24,
    );
  });

  test('chiffres uniquement', () {
    final generator = PasswordGenerator(Random(2));
    final password = generator.generate(
      const PasswordGeneratorOptions(
        upper: false,
        lower: false,
        digits: true,
        symbols: false,
      ),
    );
    expect(password, matches(RegExp(r'^[0-9]+$')));
    expect(RegExp(r'[0-9]').hasMatch(password), isTrue);
  });

  test('contient au moins un caractère de chaque type choisi', () {
    final generator = PasswordGenerator(Random(3));
    final password = generator.generate(
      const PasswordGeneratorOptions(length: 12),
    );
    expect(RegExp(r'[A-Z]').hasMatch(password), isTrue);
    expect(RegExp(r'[a-z]').hasMatch(password), isTrue);
    expect(RegExp(r'[0-9]').hasMatch(password), isTrue);
    expect(RegExp(r'[!@#\$%^&*()\-_=+\[\]{};:,.<>?]').hasMatch(password), isTrue);
  });

  test('refuse zéro type de caractère', () {
    final generator = PasswordGenerator(Random(4));
    expect(
      () => generator.generate(
        const PasswordGeneratorOptions(
          upper: false,
          lower: false,
          digits: false,
          symbols: false,
        ),
      ),
      throwsA(isA<PasswordGeneratorException>()),
    );
  });
}
