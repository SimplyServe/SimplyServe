import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplyserve/services/reroll_avoidance_service.dart';

void main() {
  group('RerollAvoidanceService', () {
    late RerollAvoidanceService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = RerollAvoidanceService();
    });

    group('getRolledToday', () {
      test('returns empty set when no rolls recorded', () async {
        final rolled = await service.getRolledToday();
        expect(rolled, isEmpty);
      });

      test('returns empty set when stored data is for a different day', () async {
        // Store data for a past date
        SharedPreferences.setMockInitialValues({
          'reroll_avoidance': '{"date":"2020-01-01","titles":["Pasta"]}',
        });
        service = RerollAvoidanceService();

        final rolled = await service.getRolledToday();
        expect(rolled, isEmpty);
      });
    });

    group('markRolled', () {
      test('records a recipe title', () async {
        await service.markRolled('Pasta');

        final rolled = await service.getRolledToday();
        expect(rolled, contains('Pasta'));
      });

      test('records multiple recipe titles', () async {
        await service.markRolled('Pasta');
        await service.markRolled('Salad');
        await service.markRolled('Soup');

        final rolled = await service.getRolledToday();
        expect(rolled.length, equals(3));
        expect(rolled, containsAll(['Pasta', 'Salad', 'Soup']));
      });

      test('does not create duplicate entries for same title', () async {
        await service.markRolled('Pasta');
        await service.markRolled('Pasta');

        final rolled = await service.getRolledToday();
        expect(rolled.length, equals(1));
      });
    });

    group('clearRolledToday', () {
      test('clears all rolled entries', () async {
        await service.markRolled('Pasta');
        await service.markRolled('Salad');

        await service.clearRolledToday();

        final rolled = await service.getRolledToday();
        expect(rolled, isEmpty);
      });

      test('clearing when already empty does not error', () async {
        await service.clearRolledToday();

        final rolled = await service.getRolledToday();
        expect(rolled, isEmpty);
      });
    });
  });
}
