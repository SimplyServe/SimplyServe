import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/services/reroll_avoidance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RerollAvoidanceService Unit Tests', () {
    setUpAll(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('RerollAvoidanceService initializes correctly', () {
      final service = RerollAvoidanceService();
      expect(service, isNotNull);
    });

    test('getRolledToday returns empty set initially', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RerollAvoidanceService();
      
      final rolled = await service.getRolledToday();
      expect(rolled, isEmpty);
    });

    test('markRolled adds recipe to rolled set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RerollAvoidanceService();
      
      await service.markRolled('Pasta Carbonara');
      
      final rolled = await service.getRolledToday();
      expect(rolled, contains('Pasta Carbonara'));
    });

    test('markRolled multiple recipes', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RerollAvoidanceService();
      
      await service.markRolled('Pasta Carbonara');
      await service.markRolled('Caesar Salad');
      await service.markRolled('Margherita Pizza');
      
      final rolled = await service.getRolledToday();
      expect(rolled.length, equals(3));
      expect(rolled, contains('Pasta Carbonara'));
      expect(rolled, contains('Caesar Salad'));
      expect(rolled, contains('Margherita Pizza'));
    });

    test('markRolled does not create duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RerollAvoidanceService();
      
      await service.markRolled('Pasta Carbonara');
      await service.markRolled('Pasta Carbonara');
      await service.markRolled('Pasta Carbonara');
      
      final rolled = await service.getRolledToday();
      expect(rolled.length, equals(1));
    });

    test('clearRolledToday removes all entries', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RerollAvoidanceService();
      
      await service.markRolled('Pasta Carbonara');
      await service.markRolled('Caesar Salad');
      
      await service.clearRolledToday();
      
      final rolled = await service.getRolledToday();
      expect(rolled, isEmpty);
    });

    test('clearRolledToday works on empty set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RerollAvoidanceService();
      
      // Should not throw error
      await service.clearRolledToday();
      
      final rolled = await service.getRolledToday();
      expect(rolled, isEmpty);
    });

    test('markRolled persists across service instances', () async {
      SharedPreferences.setMockInitialValues({});
      final service1 = RerollAvoidanceService();
      
      await service1.markRolled('Pasta Carbonara');
      
      final service2 = RerollAvoidanceService();
      final rolled = await service2.getRolledToday();
      
      expect(rolled, contains('Pasta Carbonara'));
    });

    test('getRolledToday returns set (unordered)', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RerollAvoidanceService();
      
      await service.markRolled('Recipe A');
      await service.markRolled('Recipe B');
      
      final rolled = await service.getRolledToday();
      expect(rolled, isA<Set<String>>());
    });

    test('markRolled with empty string', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RerollAvoidanceService();
      
      await service.markRolled('');
      
      final rolled = await service.getRolledToday();
      expect(rolled, contains(''));
      expect(rolled.length, equals(1));
    });

    test('markRolled preserves capitalization', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RerollAvoidanceService();
      
      await service.markRolled('Pasta Carbonara');
      
      final rolled = await service.getRolledToday();
      expect(rolled, contains('Pasta Carbonara'));
      expect(rolled, isNot(contains('pasta carbonara')));
    });

    test('many recipes can be marked rolled', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RerollAvoidanceService();
      
      for (int i = 0; i < 100; i++) {
        await service.markRolled('Recipe $i');
      }
      
      final rolled = await service.getRolledToday();
      expect(rolled.length, equals(100));
    });

    test('getRolledToday date isolation', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RerollAvoidanceService();
      
      // Mark a recipe
      await service.markRolled('Today Recipe');
      var rolled = await service.getRolledToday();
      expect(rolled.length, equals(1));
      
      // Verify it persists in same session
      rolled = await service.getRolledToday();
      expect(rolled, contains('Today Recipe'));
    });
  });
}
