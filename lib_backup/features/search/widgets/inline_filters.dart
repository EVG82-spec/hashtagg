import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Встроенные фильтры для экрана поиска
class InlineFilters extends StatefulWidget {
  final Map<String, dynamic>? filterData;
  final Map<String, bool> options;
  final Map<String, List<String>> selectedFilters;
  final TextEditingController priceFromController;
  final TextEditingController priceToController;
  final Function(String key, bool value) onOptionChanged;
  final Function(String filterId, String itemId, bool isSelected) onFilterChanged;
  final VoidCallback onFiltersUpdated;
  final VoidCallback onPriceChanged; // Новый callback для изменения цены

  const InlineFilters({
    super.key,
    required this.filterData,
    required this.options,
    required this.selectedFilters,
    required this.priceFromController,
    required this.priceToController,
    required this.onOptionChanged,
    required this.onFilterChanged,
    required this.onFiltersUpdated,
    required this.onPriceChanged,
  });

  @override
  State<InlineFilters> createState() => _InlineFiltersState();
}

class _InlineFiltersState extends State<InlineFilters> {
  bool _showAllFilters = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    
    if (widget.filterData == null) {
      return const SizedBox.shrink();
    }

    final filterOptions = widget.filterData!['options'] as Map<String, dynamic>?;
    final filters = widget.filterData!['filters'] as List?;
    
    // Проверяем, есть ли дополнительные фильтры
    final hasAdditionalFilters = (filterOptions != null && filterOptions.isNotEmpty) ||
                                  (filters != null && filters.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок "Цена"
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Text(
            'Цена',
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        
        // Строка с ценой и кнопкой "Еще" (1fr 1fr 0.3fr)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          child: Row(
            children: [
              // Цена От (1fr)
              Expanded(
                child: _PriceField(
                  controller: widget.priceFromController,
                  hint: 'От',
                  isDark: isDark,
                  onChanged: widget.onPriceChanged,
                ),
              ),
              const SizedBox(width: 12),
              // Цена До (1fr)
              Expanded(
                child: _PriceField(
                  controller: widget.priceToController,
                  hint: 'До',
                  isDark: isDark,
                  onChanged: widget.onPriceChanged,
                ),
              ),
              // Кнопка "Еще" (0.3fr) - только если есть дополнительные фильтры
              if (hasAdditionalFilters) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAllFilters = !_showAllFilters;
                    });
                  },
                  child: Container(
                    width: 70,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff233040) : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Еще',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _showAllFilters ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: isDark ? Colors.white : Colors.black,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Остальные фильтры (скрыты по умолчанию)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _showAllFilters
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Options (VIP, secure, etc.)
                    if (filterOptions != null && filterOptions.isNotEmpty) ...[
                      for (var entry in filterOptions.entries) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              Switch(
                                value: widget.options[entry.key] ?? false,
                                onChanged: (v) => widget.onOptionChanged(entry.key, v),
                                activeColor: const Color(0xff917dfa),
                                inactiveThumbColor: isDark ? Colors.white70 : Colors.grey,
                                inactiveTrackColor: isDark ? const Color(0xff233040) : Colors.grey[300],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],

                    // Dynamic filters
                    if (filters != null && filters.isNotEmpty) ...[
                      for (var filter in filters) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                filter['name'] + (filter['required'] == true ? ' *' : ''),
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                              
                              if (filter['view'] == 'select') ...[
                                _buildSelectFilter(context, filter, isDark, textColor),
                              ] else if (filter['view'] == 'select_multi') ...[
                                _buildCheckboxFilter(context, filter, isDark),
                              ] else if (filter['view'] == 'checkbox') ...[
                                _buildCheckboxFilter(context, filter, isDark),
                              ] else if (filter['view'] == 'input') ...[
                                _buildInputFilter(context, filter, isDark, textColor),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSelectFilter(BuildContext context, Map<String, dynamic> filter, bool isDark, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff233040) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: widget.selectedFilters[filter['id'].toString()]?.firstOrNull,
          dropdownColor: isDark ? const Color(0xff233040) : Colors.white,
          hint: Row(
            children: [
              Expanded(
                child: Text(
                  'Выберите ${filter['name'].toLowerCase()}',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: const Color(0xff999999),
                  ),
                ),
              ),
              if (filter['podfilter'] == true)
                const Icon(
                  Icons.filter_list,
                  size: 16,
                  color: Color(0xff917dfa),
                ),
            ],
          ),
          isExpanded: true,
          items: (filter['items'] as List).map<DropdownMenuItem<String>>((item) {
            return DropdownMenuItem<String>(
              value: item['id'].toString(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item['name'],
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (item['podfilter'] == true)
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Color(0xff917dfa),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              widget.onFilterChanged(filter['id'].toString(), value, false);
              if (filter['podfilter'] == true) {
                widget.onFiltersUpdated();
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildCheckboxFilter(BuildContext context, Map<String, dynamic> filter, bool isDark) {
    final items = filter['items'] as List?;
    print('🔵 [InlineFilters] _buildCheckboxFilter for ${filter['name']}, items count: ${items?.length ?? 0}');
    
    if (items == null || items.isEmpty) {
      print('⚠️ [InlineFilters] No items for filter ${filter['name']}');
      return const SizedBox.shrink();
    }
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map<Widget>((item) {
        final filterId = filter['id'].toString();
        final itemId = item['id'].toString();
        final isSelected = widget.selectedFilters[filterId]?.contains(itemId) ?? false;
        
        print('🔵 [InlineFilters] Item: ${item['name']}, id: $itemId, selected: $isSelected');
        
        return GestureDetector(
          onTap: () => widget.onFilterChanged(filterId, itemId, isSelected),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xff917dfa)
                  : (isDark ? const Color(0xff233040) : const Color(0xFFF5F7FA)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item['name'],
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputFilter(BuildContext context, Map<String, dynamic> filter, bool isDark, Color textColor) {
    return TextField(
      controller: TextEditingController(
        text: widget.selectedFilters[filter['id'].toString()]?.firstOrNull ?? '',
      ),
      onChanged: (value) {
        widget.onFilterChanged(filter['id'].toString(), value, false);
        widget.onPriceChanged(); // Используем тот же debounce callback
      },
      style: GoogleFonts.montserrat(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xff233040) : const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintText: 'Введите ${filter['name'].toLowerCase()}',
        hintStyle: GoogleFonts.montserrat(
          color: const Color(0xff999999),
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final VoidCallback onChanged;

  const _PriceField({
    required this.controller,
    required this.hint,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => onChanged(),
      style: GoogleFonts.montserrat(
        fontSize: 14,
        color: isDark ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xff233040) : const Color(0xFFF5F7FA),
        hintText: hint,
        hintStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: const Color(0xff999999),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
