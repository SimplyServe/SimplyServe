import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:simplyserve/recipe_page.dart';

class SpinningWheelWidget extends StatefulWidget {
  const SpinningWheelWidget({super.key});

  @override
  State<SpinningWheelWidget> createState() => _SpinningWheelWidgetState();
}

class _SpinningWheelWidgetState extends State<SpinningWheelWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Maps wheel label → RecipeModel. Add more entries here as recipes are added.
  final Map<String, RecipeModel> _recipeMap = {
    'Tuscan Salmon': kSalmonRecipe,
    'Carbonara': kCarbonaraRecipe,
    'Chicken Tacos': kChickenTacosRecipe,
  };

  List<String> get _meals => _recipeMap.keys.toList();

  String _selectedMeal = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spinWheel() {
    if (_controller.isAnimating) return;

    setState(() {
      _selectedMeal = '';
    });

    final random = math.Random();
    final spinRotations = (5 + random.nextInt(5)) * 2 * math.pi;
    final randomAngle = random.nextDouble() * 2 * math.pi;

    final currentAngle = _animation.value;
    final normalizedCurrentAngle = currentAngle % (2 * math.pi);

    final targetAngle =
        currentAngle - normalizedCurrentAngle + spinRotations + randomAngle;

    _animation = Tween<double>(begin: currentAngle, end: targetAngle).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _controller.forward(from: 0).then((_) {
      _calculateResult(targetAngle);
    });
  }

  void _calculateResult(double endAngle) {
    double theta = (1.5 * math.pi - endAngle) % (2 * math.pi);
    if (theta < 0) {
      theta += 2 * math.pi;
    }

    final sweepAngle = 2 * math.pi / _meals.length;
    final index = (theta / sweepAngle).floor();

    setState(() {
      _selectedMeal = _meals[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'What to eat?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Arrow pointing down
          const Icon(
            Icons.arrow_drop_down,
            size: 40,
            color: Color(0xFF1C2A45),
          ),

          // Wheel and Spin Button
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animation.value,
                      child: SizedBox(
                        width: 260,
                        height: 260,
                        child: CustomPaint(
                          painter: WheelPainter(_meals),
                        ),
                      ),
                    );
                  }),
              GestureDetector(
                onTap: _spinWheel,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ]),
                  alignment: Alignment.center,
                  child: const Text(
                    'SPIN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1C2A45),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          AnimatedOpacity(
            opacity: _selectedMeal.isNotEmpty ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFF74BC42).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF74BC42))),
              child: Text(
                'Selected: $_selectedMeal',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF74BC42),
                ),
              ),
            ),
          ),

          // "Go to Recipe" button — shown only when a meal has been selected
          AnimatedOpacity(
            opacity: _selectedMeal.isNotEmpty ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: _selectedMeal.isEmpty,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final recipe = _recipeMap[_selectedMeal];
                      Navigator.pushNamed(
                        context,
                        '/recipe',
                        arguments: recipe,
                      );
                    },
                    icon: const Icon(Icons.menu_book_rounded,
                        color: Colors.white),
                    label: const Text(
                      'Go to Recipe',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF74BC42),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<String> items;

  WheelPainter(this.items);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final sweepAngle = 2 * math.pi / items.length;

    for (int i = 0; i < items.length; i++) {
      final paint = Paint()
        ..color = i % 2 == 0 ? const Color(0xFF74BC42) : const Color(0xFF74BC42)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweepAngle,
        sweepAngle,
        true,
        paint,
      );

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweepAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);

      final midAngle = i * sweepAngle + sweepAngle / 2;
      final normalizedMid = midAngle % (2 * math.pi);
      final isFlipped =
          normalizedMid > math.pi / 2 && normalizedMid < 3 * math.pi / 2;

      final textPainter = TextPainter(
        text: TextSpan(
          text: items[i],
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '..',
      );
      textPainter.layout(maxWidth: radius * 0.44);

      canvas.rotate(midAngle);
      if (isFlipped) {
        canvas.rotate(math.pi);
        canvas.translate(
          -(radius * 0.55 + textPainter.width / 2),
          -textPainter.height / 2,
        );
      } else {
        canvas.translate(
          radius * 0.55 - textPainter.width / 2,
          -textPainter.height / 2,
        );
      }
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
