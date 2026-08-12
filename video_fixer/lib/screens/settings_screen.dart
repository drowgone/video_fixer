import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/youtube_account.dart';
import '../services/settings_provider.dart';
import '../services/youtube_uploader.dart';
import '../utils/youtube_validator.dart';
import '../utils/location_data.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _sttApiKeyController;
  late TextEditingController _sttEndpointController;
  bool _sttEnabledLocal = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    _sttApiKeyController = TextEditingController(text: provider.sttApiKey);
    _sttEndpointController = TextEditingController(text: provider.sttEndpoint);
    _sttEnabledLocal = provider.sttEnabled;
  }

  @override
  void dispose() {
    _sttApiKeyController.dispose();
    _sttEndpointController.dispose();
    super.dispose();
  }

  Future<void> _connectAccount() async {
    try {
      final newAccounts = await YouTubeUploader.connectAndFetchChannels(context);
      if (!mounted) return;
      final provider = Provider.of<SettingsProvider>(context, listen: false);

      int added = 0;
      int updated = 0;
      for (var newAccount in newAccounts) {
        final existingIndex =
            provider.accounts.indexWhere((a) => a.channelId == newAccount.channelId);
        if (existingIndex >= 0) {
          final updatedAccount = provider.accounts[existingIndex].copyWith(
            name: newAccount.name,
            channelProfilePic: newAccount.channelProfilePic,
            channelId: newAccount.channelId,
            connectionDate: newAccount.connectionDate,
            status: 'active',
            subscriberCount: newAccount.subscriberCount,
            videoCount: newAccount.videoCount,
          );
          await provider.updateAccount(updatedAccount);
          updated++;
        } else {
          await provider.addAccount(newAccount);
          added++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("✅ Kanallar ulandi! Yangilandi: $updated, Qo'shildi: $added"),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Xatolik: $e')));
    }
  }

  void _showChannelSettingsDialog(YouTubeAccount account) async {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final settings = await provider.getChannelSettings(account.channelId);
    if (!mounted) return;

    String desc = settings['description'] ?? '';
    final hashes = settings['hashtags'] ?? '';
    if (hashes.isNotEmpty && !desc.contains(hashes)) {
      desc = desc.isEmpty ? hashes : '$desc\n\n$hashes';
    }

    final titleController = TextEditingController(text: settings['titleTemplate']);
    final descController = HashtagHighlightController()..text = desc;
    final tagsController = TextEditingController(text: settings['tags']);
    final locationController = TextEditingController(text: settings['location']);

    String selectedPrivacy = settings['privacy'] ?? 'public';
    String selectedCategory = settings['category'] ?? '22';
    bool isMadeForKids = (settings['audience'] ?? 'false') == 'true';
    String selectedLang = settings['language'] ?? 'uz';
    List<String> sheetErrors = [];

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final titleVal = YouTubeInputValidator.validateTitle(titleController.text);
            final descVal = YouTubeInputValidator.validateDescription(descController.text);
            final tagsList = tagsController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            final tagsVal = YouTubeInputValidator.validateTags(tagsList);

            Future<void> importJson() async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                );
                if (!ctx.mounted) return;
                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);
                  final jsonString = await file.readAsString();
                  if (!ctx.mounted) return;
                  final Map<String, dynamic> data = json.decode(jsonString);
                  setSheetState(() {
                    if (data.containsKey('titleTemplate')) {
                      titleController.text = data['titleTemplate'].toString();
                    }
                    if (data.containsKey('description')) {
                      descController.text = data['description'].toString();
                    }
                    if (data.containsKey('tags')) {
                      tagsController.text = data['tags'].toString();
                    }
                    if (data.containsKey('location')) {
                      locationController.text = data['location'].toString();
                    }
                    if (data.containsKey('privacy')) {
                      final p = data['privacy'].toString().toLowerCase();
                      if (['public', 'unlisted', 'private'].contains(p)) {
                        selectedPrivacy = p;
                      }
                    }
                    if (data.containsKey('category')) {
                      selectedCategory = data['category'].toString();
                    }
                    if (data.containsKey('audience')) {
                      isMadeForKids = data['audience'].toString() == 'true';
                    }
                    if (data.containsKey('language')) {
                      selectedLang = data['language'].toString().toLowerCase();
                    }
                  });
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('✅ JSON muvaffaqiyatli import qilindi!'),
                      backgroundColor: Colors.green,
                    ));
                  }
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('❌ Import xatosi: $e'),
                    backgroundColor: Colors.redAccent,
                  ));
                }
              }
            }

            Future<void> saveSettings() async {
              final tVal = YouTubeInputValidator.validateTitle(titleController.text);
              final dVal = YouTubeInputValidator.validateDescription(descController.text);
              final tgsList = tagsController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final tgVal = YouTubeInputValidator.validateTags(tgsList);

              final errors = <String>[];
              if (!tVal['valid']) errors.add('Sarlavha: ${tVal['message']}');
              if (!dVal['valid']) errors.add('Tavsif: ${dVal['message']}');
              if (!tgVal['valid']) errors.add('Teglar: ${tgVal['message']}');

              if (errors.isNotEmpty) {
                setSheetState(() => sheetErrors = errors);
                return;
              }

              final cleanDesc = YouTubeInputValidator.deduplicateDescription(descController.text);
              await provider.saveChannelSettings(account.channelId, {
                'titleTemplate': titleController.text.trim(),
                'description': cleanDesc,
                'tags': tagsController.text.trim(),
                'hashtags': '',
                'privacy': selectedPrivacy,
                'category': selectedCategory,
                'audience': isMadeForKids.toString(),
                'language': selectedLang,
                'location': locationController.text.trim(),
              });
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('✅ Kanal sozlamalari saqlandi!'),
                ));
              }
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.92,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (sheetCtx, scrollController) {
                final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: account.channelProfilePic != null
                                ? NetworkImage(account.channelProfilePic!)
                                : null,
                            radius: 18,
                            backgroundColor: const Color(0xFF2A2A2A),
                            child: account.channelProfilePic == null
                                ? const Icon(Icons.video_camera_front,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Kanal Sozlamalari',
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white38, size: 22),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    // Scrollable form
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + bottomInset),
                        children: [
                          // JSON import
                          OutlinedButton.icon(
                            onPressed: importJson,
                            icon: const Icon(Icons.file_open,
                                color: Colors.blueAccent, size: 16),
                            label: const Text('JSON dan import qilish',
                                style: TextStyle(
                                    color: Colors.blueAccent, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.blueAccent),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Validation errors
                          if (sheetErrors.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.1),
                                border: Border.all(
                                    color:
                                        Colors.redAccent.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.warning,
                                          color: Colors.redAccent, size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        "Quyidagilarni to'g'rilang:",
                                        style: TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ...sheetErrors.map((e) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 3),
                                        child: Text('• $e',
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12)),
                                      )),
                                ],
                              ),
                            ),
                          ],

                          // Title
                          _sectionLabel('Sarlavha Shablon', Icons.title),
                          const SizedBox(height: 6),
                          _settingsTextField(
                            controller: titleController,
                            hint: 'Default sarlavha...',
                            onChanged: (_) => setSheetState(() {}),
                          ),
                          YouTubeValidationFeedback(
                            validation: titleVal,
                            currentLength: titleController.text.length,
                            maxLength: 100,
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 4, bottom: 2),
                            child: Text(
                              'O\'zgaruvchilar: {filename} — fayl nomi, {title} — fayl nomi, {date} — sana (YYYY-MM-DD), {index} — tartib raqam',
                              style: TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Description
                          _sectionLabel('Tavsif', Icons.description_outlined),
                          const SizedBox(height: 6),
                          _settingsTextField(
                            controller: descController,
                            hint: 'Default tavsif va #hashtaglar...',
                            maxLines: 4,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                          YouTubeValidationFeedback(
                            validation: descVal,
                            currentLength: descController.text.length,
                            maxLength: 5000,
                          ),
                          const SizedBox(height: 16),

                          // Tags
                          _sectionLabel(
                              'Teglar (vergul bilan ajratilib)', Icons.tag),
                          const SizedBox(height: 6),
                          TagChipInput(
                            tags: tagsController.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList(),
                            onChanged: (newTagsList) {
                              setSheetState(() {
                                tagsController.text = newTagsList.join(', ');
                              });
                            },
                          ),
                          YouTubeValidationFeedback(
                            validation: tagsVal,
                            currentLength: tagsController.text.length,
                            maxLength: 500,
                          ),
                          const SizedBox(height: 16),

                          // Privacy
                          _sectionLabel(
                              'Maxfiylik (Privacy)', Icons.lock_outline),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'public',
                                  label: Text('Public',
                                      style: TextStyle(fontSize: 12))),
                              ButtonSegment(
                                  value: 'unlisted',
                                  label: Text('Unlisted',
                                      style: TextStyle(fontSize: 12))),
                              ButtonSegment(
                                  value: 'private',
                                  label: Text('Private',
                                      style: TextStyle(fontSize: 12))),
                            ],
                            selected: {selectedPrivacy},
                            onSelectionChanged: (s) =>
                                setSheetState(() => selectedPrivacy = s.first),
                          ),
                          const SizedBox(height: 16),

                          // Category
                          _sectionLabel(
                              'Toifa (Category)', Icons.category_outlined),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: ValueKey(selectedCategory),
                            initialValue: selectedCategory,
                            dropdownColor: const Color(0xFF2A2A2A),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            decoration: _settingsDropdownDecoration(),
                            items: const [
                              DropdownMenuItem(
                                  value: '24',
                                  child: Text("Entertainment (Ko'ngilochar)")),
                              DropdownMenuItem(
                                  value: '27',
                                  child: Text("Education (Ta'lim)")),
                              DropdownMenuItem(
                                  value: '20',
                                  child: Text("Gaming (O'yinlar)")),
                              DropdownMenuItem(
                                  value: '10',
                                  child: Text('Music (Musiqa)')),
                              DropdownMenuItem(
                                  value: '22',
                                  child: Text('People & Blogs (Bloglar)')),
                              DropdownMenuItem(
                                  value: '1',
                                  child: Text('Film & Animation')),
                              DropdownMenuItem(
                                  value: '28',
                                  child: Text('Science & Tech')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() => selectedCategory = val);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Language
                          _sectionLabel('Video Tili (Language)', Icons.language),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: ValueKey(selectedLang),
                            initialValue: selectedLang,
                            dropdownColor: const Color(0xFF2A2A2A),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            decoration: _settingsDropdownDecoration(),
                            items: const [
                              DropdownMenuItem(
                                  value: 'uz', child: Text("O'zbekcha")),
                              DropdownMenuItem(
                                  value: 'ru', child: Text('Ruscha')),
                              DropdownMenuItem(
                                  value: 'en', child: Text('Inglizcha')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() => selectedLang = val);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Location picker
                          _sectionLabel(
                              'Joylashuv (Location)', Icons.location_on_outlined),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showLocationPicker(
                                  context, locationController.text);
                              if (picked != null) {
                                setSheetState(
                                    () => locationController.text = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Color(0xFFFF0000), size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      locationController.text.isEmpty
                                          ? 'Joylashuvni tanlang...'
                                          : locationController.text,
                                      style: TextStyle(
                                        color: locationController.text.isEmpty
                                            ? Colors.white38
                                            : Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (locationController.text.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => setSheetState(
                                          () => locationController.text = ''),
                                      child: const Icon(Icons.close,
                                          color: Colors.white38, size: 16),
                                    )
                                  else
                                    const Icon(Icons.arrow_forward_ios,
                                        color: Colors.white24, size: 14),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Made for kids
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SwitchListTile(
                              title: const Text(
                                  'Bolalar uchun (Made for Kids)',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14)),
                              value: isMadeForKids,
                              activeThumbColor: const Color(0xFFFF0000),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              onChanged: (val) =>
                                  setSheetState(() => isMadeForKids = val),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Save button — disabled when tags exceed 500 chars
                          Builder(
                            builder: (context) {
                              final tagsCharsLen = tagsController.text
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .join(',')
                                  .length;
                              final saveable = tagsCharsLen <= 500;
                              return SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: saveable
                                        ? const Color(0xFFFF0000)
                                        : Colors.grey.shade700,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: saveable ? saveSettings : null,
                                  child: const Text(
                                    'Saqlash',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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

    titleController.dispose();
    descController.dispose();
    tagsController.dispose();
    locationController.dispose();
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  Widget _settingsTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      maxLines: maxLines,
      keyboardType: TextInputType.text,
      autocorrect: false,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF0000)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  InputDecoration _settingsDropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF0000)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }

  Widget _buildGoogleConnectButton() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF202124),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              onPressed: _connectAccount,
              icon: Image.asset(
                'assets/google_logo.png',
                width: 22,
                height: 22,
                errorBuilder: (c, e, s) => Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              label: const Text(
                'Google orqali ulash',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 13, color: Colors.white24),
              SizedBox(width: 4),
              Text(
                'Ulanish faqat yuklash uchun ishlatiladi',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('YouTube Sozlamalari',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF0000)));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'YouTube Kanallari',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (provider.accounts.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 24, bottom: 16),
                  child: Center(
                    child: Text(
                      'Ulanishlar topilmadi.\nGoogle orqali kanalni ulashingiz mumkin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 15, height: 1.4),
                    ),
                  ),
                ),
                _buildGoogleConnectButton(),
              ] else ...[
                ...provider.accounts.map((account) {
                  return Card(
                    color: const Color(0xFF161616),
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.white10, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 23,
                                backgroundColor: const Color(0xFF2A2A2A),
                                backgroundImage: account.channelProfilePic != null
                                    ? NetworkImage(account.channelProfilePic!)
                                    : null,
                                child: account.channelProfilePic == null
                                    ? const Icon(Icons.video_camera_front, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            account.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (account.status == 'active')
                                          const Icon(Icons.check_circle,
                                              color: Color(0xFF69F0AE), size: 15)
                                        else
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white24,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.group_outlined, color: Colors.white38, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          account.subscriberCount ?? "0",
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.smart_display_outlined, color: Colors.white38, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          account.videoCount ?? "0",
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Switch(
                                value: account.isActive,
                                activeThumbColor: const Color(0xFFFF0000),
                                activeTrackColor: const Color(0xFFFF0000).withValues(alpha: 0.25),
                                inactiveThumbColor: Colors.white30,
                                inactiveTrackColor: const Color(0xFF2A2A2A),
                                onChanged: (val) {
                                  provider.toggleAccountActive(account.id, val);
                                },
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(color: Colors.white10),
                                      backgroundColor: const Color(0xFF222222),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () => _showChannelSettingsDialog(account),
                                    icon: const Icon(Icons.tune, size: 16, color: Colors.white70),
                                    label: const Text(
                                      'Standart sozlamalar',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF222222),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                                  color: const Color(0xFF2A2A2A),
                                  padding: EdgeInsets.zero,
                                  onSelected: (val) {
                                    if (val == 'delete') {
                                      provider.deleteAccount(account.id);
                                      YouTubeUploader.signOut();
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        "Chiqish (O'chirish)",
                                        style: TextStyle(color: Colors.redAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _buildGoogleConnectButton(),
                _buildSTTSettingsPanel(provider),
              ],
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSTTSettingsPanel(SettingsProvider provider) {
    return Card(
      color: const Color(0xFF161616),
      margin: const EdgeInsets.only(top: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white10, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_voice, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Speech-to-Text (Ovozdan Matnga)',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Switch(
                  value: _sttEnabledLocal,
                  activeThumbColor: const Color(0xFFFF0000),
                  activeTrackColor: const Color(0xFFFF0000).withValues(alpha: 0.25),
                  onChanged: (val) {
                    setState(() {
                      _sttEnabledLocal = val;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Ovozli videolarni avtomatik matnga aylantirish (Whisper AI) xizmati.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            if (_sttEnabledLocal) ...[
              const Divider(color: Colors.white10, height: 24),
              const Text(
                'API kaliti',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _settingsTextField(
                controller: _sttApiKeyController,
                hint: 'Whisper API Kaliti (shaxsiy)...',
              ),
              const SizedBox(height: 12),
              const Text(
                'API Endpoint (Whisper API)',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _settingsTextField(
                controller: _sttEndpointController,
                hint: 'https://api.openai.com/v1/...',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFFF0000)),
                    backgroundColor: const Color(0xFFFF0000).withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await provider.saveSTTSettings(
                      enabled: _sttEnabledLocal,
                      apiKey: _sttApiKeyController.text.trim(),
                      endpoint: _sttEndpointController.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('✅ STT sozlamalari muvaffaqiyatli saqlandi!'),
                      ));
                    }
                  },
                  child: const Text('Sozlamalarni saqlash', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white10),
                    backgroundColor: const Color(0xFF222222),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await provider.saveSTTSettings(
                      enabled: _sttEnabledLocal,
                      apiKey: '',
                      endpoint: _sttEndpointController.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('✅ STT xizmati o\'chirildi!'),
                      ));
                    }
                  },
                  child: const Text('O\'chirishni saqlash', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
