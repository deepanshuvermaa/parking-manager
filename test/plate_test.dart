import 'package:flutter_test/flutter_test.dart';
import 'package:parkease_manager/utils/plate.dart';

void main() {
  group('normalizePlate', () {
    test('strips separators and folds case', () {
      expect(normalizePlate(' up-32 ab 1234 '), 'UP32AB1234');
      expect(normalizePlate('UP32AB1234'), 'UP32AB1234');
      expect(normalizePlate('UP.32.AB.1234'), 'UP32AB1234');
    });

    test('empty and separator-only input collapses to empty', () {
      expect(normalizePlate(''), '');
      expect(normalizePlate('   - . '), '');
    });
  });

  group('isSamePlate', () {
    test('treats spacing and case variants as one vehicle', () {
      expect(isSamePlate('UP 32 AB 1234', 'up32ab1234'), isTrue);
    });

    test('does not collapse genuinely different plates', () {
      expect(isSamePlate('UP32AB1234', 'UP32AB1235'), isFalse);
    });
  });

  group('plateContains', () {
    test('finds a spaced plate from an unspaced query', () {
      expect(plateContains('UP 32 AB 1234', 'UP32AB'), isTrue);
    });

    test('empty query matches everything', () {
      expect(plateContains('UP32AB1234', ''), isTrue);
    });

    test('non-matching query is rejected', () {
      expect(plateContains('UP32AB1234', 'MH12'), isFalse);
    });
  });

  group('validatePlate', () {
    test('rejects empty', () {
      expect(validatePlate('  '), isNotNull);
    });

    test('rejects too-short entries after normalising', () {
      expect(validatePlate('U-P'), isNotNull);
    });

    test('accepts a realistic plate', () {
      expect(validatePlate('UP 32 AB 1234'), isNull);
    });

    test('accepts short-but-plausible informal identifiers', () {
      expect(validatePlate('FHJG'), isNull);
    });
  });
}
