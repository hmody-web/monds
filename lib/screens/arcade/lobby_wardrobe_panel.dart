import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/killer_killed_avatar.dart';
import '../killer_killed/killer_killed_avatar_preview.dart';

enum LobbyWardrobeCategory {
  costume,
  expression,
  head,
  faceAccessory,
  headwear,
  shirt,
  gloves,
  bottom,
  shoes,
}

extension LobbyWardrobeCategoryLabel on LobbyWardrobeCategory {
  String get label => switch (this) {
        LobbyWardrobeCategory.costume => 'بدلات',
        LobbyWardrobeCategory.expression => 'تعابير',
        LobbyWardrobeCategory.head => 'الشعر',
        LobbyWardrobeCategory.faceAccessory => 'إكسسوارات الوجه',
        LobbyWardrobeCategory.headwear => 'خوذة وغطاء',
        LobbyWardrobeCategory.shirt => 'تيشيرت',
        LobbyWardrobeCategory.gloves => 'كفوف',
        LobbyWardrobeCategory.bottom => 'السروال',
        LobbyWardrobeCategory.shoes => 'الحذاء',
      };

  IconData get icon => switch (this) {
        LobbyWardrobeCategory.costume => Icons.theater_comedy_rounded,
        LobbyWardrobeCategory.expression => Icons.sentiment_satisfied_alt_rounded,
        LobbyWardrobeCategory.head => Icons.content_cut_rounded,
        LobbyWardrobeCategory.faceAccessory => Icons.masks_rounded,
        LobbyWardrobeCategory.headwear => Icons.workspace_premium_rounded,
        LobbyWardrobeCategory.shirt => Icons.checkroom_rounded,
        LobbyWardrobeCategory.gloves => Icons.back_hand_rounded,
        LobbyWardrobeCategory.bottom => Icons.straighten_rounded,
        LobbyWardrobeCategory.shoes => Icons.directions_run_rounded,
      };

  KillerKilledPreviewFocus get previewFocus => switch (this) {
        LobbyWardrobeCategory.costume => KillerKilledPreviewFocus.costume,
        LobbyWardrobeCategory.expression => KillerKilledPreviewFocus.expression,
        LobbyWardrobeCategory.head => KillerKilledPreviewFocus.head,
        LobbyWardrobeCategory.faceAccessory =>
          KillerKilledPreviewFocus.faceAccessory,
        LobbyWardrobeCategory.headwear => KillerKilledPreviewFocus.headwear,
        LobbyWardrobeCategory.shirt => KillerKilledPreviewFocus.shirt,
        LobbyWardrobeCategory.gloves => KillerKilledPreviewFocus.gloves,
        LobbyWardrobeCategory.bottom => KillerKilledPreviewFocus.bottom,
        LobbyWardrobeCategory.shoes => KillerKilledPreviewFocus.shoes,
      };
}

class LobbyWardrobePanel extends StatelessWidget {
  const LobbyWardrobePanel({
    super.key,
    required this.avatar,
    required this.category,
    required this.onCategoryChanged,
    required this.onAvatarChanged,
    required this.onClose,
    this.panelHeightFraction = .43,
    this.panelOpacity = .86,
    this.blurSigma = 17,
    this.cornerRadius = 30,
    this.cardWidth = 132,
    this.cardHeight = 154,
    this.cardGap = 10,
    this.backgroundColor = const Color(0xFF07131E),
    this.accentColor = const Color(0xFFFFB83B),
    this.textColor = Colors.white,
    this.previewOffsetX = 0,
    this.previewOffsetY = 0,
    this.previewOffsetZ = 0,
    this.previewScale = 1,
    this.previewRotX = 0,
    this.previewRotY = 0,
    this.previewRotZ = 0,
    this.previewCameraX,
    this.previewCameraY,
    this.previewCameraZ,
    this.previewTargetX,
    this.previewTargetY,
    this.previewTargetZ,
    this.previewFov,
  });

  final KillerKilledAvatar avatar;
  final LobbyWardrobeCategory category;
  final ValueChanged<LobbyWardrobeCategory> onCategoryChanged;
  final ValueChanged<KillerKilledAvatar> onAvatarChanged;
  final VoidCallback onClose;

  final double panelHeightFraction;
  final double panelOpacity;
  final double blurSigma;
  final double cornerRadius;
  final double cardWidth;
  final double cardHeight;
  final double cardGap;
  final Color backgroundColor;
  final Color accentColor;
  final Color textColor;
  final double previewOffsetX;
  final double previewOffsetY;
  final double previewOffsetZ;
  final double previewScale;
  final double previewRotX;
  final double previewRotY;
  final double previewRotZ;
  final double? previewCameraX;
  final double? previewCameraY;
  final double? previewCameraZ;
  final double? previewTargetX;
  final double? previewTargetY;
  final double? previewTargetZ;
  final double? previewFov;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height *
        panelHeightFraction.clamp(.25, .70);
    final choices = _choicesFor(category, avatar);

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        height: height,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cornerRadius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: blurSigma.clamp(0, 40),
              sigmaY: blurSigma.clamp(0, 40),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(panelOpacity.clamp(.20, 1)),
                borderRadius: BorderRadius.circular(cornerRadius),
                border: Border.all(
                  color: accentColor.withOpacity(.78),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(.12),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _Header(
                    accentColor: accentColor,
                    textColor: textColor,
                    onClose: onClose,
                    selectedCategoryLabel: category.label,
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: LobbyWardrobeCategory.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = LobbyWardrobeCategory.values[index];
                        return _CategoryTab(
                          category: item,
                          selected: item == category,
                          accentColor: accentColor,
                          textColor: textColor,
                          onTap: () => onCategoryChanged(item),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: choices.length,
                      separatorBuilder: (_, __) => SizedBox(width: cardGap),
                      itemBuilder: (context, index) {
                        final choice = choices[index];
                        return _WardrobeChoiceCard(
                          choice: choice,
                          category: category,
                          width: cardWidth,
                          height: cardHeight,
                          accentColor: accentColor,
                          textColor: textColor,
                          previewOffsetX: previewOffsetX,
                          previewOffsetY: previewOffsetY,
                          previewOffsetZ: previewOffsetZ,
                          previewScale: previewScale,
                          previewRotX: previewRotX,
                          previewRotY: previewRotY,
                          previewRotZ: previewRotZ,
                          previewCameraX: previewCameraX,
                          previewCameraY: previewCameraY,
                          previewCameraZ: previewCameraZ,
                          previewTargetX: previewTargetX,
                          previewTargetY: previewTargetY,
                          previewTargetZ: previewTargetZ,
                          previewFov: previewFov,
                          onTap: () => onAvatarChanged(choice.avatar),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.accentColor,
    required this.textColor,
    required this.onClose,
    required this.selectedCategoryLabel,
  });

  final Color accentColor;
  final Color textColor;
  final VoidCallback onClose;
  final String selectedCategoryLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(.14),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: accentColor.withOpacity(.42)),
            ),
            child: IconButton(
              tooltip: 'إغلاق',
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, color: textColor, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'خزانة الشخصية',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'PCB',
                  ),
                ),
                Text(
                  'القسم الحالي: $selectedCategoryLabel — السحب يمين ويسار للتصفح',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withOpacity(.68),
                    fontSize: 10.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.category,
    required this.selected,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });

  final LobbyWardrobeCategory category;
  final bool selected;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withOpacity(.96)
                  : Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? accentColor
                    : Colors.white.withOpacity(.14),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: accentColor.withOpacity(.25),
                        blurRadius: 16,
                        spreadRadius: .5,
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  category.icon,
                  size: 18,
                  color: selected ? const Color(0xFF07131E) : textColor,
                ),
                const SizedBox(height: 5),
                Text(
                  category.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        selected ? const Color(0xFF07131E) : textColor,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WardrobeChoice {
  const _WardrobeChoice({
    required this.id,
    required this.label,
    required this.avatar,
    required this.selected,
  });

  final String id;
  final String label;
  final KillerKilledAvatar avatar;
  final bool selected;
}

class _WardrobeChoiceCard extends StatelessWidget {
  const _WardrobeChoiceCard({
    required this.choice,
    required this.category,
    required this.width,
    required this.height,
    required this.accentColor,
    required this.textColor,
    required this.previewOffsetX,
    required this.previewOffsetY,
    required this.previewOffsetZ,
    required this.previewScale,
    required this.previewRotX,
    required this.previewRotY,
    required this.previewRotZ,
    required this.previewCameraX,
    required this.previewCameraY,
    required this.previewCameraZ,
    required this.previewTargetX,
    required this.previewTargetY,
    required this.previewTargetZ,
    required this.previewFov,
    required this.onTap,
  });

  final _WardrobeChoice choice;
  final LobbyWardrobeCategory category;
  final double width;
  final double height;
  final Color accentColor;
  final Color textColor;
  final double previewOffsetX;
  final double previewOffsetY;
  final double previewOffsetZ;
  final double previewScale;
  final double previewRotX;
  final double previewRotY;
  final double previewRotZ;
  final double? previewCameraX;
  final double? previewCameraY;
  final double? previewCameraZ;
  final double? previewTargetX;
  final double? previewTargetY;
  final double? previewTargetZ;
  final double? previewFov;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: choice.selected
                  ? accentColor.withOpacity(.16)
                  : Colors.black.withOpacity(.23),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: choice.selected
                    ? accentColor
                    : Colors.white.withOpacity(.12),
                width: choice.selected ? 2.2 : 1.0,
              ),
              boxShadow: choice.selected
                  ? [
                      BoxShadow(
                        color: accentColor.withOpacity(.18),
                        blurRadius: 16,
                      ),
                    ]
                  : const [],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: 34,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                    child: KillerKilledAvatarPreview(
                      avatar: choice.avatar,
                      interactive: false,
                      compact: false,
                      fullBodyFraming: false,
                      focus: category.previewFocus,
                      itemOnly: true,
                      previewOffsetX: previewOffsetX,
                      previewOffsetY: previewOffsetY,
                      previewOffsetZ: previewOffsetZ,
                      previewScale: previewScale,
                      previewRotX: previewRotX,
                      previewRotY: previewRotY,
                      previewRotZ: previewRotZ,
                      previewCameraX: previewCameraX,
                      previewCameraY: previewCameraY,
                      previewCameraZ: previewCameraZ,
                      previewTargetX: previewTargetX,
                      previewTargetY: previewTargetY,
                      previewTargetZ: previewTargetZ,
                      previewFov: previewFov,
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Container(
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xE0101720),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      choice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: choice.selected ? accentColor : textColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (choice.selected)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      width: 23,
                      height: 23,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Color(0xFF07131E),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<_WardrobeChoice> _choicesFor(
  LobbyWardrobeCategory category,
  KillerKilledAvatar current,
) {
  _WardrobeChoice choice(
    String id,
    String label,
    KillerKilledAvatar avatar,
    bool selected,
  ) =>
      _WardrobeChoice(
        id: id,
        label: label,
        avatar: avatar,
        selected: selected,
      );

  switch (category) {
    case LobbyWardrobeCategory.costume:
      return [
        choice(
          'none',
          'بدون بدلة',
          current.copyWith(clearCostume: true),
          current.costume == null,
        ),
        choice(
          'Costume_10_001',
          'بدلة 1',
          current.copyWith(
            costume: 'Costume_10_001',
            clearShirt: true,
            clearOuterwear: true,
            clearBottom: true,
          ),
          current.costume == 'Costume_10_001',
        ),
        choice(
          'Costume_6_001',
          'بدلة 2',
          current.copyWith(
            costume: 'Costume_6_001',
            clearShirt: true,
            clearOuterwear: true,
            clearBottom: true,
          ),
          current.costume == 'Costume_6_001',
        ),
      ];

    case LobbyWardrobeCategory.expression:
      return [
        choice(
          'Male_emotion_usual_001',
          'طبيعي',
          current.copyWith(face: 'Male_emotion_usual_001'),
          current.face == 'Male_emotion_usual_001',
        ),
        choice(
          'Male_emotion_happy_002',
          'سعيد',
          current.copyWith(face: 'Male_emotion_happy_002'),
          current.face == 'Male_emotion_happy_002',
        ),
        choice(
          'Male_emotion_angry_003',
          'غاضب',
          current.copyWith(face: 'Male_emotion_angry_003'),
          current.face == 'Male_emotion_angry_003',
        ),
      ];

    case LobbyWardrobeCategory.head:
      return [
        choice(
          'none',
          'بدون شعر إضافي',
          current.copyWith(clearHair: true),
          current.hair == null,
        ),
        choice(
          'Hairstyle_male_010',
          'شعر 1',
          current.copyWith(hair: 'Hairstyle_male_010'),
          current.hair == 'Hairstyle_male_010',
        ),
        choice(
          'Hairstyle_male_012',
          'شعر 2',
          current.copyWith(hair: 'Hairstyle_male_012'),
          current.hair == 'Hairstyle_male_012',
        ),
      ];

    case LobbyWardrobeCategory.faceAccessory:
      return [
        choice(
          'none',
          'بدون',
          current.copyWith(clearGlasses: true, clearFaceAccessory: true),
          current.glasses == null && current.faceAccessory == null,
        ),
        choice(
          'Glasses_004',
          'نظارة 1',
          current.copyWith(glasses: 'Glasses_004', clearFaceAccessory: true),
          current.glasses == 'Glasses_004',
        ),
        choice(
          'Glasses_006',
          'نظارة 2',
          current.copyWith(glasses: 'Glasses_006', clearFaceAccessory: true),
          current.glasses == 'Glasses_006',
        ),
        choice(
          'Moustache_001',
          'شارب 1',
          current.copyWith(faceAccessory: 'Moustache_001', clearGlasses: true),
          current.faceAccessory == 'Moustache_001',
        ),
        choice(
          'Moustache_002',
          'شارب 2',
          current.copyWith(faceAccessory: 'Moustache_002', clearGlasses: true),
          current.faceAccessory == 'Moustache_002',
        ),
        choice(
          'Clown_nose_001',
          'أنف مهرج',
          current.copyWith(faceAccessory: 'Clown_nose_001', clearGlasses: true),
          current.faceAccessory == 'Clown_nose_001',
        ),
        choice(
          'Pacifier_001',
          'لهاية',
          current.copyWith(faceAccessory: 'Pacifier_001', clearGlasses: true),
          current.faceAccessory == 'Pacifier_001',
        ),
      ];

    case LobbyWardrobeCategory.headwear:
      return [
        choice(
          'none',
          'بدون',
          current.copyWith(clearHat: true),
          current.hat == null,
        ),
        choice(
          'Hat_010',
          'قبعة 1',
          current.copyWith(hat: 'Hat_010'),
          current.hat == 'Hat_010',
        ),
        choice(
          'Hat_049',
          'قبعة 2',
          current.copyWith(hat: 'Hat_049'),
          current.hat == 'Hat_049',
        ),
        choice(
          'Hat_057',
          'قبعة 3',
          current.copyWith(hat: 'Hat_057'),
          current.hat == 'Hat_057',
        ),
        choice(
          'Headphones_002',
          'سماعات',
          current.copyWith(hat: 'Headphones_002'),
          current.hat == 'Headphones_002',
        ),
      ];

    case LobbyWardrobeCategory.shirt:
      return [
        choice(
          'none',
          'بدون',
          current.copyWith(clearShirt: true, clearOuterwear: true),
          current.shirt == null && current.outerwear == null,
        ),
        choice(
          'T_Shirt_009',
          'تيشيرت',
          current.copyWith(shirt: 'T_Shirt_009', clearCostume: true),
          current.shirt == 'T_Shirt_009' && current.outerwear == null,
        ),
        choice(
          'Outerwear_029',
          'جاكيت 1',
          current.copyWith(
            shirt: 'T_Shirt_009',
            outerwear: 'Outerwear_029',
            clearCostume: true,
          ),
          current.outerwear == 'Outerwear_029',
        ),
        choice(
          'Outerwear_036',
          'جاكيت 2',
          current.copyWith(
            shirt: 'T_Shirt_009',
            outerwear: 'Outerwear_036',
            clearCostume: true,
          ),
          current.outerwear == 'Outerwear_036',
        ),
      ];

    case LobbyWardrobeCategory.gloves:
      return [
        choice(
          'none',
          'بدون',
          current.copyWith(clearGloves: true),
          current.gloves == null,
        ),
        choice(
          'Gloves_006',
          'كفوف 1',
          current.copyWith(gloves: 'Gloves_006'),
          current.gloves == 'Gloves_006',
        ),
        choice(
          'Gloves_014',
          'كفوف 2',
          current.copyWith(gloves: 'Gloves_014'),
          current.gloves == 'Gloves_014',
        ),
      ];

    case LobbyWardrobeCategory.bottom:
      return [
        choice(
          'none',
          'بدون',
          current.copyWith(clearBottom: true),
          current.bottom == null,
        ),
        choice(
          'Pants_010',
          'سروال 1',
          current.copyWith(bottom: 'Pants_010', clearCostume: true),
          current.bottom == 'Pants_010',
        ),
        choice(
          'Pants_014',
          'سروال 2',
          current.copyWith(bottom: 'Pants_014', clearCostume: true),
          current.bottom == 'Pants_014',
        ),
        choice(
          'Shorts_003',
          'شورت',
          current.copyWith(bottom: 'Shorts_003', clearCostume: true),
          current.bottom == 'Shorts_003',
        ),
      ];

    case LobbyWardrobeCategory.shoes:
      return [
        choice(
          'none',
          'بدون',
          current.copyWith(clearShoes: true, socks: false),
          current.shoes == null && !current.socks,
        ),
        choice(
          'Shoe_Slippers_002',
          'نعال 1',
          current.copyWith(shoes: 'Shoe_Slippers_002'),
          current.shoes == 'Shoe_Slippers_002',
        ),
        choice(
          'Shoe_Slippers_005',
          'نعال 2',
          current.copyWith(shoes: 'Shoe_Slippers_005'),
          current.shoes == 'Shoe_Slippers_005',
        ),
        choice(
          'Shoe_Sneakers_009',
          'سنيكرز',
          current.copyWith(shoes: 'Shoe_Sneakers_009'),
          current.shoes == 'Shoe_Sneakers_009',
        ),
        choice(
          'Socks_008',
          'جوارب',
          current.copyWith(socks: true),
          current.socks,
        ),
      ];
  }
}
