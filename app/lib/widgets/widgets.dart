import 'package:flutter/material.dart';

class AppNavigation extends StatelessWidget {
  final String bannerText;
  const AppNavigation({super.key, required this.bannerText});

  void _placeholderCallbackForButtons() {}

  Widget _navTextButton(BuildContext context, String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        // changed WidgetStateProperty -> MaterialStateProperty
        padding: MaterialStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        foregroundColor: MaterialStateProperty.all(Colors.grey[800]),
        textStyle: MaterialStateProperty.resolveWith<TextStyle?>(
          (states) {
            // changed WidgetState -> MaterialState
            final hovered = states.contains(MaterialState.hovered);
            return TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              decoration: hovered ? TextDecoration.underline : TextDecoration.none,
              decorationThickness: hovered ? 1.4 : 0,
            );
          },
        ),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints){
        final showFullNav = constraints.maxWidth > 900;
        
        return Container(
          height: 60,
          color: Colors.white,
          child: Column(
            children: [
              // Top banner
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                    },
                    child: Image.asset(
                      'assets/image.png',
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          width: 40,
                          height: 40,
                          child: const Center(
                            child: Icon(Icons.image_not_supported, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  // Centered nav buttons
                  if (showFullNav)
                     Expanded(
                       child: Center(
                         child: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             _navTextButton(context, 'Home', () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false)),
                             const SizedBox(width: 12),
                             _navTextButton(context, 'holder', () => Navigator.pushNamed(context, '/holder')),
                             const SizedBox(width: 12),
                             _navTextButton(context, 'About', () => Navigator.pushNamed(context, '/holder')),
                             
                           ],
                         ),
                       ),
                     )
                  else
                    // show a compact popup menu on small screens
                    PopupMenuButton<int>(
                      icon: const Icon(Icons.menu, color: Colors.grey),
                      onSelected: (value) {
                        if (value == 0) Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                        if (value == 1) Navigator.pushNamed(context, '/holder');
                        if (value == 2) Navigator.pushNamed(context, '/holder');
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 0, child: Text('Home')),
                        PopupMenuItem(value: 1, child: Text('Holder')),
                        PopupMenuItem(value: 2, child: Text('About')),
                      ],
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search, size: 18, color: Colors.grey),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: _placeholderCallbackForButtons,
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => Navigator.pushNamed(context, '/login'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.grey),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => Navigator.pushNamed(context, '/cart'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      }
    );
  }
}