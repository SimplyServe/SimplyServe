import 'package:flutter/material.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/widgets/navbar.dart';

// Simple in-memory meal calendar. Persist as needed.
class MealCalendarView extends StatefulWidget {
  const MealCalendarView({super.key});

  @override
  State<MealCalendarView> createState() => _MealCalendarViewState();
}

class _MealCalendarViewState extends State<MealCalendarView> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  // Key: yyyy-MM-dd, Value: list of recipes scheduled for that day
  final Map<String, List<RecipeModel>> _scheduled = {};

  // Use the hardcoded recipe constants from recipe_page.dart
  List<RecipeModel> get _availableRecipes => [
        kSalmonRecipe,
        kChickenTacosRecipe,
        kCarbonaraRecipe,
        kBeefStirFryRecipe,
        kMasalaDaalRecipe,
      ];

  String _dayKey(DateTime d) => "${d.year.toString().padLeft(4, '0')}-"
      "${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";

  void _addOrRemoveRecipe(String key, RecipeModel r) {
    final list = _scheduled[key] ?? <RecipeModel>[];
    final idx = list.indexWhere((e) => e.title == r.title);
    setState(() {
      if (idx >= 0) {
        list.removeAt(idx);
      } else {
        list.add(r);
      }
      if (list.isEmpty) {
        _scheduled.remove(key);
      } else {
        _scheduled[key] = list;
      }
    });
  }

  void _openDaySheet(DateTime day) {
    final key = _dayKey(day);
    final scheduled = List<RecipeModel>.from(_scheduled[key] ?? []);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          bool isSelected(RecipeModel r) =>
              scheduled.any((s) => s.title == r.title);

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 6,
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          "${day.day} ${_monthName(day.month)} ${day.year}",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _scheduled.remove(key);
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Clear'),
                        )
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: _availableRecipes.map((r) {
                        final selected = isSelected(r);
                        return ListTile(
                          leading: SizedBox(
                            width: 40,
                            height: 30,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                r.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: Colors.grey[200]),
                              ),
                            ),
                          ),
                          title: Text(r.title),
                          subtitle: Text(r.totalTime),
                          trailing: IconButton(
                            icon: Icon(
                                selected ? Icons.check_box : Icons.check_box_outline_blank,
                                color: selected ? const Color(0xFF74BC42) : null),
                            onPressed: () {
                              setModalState(() {
                                if (selected) {
                                  scheduled.removeWhere((s) => s.title == r.title);
                                } else {
                                  scheduled.add(r);
                                }
                              });
                              // keep sheet open but reflect change in parent state as well
                              setState(() {
                                if (scheduled.isEmpty) {
                                  _scheduled.remove(key);
                                } else {
                                  _scheduled[key] = List.from(scheduled);
                                }
                              });
                            },
                          ),
                          onTap: () {
                            // toggle
                            setModalState(() {
                              if (selected) {
                                scheduled.removeWhere((s) => s.title == r.title);
                              } else {
                                scheduled.add(r);
                              }
                            });
                            setState(() {
                              if (scheduled.isEmpty) {
                                _scheduled.remove(key);
                              } else {
                                _scheduled[key] = List.from(scheduled);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  String _monthName(int m) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[m];
  }

  @override
  Widget build(BuildContext context) {
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final first = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final startWeekday = first.weekday % 7; // Make Sunday=0
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return NavBarScaffold(
      title: 'Meal Calendar',
      // Changed to SingleChildScrollView + shrink-wrapped GridView so content
      // fits on one scrollable page instead of using Expanded.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Month header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                    });
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      "${_monthName(month)} ${year}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Weekday labels
            Row(
              children: const [
                Expanded(child: Center(child: Text('Sun'))),
                Expanded(child: Center(child: Text('Mon'))),
                Expanded(child: Center(child: Text('Tue'))),
                Expanded(child: Center(child: Text('Wed'))),
                Expanded(child: Center(child: Text('Thu'))),
                Expanded(child: Center(child: Text('Fri'))),
                Expanded(child: Center(child: Text('Sat'))),
              ],
            ),
            const SizedBox(height: 8),

            // Calendar grid (shrink-wrapped so it lives inside the scroll view)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: rows * 7,
              itemBuilder: (context, index) {
                final dayIndex = index - startWeekday + 1;
                final inMonth = dayIndex >= 1 && dayIndex <= daysInMonth;
                if (!inMonth) {
                  return Container(); // empty cell
                }
                final day = DateTime(year, month, dayIndex);
                final key = _dayKey(day);
                final scheduled = _scheduled[key] ?? [];
                return GestureDetector(
                  onTap: () => _openDaySheet(day),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$dayIndex',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (day.day == DateTime.now().day &&
                                      day.month == DateTime.now().month &&
                                      day.year == DateTime.now().year)
                                  ? const Color(0xFF74BC42)
                                  : Colors.black),
                        ),
                        const Spacer(),
                        if (scheduled.isNotEmpty)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF74BC42),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${scheduled.length} recipe${scheduled.length > 1 ? 's' : ''}',
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Quick summary of today's schedule
            Card(
              child: ListTile(
                title: const Text('Today'),
                subtitle: Text(
                  '${_scheduled[_dayKey(DateTime.now())]?.length ?? 0} recipe(s) planned',
                ),
                trailing: TextButton(
                  onPressed: () => _openDaySheet(DateTime.now()),
                  child: const Text('Manage'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}