import 'package:flutter_test/flutter_test.dart';
import 'package:billsprout/utils/pin_hasher.dart';

void main() {
  group('PinHasher', () {
    test('same pin and salt produce the same hash', () {
      final salt = PinHasher.generateSalt();
      expect(PinHasher.hash('1234', salt), PinHasher.hash('1234', salt));
    });

    test('same pin with different salts produces different hashes', () {
      final a = PinHasher.hash('1234', PinHasher.generateSalt());
      final b = PinHasher.hash('1234', PinHasher.generateSalt());
      expect(a, isNot(b));
    });

    test('hash does not contain the plaintext pin', () {
      final salt = PinHasher.generateSalt();
      expect(PinHasher.hash('4821', salt).contains('4821'), isFalse);
    });

    test('verify accepts the correct pin', () {
      final salt = PinHasher.generateSalt();
      final hash = PinHasher.hash('9271', salt);
      expect(
        PinHasher.verify(pin: '9271', salt: salt, expectedHash: hash),
        isTrue,
      );
    });

    test('verify rejects the wrong pin', () {
      final salt = PinHasher.generateSalt();
      final hash = PinHasher.hash('9271', salt);
      expect(
        PinHasher.verify(pin: '9272', salt: salt, expectedHash: hash),
        isFalse,
      );
    });

    test('verify rejects an empty stored hash or salt', () {
      expect(
        PinHasher.verify(pin: '1234', salt: 'abc', expectedHash: ''),
        isFalse,
      );
      expect(
        PinHasher.verify(pin: '1234', salt: '', expectedHash: 'abc'),
        isFalse,
      );
    });

    test('salts are 32 hex characters and unique per call', () {
      final salts = List.generate(50, (_) => PinHasher.generateSalt());
      for (final s in salts) {
        expect(s, matches(RegExp(r'^[0-9a-f]{32}$')));
      }
      expect(salts.toSet().length, salts.length);
    });

    group('validateFormat', () {
      test('accepts 4 to 6 varied digits', () {
        expect(PinHasher.validateFormat('1234'), isNull);
        expect(PinHasher.validateFormat('918273'), isNull);
      });

      test('rejects wrong length', () {
        expect(PinHasher.validateFormat('123'), isNotNull);
        expect(PinHasher.validateFormat('1234567'), isNotNull);
        expect(PinHasher.validateFormat(''), isNotNull);
      });

      test('rejects non digits', () {
        expect(PinHasher.validateFormat('12a4'), isNotNull);
      });

      test('rejects a single repeated digit', () {
        expect(PinHasher.validateFormat('1111'), isNotNull);
        expect(PinHasher.validateFormat('999999'), isNotNull);
      });
    });
  });
}
