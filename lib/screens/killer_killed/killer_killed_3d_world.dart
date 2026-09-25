import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show Color, Offset, Size;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/killer_killed_avatar.dart';

class KillerKilled3DWorld {
  KillerKilled3DWorld();

  static const double arenaWorldSize = 7.2;
  static const double fighterLabelHeight = 2.22;

  final Scene scene = Scene();
  final Map<int, KillerKilledFighterVisual> fighters = {};
  final List<Node> _bloodNodes = [];
  final List<_BloodParticle> _bloodParticles = [];
  final math.Random _random = math.Random(1729);

  bool ready = false;

  late final _GeometryBank _geo;
  late final PhysicallyBasedMaterial _floorMaterial;
  late final PhysicallyBasedMaterial _parapetMaterial;
  late final PhysicallyBasedMaterial _obstacleTopMaterial;
  late final PhysicallyBasedMaterial _obstacleSideMaterial;
  late final PhysicallyBasedMaterial _obstacleEdgeMaterial;
  late final PhysicallyBasedMaterial _metalMaterial;
  late final UnlitMaterial _gridMaterial;
  late final UnlitMaterial _bloodMaterial;
  late final UnlitMaterial _bloodSprayMaterial;
  late final UnlitMaterial _laserMaterial;
  late final UnlitMaterial _laserGlowMaterial;
  late final UnlitMaterial _shotMaterial;

  late final Node _obstacleRoot;
  late final Node _characterTemplate;
  late final Node _stageTemplate;
  late final Node _graveTemplate;
  Node? _stageOuterBackground;

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

    final thermalOptimized =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    // iOS uses a lighter render profile to avoid driving Retina-resolution
    // offscreen targets, cascaded shadows and SSAO at full cost continuously.
    // Other platforms keep the previously approved visual settings.
    scene.renderScale = thermalOptimized ? .80 : 1.0;
    scene.exposure = 1.12;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.56, -1.0, -.42),
      color: vm.Vector3(.84, .91, 1.0),
      intensity: 2.5,
      castsShadow: true,
      shadowCascadeCount: thermalOptimized ? 1 : 2,
      shadowMaxDistance: thermalOptimized ? 18 : 36,
      shadowMapResolution: thermalOptimized ? 512 : 1024,
      shadowSoftness: .16,
      shadowAmbientStrength: .22,
    );
    scene.ambientOcclusion
      ..enabled = true
      ..halfResolution = true
      ..sampleCount = thermalOptimized ? 4 : 8
      ..radius = .34
      ..intensity = .86;

    _geo = _GeometryBank();
    _createMaterials();
    onProgress?.call(.24, 'تحميل الشخصية');
    _characterTemplate = await Node.fromGlbAsset(
      'assets/models/creative_character_free.glb',
    );
    onProgress?.call(.48, 'تحميل الستيج الدائري');
    _stageTemplate = await Node.fromGlbAsset(
      'assets/models/low_poly_sci_fi_fighting_stage.glb',
    );
    onProgress?.call(.60, 'تحميل حاجز القبر');
    _graveTemplate = await Node.fromGlbAsset(
      'assets/models/graveyard_stone.glb',
    );
    onProgress?.call(.68, 'تجهيز خلفية الستيج');
    onProgress?.call(.86, 'بناء الساحة');
    _buildRooftop();
    ready = true;
    onProgress?.call(1, 'المشهد جاهز');
  }

  void _createMaterials() {
    _floorMaterial = _pbr(const Color(0xFF182433), roughness: .72, metallic: .17);
    _parapetMaterial = _pbr(const Color(0xFF222D3A), roughness: .64, metallic: .22);
    // Industrial floor-matched obstacle: muted yellow metal with deep black guards.
    _obstacleTopMaterial = _pbr(const Color(0xFFA48B3B), roughness: .48, metallic: .48);
    _obstacleSideMaterial = _pbr(const Color(0xFF716437), roughness: .58, metallic: .40);
    _obstacleEdgeMaterial = _pbr(const Color(0xFF07090D), roughness: .42, metallic: .72);
    _metalMaterial = _pbr(const Color(0xFF3D4654), roughness: .32, metallic: .76);
    _gridMaterial = _unlit(const Color(0x3A2F6DFF));
    _bloodMaterial = _unlit(const Color(0xFFB00008));
    _bloodSprayMaterial = _unlit(const Color(0xFFE0000B));
    // Bright neon-red laser: a crisp luminous core plus a wider transparent
    // halo so it reads clearly against the black/star background.
    // Opaque neon core keeps correct depth against the floor; only the halo blends.
    // This prevents the beam from looking as if it were rendered underneath the floor.
    _laserMaterial = _unlit(const Color(0xFFFF0016));
    _laserGlowMaterial = _unlit(const Color(0x88FF0016));
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
    // The fighting-stage GLB already contains the circular floor, its light
    // ring and the surrounding sci-fi structure.  The inner edge of the light
    // ring is radius 12.445198 in the source mesh, with the GLB carrying an
    // internal 0.01 scale.  Scaling the imported root by 28.92682 therefore
    // makes that exact inner edge 3.60 world units from the center.
    //
    // This is intentional: a 3.60-radius circle has an area of 40.715 world²,
    // almost identical to the previous practical movement square
    // (6.408 x 6.408 = 41.062 world²).  So the arena keeps essentially the
    // same usable size while becoming genuinely circular.
    const stageScale = 28.92681967;
    final stage = _stageTemplate.clone(recursive: true)
      ..name = 'sci_fi_fighting_stage'
      ..rotation = vm.Quaternion.identity()
      ..scale = vm.Vector3.all(stageScale)
      ..position = vm.Vector3.zero();

    // Keep the playable circular floor and its illuminated edge EXACTLY at the
    // approved size, but move the outer architecture much farther away. The
    // source model keeps the roof / outer supports in the `Spot` branch and
    // the huge environment dome in `AS`. Scaling those branches independently
    // gives the camera a large, clean volume without changing gameplay bounds.
    //
    // Spot source bounds: y 1.6100545 -> 10.342126. We scale around the lower
    // anchor, so the supports still start at the same height while the upper
    // ring/ceiling rises to roughly 7.5 world units. X/Z are doubled to push
    // the outer supports away from the camera.
    final outerStructure = stage.getChildByName('Spot');
    if (outerStructure != null) {
      const outerXZ = 2.0;
      const outerY = 2.8;
      const sourceBaseY = 1.6100545;
      outerStructure
        ..scale = vm.Vector3(outerXZ, outerY, outerXZ)
        ..position = vm.Vector3(0, sourceBaseY * (1 - outerY), 0);
    }

    // V12: the GLB itself now preserves the playable circular floor at its
    // approved size while radially widening ONLY the surrounding/lower Ground
    // geometry until it reaches the enlarged outer pillar footprint.  Do not
    // add a cloned Ground branch here; that old workaround created a separate
    // visible ring instead of enlarging the actual floor under the stage.

    // `AS` is the model's own purple sci-fi environment. Enlarge it enough to
    // keep every allowed camera position inside, and retain a direct reference
    // so we can animate THIS background instead of the old external star GLB.
    final outerDome = stage.getChildByName('AS');
    final animatedBackgroundMeshes = <Node>{};
    if (outerDome != null) {
      const domeXZ = 1.90;
      const domeY = 1.90;
      const sourceDomeBaseY = -7.9562254;
      outerDome
        ..scale = vm.Vector3(domeXZ, domeY, domeXZ)
        ..position = vm.Vector3(0, sourceDomeBaseY * (1 - domeY), 0);

      // The animated environment never needs to cast a shadow. Disable its
      // actual mesh nodes too (castsShadows is not inherited by descendants).
      for (final meshNode in outerDome.meshNodes) {
        meshNode.castsShadows = false;
        animatedBackgroundMeshes.add(meshNode);
      }
      _stageOuterBackground = outerDome;
    }

    // Everything else in the stage is genuinely static. flutter_scene can
    // cache those shadow tiles instead of re-encoding the same geometry every
    // frame, while fighters and the movable grave remain dynamic casters.
    for (final meshNode in stage.meshNodes) {
      if (!animatedBackgroundMeshes.contains(meshNode)) {
        meshNode.shadowStatic = true;
      }
    }

    scene.add(stage);

    // Border walls removed by request.

    // Random protection object: use the supplied grave model instead of the old
    // yellow cuboid. The source grave is intentionally non-uniformly scaled so
    // its final world footprint/height matches the previous blocker almost
    // exactly: 1.05 W x 1.78 H x 0.82 D. This preserves gameplay spacing and
    // the existing logical collision rectangle while changing only the visual.
    _obstacleRoot = Node(name: 'dynamic_grave_obstacle')..visible = false;
    final grave = _graveTemplate.clone(recursive: true)
      ..name = 'grave_shield'
      // Source bounds after its Sketchfab X rotation:
      // width=172.3182, depth=132.1344, height=242.5097.
      ..scale = vm.Vector3(0.0060934, 0.0062120, 0.0073400)
      // Source vertical range is -134.3878..108.1219 after rotation; this
      // offset plants the lowest point exactly on the arena floor.
      ..position = vm.Vector3(0, .9864, 0);
    for (final meshNode in grave.meshNodes) {
      meshNode.highlightColor = null;
      meshNode.castsShadows = true;
    }
    _obstacleRoot.add(grave);
    scene.add(_obstacleRoot);
  }

  void _updateBackground(double seconds) {
    // Animate only the stage model's own purple `AS` environment. A slow yaw
    // creates continuous motion without moving the floor, lights, pillars or
    // camera. No separate star-field model is used anymore.
    final background = _stageOuterBackground;
    if (background == null) return;
    final yaw = seconds * 0.0105;
    background.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw);
  }

  void setObstacle({required bool visible, double x = .5, double y = .5}) {
    _obstacleRoot.visible = visible;
    if (!visible) return;
    final world = worldPosition(x, y);
    _obstacleRoot.position = vm.Vector3(world.x, 0, world.z);
  }

  KillerKilledFighterVisual addFighter(
    int id,
    KillerKilledAvatar avatar,
    Color accentColor,
  ) {
    final existing = fighters[id];
    if (existing != null) return existing;

    final visual = _buildFighter(id, avatar, accentColor);
    fighters[id] = visual;
    scene.add(visual.root);
    return visual;
  }

  void setFighterAvatar(int id, KillerKilledAvatar avatar) {
    final visual = fighters[id];
    if (visual == null) return;
    _applyAvatarToModel(visual.model, avatar);
  }

  void _applyAvatarToModel(Node model, KillerKilledAvatar avatar) {
    final visible = avatar.visibleNodeNames;
    for (final name in KillerKilledAvatar.customizableNodeNames) {
      final node = model.getChildByName(name);
      if (node != null) node.visible = visible.contains(name);
    }
    final body = model.getChildByName('Body_010');
    if (body != null) body.visible = true;
  }

  KillerKilledFighterVisual _buildFighter(
    int id,
    KillerKilledAvatar avatar,
    Color accentColor,
  ) {
    final root = Node(name: 'fighter_$id');
    final bodyRoot = Node(name: 'body_root_$id');
    root.add(bodyRoot);

    final model = _characterTemplate.clone(recursive: true)
      ..name = 'creative_character_$id'
      ..scale = vm.Vector3.all(1.02)
      // The Creative Characters rig faces local +Z, which is the arena's
      // gameplay-forward axis.
      ..rotation = vm.Quaternion.identity();
    bodyRoot.add(model);

    // Selection outlines never change during gameplay. Configure them once
    // instead of touching every mesh on every frame for every fighter.
    for (final meshNode in model.meshNodes) {
      meshNode.highlightColor = null;
    }

    _applyAvatarToModel(model, avatar);

    Node bone(String name) {
      final node = model.getChildByName(name);
      if (node == null) {
        throw StateError('Missing character bone: $name');
      }
      return node;
    }

    final hips = bone('Hips');
    final spine = bone('Spine');
    final spine1 = bone('Spine1');
    // Creative Characters uses a two-spine chain. Keep a detached no-op node
    // for the optional third chest bone so the animation code stays generic.
    final spine2 = model.getChildByName('Spine2') ?? Node(name: 'virtual_spine2_$id');
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
    final leftHandProp = bone('LeftHandProp');
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

    // Creative Characters' imported hand labels are visually mirrored in this
    // scene. LeftHandProp is the character's visible RIGHT hand, so the pistol
    // must be attached here to appear in the correct hand on screen.
    final gunBaseRotation = vm.Quaternion(
      0.81208887,
      -0.34605342,
      -0.34939943,
      -0.31413173,
    );
    final gunRoot = Node(name: 'gun_$id')
      ..position = vm.Vector3.zero()
      ..rotation = vm.Quaternion.copy(gunBaseRotation);
    // Offset in the pistol's own local axes: slightly higher and a little back
    // toward the wrist, without changing the hand/arm pose.
    final gunContent = Node(name: 'gun_content_$id')
      ..position = vm.Vector3(0, .032, -.035);
    gunRoot.add(gunContent);
    gunContent.add(
      _meshNode(
        _geo.gunBody,
        _metalMaterial,
        position: vm.Vector3(0, 0, .13),
      ),
    );
    gunContent.add(
      _meshNode(
        _geo.gunBarrel,
        _metalMaterial,
        position: vm.Vector3(0, .01, .31),
      ),
    );
    gunContent.add(
      _meshNode(
        _geo.gunHandle,
        _metalMaterial,
        position: vm.Vector3(0, -.105, .055),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -.34),
      ),
    );
    gunContent.add(
      _meshNode(
        _geo.muzzleAccent,
        _metalMaterial,
        position: vm.Vector3(0, .01, .405),
      ),
    );
    leftHandProp.add(gunRoot);

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
    gunContent.add(aimRoot);

    // Disable flutter_scene selection outlines completely for the weapon and
    // beam. A transparent highlight color still registers as a highlighted
    // node, so use null (no highlight pass) rather than RGBA(0,0,0,0).
    gunRoot.highlightColor = null;
    gunContent.highlightColor = null;
    aimRoot.highlightColor = null;
    laser.highlightColor = null;
    laserGlow.highlightColor = null;
    shotTracer.highlightColor = null;
    muzzleFlash.highlightColor = null;

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
      gunBaseRotation: gunBaseRotation,
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

  void setFighterVisible(int id, bool visible) {
    final visual = fighters[id];
    if (visual == null || visual.root.visible == visible) return;
    visual.root.visible = visible;
  }

  void updateFighter({
    required int id,
    required double x,
    required double y,
    required double angle,
    required double walkTime,
    required double speed,
    required double forwardMotion,
    required double strafeMotion,
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

    if (visual.root.visible != visible) {
      visual.root.visible = visible;
    }
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
    final idle = fall > 0 ? 0.0 : math.sin(walkTime * 1.65 + id * .7);
    final forwardIntent = forwardMotion.clamp(-1.0, 1.0).toDouble();
    final strafeIntent = strafeMotion.clamp(-1.0, 1.0).toDouble();
    final recoil = (shotFlash / .22).clamp(0.0, 1.0).toDouble();
    final hit = hitFlash.clamp(0.0, 1.0).toDouble();
    final aim = alive;

    final forwardAmount = forwardIntent.abs();
    final strafeAmount = strafeIntent.abs();
    final intentTotal = forwardAmount + strafeAmount;
    final forwardWeight = intentTotal > .001 ? forwardAmount / intentTotal : 0.0;
    final strafeWeight = intentTotal > .001 ? strafeAmount / intentTotal : 0.0;
    final gaitDirection = forwardIntent < -.08 ? -1.0 : 1.0;
    final forwardStep = step * gaitDirection * move * forwardWeight;

    // The Creative Characters legs are mirrored. Applying opposite local-Z
    // rotations made both feet travel the same world direction at once. Using
    // the SAME local-Z phase makes one foot advance while the other goes back.
    double leftSideSwing = 0;
    double rightSideSwing = 0;
    final sideAmplitude = .42 * move * strafeWeight;
    if (strafeIntent > .04) {
      // Move right: right foot leads, then the left foot follows.
      rightSideSwing = math.max(0.0, step) * sideAmplitude;
      leftSideSwing = -math.max(0.0, -step) * sideAmplitude;
    } else if (strafeIntent < -.04) {
      // Move left: left foot leads, then the right foot follows.
      leftSideSwing = math.max(0.0, step) * sideAmplitude;
      rightSideSwing = -math.max(0.0, -step) * sideAmplitude;
    }

    // Only vertical breathing/bounce here. Side movement rotates the whole
    // fighter in gameplay; it must never look like the body is falling/leaning.
    visual.bodyRoot.position = vm.Vector3(
      hit * -.035,
      .010 * idle * (1 - move) + .016 * step.abs() * move,
      0,
    );
    visual.bodyRoot.rotation = _withDelta(
      vm.Quaternion.identity(),
      z: -.085 * hit + .012 * idle * (1 - move),
    );

    // Natural forward/back gait: opposite feet in world space, with real knee
    // flex. Backward simply reverses the phase while keeping the torso facing
    // the same way. Sideways uses local-X stepping instead of fake forward steps.
    visual.leftUpLeg.rotation = _withDelta(
      visual.baseRotations['leftUpLeg']!,
      x: leftSideSwing,
      z: .50 * forwardStep + .16 * fall,
    );
    visual.rightUpLeg.rotation = _withDelta(
      visual.baseRotations['rightUpLeg']!,
      x: rightSideSwing,
      z: .50 * forwardStep - .12 * fall,
    );
    visual.leftLeg.rotation = _withDelta(
      visual.baseRotations['leftLeg']!,
      z: .34 * math.max(0.0, -forwardStep) + .15 * leftSideSwing.abs() + .25 * fall,
    );
    visual.rightLeg.rotation = _withDelta(
      visual.baseRotations['rightLeg']!,
      z: -.34 * math.max(0.0, forwardStep) - .15 * rightSideSwing.abs() - .18 * fall,
    );
    visual.leftFoot.rotation = _withDelta(
      visual.baseRotations['leftFoot']!,
      x: -.10 * leftSideSwing,
      z: -.09 * forwardStep,
    );
    visual.rightFoot.rotation = _withDelta(
      visual.baseRotations['rightFoot']!,
      x: -.10 * rightSideSwing,
      z: .09 * forwardStep,
    );

    visual.hips.rotation = _withDelta(
      visual.baseRotations['hips']!,
      y: .030 * step * move,
      z: .10 * fall,
    );
    visual.spine.rotation = _withDelta(
      visual.baseRotations['spine']!,
      x: -.020 * move,
      z: -.020 * step * move - .12 * hit,
    );
    visual.spine1.rotation = _withDelta(
      visual.baseRotations['spine1']!,
      x: .010 * idle * (1 - move) - .035 * aim + .06 * recoil,
      z: .014 * step * move,
    );
    visual.spine2.rotation = _withDelta(
      visual.baseRotations['spine2']!,
      z: .016 * step * move,
    );

    // The imported rig is visually mirrored: the bones named Left* drive the
    // character's visible RIGHT arm. Keep that arm fully extended with the gun.
    // The visible LEFT arm (Right* bones) hangs relaxed at idle and rises
    // diagonally while walking, then smoothly lowers again when movement stops.
    vm.Vector3 death(String key) => visual.deathPose[key]!;
    double mix(double aliveValue, double deadValue) => aliveValue * alive + deadValue * fall;
    double pose(double idleValue, double walkingValue) =>
        idleValue + (walkingValue - idleValue) * move;

    // Visible RIGHT arm: pistol arm, stretched forward. Values are the mirrored
    // counterpart of the previously tested opposite-hand aiming pose.
    visual.leftShoulder.rotation = _withDelta(
      visual.baseRotations['leftShoulder']!,
      x: mix(.101 + .012 * recoil, death('leftShoulder').x),
      y: mix(-.470, death('leftShoulder').y),
      z: mix(-.229, death('leftShoulder').z),
    );
    visual.leftArm.rotation = _withDelta(
      visual.baseRotations['leftArm']!,
      x: mix(-.675 + .028 * recoil, death('leftArm').x),
      y: mix(.386, death('leftArm').y),
      z: mix(-.853, death('leftArm').z),
    );
    visual.leftForeArm.rotation = _withDelta(
      visual.baseRotations['leftForeArm']!,
      x: mix(-.173 + .022 * recoil, death('leftForeArm').x),
      y: mix(-.003, death('leftForeArm').y),
      z: mix(.304, death('leftForeArm').z),
    );

    // Visible LEFT arm: relaxed down while idle, raised diagonally on walk.
    visual.rightShoulder.rotation = _withDelta(
      visual.baseRotations['rightShoulder']!,
      x: mix(pose(.126, .365) + .018 * step * move, death('rightShoulder').x),
      y: mix(pose(-.284, .003), death('rightShoulder').y),
      z: mix(pose(.200, -.468) - .026 * step * move, death('rightShoulder').z),
    );
    visual.rightArm.rotation = _withDelta(
      visual.baseRotations['rightArm']!,
      x: mix(pose(-.651, -.868) + .030 * step * move, death('rightArm').x),
      y: mix(pose(-.688, -.644), death('rightArm').y),
      z: mix(pose(.366, .738) + .035 * step * move, death('rightArm').z),
    );
    visual.rightForeArm.rotation = _withDelta(
      visual.baseRotations['rightForeArm']!,
      x: mix(pose(-.051, .407) + .024 * step * move, death('rightForeArm').x),
      y: mix(pose(-.499, -.769), death('rightForeArm').y),
      z: mix(pose(-.105, -.776), death('rightForeArm').z),
    );

    visual.leftHand.rotation = _withDelta(
      visual.baseRotations['leftHand']!,
      x: mix(.012 * recoil, death('leftHand').x),
      y: mix(0, death('leftHand').y),
      z: mix(0, death('leftHand').z),
    );
    visual.rightHand.rotation = _withDelta(
      visual.baseRotations['rightHand']!,
      x: mix(0, death('rightHand').x),
      y: mix(0, death('rightHand').y),
      z: mix(0, death('rightHand').z),
    );

    visual.gunRoot.rotation = visual.gunBaseRotation *
        vm.Quaternion.axisAngle(
          vm.Vector3(1, 0, 0),
          recoil * .070,
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


    // Keep only the clean laser core; the old outer glow looked like a colored
    // border around the beam.
    if (visual.laser.visible != laserVisible) {
      visual.laser.visible = laserVisible;
    }
    if (laserVisible) {
      final visualLength = laserLength.clamp(.30, 8.2).toDouble();
      visual.laser.position = vm.Vector3(0, .012, visualLength / 2);
      visual.laser.scale = vm.Vector3(.78, .78, visualLength);
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

  void addBlood(double x, double y, {double shotAngle = 0, bool lethal = false}) {
    final world = worldPosition(x, y);

    // Strong red floor stain. Fatal hits leave a larger irregular pool.
    final stain = _meshNode(
      _geo.bloodDisc,
      _bloodMaterial,
      position: vm.Vector3(world.x, .018, world.z),
      scale: vm.Vector3(
        (lethal ? 1.35 : .86) + _random.nextDouble() * .55,
        1,
        (lethal ? 1.08 : .62) + _random.nextDouble() * .48,
      ),
      rotation: vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        _random.nextDouble() * math.pi,
      ),
    )..castsShadows = false;
    scene.add(stain);
    _bloodNodes.add(stain);

    final floorDrops = lethal ? 11 : 5;
    for (var i = 0; i < floorDrops; i++) {
      final drop = _meshNode(
        _geo.bloodDrop,
        _bloodMaterial,
        position: vm.Vector3(
          world.x + (_random.nextDouble() - .5) * (lethal ? .95 : .52),
          .019,
          world.z + (_random.nextDouble() - .5) * (lethal ? .95 : .52),
        ),
        scale: vm.Vector3.all(.22 + _random.nextDouble() * (lethal ? .48 : .32)),
      )..castsShadows = false;
      scene.add(drop);
      _bloodNodes.add(drop);
    }

    // Airborne spray comes from torso height and travels mainly away from the
    // incoming shot, with randomized vertical/side velocity. Fatal hits create
    // a much denser burst.
    final particleCount = lethal ? 38 : 16;
    final sprayForwardX = math.cos(shotAngle);
    final sprayForwardZ = math.sin(shotAngle);
    for (var i = 0; i < particleCount; i++) {
      final lateral = (_random.nextDouble() - .5) * (lethal ? 1.9 : 1.25);
      final forward = (lethal ? 1.15 : .72) + _random.nextDouble() * (lethal ? 1.65 : 1.00);
      final sideX = -sprayForwardZ;
      final sideZ = sprayForwardX;
      final velocity = vm.Vector3(
        sprayForwardX * forward + sideX * lateral,
        .72 + _random.nextDouble() * (lethal ? 1.90 : 1.25),
        sprayForwardZ * forward + sideZ * lateral,
      );
      final particle = _meshNode(
        _geo.bloodParticle,
        _bloodSprayMaterial,
        position: vm.Vector3(
          world.x + (_random.nextDouble() - .5) * .16,
          .92 + _random.nextDouble() * .42,
          world.z + (_random.nextDouble() - .5) * .16,
        ),
        scale: vm.Vector3.all((lethal ? .72 : .52) + _random.nextDouble() * .58),
      )..castsShadows = false;
      scene.add(particle);
      _bloodParticles.add(
        _BloodParticle(
          node: particle,
          velocity: velocity,
          life: .52 + _random.nextDouble() * (lethal ? .78 : .50),
        ),
      );
    }
  }

  void updateEffects(double dt) {
    for (var i = _bloodParticles.length - 1; i >= 0; i--) {
      final particle = _bloodParticles[i];
      particle.life -= dt;
      if (particle.life <= 0) {
        particle.node.detach();
        _bloodParticles.removeAt(i);
        continue;
      }

      particle.velocity.y -= 4.8 * dt;
      final current = particle.node.position;
      particle.node.position = vm.Vector3(
        current.x + particle.velocity.x * dt,
        current.y + particle.velocity.y * dt,
        current.z + particle.velocity.z * dt,
      );

      if (particle.node.position.y <= .025) {
        final impact = _meshNode(
          _geo.bloodDrop,
          _bloodMaterial,
          position: vm.Vector3(particle.node.position.x, .019, particle.node.position.z),
          scale: vm.Vector3.all(.18 + _random.nextDouble() * .24),
        )..castsShadows = false;
        scene.add(impact);
        _bloodNodes.add(impact);
        particle.node.detach();
        _bloodParticles.removeAt(i);
      }
    }
  }

  void clearBlood() {
    for (final node in _bloodNodes) {
      node.detach();
    }
    for (final particle in _bloodParticles) {
      particle.node.detach();
    }
    _bloodNodes.clear();
    _bloodParticles.clear();
  }

  vm.Vector3 worldPosition(double x, double y, {double height = 0}) {
    return vm.Vector3(
      (x - .5) * arenaWorldSize,
      height,
      (y - .5) * arenaWorldSize,
    );
  }

  vm.Vector3 _clampCameraInsideStage(vm.Vector3 position) {
    // Safe camera cylinder is intentionally smaller than the expanded outer
    // supports and roof. This guarantees that no legal pinch/orbit/death view
    // can reveal the model from the outside.
    const safeRadius = 10.15;
    const minHeight = .60;
    const maxHeight = 7.05;

    var x = position.x;
    var z = position.z;
    final radial = math.sqrt(x * x + z * z);
    if (radial > safeRadius && radial > .000001) {
      final scale = safeRadius / radial;
      x *= scale;
      z *= scale;
    }

    return vm.Vector3(
      x,
      position.y.clamp(minHeight, maxHeight).toDouble(),
      z,
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
    required double cameraDistance,
    required double cameraOffsetX,
    required double cameraOffsetY,
    required double cameraYawOffset,
    required double spectatorAmount,
    bool updateBackground = true,
  }) {
    if (updateBackground) {
      _updateBackground(seconds);
    }

    final player = worldPosition(playerX, playerY);
    final orbitHeading = playerAngle + cameraYawOffset + cameraOrbit;
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

    // Third-person camera is intentionally constrained to the *interior* of
    // the enlarged stage. Pinch can still zoom in/out naturally, but it can no
    // longer pull the camera through the roof/dome or behind the outside shell.
    final zoom = math.max(.28, cameraZoom);
    final thirdPersonHorizontalDistance =
        (cameraDistance / zoom).clamp(.18, 6.20).toDouble();
    const baseThirdPersonElevation = 0.30;
    final thirdPersonElevation =
        (baseThirdPersonElevation + cameraPitch).clamp(-.82, 1.02).toDouble();
    final thirdPersonTarget = vm.Vector3(
      player.x + playerForward.x * .68,
      (1.08 + cameraOffsetY * .18).clamp(.55, 2.35).toDouble(),
      player.z + playerForward.z * .68,
    );
    final rawThirdPersonPosition = vm.Vector3(
      player.x - cameraForward.x * thirdPersonHorizontalDistance + cameraRight.x * cameraOffsetX,
      thirdPersonTarget.y + math.tan(thirdPersonElevation) * thirdPersonHorizontalDistance + cameraOffsetY,
      player.z - cameraForward.z * thirdPersonHorizontalDistance + cameraRight.z * cameraOffsetX,
    );
    final thirdPersonPosition = _clampCameraInsideStage(rawThirdPersonPosition);

    // On death, transition to a composed arena-wide spectator shot rather than
    // flying the camera high above the model. The view still reacts to orbit,
    // pitch and pinch, but only inside a deliberately safe interior envelope.
    final spectatorHeading = (-math.pi / 4) + cameraOrbit;
    final spectatorZoomFactor = math.sqrt(.69 / zoom).clamp(.78, 1.22).toDouble();
    final spectatorHorizontalRadius =
        (6.65 * spectatorZoomFactor).clamp(5.25, 8.10).toDouble();
    final spectatorHeight =
        (5.05 + cameraPitch * 1.45).clamp(3.55, 6.65).toDouble();
    final rawSpectatorPosition = vm.Vector3(
      math.cos(spectatorHeading) * spectatorHorizontalRadius,
      spectatorHeight,
      math.sin(spectatorHeading) * spectatorHorizontalRadius,
    );
    final spectatorPosition = _clampCameraInsideStage(rawSpectatorPosition);
    final spectatorTarget = vm.Vector3(0, .48, 0);

    final t = spectatorAmount.clamp(0.0, 1.0).toDouble();
    vm.Vector3 blend(vm.Vector3 a, vm.Vector3 b) => vm.Vector3(
          a.x + (b.x - a.x) * t,
          a.y + (b.y - a.y) * t,
          a.z + (b.z - a.z) * t,
        );

    final position = _clampCameraInsideStage(
      blend(thirdPersonPosition, spectatorPosition),
    );
    final target = blend(thirdPersonTarget, spectatorTarget);
    final fovDegrees = 58.0 + (54.0 - 58.0) * t;

    return PerspectiveCamera(
      position: position,
      target: target,
      up: vm.Vector3(0, 1, 0),
      fovRadiansY: fovDegrees * math.pi / 180,
      fovNear: .08,
      fovFar: 1000,
    );
  }

  Offset? labelScreenPoint({
    PerspectiveCamera? camera,
    required double x,
    required double y,
    required double seconds,
    required double playerX,
    required double playerY,
    required double playerAngle,
    required double cameraOrbit,
    required double cameraPitch,
    required double cameraZoom,
    required double cameraDistance,
    required double cameraOffsetX,
    required double cameraOffsetY,
    required double cameraYawOffset,
    required double spectatorAmount,
    required Size viewSize,
  }) {
    final resolvedCamera = camera ?? cameraFor(
      seconds: seconds,
      playerX: playerX,
      playerY: playerY,
      playerAngle: playerAngle,
      cameraOrbit: cameraOrbit,
      cameraPitch: cameraPitch,
      cameraZoom: cameraZoom,
      cameraDistance: cameraDistance,
      cameraOffsetX: cameraOffsetX,
      cameraOffsetY: cameraOffsetY,
      cameraYawOffset: cameraYawOffset,
      spectatorAmount: spectatorAmount,
    );
    return resolvedCamera.worldToScreen(
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
    required this.gunBaseRotation,
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
  final vm.Quaternion gunBaseRotation;
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
        bloodDrop = DiscGeometry(radius: .10, segments: 14),
        bloodParticle = IcosphereGeometry(radius: .045, subdivisions: 1);

  final Geometry gunBody;
  final Geometry gunBarrel;
  final Geometry gunHandle;
  final Geometry muzzleAccent;
  final Geometry laser;
  final Geometry laserGlow;
  final Geometry muzzleFlash;
  final Geometry bloodDisc;
  final Geometry bloodDrop;
  final Geometry bloodParticle;
}

class _BloodParticle {
  _BloodParticle({
    required this.node,
    required this.velocity,
    required this.life,
  });

  final Node node;
  final vm.Vector3 velocity;
  double life;
}
