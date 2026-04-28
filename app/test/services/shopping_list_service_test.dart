import 'package:flutter_test/flutter_test.dart';
import 'package:simplyserve/services/shopping_list_service.dart';

void main() {
  group('ShoppingListService Tests', () {
    late ShoppingListService service;

    setUp(() {
      service = ShoppingListService();
      service.clearAll();
    });

    group('ShoppingItem', () {
      test('creates item with unique IDs', () {
        final item1 = ShoppingItem(name: 'Eggs');
        final item2 = ShoppingItem(name: 'Butter');
        expect(item1.id, isNot(equals(item2.id)));
      });

      test('default quantity is 1', () {
        final item = ShoppingItem(name: 'Milk');
        expect(item.quantity, equals(1));
      });

      test('stores recipeTitle in recipeTitles set', () {
        final item = ShoppingItem(name: 'Pasta', recipeTitle: 'Carbonara');
        expect(item.recipeTitles, contains('Carbonara'));
        expect(item.recipeTitles.length, equals(1));
      });

      test('no recipeTitle gives empty recipeTitles', () {
        final item = ShoppingItem(name: 'Salt');
        expect(item.recipeTitles, isEmpty);
      });
    });

    group('ShoppingRecipeEntry', () {
      test('stores plannedDate', () {
        final entry = ShoppingRecipeEntry(
          recipeTitle: 'Pasta',
          caloriesPerServing: 400,
          proteinPerServing: 20,
          carbsPerServing: 50,
          fatsPerServing: 12,
          plannedDate: DateTime(2026, 5, 10),
        );
        expect(entry.plannedDate, equals(DateTime(2026, 5, 10)));
        expect(entry.recipeTitle, equals('Pasta'));
      });

      test('plannedDate defaults to null', () {
        const entry = ShoppingRecipeEntry(
          recipeTitle: 'Salad',
          caloriesPerServing: 150,
          proteinPerServing: 5,
          carbsPerServing: 15,
          fatsPerServing: 8,
        );
        expect(entry.plannedDate, isNull);
      });
    });

    group('addIngredients', () {
      test('adds new ingredient to empty list', () {
        service.addIngredients(['Eggs'], recipeTitle: 'Omelette');
        expect(service.items.length, equals(1));
        expect(service.items.first.name, equals('Eggs'));
      });

      test('increments quantity when same ingredient added again', () {
        service.addIngredients(['Eggs'], recipeTitle: 'Omelette');
        service.addIngredients(['Eggs'], recipeTitle: 'Scrambled Eggs');
        expect(service.items.length, equals(1));
        expect(service.items.first.quantity, equals(2));
      });

      test('accumulates recipeTitles for same ingredient across multiple recipes', () {
        service.addIngredients(['Eggs'], recipeTitle: 'Omelette');
        service.addIngredients(['Eggs'], recipeTitle: 'Scrambled Eggs');
        expect(
          service.items.first.recipeTitles,
          containsAll(['Omelette', 'Scrambled Eggs']),
        );
      });

      test('item in two recipes has two recipeTitles (common ingredient)', () {
        service.addIngredients(['Flour'], recipeTitle: 'Bread');
        service.addIngredients(['Flour'], recipeTitle: 'Pizza');
        expect(service.items.first.recipeTitles.length, equals(2));
      });

      test('item in one recipe has one recipeTitle', () {
        service.addIngredients(['Yeast'], recipeTitle: 'Bread');
        expect(service.items.first.recipeTitles.length, equals(1));
      });

      test('adds separate items for distinct ingredient names', () {
        service.addIngredients(['Eggs', 'Butter'], recipeTitle: 'Omelette');
        expect(service.items.length, equals(2));
      });

      test('deduplication is case-insensitive', () {
        service.addIngredients(['eggs'], recipeTitle: 'Omelette');
        service.addIngredients(['Eggs'], recipeTitle: 'Scrambled Eggs');
        expect(service.items.length, equals(1));
      });

      test('trims whitespace from ingredient names', () {
        service.addIngredients(['  Eggs  '], recipeTitle: 'Omelette');
        expect(service.items.first.name, equals('Eggs'));
      });

      test('ignores blank or whitespace-only ingredient names', () {
        service.addIngredients(['', '  ', 'Eggs']);
        expect(service.items.length, equals(1));
      });

      test('adds ingredient with no recipe title', () {
        service.addIngredients(['Salt']);
        expect(service.items.first.recipeTitles, isEmpty);
      });
    });

    group('removeItem', () {
      test('removes item by id', () {
        service.addIngredients(['Eggs']);
        final id = service.items.first.id;
        service.removeItem(id);
        expect(service.items, isEmpty);
      });

      test('does nothing for unknown id', () {
        service.addIngredients(['Eggs']);
        service.removeItem('nonexistent-id');
        expect(service.items.length, equals(1));
      });
    });

    group('updateQuantity', () {
      test('updates quantity for known id', () {
        service.addIngredients(['Eggs']);
        final id = service.items.first.id;
        service.updateQuantity(id, 5);
        expect(service.items.first.quantity, equals(5));
      });

      test('removes item when quantity set to 0', () {
        service.addIngredients(['Eggs']);
        final id = service.items.first.id;
        service.updateQuantity(id, 0);
        expect(service.items, isEmpty);
      });

      test('removes item when quantity set to negative', () {
        service.addIngredients(['Eggs']);
        final id = service.items.first.id;
        service.updateQuantity(id, -1);
        expect(service.items, isEmpty);
      });
    });

    group('addRecipe', () {
      test('adds recipe with plannedDate', () {
        service.addRecipe(ShoppingRecipeEntry(
          recipeTitle: 'Pasta',
          caloriesPerServing: 400,
          proteinPerServing: 20,
          carbsPerServing: 50,
          fatsPerServing: 12,
          plannedDate: DateTime(2026, 5, 1),
        ));
        expect(service.recipes.length, equals(1));
        expect(service.recipes.first.plannedDate, equals(DateTime(2026, 5, 1)));
      });

      test('does not add duplicate recipes by title', () {
        const entry = ShoppingRecipeEntry(
          recipeTitle: 'Pasta',
          caloriesPerServing: 400,
          proteinPerServing: 20,
          carbsPerServing: 50,
          fatsPerServing: 12,
        );
        service.addRecipe(entry);
        service.addRecipe(entry);
        expect(service.recipes.length, equals(1));
      });

      test('deduplication of recipe titles is case-insensitive', () {
        service.addRecipe(const ShoppingRecipeEntry(
          recipeTitle: 'pasta',
          caloriesPerServing: 400,
          proteinPerServing: 20,
          carbsPerServing: 50,
          fatsPerServing: 12,
        ));
        service.addRecipe(const ShoppingRecipeEntry(
          recipeTitle: 'Pasta',
          caloriesPerServing: 400,
          proteinPerServing: 20,
          carbsPerServing: 50,
          fatsPerServing: 12,
        ));
        expect(service.recipes.length, equals(1));
      });
    });

    group('clearAll', () {
      test('clears all items and recipes', () {
        service.addIngredients(['Eggs'], recipeTitle: 'Omelette');
        service.addRecipe(const ShoppingRecipeEntry(
          recipeTitle: 'Omelette',
          caloriesPerServing: 300,
          proteinPerServing: 15,
          carbsPerServing: 20,
          fatsPerServing: 10,
        ));
        service.clearAll();
        expect(service.items, isEmpty);
        expect(service.recipes, isEmpty);
      });
    });

    group('Common ingredient grouping logic', () {
      test('three recipes sharing one ingredient: recipeTitles has three entries', () {
        service.addIngredients(['Salt'], recipeTitle: 'Soup');
        service.addIngredients(['Salt'], recipeTitle: 'Bread');
        service.addIngredients(['Salt'], recipeTitle: 'Pasta');
        final item = service.items.first;
        expect(item.recipeTitles.length, equals(3));
      });

      test('unique ingredients per recipe stay separate', () {
        service.addIngredients(['Egg'], recipeTitle: 'Omelette');
        service.addIngredients(['Chicken'], recipeTitle: 'Stir Fry');
        expect(service.items.length, equals(2));
        for (final item in service.items) {
          expect(item.recipeTitles.length, equals(1));
        }
      });

      test('mixed scenario: one common, two unique', () {
        service.addIngredients(['Olive Oil', 'Garlic'], recipeTitle: 'Pasta');
        service.addIngredients(['Olive Oil', 'Tomato'], recipeTitle: 'Pizza');
        expect(service.items.length, equals(3));
        final oliveOil =
            service.items.firstWhere((i) => i.name == 'Olive Oil');
        expect(oliveOil.recipeTitles.length, equals(2));
      });
    });

    group('Recipe date ordering (data layer)', () {
      test('recipes with earlier plannedDate should sort before later ones', () {
        final earlier = ShoppingRecipeEntry(
          recipeTitle: 'Soup',
          caloriesPerServing: 200,
          proteinPerServing: 10,
          carbsPerServing: 20,
          fatsPerServing: 5,
          plannedDate: DateTime(2026, 5, 1),
        );
        final later = ShoppingRecipeEntry(
          recipeTitle: 'Steak',
          caloriesPerServing: 600,
          proteinPerServing: 50,
          carbsPerServing: 5,
          fatsPerServing: 30,
          plannedDate: DateTime(2026, 5, 5),
        );
        service.addRecipe(later);
        service.addRecipe(earlier);

        final sorted = List.of(service.recipes)
          ..sort((a, b) {
            if (a.plannedDate == null && b.plannedDate == null) return 0;
            if (a.plannedDate == null) return 1;
            if (b.plannedDate == null) return -1;
            return a.plannedDate!.compareTo(b.plannedDate!);
          });

        expect(sorted.first.recipeTitle, equals('Soup'));
        expect(sorted.last.recipeTitle, equals('Steak'));
      });

      test('recipe without plannedDate sorts after dated recipes', () {
        final dated = ShoppingRecipeEntry(
          recipeTitle: 'Salad',
          caloriesPerServing: 150,
          proteinPerServing: 5,
          carbsPerServing: 10,
          fatsPerServing: 7,
          plannedDate: DateTime(2026, 5, 3),
        );
        const undated = ShoppingRecipeEntry(
          recipeTitle: 'Snack',
          caloriesPerServing: 100,
          proteinPerServing: 2,
          carbsPerServing: 15,
          fatsPerServing: 3,
        );
        service.addRecipe(undated);
        service.addRecipe(dated);

        final sorted = List.of(service.recipes)
          ..sort((a, b) {
            if (a.plannedDate == null && b.plannedDate == null) return 0;
            if (a.plannedDate == null) return 1;
            if (b.plannedDate == null) return -1;
            return a.plannedDate!.compareTo(b.plannedDate!);
          });

        expect(sorted.first.recipeTitle, equals('Salad'));
        expect(sorted.last.recipeTitle, equals('Snack'));
      });
    });
  });
}
