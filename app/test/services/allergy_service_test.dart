import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplyserve/services/allergy_service.dart';

void main() {
  group('AllergyService', () {
    late AllergyService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = AllergyService();
    });

    group('loadAllergies', () {
      test('returns empty list when no allergies saved', () async {
        final allergies = await service.loadAllergies();
        expect(allergies, isEmpty);
      });

      test('returns saved allergies', () async {
        SharedPreferences.setMockInitialValues({
          'user_allergies': ['Gluten', 'Dairy'],
        });
        service = AllergyService();

        final allergies = await service.loadAllergies();
        expect(allergies, containsAll(['Gluten', 'Dairy']));
      });

      test('normalizes loaded allergies by removing duplicates', () async {
        SharedPreferences.setMockInitialValues({
          'user_allergies': ['gluten', 'Gluten', 'GLUTEN'],
        });
        service = AllergyService();

        final allergies = await service.loadAllergies();
        expect(allergies.length, equals(1));
      });

      test('removes empty strings when loading', () async {
        SharedPreferences.setMockInitialValues({
          'user_allergies': ['Gluten', '', '  ', 'Dairy'],
        });
        service = AllergyService();

        final allergies = await service.loadAllergies();
        expect(allergies.length, equals(2));
        expect(allergies, containsAll(['Gluten', 'Dairy']));
      });
    });

    group('saveAllergies', () {
      test('saves and loads allergies', () async {
        await service.saveAllergies(['Eggs', 'Peanuts']);

        final loaded = await service.loadAllergies();
        expect(loaded, containsAll(['Eggs', 'Peanuts']));
      });

      test('normalizes before saving (removes duplicates)', () async {
        await service.saveAllergies(['dairy', 'Dairy', 'DAIRY']);

        final loaded = await service.loadAllergies();
        expect(loaded.length, equals(1));
      });

      test('trims whitespace when saving', () async {
        await service.saveAllergies(['  Gluten  ', '  Dairy  ']);

        final loaded = await service.loadAllergies();
        expect(loaded, containsAll(['Gluten', 'Dairy']));
      });

      test('filters out empty entries when saving', () async {
        await service.saveAllergies(['Gluten', '', '  ', 'Dairy']);

        final loaded = await service.loadAllergies();
        expect(loaded.length, equals(2));
      });

      test('overwrites previous allergies', () async {
        await service.saveAllergies(['Gluten', 'Dairy']);
        await service.saveAllergies(['Fish']);

        final loaded = await service.loadAllergies();
        expect(loaded.length, equals(1));
        expect(loaded.first, equals('Fish'));
      });

      test('saving empty list clears allergies', () async {
        await service.saveAllergies(['Gluten']);
        await service.saveAllergies([]);

        final loaded = await service.loadAllergies();
        expect(loaded, isEmpty);
      });
    });
  });
}
