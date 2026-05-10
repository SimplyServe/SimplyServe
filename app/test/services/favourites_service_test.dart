import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplyserve/services/favourites_service.dart';

void main() {
  group('FavouritesService', () {
    late FavouritesService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = FavouritesService();
    });

    group('loadFavourites', () {
      test('returns empty set when no favourites saved', () async {
        final favourites = await service.loadFavourites();
        expect(favourites, isEmpty);
      });

      test('returns saved favourites as a set', () async {
        SharedPreferences.setMockInitialValues({
          'favourited_recipes': ['Pasta', 'Salad'],
        });
        service = FavouritesService();

        final favourites = await service.loadFavourites();
        expect(favourites, containsAll(['Pasta', 'Salad']));
        expect(favourites.length, equals(2));
      });
    });

    group('addFavourite', () {
      test('adds a recipe to favourites', () async {
        await service.addFavourite('Pasta Carbonara');

        final favourites = await service.loadFavourites();
        expect(favourites, contains('Pasta Carbonara'));
      });

      test('does not add duplicate', () async {
        await service.addFavourite('Pasta');
        await service.addFavourite('Pasta');

        final favourites = await service.loadFavourites();
        expect(favourites.length, equals(1));
      });

      test('adds multiple different recipes', () async {
        await service.addFavourite('Pasta');
        await service.addFavourite('Salad');
        await service.addFavourite('Soup');

        final favourites = await service.loadFavourites();
        expect(favourites.length, equals(3));
      });
    });

    group('removeFavourite', () {
      test('removes existing favourite', () async {
        await service.addFavourite('Pasta');
        await service.addFavourite('Salad');
        await service.removeFavourite('Pasta');

        final favourites = await service.loadFavourites();
        expect(favourites, isNot(contains('Pasta')));
        expect(favourites, contains('Salad'));
      });

      test('does nothing when removing non-existent favourite', () async {
        await service.addFavourite('Pasta');
        await service.removeFavourite('Nonexistent');

        final favourites = await service.loadFavourites();
        expect(favourites.length, equals(1));
      });
    });

    group('isFavourite', () {
      test('returns true for favourited recipe', () async {
        await service.addFavourite('Pasta');
        expect(await service.isFavourite('Pasta'), isTrue);
      });

      test('returns false for non-favourited recipe', () async {
        expect(await service.isFavourite('Unknown'), isFalse);
      });

      test('returns false after removing favourite', () async {
        await service.addFavourite('Pasta');
        await service.removeFavourite('Pasta');
        expect(await service.isFavourite('Pasta'), isFalse);
      });
    });
  });
}
