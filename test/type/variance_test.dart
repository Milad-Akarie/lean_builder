import 'package:lean_builder/src/type/variance.dart';
import 'package:test/test.dart';

void main() {
  group('Variance', () {
    group('isCovariant', () {
      test('returns true for covariant', () {
        expect(Variance.covariant.isCovariant, isTrue);
      });

      test('returns false for other variances', () {
        expect(Variance.contravariant.isCovariant, isFalse);
        expect(Variance.invariant.isCovariant, isFalse);
        expect(Variance.unrelated.isCovariant, isFalse);
      });
    });

    group('isContravariant', () {
      test('returns true for contravariant', () {
        expect(Variance.contravariant.isContravariant, isTrue);
      });

      test('returns false for other variances', () {
        expect(Variance.covariant.isContravariant, isFalse);
        expect(Variance.invariant.isContravariant, isFalse);
        expect(Variance.unrelated.isContravariant, isFalse);
      });
    });

    group('isInvariant', () {
      test('returns true for invariant', () {
        expect(Variance.invariant.isInvariant, isTrue);
      });

      test('returns false for other variances', () {
        expect(Variance.covariant.isInvariant, isFalse);
        expect(Variance.contravariant.isInvariant, isFalse);
        expect(Variance.unrelated.isInvariant, isFalse);
      });
    });

    group('isUnrelated', () {
      test('returns true for unrelated', () {
        expect(Variance.unrelated.isUnrelated, isTrue);
      });

      test('returns false for other variances', () {
        expect(Variance.covariant.isUnrelated, isFalse);
        expect(Variance.contravariant.isUnrelated, isFalse);
        expect(Variance.invariant.isUnrelated, isFalse);
      });
    });

    group('combine', () {
      test('returns unrelated when either variance is unrelated', () {
        expect(Variance.unrelated.combine(Variance.covariant), Variance.unrelated);
        expect(Variance.covariant.combine(Variance.unrelated), Variance.unrelated);
        expect(Variance.unrelated.combine(Variance.unrelated), Variance.unrelated);
      });

      test('returns invariant when either variance is invariant', () {
        expect(Variance.invariant.combine(Variance.covariant), Variance.invariant);
        expect(Variance.covariant.combine(Variance.invariant), Variance.invariant);
      });

      test('returns covariant when both are covariant', () {
        expect(Variance.covariant.combine(Variance.covariant), Variance.covariant);
      });

      test('returns covariant when both are contravariant', () {
        expect(Variance.contravariant.combine(Variance.contravariant), Variance.covariant);
      });

      test('returns contravariant when variances differ', () {
        expect(Variance.covariant.combine(Variance.contravariant), Variance.contravariant);
        expect(Variance.contravariant.combine(Variance.covariant), Variance.contravariant);
      });
    });

    group('meet', () {
      test('returns invariant when either variance is invariant', () {
        expect(Variance.invariant.meet(Variance.covariant), Variance.invariant);
        expect(Variance.covariant.meet(Variance.invariant), Variance.invariant);
      });

      test('returns same variance when both are equal', () {
        expect(Variance.covariant.meet(Variance.covariant), Variance.covariant);
        expect(Variance.contravariant.meet(Variance.contravariant), Variance.contravariant);
      });

      test('returns other when one is unrelated', () {
        expect(Variance.unrelated.meet(Variance.covariant), Variance.covariant);
        expect(Variance.covariant.meet(Variance.unrelated), Variance.covariant);
      });

      test('returns invariant when variances differ', () {
        expect(Variance.covariant.meet(Variance.contravariant), Variance.invariant);
        expect(Variance.contravariant.meet(Variance.covariant), Variance.invariant);
      });
    });

    group('toKeywordString', () {
      test('returns correct keyword for each variance', () {
        expect(Variance.contravariant.toKeywordString(), 'in');
        expect(Variance.invariant.toKeywordString(), 'inout');
        expect(Variance.covariant.toKeywordString(), 'out');
        expect(Variance.unrelated.toKeywordString(), '');
      });
    });

    group('fromKeywordString', () {
      test('returns correct variance for each keyword', () {
        expect(Variance.fromKeywordString('in'), Variance.contravariant);
        expect(Variance.fromKeywordString('inout'), Variance.invariant);
        expect(Variance.fromKeywordString('out'), Variance.covariant);
        expect(Variance.fromKeywordString(''), Variance.unrelated);
      });

      test('throws ArgumentError for invalid keyword', () {
        expect(() => Variance.fromKeywordString('invalid'), throwsArgumentError);
      });
    });
  });
}
