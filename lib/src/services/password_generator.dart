import 'dart:math';

class PasswordGeneratorOptions {
  const PasswordGeneratorOptions({
    this.length = 16,
    this.upper = true,
    this.lower = true,
    this.digits = true,
    this.symbols = true,
  });

  static const minLength = 8;
  static const maxLength = 64;

  final int length;
  final bool upper;
  final bool lower;
  final bool digits;
  final bool symbols;

  PasswordGeneratorOptions copyWith({
    int? length,
    bool? upper,
    bool? lower,
    bool? digits,
    bool? symbols,
  }) {
    return PasswordGeneratorOptions(
      length: length ?? this.length,
      upper: upper ?? this.upper,
      lower: lower ?? this.lower,
      digits: digits ?? this.digits,
      symbols: symbols ?? this.symbols,
    );
  }
}

class PasswordGeneratorException implements Exception {
  const PasswordGeneratorException([
    this.message = 'Choisis au moins un type de caractère.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class PasswordGenerator {
  PasswordGenerator([Random? random]) : _random = random ?? Random.secure();

  static const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const _digits = '0123456789';
  static const _symbols = r'!@#$%^&*()-_=+[]{};:,.<>?';

  final Random _random;

  String generate([
    PasswordGeneratorOptions options = const PasswordGeneratorOptions(),
  ]) {
    final pools = <String>[
      if (options.upper) _upper,
      if (options.lower) _lower,
      if (options.digits) _digits,
      if (options.symbols) _symbols,
    ];
    if (pools.isEmpty) {
      throw const PasswordGeneratorException();
    }
    final length = options.length.clamp(
      PasswordGeneratorOptions.minLength,
      PasswordGeneratorOptions.maxLength,
    );
    if (length < pools.length) {
      throw PasswordGeneratorException(
        'Longueur trop courte pour ${pools.length} types.',
      );
    }

    final chars = <String>[
      for (final pool in pools) pool[_random.nextInt(pool.length)],
    ];
    final alphabet = pools.join();
    while (chars.length < length) {
      chars.add(alphabet[_random.nextInt(alphabet.length)]);
    }
    for (var i = chars.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final tmp = chars[i];
      chars[i] = chars[j];
      chars[j] = tmp;
    }
    return chars.join();
  }
}
