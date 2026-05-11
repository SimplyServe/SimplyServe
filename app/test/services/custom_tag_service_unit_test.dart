import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/services/custom_tag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CustomTagService Unit Tests', () {
    setUpAll(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('CustomTagService initializes correctly', () {
      final service = CustomTagService();
      expect(service, isNotNull);
    });

    test('loadTags returns empty list initially', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomTagService();
      final tags = await service.loadTags();
      expect(tags, isEmpty);
    });

    test('addTag adds new tag successfully', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomTagService();
      
      final result = await service.addTag('Paleo');
      expect(result, isTrue);
      
      final tags = await service.loadTags();
      expect(tags, contains('Paleo'));
    });

    test('addTag returns false for empty tag', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomTagService();
      
      final result = await service.addTag('');
      expect(result, isFalse);
      
      final result2 = await service.addTag('   ');
      expect(result2, isFalse);
    });

    test('addTag returns false for duplicate tag case-insensitive', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomTagService();
      
      await service.addTag('Keto');
      final result = await service.addTag('keto');
      expect(result, isFalse);
      
      final tags = await service.loadTags();
      expect(tags.length, equals(1));
    });

    test('addTag trims whitespace', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomTagService();
      
      await service.addTag('  Mediterranean  ');
      final tags = await service.loadTags();
      expect(tags.contains('Mediterranean'), isTrue);
      expect(tags.contains('  Mediterranean  '), isFalse);
    });

    test('renameTag updates tag name', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomTagService();
      
      await service.addTag('OldName');
      await service.renameTag('OldName', 'NewName');
      
      final tags = await service.loadTags();
      expect(tags, contains('NewName'));
      expect(tags, isNot(contains('OldName')));
    });

    test('renameTag does nothing for non-existent tag', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomTagService();
      
      await service.addTag('Existing');
      await service.renameTag('NonExistent', 'NewName');
      
      final tags = await service.loadTags();
      expect(tags, contains('Existing'));
      expect(tags.length, equals(1));
    });

    test('deleteTag removes tag', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomTagService();
      
      await service.addTag('TagToDelete');
      await service.deleteTag('TagToDelete');
      
      final tags = await service.loadTags();
      expect(tags, isEmpty);
    });

    test('deleteTag does nothing for non-existent tag', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomTagService();
      
      await service.addTag('ExistingTag');
      await service.deleteTag('NonExistent');
      
      final tags = await service.loadTags();
      expect(tags, contains('ExistingTag'));
      expect(tags.length, equals(1));
    });

    test('saveTags and loadTags roundtrip', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomTagService();
      
      final tagsToSave = ['Italian', 'Asian', 'Comfort Food'];
      await service.saveTags(tagsToSave);
      
      final loaded = await service.loadTags();
      expect(loaded, equals(tagsToSave));
    });

    test('multiple operations maintain state', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomTagService();
      
      await service.addTag('Tag1');
      await service.addTag('Tag2');
      await service.addTag('Tag3');
      
      await service.renameTag('Tag2', 'Tag2Renamed');
      
      await service.deleteTag('Tag3');
      
      final tags = await service.loadTags();
      expect(tags, contains('Tag1'));
      expect(tags, contains('Tag2Renamed'));
      expect(tags, isNot(contains('Tag3')));
      expect(tags.length, equals(2));
    });

    test('addTag with whitespace-only string returns false', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomTagService();
      
      final result = await service.addTag('\t\n  ');
      expect(result, isFalse);
      
      final tags = await service.loadTags();
      expect(tags, isEmpty);
    });
  });
}
