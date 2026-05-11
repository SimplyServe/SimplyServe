import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/services/allergy_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AllergyService Unit Tests', () {
    setUpAll(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('AllergyService initializes correctly', () {
      final service = AllergyService();
      expect(service, isNotNull);
    });

    test('loadAllergies returns empty list for new service', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AllergyService();
      final allergies = await service.loadAllergies();
      expect(allergies, isEmpty);
    });

    test('saveAllergies and loadAllergies roundtrip', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AllergyService();
      
      final testAllergies = ['Peanuts', 'Dairy', 'Shellfish'];
      await service.saveAllergies(testAllergies);
      
      final loaded = await service.loadAllergies();
      expect(loaded, contains('Peanuts'));
      expect(loaded, contains('Dairy'));
      expect(loaded, contains('Shellfish'));
    });

    test('saveAllergies deduplicates case-insensitive', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AllergyService();
      
      final testAllergies = ['Peanuts', 'peanuts', 'PEANUTS'];
      await service.saveAllergies(testAllergies);
      
      final loaded = await service.loadAllergies();
      expect(loaded.where((a) => a.toLowerCase() == 'peanuts').length, equals(1));
    });

    test('saveAllergies trims whitespace', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AllergyService();
      
      final testAllergies = ['  Peanuts  ', '\tDairy\t', '\nFish\n'];
      await service.saveAllergies(testAllergies);
      
      final loaded = await service.loadAllergies();
      expect(loaded, contains('Peanuts'));
      expect(loaded, contains('Dairy'));
      expect(loaded, contains('Fish'));
    });

    test('saveAllergies removes empty strings', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AllergyService();
      
      final testAllergies = ['Peanuts', '', '   ', 'Dairy'];
      await service.saveAllergies(testAllergies);
      
      final loaded = await service.loadAllergies();
      expect(loaded.length, equals(2));
      expect(loaded, contains('Peanuts'));
      expect(loaded, contains('Dairy'));
    });

    test('saveAllergies with empty list', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AllergyService();
      
      await service.saveAllergies([]);
      final loaded = await service.loadAllergies();
      expect(loaded, isEmpty);
    });

    test('loadAllergies preserves capitalization', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AllergyService();
      
      final testAllergies = ['Peanuts', 'Dairy'];
      await service.saveAllergies(testAllergies);
      
      final loaded = await service.loadAllergies();
      expect(loaded.first, equals('Peanuts'));
    });
  });
}
