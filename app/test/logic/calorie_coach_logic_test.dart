// ignore_for_file: prefer_const_declarations

import 'package:flutter_test/flutter_test.dart';

// These functions mirror the private calculation methods in CalorieCoachView.
// Keeping them here lets us test the maths without touching the widget.

double _computeBmr(double weight, double height, int age, String gender) {
  if (gender == 'Male') {
    return 10 * weight + 6.25 * height - 5 * age + 5;
  } else {
    return 10 * weight + 6.25 * height - 5 * age - 161;
  }
}

double _computeCalorieTarget(double tdee, String goal) {
  double target;
  switch (goal) {
    case 'gain':
      target = tdee + 400;
      break;
    case 'lose':
      target = tdee - 500;
      break;
    default:
      target = tdee;
  }
  if (target < 1200) target = 1200;
  return target;
}

double _computeProteinTarget(double calories, double? weight, String? goal) {
  if (weight == null) return (calories * 0.30) / 4;
  final double gPerKg;
  switch (goal) {
    case 'lose':
      gPerKg = 2.0;
      break;
    case 'gain':
      gPerKg = 2.2;
      break;
    default:
      gPerKg = 1.8;
  }
  final proteinG = weight * gPerKg;
  final maxProteinG = (calories * 0.35) / 4;
  return proteinG < maxProteinG ? proteinG : maxProteinG;
}

double _computeFatTarget(double calories) => (calories * 0.25) / 9;

double _computeCarbTarget(double calories, double? weight, String? goal) {
  final proteinCals = _computeProteinTarget(calories, weight, goal) * 4;
  final fatCals = _computeFatTarget(calories) * 9;
  final remaining = calories - proteinCals - fatCals;
  return remaining > 0 ? remaining / 4 : 0;
}

void main() {
  group('Calorie Coach Logic Tests', () {
    group('BMR — Mifflin-St Jeor formula', () {
      test('male BMR calculated correctly', () {
        // 10*75 + 6.25*175 - 5*25 + 5 = 750 + 1093.75 - 125 + 5 = 1723.75
        expect(_computeBmr(75, 175, 25, 'Male'), closeTo(1723.75, 0.01));
      });

      test('female BMR calculated correctly', () {
        // 10*60 + 6.25*165 - 5*25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25
        expect(_computeBmr(60, 165, 25, 'Female'), closeTo(1345.25, 0.01));
      });

      test('male BMR is higher than female BMR for same stats', () {
        final male = _computeBmr(70, 170, 30, 'Male');
        final female = _computeBmr(70, 170, 30, 'Female');
        expect(male, greaterThan(female));
      });

      test('heavier person has higher BMR', () {
        final light = _computeBmr(60, 175, 25, 'Male');
        final heavy = _computeBmr(90, 175, 25, 'Male');
        expect(heavy, greaterThan(light));
      });

      test('older person has lower BMR', () {
        final young = _computeBmr(75, 175, 25, 'Male');
        final older = _computeBmr(75, 175, 45, 'Male');
        expect(older, lessThan(young));
      });

      test('taller person has higher BMR', () {
        final short = _computeBmr(70, 160, 30, 'Male');
        final tall = _computeBmr(70, 185, 30, 'Male');
        expect(tall, greaterThan(short));
      });
    });

    group('Calorie target', () {
      test('maintain returns TDEE unchanged', () {
        expect(_computeCalorieTarget(2000, 'maintain'), equals(2000));
      });

      test('gain adds 400 calorie surplus', () {
        expect(_computeCalorieTarget(2000, 'gain'), equals(2400));
      });

      test('lose subtracts 500 calorie deficit', () {
        expect(_computeCalorieTarget(2000, 'lose'), equals(1500));
      });

      test('floor is 1200 kcal even on aggressive deficit', () {
        expect(_computeCalorieTarget(1500, 'lose'), equals(1200));
        expect(_computeCalorieTarget(1000, 'lose'), equals(1200));
      });

      test('target above 1200 is not affected by floor', () {
        expect(_computeCalorieTarget(2500, 'lose'), equals(2000));
      });
    });

    group('Protein target', () {
      test('lose goal uses 2.0 g/kg', () {
        // 70 kg × 2.0 = 140 g
        expect(_computeProteinTarget(2000, 70, 'lose'), closeTo(140, 0.01));
      });

      test('gain goal uses 2.2 g/kg', () {
        // 70 kg × 2.2 = 154 g
        expect(_computeProteinTarget(2000, 70, 'gain'), closeTo(154, 0.01));
      });

      test('maintain goal uses 1.8 g/kg', () {
        // 70 kg × 1.8 = 126 g
        expect(_computeProteinTarget(2000, 70, 'maintain'), closeTo(126, 0.01));
      });

      test('protein is capped at 35% of calories', () {
        // 70 kg × 2.0 = 140 g, but cap = (1200 × 0.35) / 4 = 105 g
        expect(_computeProteinTarget(1200, 70, 'lose'), closeTo(105, 0.01));
      });

      test('falls back to 30% of calories when weight is null', () {
        // (2000 × 0.30) / 4 = 150 g
        expect(_computeProteinTarget(2000, null, 'lose'), closeTo(150, 0.01));
      });

      test('protein never exceeds 35% of calories regardless of body weight', () {
        final protein = _computeProteinTarget(1500, 100, 'gain');
        final maxAllowed = (1500 * 0.35) / 4;
        expect(protein, lessThanOrEqualTo(maxAllowed));
      });

      test('heavier person gets more protein up to the cap', () {
        final light = _computeProteinTarget(3000, 60, 'maintain');
        final heavy = _computeProteinTarget(3000, 90, 'maintain');
        expect(heavy, greaterThan(light));
      });
    });

    group('Fat target', () {
      test('fat is always 25% of calories / 9', () {
        // 2000 × 0.25 / 9 ≈ 55.56 g
        expect(_computeFatTarget(2000), closeTo(55.56, 0.01));
      });

      test('fat scales proportionally with calories', () {
        final fatLow = _computeFatTarget(1500);
        final fatHigh = _computeFatTarget(2500);
        expect(fatHigh / fatLow, closeTo(2500 / 1500, 0.01));
      });
    });

    group('Carb target', () {
      test('carbs fill the remaining calories after protein and fat', () {
        const calories = 2000.0;
        const weight = 70.0;
        const goal = 'maintain';
        final protein = _computeProteinTarget(calories, weight, goal);
        final fat = _computeFatTarget(calories);
        final carbs = _computeCarbTarget(calories, weight, goal);
        final accountedFor = (protein * 4) + (fat * 9) + (carbs * 4);
        expect(accountedFor, closeTo(calories, 1.0));
      });

      test('carb result is non-negative even with very high protein', () {
        // 150 kg gain goal → protein likely hits the 35% cap, carbs still ≥ 0
        expect(_computeCarbTarget(1200, 150, 'gain'), greaterThanOrEqualTo(0));
      });

      test('total macros always account for all calories', () {
        for (final goal in ['lose', 'maintain', 'gain']) {
          const calories = 2200.0;
          const weight = 80.0;
          final protein = _computeProteinTarget(calories, weight, goal);
          final fat = _computeFatTarget(calories);
          final carbs = _computeCarbTarget(calories, weight, goal);
          final total = (protein * 4) + (fat * 9) + (carbs * 4);
          expect(total, closeTo(calories, 1.0),
              reason: 'Total macros should equal calories for goal=$goal');
        }
      });
    });

    group('End-to-end realistic scenarios', () {
      test('70 kg male, moderately active, lose weight — sensible outputs', () {
        // BMR: Male, 30yo, 175cm, 70kg
        final bmr = _computeBmr(70, 175, 30, 'Male');
        final tdee = bmr * 1.55; // moderately active
        final calories = _computeCalorieTarget(tdee, 'lose');
        final protein = _computeProteinTarget(calories, 70, 'lose');
        final fat = _computeFatTarget(calories);
        final carbs = _computeCarbTarget(calories, 70, 'lose');

        // Protein should be ~140 g (70 kg × 2.0), not 220+ g
        expect(protein, closeTo(140, 10));
        expect(fat, greaterThan(30));
        expect(carbs, greaterThan(0));
        // Sanity: nothing absurdly large
        expect(protein, lessThan(200));
        expect(carbs, lessThan(400));
      });

      test('60 kg female, lightly active, maintain — sensible outputs', () {
        final bmr = _computeBmr(60, 165, 28, 'Female');
        final tdee = bmr * 1.375;
        final calories = _computeCalorieTarget(tdee, 'maintain');
        final protein = _computeProteinTarget(calories, 60, 'maintain');

        // 60 kg × 1.8 = 108 g protein
        expect(protein, closeTo(108, 10));
        expect(calories, greaterThan(1200));
      });

      test('calorie target with very low TDEE is floored at 1200', () {
        // Tiny BMR edge case
        final bmr = _computeBmr(40, 150, 60, 'Female');
        final tdee = bmr * 1.2; // sedentary
        final calories = _computeCalorieTarget(tdee, 'lose');
        expect(calories, greaterThanOrEqualTo(1200));
      });
    });
  });
}
