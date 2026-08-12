import 'dart:async';
import 'package:flutter/material.dart';
import '../services/places_service.dart';

const List<String> kLocationList = [
  // O'zbekiston
  "Toshkent, O'zbekiston",
  "Samarqand, O'zbekiston",
  "Buxoro, O'zbekiston",
  "Namangan, O'zbekiston",
  "Andijon, O'zbekiston",
  "Farg'ona, O'zbekiston",
  "Nukus, O'zbekiston",
  "Qarshi, O'zbekiston",
  "Jizzax, O'zbekiston",
  "Termiz, O'zbekiston",
  "Navoiy, O'zbekiston",
  "Urganch, O'zbekiston",
  "Guliston, O'zbekiston",
  "Sirdaryo, O'zbekiston",
  "Koson, O'zbekiston",
  "Denov, O'zbekiston",
  // Rossiya
  "Moskva, Rossiya",
  "Sankt-Peterburg, Rossiya",
  "Novosibirsk, Rossiya",
  "Yekaterinburg, Rossiya",
  "Kazan, Rossiya",
  "Nijniy Novgorod, Rossiya",
  "Ufa, Rossiya",
  "Samara, Rossiya",
  "Krasnodar, Rossiya",
  "Voronej, Rossiya",
  "Perm, Rossiya",
  "Krasnoyarsk, Rossiya",
  "Omsk, Rossiya",
  // Qozog'iston
  "Almati, Qozog'iston",
  "Astana, Qozog'iston",
  "Shimkent, Qozog'iston",
  "Qaraganda, Qozog'iston",
  "Aktobe, Qozog'iston",
  "Taraz, Qozog'iston",
  // Turkiya
  "Istanbul, Turkiya",
  "Ankara, Turkiya",
  "Izmir, Turkiya",
  "Antalya, Turkiya",
  "Bursa, Turkiya",
  "Adana, Turkiya",
  // BAA
  "Dubai, BAA",
  "Abu-Dabi, BAA",
  "Sharjah, BAA",
  // Qirg'iziston
  "Bishkek, Qirg'iziston",
  "Osh, Qirg'iziston",
  // Tojikiston
  "Dushanbe, Tojikiston",
  "Xo'jand, Tojikiston",
  // Turkmaniston
  "Ashxabad, Turkmaniston",
  // Belarus
  "Minsk, Belarus",
  // Ozarbayjon
  "Boku, Ozarbayjon",
  // Gruziya
  "Tbilisi, Gruziya",
  "Batumi, Gruziya",
  // Armaniston
  "Yerevan, Armaniston",
  // Ukraina
  "Kiyev, Ukraina",
  // Moldaviya
  "Kishinyov, Moldaviya",
  // Xitoy
  "Pekin, Xitoy",
  "Shanxay, Xitoy",
  "Guangzhou, Xitoy",
  // AQSH
  "Nyu-York, AQSH",
  "Los-Anjeles, AQSH",
  "Chikago, AQSH",
  "Xouston, AQSH",
  // Buyuk Britaniya
  "London, Britaniya",
  "Manchester, Britaniya",
  // Germaniya
  "Berlin, Germaniya",
  "Myunxen, Germaniya",
  "Gamburg, Germaniya",
  // Fransiya
  "Parij, Fransiya",
  // Italiya
  "Rim, Italiya",
  "Milan, Italiya",
  // Ispaniya
  "Madrid, Ispaniya",
  "Barselona, Ispaniya",
  // Niderlandiya
  "Amsterdam, Niderlandiya",
  // Janubiy Koreya
  "Seul, Janubiy Koreya",
  // Yaponiya
  "Tokio, Yaponiya",
  // Hindiston
  "Dehli, Hindiston",
  "Mumbay, Hindiston",
  // Eron
  "Tehron, Eron",
  // Pokiston
  "Lahore, Pokiston",
  "Karachi, Pokiston",
  // Saudiya Arabistoni
  "Riyadh, Saudiya Arabistoni",
  "Jidda, Saudiya Arabistoni",
  // Malayziya
  "Kuala-Lumpur, Malayziya",
  // Indoneziya
  "Jakarta, Indoneziya",
  // Tailand
  "Bangkok, Tailand",
  // Singapur
  "Singapur",
  // Kanada
  "Toronto, Kanada",
  "Vankuver, Kanada",
  // Avstraliya
  "Sidney, Avstraliya",
  "Melburn, Avstraliya",
];

Future<String?> showLocationPicker(
  BuildContext context,
  String currentValue,
) async {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _LocationPickerSheet(currentValue: currentValue),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  final String currentValue;
  const _LocationPickerSheet({required this.currentValue});

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // When Places API is configured, show API predictions; otherwise filter local list.
  List<PlacePrediction> _apiPredictions = [];
  List<String> _localFiltered = List.from(kLocationList);
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _apiPredictions = [];
        _localFiltered = List.from(kLocationList);
        _isSearching = false;
      });
      return;
    }

    if (PlacesService.isConfigured) {
      setState(() => _isSearching = true);
      _debounce = Timer(const Duration(milliseconds: 400), () async {
        final results = await PlacesService.searchPlaces(value);
        if (!mounted) return;
        setState(() {
          _apiPredictions = results;
          _isSearching = false;
        });
      });
    } else {
      final q = value.toLowerCase();
      setState(() {
        _localFiltered = kLocationList
            .where((l) => l.toLowerCase().contains(q))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool usingApi = PlacesService.isConfigured;
    final bool hasApiResults = usingApi && _apiPredictions.isNotEmpty;
    final bool showLocal = !usingApi || (!_isSearching && !hasApiResults);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    color: Color(0xFFFF0000), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Joylashuv tanlash',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              keyboardType: TextInputType.text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: usingApi
                    ? 'Shahar qidirish... (Google Places)'
                    : 'Shahar yoki mamlakat qidiring...',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38, size: 20),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF0000),
                          ),
                        ),
                      )
                    : (_searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white38, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onQueryChanged('');
                            },
                          )
                        : null),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: _buildResults(hasApiResults, showLocal),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(bool hasApiResults, bool showLocal) {
    // API autocomplete results
    if (hasApiResults) {
      return ListView.builder(
        itemCount: _apiPredictions.length,
        itemBuilder: (context, index) {
          final pred = _apiPredictions[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined,
                color: Colors.white38, size: 20),
            title: Text(
              pred.mainText,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: pred.secondaryText.isNotEmpty
                ? Text(
                    pred.secondaryText,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                  )
                : null,
            onTap: () => Navigator.pop(context, pred.fullText),
          );
        },
      );
    }

    // Local list (fallback or no API key)
    if (showLocal) {
      if (_localFiltered.isEmpty) {
        return const Center(
          child: Text(
            'Hech narsa topilmadi',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        );
      }
      return ListView.builder(
        itemCount: _localFiltered.length,
        itemBuilder: (context, index) {
          final location = _localFiltered[index];
          final isSelected = widget.currentValue == location;
          return ListTile(
            dense: true,
            leading: Icon(
              isSelected ? Icons.location_on : Icons.location_on_outlined,
              color: isSelected ? const Color(0xFFFF0000) : Colors.white38,
              size: 20,
            ),
            title: Text(
              location,
              style: TextStyle(
                color:
                    isSelected ? const Color(0xFFFF0000) : Colors.white,
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle,
                    color: Color(0xFFFF0000), size: 18)
                : null,
            onTap: () => Navigator.pop(context, location),
          );
        },
      );
    }

    // Searching via API but no results yet
    return const SizedBox.shrink();
  }
}
