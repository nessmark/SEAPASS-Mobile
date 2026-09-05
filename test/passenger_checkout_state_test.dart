import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/models/passenger_booking_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PassengerDetail model and category state tests', () {
    test('Initializes with exact category and isolated TextEditingControllers', () {
      final p1 = PassengerDetail(index: 1, category: 'regular');
      final p2 = PassengerDetail(index: 2, category: 'senior');
      final p3 = PassengerDetail(index: 3, category: 'student');

      expect(p1.category, equals('regular'));
      expect(p1.categoryLabel, equals('Regular'));

      expect(p2.category, equals('senior'));
      expect(p2.categoryLabel, equals('Senior Citizen / PWD (20% Off)'));

      expect(p3.category, equals('student'));
      expect(p3.categoryLabel, equals('Student (Discounted)'));

      // Modifying p1's controller does not affect p2 or p3
      p1.givenNamesController.text = 'Jembo';
      expect(p2.givenNamesController.text, isEmpty);
      expect(p3.givenNamesController.text, isEmpty);

      p1.dispose();
      p2.dispose();
      p3.dispose();
    });

    test('deepClone creates completely independent controllers and attributes', () {
      final original = PassengerDetail(
        index: 1,
        category: 'senior',
        initialGivenNames: 'Maria',
        initialLastName: 'Santos',
        initialIdNumber: 'SENIOR-1234',
      );

      final clone = original.deepClone(newIndex: 2, newCategory: 'regular');

      expect(clone.index, equals(2));
      expect(clone.category, equals('regular'));
      expect(clone.givenNamesController.text, equals('Maria'));

      // Mutating clone controller does not mutate original controller
      clone.givenNamesController.text = 'Pedro';
      expect(original.givenNamesController.text, equals('Maria'));

      original.dispose();
      clone.dispose();
    });
  });
}
