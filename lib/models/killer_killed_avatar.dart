import 'dart:math' as math;

class KillerKilledAvatar {
  const KillerKilledAvatar({
    required this.face,
    this.hair,
    this.hat,
    this.glasses,
    this.faceAccessory,
    this.gloves,
    this.shirt,
    this.outerwear,
    this.costume,
    this.bottom,
    this.socks = false,
    this.shoes,
  });

  final String face;
  final String? hair;
  final String? hat;
  final String? glasses;
  final String? faceAccessory;
  final String? gloves;
  final String? shirt;
  final String? outerwear;
  final String? costume;
  final String? bottom;
  final bool socks;
  final String? shoes;

  static const defaultAvatar = KillerKilledAvatar(
    face: 'Male_emotion_usual_001',
    hair: 'Hairstyle_male_010',
    gloves: 'Gloves_006',
    shirt: 'T_Shirt_009',
    bottom: 'Pants_010',
    shoes: 'Shoe_Sneakers_009',
  );

  static const customizableNodeNames = <String>{
    'Clown_nose_001',
    'Costume_10_001',
    'Costume_6_001',
    'Glasses_004',
    'Glasses_006',
    'Gloves_006',
    'Gloves_014',
    'Hairstyle_male_010',
    'Hairstyle_male_012',
    'Hat_010',
    'Hat_049',
    'Hat_057',
    'Headphones_002',
    'Male_emotion_angry_003',
    'Male_emotion_happy_002',
    'Male_emotion_usual_001',
    'Moustache_001',
    'Moustache_002',
    'Outerwear_029',
    'Outerwear_036',
    'Pacifier_001',
    'Pants_010',
    'Pants_014',
    'Shoe_Slippers_002',
    'Shoe_Slippers_005',
    'Shoe_Sneakers_009',
    'Shorts_003',
    'Socks_008',
    'T_Shirt_009',
  };

  Set<String> get visibleNodeNames => <String>{
        'Body_010',
        face,
        if (hair != null) hair!,
        if (hat != null) hat!,
        if (glasses != null) glasses!,
        if (faceAccessory != null) faceAccessory!,
        if (gloves != null) gloves!,
        if (shirt != null) shirt!,
        if (outerwear != null) outerwear!,
        if (costume != null) costume!,
        if (bottom != null) bottom!,
        if (socks) 'Socks_008',
        if (shoes != null) shoes!,
      };

  KillerKilledAvatar copyWith({
    String? face,
    String? hair,
    bool clearHair = false,
    String? hat,
    bool clearHat = false,
    String? glasses,
    bool clearGlasses = false,
    String? faceAccessory,
    bool clearFaceAccessory = false,
    String? gloves,
    bool clearGloves = false,
    String? shirt,
    bool clearShirt = false,
    String? outerwear,
    bool clearOuterwear = false,
    String? costume,
    bool clearCostume = false,
    String? bottom,
    bool clearBottom = false,
    bool? socks,
    String? shoes,
    bool clearShoes = false,
  }) {
    return KillerKilledAvatar(
      face: face ?? this.face,
      hair: clearHair ? null : (hair ?? this.hair),
      hat: clearHat ? null : (hat ?? this.hat),
      glasses: clearGlasses ? null : (glasses ?? this.glasses),
      faceAccessory: clearFaceAccessory
          ? null
          : (faceAccessory ?? this.faceAccessory),
      gloves: clearGloves ? null : (gloves ?? this.gloves),
      shirt: clearShirt ? null : (shirt ?? this.shirt),
      outerwear: clearOuterwear ? null : (outerwear ?? this.outerwear),
      costume: clearCostume ? null : (costume ?? this.costume),
      bottom: clearBottom ? null : (bottom ?? this.bottom),
      socks: socks ?? this.socks,
      shoes: clearShoes ? null : (shoes ?? this.shoes),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'face': face,
        'hair': hair,
        'hat': hat,
        'glasses': glasses,
        'faceAccessory': faceAccessory,
        'gloves': gloves,
        'shirt': shirt,
        'outerwear': outerwear,
        'costume': costume,
        'bottom': bottom,
        'socks': socks,
        'shoes': shoes,
      };

  factory KillerKilledAvatar.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      if (value == null) return null;
      final result = value.toString().trim();
      return result.isEmpty ? null : result;
    }

    final face = text('face');
    return KillerKilledAvatar(
      face: face ?? defaultAvatar.face,
      hair: text('hair'),
      hat: text('hat'),
      glasses: text('glasses'),
      faceAccessory: text('faceAccessory'),
      gloves: text('gloves'),
      shirt: text('shirt'),
      outerwear: text('outerwear'),
      costume: text('costume'),
      bottom: text('bottom'),
      socks: json['socks'] == true,
      shoes: text('shoes'),
    );
  }

  static KillerKilledAvatar random(math.Random random) {
    T? optional<T>(List<T> values, {double noneChance = .26}) {
      if (random.nextDouble() < noneChance) return null;
      return values[random.nextInt(values.length)];
    }

    final useCostume = random.nextDouble() < .22;
    return KillerKilledAvatar(
      face: const [
        'Male_emotion_usual_001',
        'Male_emotion_happy_002',
        'Male_emotion_angry_003',
      ][random.nextInt(3)],
      hair: optional(const [
        'Hairstyle_male_010',
        'Hairstyle_male_012',
      ], noneChance: .16),
      hat: optional(const [
        'Hat_010',
        'Hat_049',
        'Hat_057',
        'Headphones_002',
      ], noneChance: .38),
      glasses: optional(const [
        'Glasses_004',
        'Glasses_006',
      ], noneChance: .48),
      faceAccessory: optional(const [
        'Moustache_001',
        'Moustache_002',
        'Clown_nose_001',
        'Pacifier_001',
      ], noneChance: .58),
      gloves: optional(const [
        'Gloves_006',
        'Gloves_014',
      ], noneChance: .32),
      shirt: useCostume ? null : 'T_Shirt_009',
      outerwear: useCostume
          ? null
          : optional(const [
              'Outerwear_029',
              'Outerwear_036',
            ], noneChance: .38),
      costume: useCostume
          ? const ['Costume_10_001', 'Costume_6_001'][random.nextInt(2)]
          : null,
      bottom: useCostume
          ? null
          : const ['Pants_010', 'Pants_014', 'Shorts_003'][random.nextInt(3)],
      socks: !useCostume && random.nextBool(),
      shoes: const [
        'Shoe_Slippers_002',
        'Shoe_Slippers_005',
        'Shoe_Sneakers_009',
      ][random.nextInt(3)],
    );
  }
}
