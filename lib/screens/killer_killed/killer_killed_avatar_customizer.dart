import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/mundas_colors.dart';
import '../../models/killer_killed_avatar.dart';
import '../../services/killer_killed/killer_killed_avatar_store.dart';
import 'killer_killed_avatar_preview.dart';

enum _AvatarSlot {
  face,
  hair,
  hat,
  glasses,
  faceAccessory,
  gloves,
  shirt,
  outerwear,
  costume,
  bottom,
  socks,
  shoes,
}

class _AvatarChoice {
  const _AvatarChoice(this.value, this.label, this.icon);

  final String? value;
  final String label;
  final IconData icon;
}

class KillerKilledAvatarCustomizer extends StatefulWidget {
  const KillerKilledAvatarCustomizer({
    super.key,
    required this.initialAvatar,
  });

  final KillerKilledAvatar initialAvatar;

  @override
  State<KillerKilledAvatarCustomizer> createState() =>
      _KillerKilledAvatarCustomizerState();
}

class _KillerKilledAvatarCustomizerState
    extends State<KillerKilledAvatarCustomizer> {
  late KillerKilledAvatar _avatar;
  _AvatarSlot _slot = _AvatarSlot.hair;

  static const Map<_AvatarSlot, String> _slotLabels = {
    _AvatarSlot.face: 'الوجه',
    _AvatarSlot.hair: 'الشعر',
    _AvatarSlot.hat: 'الرأس',
    _AvatarSlot.glasses: 'النظارات',
    _AvatarSlot.faceAccessory: 'إكسسوارات الوجه',
    _AvatarSlot.gloves: 'القفازات',
    _AvatarSlot.shirt: 'التيشيرت',
    _AvatarSlot.outerwear: 'الجاكيت',
    _AvatarSlot.costume: 'البدلات',
    _AvatarSlot.bottom: 'البنطلون',
    _AvatarSlot.socks: 'الجوارب',
    _AvatarSlot.shoes: 'الأحذية',
  };

  @override
  void initState() {
    super.initState();
    _avatar = widget.initialAvatar;
  }

  List<_AvatarChoice> _choices(_AvatarSlot slot) {
    switch (slot) {
      case _AvatarSlot.face:
        return const [
          _AvatarChoice('Male_emotion_usual_001', 'طبيعي', Icons.sentiment_neutral_rounded),
          _AvatarChoice('Male_emotion_happy_002', 'سعيد', Icons.sentiment_very_satisfied_rounded),
          _AvatarChoice('Male_emotion_angry_003', 'غاضب', Icons.sentiment_very_dissatisfied_rounded),
        ];
      case _AvatarSlot.hair:
        return const [
          _AvatarChoice(null, 'بدون', Icons.block_rounded),
          _AvatarChoice('Hairstyle_male_010', 'شعر 1', Icons.face_retouching_natural_rounded),
          _AvatarChoice('Hairstyle_male_012', 'شعر 2', Icons.face_retouching_natural_rounded),
        ];
      case _AvatarSlot.hat:
        return const [
          _AvatarChoice(null, 'بدون', Icons.block_rounded),
          _AvatarChoice('Hat_010', 'قبعة 1', Icons.sports_baseball_rounded),
          _AvatarChoice('Hat_049', 'قبعة 2', Icons.sports_baseball_rounded),
          _AvatarChoice('Hat_057', 'قبعة 3', Icons.sports_baseball_rounded),
          _AvatarChoice('Headphones_002', 'سماعات', Icons.headphones_rounded),
        ];
      case _AvatarSlot.glasses:
        return const [
          _AvatarChoice(null, 'بدون', Icons.block_rounded),
          _AvatarChoice('Glasses_004', 'نظارة 1', Icons.visibility_rounded),
          _AvatarChoice('Glasses_006', 'نظارة 2', Icons.visibility_rounded),
        ];
      case _AvatarSlot.faceAccessory:
        return const [
          _AvatarChoice(null, 'بدون', Icons.block_rounded),
          _AvatarChoice('Moustache_001', 'شارب 1', Icons.face_rounded),
          _AvatarChoice('Moustache_002', 'شارب 2', Icons.face_rounded),
          _AvatarChoice('Clown_nose_001', 'أنف مهرج', Icons.celebration_rounded),
          _AvatarChoice('Pacifier_001', 'لهاية', Icons.child_care_rounded),
        ];
      case _AvatarSlot.gloves:
        return const [
          _AvatarChoice(null, 'بدون', Icons.block_rounded),
          _AvatarChoice('Gloves_006', 'قفاز 1', Icons.back_hand_rounded),
          _AvatarChoice('Gloves_014', 'قفاز 2', Icons.back_hand_rounded),
        ];
      case _AvatarSlot.shirt:
        return const [
          _AvatarChoice(null, 'بدون', Icons.block_rounded),
          _AvatarChoice('T_Shirt_009', 'تيشيرت', Icons.checkroom_rounded),
        ];
      case _AvatarSlot.outerwear:
        return const [
          _AvatarChoice(null, 'بدون', Icons.block_rounded),
          _AvatarChoice('Outerwear_029', 'جاكيت 1', Icons.checkroom_rounded),
          _AvatarChoice('Outerwear_036', 'جاكيت 2', Icons.checkroom_rounded),
        ];
      case _AvatarSlot.costume:
        return const [
          _AvatarChoice(null, 'بدون', Icons.block_rounded),
          _AvatarChoice('Costume_10_001', 'بدلة 1', Icons.theater_comedy_rounded),
          _AvatarChoice('Costume_6_001', 'بدلة 2', Icons.theater_comedy_rounded),
        ];
      case _AvatarSlot.bottom:
        return const [
          _AvatarChoice(null, 'بدون', Icons.block_rounded),
          _AvatarChoice('Pants_010', 'بنطلون 1', Icons.checkroom_rounded),
          _AvatarChoice('Pants_014', 'بنطلون 2', Icons.checkroom_rounded),
          _AvatarChoice('Shorts_003', 'شورت', Icons.checkroom_rounded),
        ];
      case _AvatarSlot.socks:
        return const [
          _AvatarChoice(null, 'بدون', Icons.block_rounded),
          _AvatarChoice('Socks_008', 'جوارب', Icons.checkroom_rounded),
        ];
      case _AvatarSlot.shoes:
        return const [
          _AvatarChoice(null, 'بدون', Icons.block_rounded),
          _AvatarChoice('Shoe_Slippers_002', 'نعال 1', Icons.ice_skating_rounded),
          _AvatarChoice('Shoe_Slippers_005', 'نعال 2', Icons.ice_skating_rounded),
          _AvatarChoice('Shoe_Sneakers_009', 'سنيكرز', Icons.directions_run_rounded),
        ];
    }
  }

  String? _selectedValue(_AvatarSlot slot) {
    switch (slot) {
      case _AvatarSlot.face:
        return _avatar.face;
      case _AvatarSlot.hair:
        return _avatar.hair;
      case _AvatarSlot.hat:
        return _avatar.hat;
      case _AvatarSlot.glasses:
        return _avatar.glasses;
      case _AvatarSlot.faceAccessory:
        return _avatar.faceAccessory;
      case _AvatarSlot.gloves:
        return _avatar.gloves;
      case _AvatarSlot.shirt:
        return _avatar.shirt;
      case _AvatarSlot.outerwear:
        return _avatar.outerwear;
      case _AvatarSlot.costume:
        return _avatar.costume;
      case _AvatarSlot.bottom:
        return _avatar.bottom;
      case _AvatarSlot.socks:
        return _avatar.socks ? 'Socks_008' : null;
      case _AvatarSlot.shoes:
        return _avatar.shoes;
    }
  }

  void _select(_AvatarSlot slot, String? value) {
    setState(() {
      switch (slot) {
        case _AvatarSlot.face:
          if (value != null) _avatar = _avatar.copyWith(face: value);
          break;
        case _AvatarSlot.hair:
          _avatar = value == null
              ? _avatar.copyWith(clearHair: true)
              : _avatar.copyWith(hair: value);
          break;
        case _AvatarSlot.hat:
          _avatar = value == null
              ? _avatar.copyWith(clearHat: true)
              : _avatar.copyWith(hat: value);
          break;
        case _AvatarSlot.glasses:
          _avatar = value == null
              ? _avatar.copyWith(clearGlasses: true)
              : _avatar.copyWith(glasses: value);
          break;
        case _AvatarSlot.faceAccessory:
          _avatar = value == null
              ? _avatar.copyWith(clearFaceAccessory: true)
              : _avatar.copyWith(faceAccessory: value);
          break;
        case _AvatarSlot.gloves:
          _avatar = value == null
              ? _avatar.copyWith(clearGloves: true)
              : _avatar.copyWith(gloves: value);
          break;
        case _AvatarSlot.shirt:
          _avatar = value == null
              ? _avatar.copyWith(clearShirt: true)
              : _avatar.copyWith(shirt: value);
          break;
        case _AvatarSlot.outerwear:
          _avatar = value == null
              ? _avatar.copyWith(clearOuterwear: true)
              : _avatar.copyWith(outerwear: value);
          break;
        case _AvatarSlot.costume:
          _avatar = value == null
              ? _avatar.copyWith(clearCostume: true)
              : _avatar.copyWith(costume: value);
          break;
        case _AvatarSlot.bottom:
          _avatar = value == null
              ? _avatar.copyWith(clearBottom: true)
              : _avatar.copyWith(bottom: value);
          break;
        case _AvatarSlot.socks:
          _avatar = _avatar.copyWith(socks: value != null);
          break;
        case _AvatarSlot.shoes:
          _avatar = value == null
              ? _avatar.copyWith(clearShoes: true)
              : _avatar.copyWith(shoes: value);
          break;
      }
    });
  }

  Future<void> _saveAndClose() async {
    await KillerKilledAvatarStore.save(_avatar);
    if (!mounted) return;
    Navigator.pop(context, _avatar);
  }

  @override
  Widget build(BuildContext context) {
    final choices = _choices(_slot);
    final selected = _selectedValue(_slot);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('شخصيتي', style: TextStyle(fontSize: 21)),
                        Text(
                          'اسحب الشخصية لتدويرها واختر أي تركيبة تعجبك',
                          style: TextStyle(fontSize: 10.5, color: MundasColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'عشوائي',
                    onPressed: () => setState(
                      () => _avatar = KillerKilledAvatar.random(math.Random()),
                    ),
                    icon: const Icon(Icons.casino_rounded),
                  ),
                  IconButton(
                    tooltip: 'إعادة',
                    onPressed: () => setState(
                      () => _avatar = KillerKilledAvatar.defaultAvatar,
                    ),
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 47,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF07100F),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: MundasColors.ink, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: MundasColors.ink,
                        offset: Offset(0, 5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: KillerKilledAvatarPreview(avatar: _avatar),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swipe_rounded, color: Colors.white70, size: 15),
                              SizedBox(width: 5),
                              Text('دوّر الشخصية', style: TextStyle(color: Colors.white70, fontSize: 9.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                reverse: true,
                itemCount: _AvatarSlot.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final slot = _AvatarSlot.values[index];
                  final active = slot == _slot;
                  return ChoiceChip(
                    selected: active,
                    onSelected: (_) => setState(() => _slot = slot),
                    label: Text(_slotLabels[slot]!),
                    selectedColor: const Color(0xFFD9F4EF),
                    side: BorderSide(
                      color: active ? const Color(0xFF219587) : MundasColors.line,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: active ? const Color(0xFF126F64) : MundasColors.ink,
                    ),
                  );
                },
              ),
            ),
            Expanded(
              flex: 30,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                  border: Border.all(color: MundasColors.line),
                ),
                child: GridView.builder(
                  itemCount: choices.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 9,
                    crossAxisSpacing: 9,
                    childAspectRatio: .95,
                  ),
                  itemBuilder: (context, index) {
                    final choice = choices[index];
                    final active = choice.value == selected;
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _select(_slot, choice.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFFE5F7F3) : const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active ? const Color(0xFF219587) : MundasColors.line,
                            width: active ? 1.8 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              choice.icon,
                              size: 24,
                              color: active ? const Color(0xFF167B70) : MundasColors.ink,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              choice.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9.5),
                            ),
                            if (active) ...[
                              const SizedBox(height: 3),
                              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF219587)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 16, 14),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _saveAndClose,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('حفظ الشخصية'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
