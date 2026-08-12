import sys

def patch():
    with open('lib/screens/history_screen.dart', 'r') as f:
        content = f.read()

    new_methods = """
  Widget _buildEmptyFilteredState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Bu filtr bo\\'yicha video topilmadi',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _statusFilter = 'All';
                _timeFilter = 'All';
                _customDateRange = null;
                _selectedChannels.clear();
                _sortFilter = 'Newest';
              });
            },
            icon: const Icon(Icons.clear_all, color: Colors.redAccent),
            label: const Text('Filterni tozalash', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    List<Widget> chips = [];

    Widget buildChip(String label, Color color, VoidCallback onRemove) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close, size: 14, color: color),
              ),
            ],
          ),
        ),
      );
    }

    if (_statusFilter != 'All') {
      String label = '';
      Color color = Colors.white;
      if (_statusFilter == 'Uploaded') { label = '✅ Yuklangan'; color = Colors.greenAccent; }
      else if (_statusFilter == 'Deleted') { label = '❌ O\\'chirilgan'; color = Colors.redAccent; }
      else if (_statusFilter == 'Processing') { label = '⏳ Jarayonda'; color = Colors.orangeAccent; }
      else if (_statusFilter == 'NotUploaded') { label = '📂 Yuklanmagan'; color = Colors.grey; }
      chips.add(buildChip(label, color, () => setState(() => _statusFilter = 'All')));
    }

    if (_timeFilter != 'All') {
      String label = '';
      if (_timeFilter == 'Today') label = '📅 Bugun';
      else if (_timeFilter == 'ThisWeek') label = '📅 Bu hafta';
      else if (_timeFilter == 'ThisMonth') label = '📅 Bu oy';
      else if (_timeFilter == 'ThisYear') label = '📅 Bu yil';
      else if (_timeFilter == 'Custom') label = '📅 Tanlangan sana';
      chips.add(buildChip(label, Colors.blueAccent, () => setState(() { _timeFilter = 'All'; _customDateRange = null; })));
    }

    if (_sortFilter != 'Newest') {
      String label = '';
      if (_sortFilter == 'Oldest') label = '🕐 Eski';
      else if (_sortFilter == 'Largest') label = '📦 Katta';
      else if (_sortFilter == 'Smallest') label = '📦 Kichik';
      chips.add(buildChip(label, Colors.purpleAccent, () => setState(() => _sortFilter = 'Newest')));
    }

    for (String channel in _selectedChannels) {
      chips.add(buildChip('📺 $channel', Colors.orange, () => setState(() => _selectedChannels.remove(channel))));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF1A1A1A),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: chips,
      ),
    );
  }

  void _openFilterBottomSheet() {
    String tempStatus = _statusFilter;
    String tempTime = _timeFilter;
    DateTimeRange? tempCustomDateRange = _customDateRange;
    List<String> tempChannels = List.from(_selectedChannels);
    String tempSort = _sortFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Widget buildSectionTitle(String title) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              );
            }

            Widget buildRadioButton(String title, String value, String groupValue, ValueChanged<String?> onChanged) {
              final isSelected = value == groupValue;
              return InkWell(
                onTap: () => onChanged(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? Colors.redAccent : Colors.white30, size: 20),
                      const SizedBox(width: 12),
                      Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              );
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, controller) {
                return Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('🔽 Filtr', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempStatus = 'All';
                                tempTime = 'All';
                                tempCustomDateRange = null;
                                tempChannels.clear();
                                tempSort = 'Newest';
                              });
                            },
                            child: const Text('Tozalash', style: TextStyle(color: Colors.white54)),
                          )
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: ListView(
                        controller: controller,
                        children: [
                          const SizedBox(height: 8),
                          buildSectionTitle('Video holati'),
                          buildRadioButton('📱 Barchasi', 'All', tempStatus, (v) => setModalState(() => tempStatus = v!)),
                          buildRadioButton('✅ Yuklangan', 'Uploaded', tempStatus, (v) => setModalState(() => tempStatus = v!)),
                          buildRadioButton('❌ O\\'chirilgan', 'Deleted', tempStatus, (v) => setModalState(() => tempStatus = v!)),
                          buildRadioButton('⏳ Jarayonda', 'Processing', tempStatus, (v) => setModalState(() => tempStatus = v!)),
                          buildRadioButton('📂 Yuklanmagan', 'NotUploaded', tempStatus, (v) => setModalState(() => tempStatus = v!)),
                          const Divider(color: Colors.white10, height: 24),
                          
                          buildSectionTitle('Vaqt bo\\'yicha'),
                          buildRadioButton('📅 Barchasi', 'All', tempTime, (v) => setModalState(() => tempTime = v!)),
                          buildRadioButton('📅 Bugun', 'Today', tempTime, (v) => setModalState(() => tempTime = v!)),
                          buildRadioButton('📅 Bu hafta', 'ThisWeek', tempTime, (v) => setModalState(() => tempTime = v!)),
                          buildRadioButton('📅 Bu oy', 'ThisMonth', tempTime, (v) => setModalState(() => tempTime = v!)),
                          buildRadioButton('📅 Bu yil', 'ThisYear', tempTime, (v) => setModalState(() => tempTime = v!)),
                          buildRadioButton('📅 Sana tanlash', 'Custom', tempTime, (v) async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) => Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(primary: Colors.redAccent, onPrimary: Colors.white, surface: Color(0xFF1E1E1E), onSurface: Colors.white),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setModalState(() {
                                tempTime = 'Custom';
                                tempCustomDateRange = picked;
                              });
                            }
                          }),
                          const Divider(color: Colors.white10, height: 24),

                          buildSectionTitle('Kanal bo\\'yicha'),
                          Consumer<SettingsProvider>(
                            builder: (context, settings, _) {
                              return Wrap(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                spacing: 8,
                                children: settings.channels.map((ch) {
                                  final isSelected = tempChannels.contains(ch.name);
                                  return ChoiceChip(
                                    label: Text(ch.name),
                                    selected: isSelected,
                                    selectedColor: Colors.orange.withOpacity(0.3),
                                    backgroundColor: Colors.white10,
                                    labelStyle: TextStyle(color: isSelected ? Colors.orangeAccent : Colors.white70, fontSize: 12),
                                    side: BorderSide(color: isSelected ? Colors.orange : Colors.transparent),
                                    onSelected: (val) {
                                      setModalState(() {
                                        if (val) tempChannels.add(ch.name);
                                        else tempChannels.remove(ch.name);
                                      });
                                    },
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const Divider(color: Colors.white10, height: 24),

                          buildSectionTitle('Tartib bo\\'yicha'),
                          buildRadioButton('🕐 Yangi', 'Newest', tempSort, (v) => setModalState(() => tempSort = v!)),
                          buildRadioButton('🕐 Eski', 'Oldest', tempSort, (v) => setModalState(() => tempSort = v!)),
                          buildRadioButton('📦 Katta', 'Largest', tempSort, (v) => setModalState(() => tempSort = v!)),
                          buildRadioButton('📦 Kichik', 'Smallest', tempSort, (v) => setModalState(() => tempSort = v!)),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    // Footer Apply button
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              _statusFilter = tempStatus;
                              _timeFilter = tempTime;
                              _customDateRange = tempCustomDateRange;
                              _selectedChannels = tempChannels;
                              _sortFilter = tempSort;
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Filterni qo\\'llash', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
"""

    parts = content.rsplit('}', 2)
    final_content = parts[0] + '}' + new_methods + '}' + parts[2]
    
    with open('lib/screens/history_screen.dart', 'w') as f:
        f.write(final_content)

patch()
