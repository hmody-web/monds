import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/nav.dart';
import '../../widgets/arcade_game_shell.dart';
import '../../services/multiplayer_service.dart';
import '../../services/player_name_store.dart';
import 'multiplayer_lobby_screen.dart';

class MultiplayerEntryScreen extends StatefulWidget {
  const MultiplayerEntryScreen({super.key});
  @override
  State<MultiplayerEntryScreen> createState() => _MultiplayerEntryScreenState();
}

class _MultiplayerEntryScreenState extends State<MultiplayerEntryScreen> {
  final service = MultiplayerService();
  final name = TextEditingController();
  final code = TextEditingController();
  Timer? _saveTimer;
  int avatar = 0;
  bool loading = false;
  bool joining = false;
  static const avatars = ['🕵️','🦊','🐼','🐯','🐸','🦝','🐧','🐻'];

  @override
  void initState() {
    super.initState();
    _loadSavedName();
  }

  Future<void> _loadSavedName() async {
    final saved = await PlayerNameStore.loadOnlineName();
    if (!mounted || saved.isEmpty || name.text.trim().isNotEmpty) return;
    name.text = saved;
    name.selection = TextSelection.collapsed(offset: name.text.length);
  }

  void _scheduleSaveName() {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(PlayerNameStore.saveOnlineName(name.text)),
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(PlayerNameStore.saveOnlineName(name.text));
    name.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _go(bool host) async {
    if (name.text.trim().length < 2) return _toast('اكتب اسمك أولاً');
    if (!host && code.text.trim().length < 4) return _toast('اكتب رمز الغرفة');
    await PlayerNameStore.saveOnlineName(name.text);
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final id = host
          ? await service.createRoom(name: name.text.trim(), avatar: avatar)
          : await service.joinRoom(
              code: code.text,
              name: name.text.trim(),
              avatar: avatar,
            );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        mundasRoute(MultiplayerLobbyScreen(identity: id)),
      );
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return ArcadeGameShell(
      title: 'اللعب مع صديق',
      bottom: ArcadePrimaryButton(
        label: loading
            ? 'لحظة...'
            : (joining ? 'دخول الغرفة' : 'إنشاء غرفة'),
        icon: joining ? Icons.login_rounded : Icons.add_rounded,
        onPressed: loading ? null : () => _go(!joining),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        physics: const BouncingScrollPhysics(),
        children: [
          const Text(
            'اسمك',
            style: TextStyle(
              color: Color(0xFFFFC547),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: name,
            maxLength: 18,
            onChanged: (_) => _scheduleSaveName(),
            style: const TextStyle(color: Colors.white),
            cursorColor: const Color(0xFFFFC547),
            decoration: _arcadeInput('مثلاً: محمد'),
          ),
          const SizedBox(height: 12),
          const Text(
            'الشخصية',
            style: TextStyle(
              color: Color(0xFFFFC547),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: List.generate(
              avatars.length,
              (i) => InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => avatar = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatar == i
                        ? const Color(0xFF17333A)
                        : const Color(0xFF101820),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: avatar == i
                          ? const Color(0xFF27C38A)
                          : const Color(0xFF5F6670),
                      width: avatar == i ? 2.2 : 1.2,
                    ),
                  ),
                  child: Text(avatars[i], style: const TextStyle(fontSize: 28)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _modeButton(
                  selected: !joining,
                  label: 'إنشاء غرفة',
                  icon: Icons.add_circle_outline_rounded,
                  onTap: () => setState(() => joining = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _modeButton(
                  selected: joining,
                  label: 'انضمام',
                  icon: Icons.login_rounded,
                  onTap: () => setState(() => joining = true),
                ),
              ),
            ],
          ),
          if (joining) ...[
            const SizedBox(height: 18),
            TextField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                letterSpacing: 4,
                fontWeight: FontWeight.w800,
              ),
              decoration: _arcadeInput('ABCDE').copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFFFFC547),
                  ),
                  onPressed: () async {
                    final result = await Navigator.push<String>(
                      context,
                      mundasRoute(const _QrScanScreen()),
                    );
                    if (result != null) code.text = result;
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _arcadeInput(String hint) {
    return InputDecoration(
      counterText: '',
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF818894)),
      filled: true,
      fillColor: const Color(0xFF0B1118),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF5F6670)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFFC547), width: 1.8),
      ),
    );
  }

  Widget _modeButton({
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ArcadePanel(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selected ? const Color(0xFF27C38A) : Colors.white70,
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();
  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  bool done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                if (done || capture.barcodes.isEmpty) return;
                final raw = capture.barcodes.first.rawValue ?? '';
                final match = RegExp(
                  r'(?:room=|/)([A-Z0-9]{5,8})$',
                  caseSensitive: false,
                ).firstMatch(raw);
                final value = (match?.group(1) ?? raw).trim().toUpperCase();
                if (RegExp(r'^[A-Z0-9]{5,8}$').hasMatch(value)) {
                  done = true;
                  Navigator.pop(context, value);
                }
              },
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: IconButton.filled(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ),
            const Center(
              child: SizedBox(
                width: 245,
                height: 245,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.white, width: 3),
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(28)),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
