import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:swastik_mobile_app/core/utils/time_utils.dart';

/// Result returned when the user applies a custom filter.
class CustomFilterResult {
  /// 'date', 'date_range', or 'month_year'
  final String type;

  /// Only set when type == 'date' or 'date_range'
  final DateTime? date;

  /// Only set when type == 'date_range'
  final DateTime? endDate;

  /// 1‑12, set for 'month_year'
  final int? month;

  /// Set for 'month_year'
  final int? year;

  const CustomFilterResult({
    required this.type,
    this.date,
    this.endDate,
    this.month,
    this.year,
  });

  /// Human‑readable label for the filter chip / button.
  String get displayLabel {
    switch (type) {
      case 'date':
        if (date != null) return DateFormat('dd MMM yyyy').format(date!);
        return 'Custom Date';
      case 'date_range':
        if (date != null && endDate != null) {
          return '${DateFormat('dd MMM').format(date!)} - ${DateFormat('dd MMM').format(endDate!)}';
        }
        return 'Custom Range';
      case 'month_year':
        if (month != null && year != null) {
          return '${DateFormat.MMMM().format(DateTime(0, month!))} $year';
        }
        return 'Custom Month';
      default:
        return 'Custom';
    }
  }
}

/// A premium bottom sheet that lets the user pick a Date or a Month & Year
/// for filtering transactions.
class CustomFilterSheet extends StatefulWidget {
  /// Optional initial values so the sheet can restore a previous selection.
  final CustomFilterResult? initial;

  const CustomFilterSheet({super.key, this.initial});

  @override
  State<CustomFilterSheet> createState() => _CustomFilterSheetState();
}

class _CustomFilterSheetState extends State<CustomFilterSheet>
    with SingleTickerProviderStateMixin {
  // ── Design tokens ──────────────────────────────────────────────
  static const _teal = Color(0xFF01565B);
  static const _gold = Color(0xFFDFBA6B);
  static const _darkGold = Color(0xFF735C0F);
  static const _beige = Color(0xFFFAF6EE);
  static const _cardBorder = Color(0xFFE5DEC9);
  static const _textDark = Color(0xFF4A3E1F);

  late TabController _tabController;

  // ── State ──────────────────────────────────────────────────────
  DateTime _selectedDate = TimeUtils.now;
  DateTime? _selectedEndDate;
  bool _isDateRange = false;
  bool _selectingStartDate = true;

  late DateTime _currentMonth;

  int _selectedMonth = TimeUtils.now.month;
  int _selectedYear = TimeUtils.now.year;

  static const List<String> _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    // Reduced length to 2
    _tabController = TabController(length: 2, vsync: this);

    _currentMonth = DateTime(TimeUtils.now.year, TimeUtils.now.month);

    // Restore previous selection
    final init = widget.initial;
    if (init != null) {
      switch (init.type) {
        case 'date':
          _tabController.index = 0;
          if (init.date != null) {
            _selectedDate = init.date!;
            _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
          }
          break;
        case 'date_range':
          _tabController.index = 0;
          _isDateRange = true;
          if (init.date != null) _selectedDate = init.date!;
          if (init.endDate != null) _selectedEndDate = init.endDate!;
          _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
          break;
        case 'month_year':
          _tabController.index = 1;
          if (init.month != null) _selectedMonth = init.month!;
          if (init.year != null) _selectedYear = init.year!;
          break;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: _teal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Custom Filter',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
            ),

            // Segmented Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: _beige,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  onTap: (_) => setState(() {}),
                  indicator: BoxDecoration(
                    color: _teal,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: _teal.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: _darkGold,
                  labelStyle: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Date'),
                    Tab(text: 'Month & Year'),
                  ],
                ),
              ),
            ),

            // Content
            SizedBox(
              height: 440,
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildDateTab(),
                  _buildMonthYearTab(),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.montserrat(
                          color: _darkGold,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _onApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        elevation: 3,
                        shadowColor: _teal.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Apply Filter',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date Tab ───────────────────────────────────────────────────
  Widget _buildDateTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Single / Multiple Day Toggle
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _beige,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDateRange = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isDateRange ? _teal : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Single Day',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: !_isDateRange ? FontWeight.bold : FontWeight.w600,
                          color: !_isDateRange ? Colors.white : _darkGold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDateRange = true;
                        _selectedEndDate ??= _selectedDate.add(const Duration(days: 1));
                        _selectingStartDate = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isDateRange ? _teal : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Multiple Days',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: _isDateRange ? FontWeight.bold : FontWeight.w600,
                          color: _isDateRange ? Colors.white : _darkGold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Selected date chip(s)
          if (!_isDateRange)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _teal.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: _teal),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _teal,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectingStartDate = true),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectingStartDate ? _teal.withOpacity(0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectingStartDate ? _teal.withOpacity(0.3) : _cardBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Start Date',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _selectingStartDate ? _teal : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd MMM yyyy').format(_selectedDate),
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectingStartDate ? _teal : _textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectingStartDate = false),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: !_selectingStartDate ? _teal.withOpacity(0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !_selectingStartDate ? _teal.withOpacity(0.3) : _cardBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'End Date',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: !_selectingStartDate ? _teal : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedEndDate != null
                                ? DateFormat('dd MMM yyyy').format(_selectedEndDate!)
                                : 'Select',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !_selectingStartDate ? _teal : _textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

          Expanded(
            child: _buildCustomCalendar(),
          ),
        ],
      ),
    );
  }

  // ── Custom Calendar Logic ──────────────────────────────────────
  Widget _buildCustomCalendar() {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstDayOffset = DateTime(year, month, 1).weekday % 7; // Sunday=0

    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_currentMonth),
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down_rounded, color: Colors.grey[600], size: 20),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: _textDark),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(year, month - 1);
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: _textDark),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(year, month + 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Weekdays
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays.map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textDark,
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
        // Grid
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: firstDayOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return const SizedBox.shrink();

              final day = index - firstDayOffset + 1;
              final date = DateTime(year, month, day);

              return _buildCalendarCell(date);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCell(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final normalizedEnd = _selectedEndDate != null
        ? DateTime(_selectedEndDate!.year, _selectedEndDate!.month, _selectedEndDate!.day)
        : null;

    bool isStart = normalizedDate.isAtSameMomentAs(normalizedStart);
    bool isEnd = _isDateRange && normalizedEnd != null && normalizedDate.isAtSameMomentAs(normalizedEnd);
    bool isSingle = !_isDateRange || (isStart && normalizedEnd == null) || (isStart && isEnd);

    bool inRange = false;
    if (_isDateRange && normalizedEnd != null) {
      if (normalizedDate.isAfter(normalizedStart) && normalizedDate.isBefore(normalizedEnd)) {
        inRange = true;
      }
    }

    bool isSelected = isStart || isEnd;

    Widget cellContent = Center(
      child: Text(
        '${date.day}',
        style: GoogleFonts.montserrat(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : (inRange ? _teal : _textDark),
        ),
      ),
    );

    if (isSingle && isSelected) {
      return GestureDetector(
        onTap: () => _onDateSelected(date),
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: _teal,
            shape: BoxShape.circle,
          ),
          child: cellContent,
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onDateSelected(date),
      child: Stack(
        children: [
          if (inRange || (isSelected && !isSingle))
            Positioned.fill(
              top: 6,
              bottom: 6,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      color: (isEnd || inRange) ? _teal.withOpacity(0.15) : Colors.transparent,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: (isStart || inRange) ? _teal.withOpacity(0.15) : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: _teal,
                shape: BoxShape.circle,
              ),
              child: cellContent,
            )
          else
            Container(
              margin: const EdgeInsets.all(6),
              child: cellContent,
            ),
        ],
      ),
    );
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      if (!_isDateRange) {
        _selectedDate = date;
      } else {
        if (_selectingStartDate) {
          _selectedDate = date;
          if (_selectedEndDate != null && _selectedDate.isAfter(_selectedEndDate!)) {
            _selectedEndDate = _selectedDate.add(const Duration(days: 1));
          }
        } else {
          _selectedEndDate = date;
          if (_selectedDate.isAfter(_selectedEndDate!)) {
            _selectedDate = _selectedEndDate!.subtract(const Duration(days: 1));
          }
        }
      }
    });
  }

  // ── Month & Year Tab ───────────────────────────────────────────
  Widget _buildMonthYearTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Year Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _beige,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _yearArrow(Icons.chevron_left_rounded, -1, isMonthYear: true),
                Text(
                  '$_selectedYear',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _darkGold,
                  ),
                ),
                _yearArrow(Icons.chevron_right_rounded, 1, isMonthYear: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Month Grid
          Expanded(
            child: _buildMonthGrid(_selectedMonth, (m) {
              setState(() => _selectedMonth = m);
            }),
          ),
        ],
      ),
    );
  }

  // ── Shared: Month Grid ─────────────────────────────────────────
  Widget _buildMonthGrid(int selectedMonth, ValueChanged<int> onSelect) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1;
        final isSelected = month == selectedMonth;
        final isCurrentMonth = month == TimeUtils.now.month;

        return GestureDetector(
          onTap: () => onSelect(month),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? _teal
                  : isCurrentMonth
                      ? _teal.withOpacity(0.06)
                      : _beige,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? _teal
                    : isCurrentMonth
                        ? _teal.withOpacity(0.3)
                        : _cardBorder,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _teal.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              _monthLabels[index],
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : _textDark,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Shared: Year Arrow ─────────────────────────────────────────
  Widget _yearArrow(IconData icon, int delta, {required bool isMonthYear}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            if (isMonthYear) {
              _selectedYear += delta;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _teal, size: 22),
        ),
      ),
    );
  }

  // ── Apply ──────────────────────────────────────────────────────
  void _onApply() {
    CustomFilterResult result;

    switch (_tabController.index) {
      case 0:
        if (_isDateRange) {
          result = CustomFilterResult(
            type: 'date_range',
            date: _selectedDate,
            endDate: _selectedEndDate ?? _selectedDate,
          );
        } else {
          result = CustomFilterResult(type: 'date', date: _selectedDate);
        }
        break;
      case 1:
        result = CustomFilterResult(
          type: 'month_year',
          month: _selectedMonth,
          year: _selectedYear,
        );
        break;
      default:
        result = CustomFilterResult(type: 'date', date: _selectedDate);
    }

    Navigator.pop(context, result);
  }
}