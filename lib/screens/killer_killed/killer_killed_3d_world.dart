import 'dart:math' as math;

import 'package:flutter/material.dart' show Color, Offset, Size;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

class KillerKilled3DWorld {
  KillerKilled3DWorld();

  static const double arenaWorldSize = 7.2;
  static const double fighterLabelHeight = 2.22;

  final Scene scene = Scene();
  final Map<int, KillerKilledFighterVisual> fighters = {};
  final List<Node> _bloodNodes = [];
  final math.Random _random = math.Random(1729);

  bool ready = false;

  late final _GeometryBank _geo;
  late final PhysicallyBasedMaterial _floorMaterial;
  late final PhysicallyBasedMaterial _parapetMaterial;
  late final PhysicallyBasedMaterial _obstacleTopMaterial;
  late final PhysicallyBasedMaterial _obstacleSideMaterial;
  late final PhysicallyBasedMaterial _metalMaterial;
  late final UnlitMaterial _gridMaterial;
  late final UnlitMaterial _bloodMaterial;
  late final UnlitMaterial _laserMaterial;
  late final UnlitMaterial _laserGlowMaterial;
  late final UnlitMaterial _shotMaterial;

  late final Node _obstacleRoot;
  late final Node _characterTemplate;
  late final Node _floorTemplate;
  late final Node _backgroundTemplate;
  late final Node _backgroundRoot;

  Future<void> initialize({
    void Function(double progress, String stage)? onProgress,
  }) async {
    if (ready) {
      onProgress?.call(1, 'المشهد جاهز');
      return;
    }
    onProgress?.call(.06, 'تهيئة محرك ثلاثي الأبعاد');
    await Scene.initializeStaticResources();
    onProgress?.call(.16, 'إعداد الإضاءة والمؤثرات');

    scene.renderScale = 1.0;
    scene.exposure = 1.12;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.56, -1.0, -.42),
      color: vm.Vector3(.84, .91, 1.0),
      intensity: 2.5,
      castsShadow: true,
      shadowCascadeCount: 2,
      shadowMaxDistance: 36,
      shadowMapResolution: 1024,
      shadowSoftness: .16,
      shadowAmbientStrength: .22,
    );
    scene.ambientOcclusion
      ..enabled = true
      ..halfResolution = true
      ..sampleCount = 8
      ..radius = .34
      ..intensity = .86;

    _geo = _GeometryBank();
    _createMaterials();
    onProgress?.call(.24, 'تحميل الشخصية');
    _characterTemplate = await Node.fromGlbAsset(
      'assets/models/killer_killed_character.glb',
    );
    onProgress?.call(.48, 'تحميل أرضية الساحة');
    _floorTemplate = await Node.fromGlbAsset(
      'assets/models/scifi_floor_vents.glb',
    );
    onProgress?.call(.68, 'تحميل خلفية النجوم');
    _backgroundTemplate = await Node.fromGlbAsset(
      'assets/models/interstellar_background_optimized.glb',
    );
    onProgress?.call(.86, 'بناء الساحة');
    _buildRooftop();
    ready = true;
    onProgress?.call(1, 'المشهد جاهز');
  }

  void _createMaterials() {
    _floorMaterial = _pbr(const Color(0xFF182433), roughness: .72, metallic: .17);
    _parapetMaterial = _pbr(const Color(0xFF222D3A), roughness: .64, metallic: .22);
    _obstacleTopMaterial = _pbr(const Color(0xFF334154), roughness: .52, metallic: .25);
    _obstacleSideMaterial = _pbr(const Color(0xFF121A25), roughness: .72, metallic: .16);
    _metalMaterial = _pbr(const Color(0xFF3D4654), roughness: .32, metallic: .76);
    _gridMaterial = _unlit(const Color(0x3A2F6DFF));
    _bloodMaterial = _unlit(const Color(0xFF8A0E1E));
    // Thin, dark-red translucent laser. The core stays readable while
    // the wider glow is deliberately faint so it looks like a real laser,
    // not an opaque red rod.
    _laserMaterial = _unlit(const Color(0x9960000A));
    _laserGlowMaterial = _unlit(const Color(0x3360000A));
    _shotMaterial = _unlit(const Color(0xFFFFF2C5));
  }

  PhysicallyBasedMaterial _pbr(
    Color color, {
    double roughness = .65,
    double metallic = .0,
  }) {
    final material = PhysicallyBasedMaterial();
    material.baseColorFactor = _vectorColor(color);
    material.roughnessFactor = roughness;
    material.metallicFactor = metallic;
    return material;
  }

  UnlitMaterial _unlit(Color color) {
    final material = UnlitMaterial();
    material.baseColorFactor = _vectorColor(color);
    final alpha = ((color.toARGB32() >> 24) & 0xFF) / 255.0;
    if (alpha < .999) material.alphaMode = AlphaMode.blend;
    return material;
  }

  vm.Vector4 _vectorColor(Color color, {double? alpha}) {
    final argb = color.toARGB32();
    final resolvedAlpha = alpha ?? (((argb >> 24) & 0xFF) / 255.0);
    return vm.Vector4(
      ((argb >> 16) & 0xFF) / 255.0,
      ((argb >> 8) & 0xFF) / 255.0,
      (argb & 0xFF) / 255.0,
      resolvedAlpha,
    );
  }

  Node _meshNode(
    Geometry geometry,
    Material material, {
    String name = '',
    vm.Vector3? position,
    vm.Quaternion? rotation,
    vm.Vector3? scale,
  }) {
    final node = Node(name: name, mesh: Mesh(geometry, material));
    if (position != null) node.position = position;
    if (rotation != null) node.rotation = rotation;
    if (scale != null) node.scale = scale;
    return node;
  }

  void _buildRooftop() {
    // Use a single floor piece across the whole arena. The source mesh is not
    // centered, so we shift it by its centroid/bounds center and scale it up
    // to fit fully inside the actual 7.2 x 7.2 playable arena without repeating it.
    // Apply scale directly to the floor node and use a world-space centering
    // offset. This avoids parent-scale/child-translation transform ambiguity
    // that previously pushed most of the mesh outside the playable area.
    const floorScale = 2.92;
    final floor = _floorTemplate.clone(recursive: true)
      ..name = 'arena_floor'
      ..rotation = vm.Quaternion.identity()
      ..scale = vm.Vector3(floorScale, 1.0, floorScale)
      ..position = vm.Vector3(-2.35990966, 0.03534082, 2.35990966);
    scene.add(floor);

    // Huge star field centered around the entire arena/camera volume.
    // Keeping the camera *inside* the field makes the stars fill the whole
    // screen instead of appearing as a small patch at the top.
    _backgroundRoot = Node(name: 'moving_star_background')
      ..position = vm.Vector3.zero()
      ..scale = vm.Vector3.all(0.085);
    final background = _backgroundTemplate.clone(recursive: true)
      ..name = 'moving_star_background_model';
    background.castsShadows = false;
    _backgroundRoot.add(background);
    scene.add(_backgroundRoot);

    // Border walls removed by request.

    _obstacleRoot = Node(name: 'dynamic_obstacle')..visible = false;
    final obstacleBody = _meshNode(
      CuboidGeometry(vm.Vector3(1.05, 1.78, .82)),
      _obstacleSideMaterial,
      position: vm.Vector3(0, .89, 0),
    );
    final obstacleTop = _meshNode(
      CuboidGeometry(vm.Vector3(.92, .09, .70)),
      _obstacleTopMaterial,
      position: vm.Vector3(0, 1.825, 0),
    );
    final obstacleStrip = _meshNode(
      CuboidGeometry(vm.Vector3(.60, .024, .03)),
      _gridMaterial,
      position: vm.Vector3(0, 1.885, 0),
    )..castsShadows = false;
    _obstacleRoot.addAll([obstacleBody, obstacleTop, obstacleStrip]);
    scene.add(_obstacleRoot);
  }

  void _updateBackground(double seconds) {
    // Very slow, almost imperceptible celestial drift. The field stays centered
    // around the camera/arena so no empty strip can appear at the edges.
    final spin = seconds * 0.018;
    final pitchWave = math.sin(seconds * 0.10) * 0.018;
    final rollWave = math.sin(seconds * 0.075) * 0.010;
    _backgroundRoot.position = vm.Vector3(
      math.sin(seconds * 0.08) * 0.45,
      math.cos(seconds * 0.06) * 0.28,
      math.cos(seconds * 0.07) * 0.45,
    );
    final yaw = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), spin);
    final pitch = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), pitchWave);
    final roll = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), rollWave);
    _backgroundRoot.rotation = yaw * pitch * roll;
  }

  void setObstacle({required bool visible, double x = .5, double y = .5}) {
    _obstacleRoot.visible = visible;
    if (!visible) return;
    final world = worldPosition(x, y);
    _obstacleRoot.position = vm.Vector3(world.x, 0, world.z);
  }

  KillerKilledFighterVisual addFighter(int id, Color accentColor) {
    final existing = fighters[id];
    if (existing != null) return existing;

    final visual = _buildFighter(id, accentColor);
    fighters[id] = visual;
    scene.add(visual.root);
    return visual;
  }

  KillerKilledFighterVisual _buildFighter(
    int id,
    Color accentColor,
  ) {
    final root = Node(name: 'fighter_$id');
    final bodyRoot = Node(name: 'body_root_$id');
    root.add(bodyRoot);

    final model = _characterTemplate.clone(recursive: true)
      ..name = 'cyberpunk_character_$id'
      ..scale = vm.Vector3.all(1.02)
      // The supplied Ready Player Me avatar already faces local +Z. Keeping
      // this identity is important: the previous extra 180° turn made the
      // character walk backwards with its back leading.
      ..rotation = vm.Quaternion.identity();
    bodyRoot.add(model);

    // Keep the supplied Cyberpunk model exactly as it is: original hair,
    // glasses, outfit, shoes and textures. No hat, coat cubes, accent strips or
    // other geometry is added around the legs/body.
    Node bone(String name) => model.getChildByName(name) ?? model;

    final hips = bone('Hips');
    final spine = bone('Spine');
    final spine1 = bone('Spine1');
    final spine2 = bone('Spine2');
    final neck = bone('Neck');
    final head = bone('Head');
    final leftShoulder = bone('LeftShoulder');
    final rightShoulder = bone('RightShoulder');
    final leftArm = bone('LeftArm');
    final rightArm = bone('RightArm');
    final leftForeArm = bone('LeftForeArm');
    final rightForeArm = bone('RightForeArm');
    final leftHand = bone('LeftHand');
    final rightHand = bone('RightHand');
    final leftUpLeg = bone('LeftUpLeg');
    final rightUpLeg = bone('RightUpLeg');
    final leftLeg = bone('LeftLeg');
    final rightLeg = bone('RightLeg');
    final leftFoot = bone('LeftFoot');
    final rightFoot = bone('RightFoot');

    final baseRotations = <String, vm.Quaternion>{
      'hips': vm.Quaternion.copy(hips.rotation),
      'spine': vm.Quaternion.copy(spine.rotation),
      'spine1': vm.Quaternion.copy(spine1.rotation),
      'spine2': vm.Quaternion.copy(spine2.rotation),
      'neck': vm.Quaternion.copy(neck.rotation),
      'head': vm.Quaternion.copy(head.rotation),
      'leftShoulder': vm.Quaternion.copy(leftShoulder.rotation),
      'rightShoulder': vm.Quaternion.copy(rightShoulder.rotation),
      'leftArm': vm.Quaternion.copy(leftArm.rotation),
      'rightArm': vm.Quaternion.copy(rightArm.rotation),
      'leftForeArm': vm.Quaternion.copy(leftForeArm.rotation),
      'rightForeArm': vm.Quaternion.copy(rightForeArm.rotation),
      'leftHand': vm.Quaternion.copy(leftHand.rotation),
      'rightHand': vm.Quaternion.copy(rightHand.rotation),
      'leftUpLeg': vm.Quaternion.copy(leftUpLeg.rotation),
      'rightUpLeg': vm.Quaternion.copy(rightUpLeg.rotation),
      'leftLeg': vm.Quaternion.copy(leftLeg.rotation),
      'rightLeg': vm.Quaternion.copy(rightLeg.rotation),
      'leftFoot': vm.Quaternion.copy(leftFoot.rotation),
      'rightFoot': vm.Quaternion.copy(rightFoot.rotation),
    };

    // Weapon is authored directly along character-local +Z (gameplay
    // forward). No 90-degree corrective rotation is needed, so the muzzle can
    // never point toward the floor. Both hands are posed around this weapon.
    final gunRoot = Node(name: 'gun_$id')
      ..position = vm.Vector3(-.035, 1.360, .400)
      ..rotation = vm.Quaternion.identity();
    gunRoot.add(
      _meshNode(
        _geo.gunBody,
        _metalMaterial,
        position: vm.Vector3(0, 0, .13),
      ),
    );
    gunRoot.add(
      _meshNode(
        _geo.gunBarrel,
        _metalMaterial,
        position: vm.Vector3(0, .01, .31),
      ),
    );
    gunRoot.add(
      _meshNode(
        _geo.gunHandle,
        _metalMaterial,
        position: vm.Vector3(0, -.105, .055),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -.34),
      ),
    );
    gunRoot.add(
      _meshNode(
        _geo.muzzleAccent,
        _metalMaterial,
        position: vm.Vector3(0, .01, .405),
      ),
    );
    bodyRoot.add(gunRoot);

    // aimRoot is a child of the weapon and sits exactly on the muzzle tip.
    // Laser, tracer and flash therefore inherit every recoil transform and
    // begin with zero visible gap from the pistol barrel.
    final aimRoot = Node(name: 'aim_root_$id')
      ..position = vm.Vector3(0, .01, .430);
    final laserGlow = _meshNode(
      _geo.laserGlow,
      _laserGlowMaterial,
      name: 'laser_glow',
      position: vm.Vector3(0, 0, 50.0),
      scale: vm.Vector3(.55, .55, 100),
    )
      ..visible = false
      ..castsShadows = false;
    final laser = _meshNode(
      _geo.laser,
      _laserMaterial,
      name: 'laser',
      position: vm.Vector3(0, 0, 50.0),
      scale: vm.Vector3(.42, .42, 100),
    )
      ..visible = false
      ..castsShadows = false;
    final shotTracer = _meshNode(
      _geo.laser,
      _shotMaterial,
      name: 'shot_tracer',
      position: vm.Vector3(0, 0, 3.0),
      scale: vm.Vector3(1.45, 1.45, 6.0),
    )
      ..visible = false
      ..castsShadows = false;
    final muzzleFlash = _meshNode(
      _geo.muzzleFlash,
      _shotMaterial,
      name: 'muzzle_flash',
      position: vm.Vector3(0, 0, .015),
      scale: vm.Vector3.zero(),
    )..castsShadows = false;
    aimRoot.addAll([laserGlow, laser, shotTracer, muzzleFlash]);
    gunRoot.add(aimRoot);

    // A different believable face-down arm arrangement is picked once per
    // fighter. It is then frozen, so corpses never keep the standing/walking
    // animation after hitting the floor.
    double rr(double min, double max) => min + _random.nextDouble() * (max - min);
    final deathPose = <String, vm.Vector3>{
      'leftShoulder': vm.Vector3(rr(-.25, .18), rr(-.35, .20), rr(.30, .90)),
      'rightShoulder': vm.Vector3(rr(-.25, .18), rr(-.20, .35), rr(-.90, -.30)),
      'leftArm': vm.Vector3(rr(-.45, .35), rr(-.30, .30), rr(.35, 1.05)),
      'rightArm': vm.Vector3(rr(-.45, .35), rr(-.30, .30), rr(-1.05, -.35)),
      'leftForeArm': vm.Vector3(rr(-.55, .35), rr(-.22, .22), rr(-.20, .55)),
      'rightForeArm': vm.Vector3(rr(-.55, .35), rr(-.22, .22), rr(-.55, .20)),
      'leftHand': vm.Vector3(rr(-.35, .35), rr(-.30, .30), rr(-.45, .45)),
      'rightHand': vm.Vector3(rr(-.35, .35), rr(-.30, .30), rr(-.45, .45)),
    };

    return KillerKilledFighterVisual(
      root: root,
      bodyRoot: bodyRoot,
      model: model,
      hips: hips,
      spine: spine,
      spine1: spine1,
      spine2: spine2,
      neck: neck,
      head: head,
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftArm: leftArm,
      rightArm: rightArm,
      leftForeArm: leftForeArm,
      rightForeArm: rightForeArm,
      leftHand: leftHand,
      rightHand: rightHand,
      leftUpLeg: leftUpLeg,
      rightUpLeg: rightUpLeg,
      leftLeg: leftLeg,
      rightLeg: rightLeg,
      leftFoot: leftFoot,
      rightFoot: rightFoot,
      baseRotations: baseRotations,
      gunRoot: gunRoot,
      aimRoot: aimRoot,
      laserGlow: laserGlow,
      laser: laser,
      muzzleFlash: muzzleFlash,
      shotTracer: shotTracer,
      deathPose: deathPose,
      accentColor: accentColor,
    );
  }

  vm.Quaternion _withDelta(
    vm.Quaternion base, {
    double x = 0,
    double y = 0,
    double z = 0,
  }) {
    var result = vm.Quaternion.copy(base);
    if (x != 0) {
      result = result * vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), x);
    }
    if (y != 0) {
      result = result * vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), y);
    }
    if (z != 0) {
      result = result * vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), z);
    }
    return result;
  }

  void updateFighter({
    required int id,
    required double x,
    required double y,
    required double angle,
    required double walkTime,
    required double speed,
    required double fall,
    required bool visible,
    required bool activeShooter,
    required bool laserVisible,
    required double laserLength,
    required double shotFlash,
    double hitFlash = 0,
  }) {
    final visual = fighters[id];
    if (visual == null) return;

    visual.root.visible = visible;
    if (!visible) return;

    final pos = worldPosition(x, y);
    visual.root.position = vm.Vector3(pos.x, fall * .08, pos.z);

    final yaw = (math.pi / 2) - angle;
    final yawQ = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw);
    if (fall > 0) {
      // Local +Z is the character's chest/front. Rotating +90° around local X
      // places that front toward the floor: a true face-down fall, not a side
      // roll.
      final faceDownQ = vm.Quaternion.axisAngle(
        vm.Vector3(1, 0, 0),
        fall * (math.pi / 2),
      );
      visual.root.rotation = yawQ * faceDownQ;
    } else {
      visual.root.rotation = yawQ;
    }

    final alive = (1.0 - fall).clamp(0.0, 1.0).toDouble();
    final move = fall > 0 ? 0.0 : (speed / .25).clamp(0.0, 1.0).toDouble();
    final step = fall > 0 ? 0.0 : math.sin(walkTime * 7.8);
    final stepOpposite = fall > 0 ? 0.0 : math.sin(walkTime * 7.8 + math.pi);
    final idle = fall > 0 ? 0.0 : math.sin(walkTime * 1.65 + id * .7);
    final recoil = (shotFlash / .22).clamp(0.0, 1.0).toDouble();
    final hit = hitFlash.clamp(0.0, 1.0).toDouble();
    // The character always carries the pistol in a focused two-hand ready
    // stance, including while walking. No T-pose/open-arm walking.
    final aim = alive;

    // Whole-body breathing / weight shift.
    visual.bodyRoot.position = vm.Vector3(
      hit * -.035,
      .012 * idle * (1 - move) + .018 * step.abs() * move,
      0,
    );
    visual.bodyRoot.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 0, 1),
      -.085 * hit + .016 * idle * (1 - move),
    );

    // Natural walk: opposite legs, bent knees, counter-swinging arms.
    visual.leftUpLeg.rotation = _withDelta(
      visual.baseRotations['leftUpLeg']!,
      x: .46 * step * move + .16 * fall,
      z: -.03 * move,
    );
    visual.rightUpLeg.rotation = _withDelta(
      visual.baseRotations['rightUpLeg']!,
      x: .46 * stepOpposite * move - .12 * fall,
      z: .03 * move,
    );
    visual.leftLeg.rotation = _withDelta(
      visual.baseRotations['leftLeg']!,
      x: .28 * math.max(0, -step) * move + .25 * fall,
    );
    visual.rightLeg.rotation = _withDelta(
      visual.baseRotations['rightLeg']!,
      x: .28 * math.max(0, step) * move - .18 * fall,
    );
    visual.leftFoot.rotation = _withDelta(
      visual.baseRotations['leftFoot']!,
      x: -.08 * step * move,
    );
    visual.rightFoot.rotation = _withDelta(
      visual.baseRotations['rightFoot']!,
      x: -.08 * stepOpposite * move,
    );

    visual.hips.rotation = _withDelta(
      visual.baseRotations['hips']!,
      z: .045 * step * move + .10 * fall,
    );
    visual.spine.rotation = _withDelta(
      visual.baseRotations['spine']!,
      x: -.025 * move,
      z: -.03 * step * move - .12 * hit,
    );
    visual.spine1.rotation = _withDelta(
      visual.baseRotations['spine1']!,
      x: .012 * idle * (1 - move),
      z: .022 * step * move,
    );
    visual.spine2.rotation = _withDelta(
      visual.baseRotations['spine2']!,
      x: -.055 * aim + .08 * recoil,
      z: .025 * step * move,
    );

    // Alive: focused two-hand pistol stance. Dead: smoothly transition to
    // the fighter's one-time randomized face-down arm pose and then freeze.
    vm.Vector3 death(String key) => visual.deathPose[key]!;
    double mix(double aliveValue, double deadValue) => aliveValue * alive + deadValue * fall;

    visual.leftShoulder.rotation = _withDelta(
      visual.baseRotations['leftShoulder']!,
      x: mix(.099, death('leftShoulder').x),
      y: mix(-.167, death('leftShoulder').y),
      z: mix(.649, death('leftShoulder').z),
    );
    visual.rightShoulder.rotation = _withDelta(
      visual.baseRotations['rightShoulder']!,
      x: mix(.198, death('rightShoulder').x),
      y: mix(.147, death('rightShoulder').y),
      z: mix(-.700, death('rightShoulder').z),
    );
    visual.leftArm.rotation = _withDelta(
      visual.baseRotations['leftArm']!,
      x: mix(.122 + .035 * recoil, death('leftArm').x),
      y: mix(.089, death('leftArm').y),
      z: mix(.550, death('leftArm').z),
    );
    visual.rightArm.rotation = _withDelta(
      visual.baseRotations['rightArm']!,
      x: mix(.126 + .095 * recoil, death('rightArm').x),
      y: mix(-.039, death('rightArm').y),
      z: mix(-.558, death('rightArm').z),
    );
    visual.leftForeArm.rotation = _withDelta(
      visual.baseRotations['leftForeArm']!,
      x: mix(.134 + .025 * recoil, death('leftForeArm').x),
      y: mix(.009, death('leftForeArm').y),
      z: mix(.069, death('leftForeArm').z),
    );
    visual.rightForeArm.rotation = _withDelta(
      visual.baseRotations['rightForeArm']!,
      x: mix(-.081 + .080 * recoil, death('rightForeArm').x),
      y: mix(-.005, death('rightForeArm').y),
      z: mix(.062, death('rightForeArm').z),
    );
    visual.leftHand.rotation = _withDelta(
      visual.baseRotations['leftHand']!,
      x: mix(-.08, death('leftHand').x),
      y: mix(-.05, death('leftHand').y),
      z: mix(.06, death('leftHand').z),
    );
    visual.rightHand.rotation = _withDelta(
      visual.baseRotations['rightHand']!,
      x: mix(-.06 + .07 * recoil, death('rightHand').x),
      y: mix(.02, death('rightHand').y),
      z: mix(-.03, death('rightHand').z),
    );

    // Recoil is applied to the actual weapon too, so hands + pistol read as
    // one physical unit rather than an arm animation over a static prop.
    visual.gunRoot.position = vm.Vector3(
      -.035 + .18 * fall,
      1.360 - .08 * fall + recoil * .012,
      .400 - recoil * .060,
    );
    visual.gunRoot.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      recoil * .10 + fall * .16,
    );

    visual.neck.rotation = _withDelta(
      visual.baseRotations['neck']!,
      y: .028 * idle * (1 - aim),
    );
    visual.head.rotation = _withDelta(
      visual.baseRotations['head']!,
      x: .018 * idle * (1 - aim),
      y: .040 * idle * (1 - aim),
      z: -.045 * hit,
    );


    // Player distinction is only a subtle colored glow/outline on the
    // original character mesh. No colored clothes, hat bands or props.
    final highlight = hit > 0
        ? vm.Vector4(1, .10, .14, .82 * hit)
        : _vectorColor(visual.accentColor, alpha: .22);
    for (final meshNode in visual.model.meshNodes) {
      meshNode.highlightColor = highlight;
    }

    visual.laser.visible = laserVisible;
    visual.laserGlow.visible = laserVisible;
    if (laserVisible) {
      const visualLength = 100.0;
      visual.laser.position = vm.Vector3(0, 0, visualLength / 2);
      visual.laser.scale = vm.Vector3(.42, .42, visualLength);
      visual.laserGlow.position = vm.Vector3(0, 0, visualLength / 2);
      visual.laserGlow.scale = vm.Vector3(.55, .55, visualLength);
    }

    if (shotFlash > 0) {
      final pulse = (shotFlash / .22).clamp(0.0, 1.0).toDouble();
      visual.muzzleFlash.scale = vm.Vector3.all(.72 + pulse * 1.42);
      visual.muzzleFlash.visible = true;
      final tracerLength = laserLength.clamp(.30, 8.2).toDouble();
      visual.shotTracer.position = vm.Vector3(0, 0, tracerLength / 2);
      visual.shotTracer.scale = vm.Vector3(
        1.55 + pulse * .95,
        1.55 + pulse * .95,
        tracerLength,
      );
      visual.shotTracer.visible = true;
    } else {
      visual.muzzleFlash.visible = false;
      visual.shotTracer.visible = false;
    }
  }

  void addBlood(double x, double y) {
    final world = worldPosition(x, y);
    final stain = _meshNode(
      _geo.bloodDisc,
      _bloodMaterial,
      position: vm.Vector3(world.x, .018, world.z),
      scale: vm.Vector3(
        .74 + _random.nextDouble() * .58,
        1,
        .54 + _random.nextDouble() * .48,
      ),
      rotation: vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        _random.nextDouble() * math.pi,
      ),
    )..castsShadows = false;
    scene.add(stain);
    _bloodNodes.add(stain);

    for (var i = 0; i < 4; i++) {
      final drop = _meshNode(
        _geo.bloodDrop,
        _bloodMaterial,
        position: vm.Vector3(
          world.x + (_random.nextDouble() - .5) * .46,
          .019,
          world.z + (_random.nextDouble() - .5) * .46,
        ),
        scale: vm.Vector3.all(.28 + _random.nextDouble() * .35),
      )..castsShadows = false;
      scene.add(drop);
      _bloodNodes.add(drop);
    }
  }

  void clearBlood() {
    for (final node in _bloodNodes) {
      node.detach();
    }
    _bloodNodes.clear();
  }

  vm.Vector3 worldPosition(double x, double y, {double height = 0}) {
    return vm.Vector3(
      (x - .5) * arenaWorldSize,
      height,
      (y - .5) * arenaWorldSize,
    );
  }

  PerspectiveCamera cameraFor({
    required double seconds,
    required double playerX,
    required double playerY,
    required double playerAngle,
    required double cameraOrbit,
    required double cameraPitch,
    required double cameraZoom,
    required double spectatorAmount,
  }) {
    _updateBackground(seconds);

    final player = worldPosition(playerX, playerY);
    final orbitHeading = playerAngle + cameraOrbit;
    final playerForward = vm.Vector3(
      math.cos(playerAngle),
      0,
      math.sin(playerAngle),
    );
    final cameraForward = vm.Vector3(
      math.cos(orbitHeading),
      0,
      math.sin(orbitHeading),
    );
    final cameraRight = vm.Vector3(
      -math.sin(orbitHeading),
      0,
      math.cos(orbitHeading),
    );

    // Third-person camera has zero autonomous motion. Its yaw is controlled
    // only by player/inspection yaw and its vertical angle only by right-side
    // touch dragging. The value persists exactly where the player leaves it.
    // Closer over-the-shoulder framing. Pinch zoom is limited to a small,
    // controlled range so the player cannot break the aiming/composition.
    const baseThirdPersonHorizontalDistance = 2.72;
    final zoom = cameraZoom.clamp(0.86, 1.18).toDouble();
    final thirdPersonHorizontalDistance = baseThirdPersonHorizontalDistance / zoom;
    const baseThirdPersonElevation = 0.34; // about 19.5 degrees
    final thirdPersonElevation =
        (baseThirdPersonElevation + cameraPitch).clamp(0.10, 0.84).toDouble();
    final thirdPersonTarget = vm.Vector3(
      player.x + playerForward.x * .78,
      1.10,
      player.z + playerForward.z * .78,
    );
    final thirdPersonPosition = vm.Vector3(
      player.x - cameraForward.x * thirdPersonHorizontalDistance + cameraRight.x * .40,
      thirdPersonTarget.y + math.tan(thirdPersonElevation) * thirdPersonHorizontalDistance,
      player.z - cameraForward.z * thirdPersonHorizontalDistance + cameraRight.z * .40,
    );

    // Dead-player spectator view keeps the requested ~60-degree tactical
    // angle, while still allowing the player to raise/lower and orbit it by
    // dragging the right half of the screen.
    final spectatorHeading = (-math.pi / 4) + cameraOrbit;
    final spectatorHorizontalRadius = 8.5 / zoom;
    final spectatorElevation =
        ((math.pi / 3) + cameraPitch * .65).clamp(0.58, 1.34).toDouble();
    final spectatorPosition = vm.Vector3(
      math.cos(spectatorHeading) * spectatorHorizontalRadius,
      math.tan(spectatorElevation) * spectatorHorizontalRadius,
      math.sin(spectatorHeading) * spectatorHorizontalRadius,
    );
    final spectatorTarget = vm.Vector3(0, .28, 0);

    final t = spectatorAmount.clamp(0.0, 1.0).toDouble();
    vm.Vector3 blend(vm.Vector3 a, vm.Vector3 b) => vm.Vector3(
          a.x + (b.x - a.x) * t,
          a.y + (b.y - a.y) * t,
          a.z + (b.z - a.z) * t,
        );

    final position = blend(thirdPersonPosition, spectatorPosition);
    final target = blend(thirdPersonTarget, spectatorTarget);
    final fovDegrees = 58.0 + (50.0 - 58.0) * t;

    return PerspectiveCamera(
      position: position,
      target: target,
      up: vm.Vector3(0, 1, 0),
      fovRadiansY: fovDegrees * math.pi / 180,
      fovNear: .08,
      fovFar: 220,
    );
  }

  Offset? labelScreenPoint({
    required double x,
    required double y,
    required double seconds,
    required double playerX,
    required double playerY,
    required double playerAngle,
    required double cameraOrbit,
    required double cameraPitch,
    required double cameraZoom,
    required double spectatorAmount,
    required Size viewSize,
  }) {
    final camera = cameraFor(
      seconds: seconds,
      playerX: playerX,
      playerY: playerY,
      playerAngle: playerAngle,
      cameraOrbit: cameraOrbit,
      cameraPitch: cameraPitch,
      cameraZoom: cameraZoom,
      spectatorAmount: spectatorAmount,
    );
    return camera.worldToScreen(
      worldPosition(x, y, height: fighterLabelHeight),
      viewSize,
    );
  }
}

class KillerKilledFighterVisual {
  KillerKilledFighterVisual({
    required this.root,
    required this.bodyRoot,
    required this.model,
    required this.hips,
    required this.spine,
    required this.spine1,
    required this.spine2,
    required this.neck,
    required this.head,
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftArm,
    required this.rightArm,
    required this.leftForeArm,
    required this.rightForeArm,
    required this.leftHand,
    required this.rightHand,
    required this.leftUpLeg,
    required this.rightUpLeg,
    required this.leftLeg,
    required this.rightLeg,
    required this.leftFoot,
    required this.rightFoot,
    required this.baseRotations,
    required this.gunRoot,
    required this.aimRoot,
    required this.laserGlow,
    required this.laser,
    required this.muzzleFlash,
    required this.shotTracer,
    required this.deathPose,
    required this.accentColor,
  });

  final Node root;
  final Node bodyRoot;
  final Node model;
  final Node hips;
  final Node spine;
  final Node spine1;
  final Node spine2;
  final Node neck;
  final Node head;
  final Node leftShoulder;
  final Node rightShoulder;
  final Node leftArm;
  final Node rightArm;
  final Node leftForeArm;
  final Node rightForeArm;
  final Node leftHand;
  final Node rightHand;
  final Node leftUpLeg;
  final Node rightUpLeg;
  final Node leftLeg;
  final Node rightLeg;
  final Node leftFoot;
  final Node rightFoot;
  final Map<String, vm.Quaternion> baseRotations;
  final Node gunRoot;
  final Node aimRoot;
  final Node laserGlow;
  final Node laser;
  final Node muzzleFlash;
  final Node shotTracer;
  final Map<String, vm.Vector3> deathPose;
  final Color accentColor;
}

class _GeometryBank {
  _GeometryBank()
      : gunBody = CuboidGeometry(vm.Vector3(.075, .075, .24)),
        gunBarrel = CuboidGeometry(vm.Vector3(.050, .050, .14)),
        gunHandle = CuboidGeometry(vm.Vector3(.075, .16, .085)),
        muzzleAccent = CuboidGeometry(vm.Vector3(.090, .090, .035)),
        laser = CuboidGeometry(vm.Vector3(.0045, .0045, 1)),
        laserGlow = CuboidGeometry(vm.Vector3(.012, .012, 1)),
        muzzleFlash = IcosphereGeometry(radius: .065, subdivisions: 1),
        bloodDisc = DiscGeometry(radius: .28, segments: 20),
        bloodDrop = DiscGeometry(radius: .10, segments: 14);

  final Geometry gunBody;
  final Geometry gunBarrel;
  final Geometry gunHandle;
  final Geometry muzzleAccent;
  final Geometry laser;
  final Geometry laserGlow;
  final Geometry muzzleFlash;
  final Geometry bloodDisc;
  final Geometry bloodDrop;
}
