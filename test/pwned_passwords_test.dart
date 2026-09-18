import 'package:flutter_pwd_container/src/services/pwned_passwords.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SHA-1 de password commence par 5BAA6', () {
    expect(HibpPwnedPasswords.sha1PrefixForTest('password'), '5BAA6');
  });

  test('compare le suffixe en local et ignore le padding', () async {
    String? requested;
    final lookup = HibpPwnedPasswords(
      fetchRange: (prefix) async {
        requested = prefix;
        return '1E4C9B93F3F0682250B6CF8331B7EE68FD8:3861493\r\n'
            '00DEADBEEF0000000000000000000000000:0\n';
      },
    );
    final hit = await lookup.check('password');
    expect(requested, '5BAA6');
    expect(requested, hasLength(5));
    expect(hit.pwned, isTrue);
    expect(hit.count, 3861493);
  });

  test('un mot de passe absent du range n’est pas fuité', () async {
    final lookup = HibpPwnedPasswords(
      fetchRange: (prefix) async => 'AAAAAAAAAABBBBBBBBBBCCCCCCCCCCDDDDD:12\n',
    );
    final hit = await lookup.check('password');
    expect(hit.pwned, isFalse);
    expect(hit.count, 0);
  });

  test('une erreur réseau ne bloque pas et ne marque pas fuité', () async {
    final lookup = HibpPwnedPasswords(
      fetchRange: (prefix) async => throw StateError('offline'),
    );
    final hit = await lookup.check('password');
    expect(hit.pwned, isFalse);
  });

  test('n’envoie jamais le secret, seulement un préfixe', () async {
    final lookup = HibpPwnedPasswords(
      fetchRange: (prefix) async {
        expect(prefix, isNot(contains('secret-value')));
        expect(RegExp(r'^[0-9A-F]{5}$').hasMatch(prefix), isTrue);
        return '';
      },
    );
    await lookup.check('secret-value');
  });
}
