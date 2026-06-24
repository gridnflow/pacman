import 'package:chompire/game/fruit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase-6 unit tests: bonus-fruit score tiers and spawn thresholds
/// (requirements §6.4). Pure data, no Flame needed.
void main() {
  group('fruitPointsForLevel (§6.4)', () {
    test('matches the canonical per-band tier table', () {
      expect(fruitPointsForLevel(1), 100);
      expect(fruitPointsForLevel(2), 300);
      expect(fruitPointsForLevel(3), 500);
      expect(fruitPointsForLevel(4), 500);
      expect(fruitPointsForLevel(5), 700);
      expect(fruitPointsForLevel(6), 700);
      expect(fruitPointsForLevel(7), 1000);
      expect(fruitPointsForLevel(8), 1000);
      expect(fruitPointsForLevel(9), 2000);
      expect(fruitPointsForLevel(10), 2000);
      expect(fruitPointsForLevel(11), 3000);
      expect(fruitPointsForLevel(12), 3000);
      expect(fruitPointsForLevel(13), 5000);
      expect(fruitPointsForLevel(50), 5000);
    });

    test('levels below 1 clamp to the L1 tier', () {
      expect(fruitPointsForLevel(0), 100);
      expect(fruitPointsForLevel(-5), 100);
    });
  });

  group('fruit spawn thresholds (§6.4)', () {
    test('two appearances at 70 and 170 dots', () {
      expect(kFruitDotThresholds, [70, 170]);
    });

    test('lingers for 9.5 seconds and spawns just below the house', () {
      expect(kFruitLifetimeSeconds, 9.5);
      expect(kFruitTile.col, 13);
      expect(kFruitTile.row, 17);
    });
  });
}
