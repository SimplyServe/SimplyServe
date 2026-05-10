import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplyserve/services/private_notes_service.dart';

void main() {
  group('PrivateNotesService', () {
    late PrivateNotesService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = PrivateNotesService();
    });

    group('getNote', () {
      test('returns empty string when no note exists', () async {
        final note = await service.getNote(title: 'Pasta');
        expect(note, isEmpty);
      });

      test('returns empty string for unknown recipe id', () async {
        final note = await service.getNote(id: 999, title: 'Unknown');
        expect(note, isEmpty);
      });
    });

    group('saveNote', () {
      test('saves and retrieves a note by title', () async {
        await service.saveNote(title: 'Pasta', note: 'Add extra garlic');

        final note = await service.getNote(title: 'Pasta');
        expect(note, equals('Add extra garlic'));
      });

      test('saves and retrieves a note by id', () async {
        await service.saveNote(id: 42, title: 'Pasta', note: 'Great recipe');

        final note = await service.getNote(id: 42, title: 'Pasta');
        expect(note, equals('Great recipe'));
      });

      test('uses id-based key when id is provided', () async {
        // Save with id
        await service.saveNote(id: 1, title: 'Pasta', note: 'With id');
        // Save with title only (different key)
        await service.saveNote(title: 'Pasta', note: 'Without id');

        // They should be stored separately
        final withId = await service.getNote(id: 1, title: 'Pasta');
        final withoutId = await service.getNote(title: 'Pasta');

        expect(withId, equals('With id'));
        expect(withoutId, equals('Without id'));
      });

      test('overwrites existing note', () async {
        await service.saveNote(title: 'Soup', note: 'First note');
        await service.saveNote(title: 'Soup', note: 'Updated note');

        final note = await service.getNote(title: 'Soup');
        expect(note, equals('Updated note'));
      });

      test('removes note when saving empty/whitespace string', () async {
        await service.saveNote(title: 'Salad', note: 'Tasty');
        await service.saveNote(title: 'Salad', note: '   ');

        final note = await service.getNote(title: 'Salad');
        expect(note, isEmpty);
      });

      test('removes note when saving empty string', () async {
        await service.saveNote(title: 'Rice', note: 'Good');
        await service.saveNote(title: 'Rice', note: '');

        final note = await service.getNote(title: 'Rice');
        expect(note, isEmpty);
      });

      test('multiple recipes store independent notes', () async {
        await service.saveNote(title: 'Pasta', note: 'Note A');
        await service.saveNote(title: 'Salad', note: 'Note B');

        expect(await service.getNote(title: 'Pasta'), equals('Note A'));
        expect(await service.getNote(title: 'Salad'), equals('Note B'));
      });
    });
  });
}
