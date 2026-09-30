import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/killer_killed_avatar.dart';

enum KillerKilledPreviewFocus {
  full,
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

class KillerKilledAvatarPreview extends StatefulWidget {
  const KillerKilledAvatarPreview({
    super.key,
    required this.avatar,
    this.interactive = true,
    this.compact = false,
    this.fullBodyFraming = false,
    this.focus = KillerKilledPreviewFocus.full,
    this.itemOnly = false,
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
  final bool interactive;
  final bool compact;
  final bool fullBodyFraming;
  final KillerKilledPreviewFocus focus;
  final bool itemOnly;
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

  static Future<void>? _sceneResourcesFuture;
  static Future<Node>? _preloadedModelFuture;
  static Future<Node>? _preloadedGuessTimeModelFuture;
  static Future<Node>? _wardrobeItemTemplateFuture;

  static Future<void> prewarm() async {
    await (_sceneResourcesFuture ??= Scene.initializeStaticResources());
    _preloadedModelFuture ??= Node.fromGlbAsset(
      'assets/models/creative_character_free.glb',
    );
    await _preloadedModelFuture;
  }

  static Future<void> prewarmGuessTime() async {
    await (_sceneResourcesFuture ??= Scene.initializeStaticResources());
    _preloadedGuessTimeModelFuture ??= Node.fromGlbAsset(
      'assets/models/guess_time_character_light.glb',
    );
    await _preloadedGuessTimeModelFuture;
  }

  static Future<void> _ensureSceneResources() {
    return _sceneResourcesFuture ??= Scene.initializeStaticResources();
  }

  static Future<Node> _takePreparedModel({
    required bool guessTimeLightweight,
    required bool itemOnly,
  }) async {
    await _ensureSceneResources();

    // Wardrobe cards are static item previews. Loading/parsing the same full
    // GLB once per card was one of the largest lobby costs. Keep one template
    // and clone its node tree so geometry/GPU resources can be reused.
    if (itemOnly) {
      final template = await (_wardrobeItemTemplateFuture ??=
          Node.fromGlbAsset('assets/models/creative_character_free.glb'));
      return template.clone(recursive: true);
    }

    if (guessTimeLightweight) {
      final prepared = _preloadedGuessTimeModelFuture;
      if (prepared != null) {
        _preloadedGuessTimeModelFuture = null;
        return prepared;
      }
      return Node.fromGlbAsset('assets/models/guess_time_character_light.glb');
    }
    final prepared = _preloadedModelFuture;
    if (prepared != null) {
      _preloadedModelFuture = null;
      return prepared;
    }
    return Node.fromGlbAsset('assets/models/creative_character_free.glb');
  }

  @override
  State<KillerKilledAvatarPreview> createState() =>
      _KillerKilledAvatarPreviewState();
}

class _KillerKilledAvatarPreviewState extends State<KillerKilledAvatarPreview> {
  final Scene _scene = Scene();
  Node? _model;
  Object? _error;
  double _yaw = 0;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant KillerKilledAvatarPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatar != widget.avatar ||
        oldWidget.focus != widget.focus ||
        oldWidget.itemOnly != widget.itemOnly ||
        oldWidget.previewOffsetX != widget.previewOffsetX ||
        oldWidget.previewOffsetY != widget.previewOffsetY ||
        oldWidget.previewOffsetZ != widget.previewOffsetZ ||
        oldWidget.previewScale != widget.previewScale ||
        oldWidget.previewRotX != widget.previewRotX ||
        oldWidget.previewRotY != widget.previewRotY ||
        oldWidget.previewRotZ != widget.previewRotZ) {
      _applyAvatar();
      _applyPreviewTransform();
    }
  }

  Future<void> _initialize() async {
    try {
      await KillerKilledAvatarPreview._ensureSceneResources();
      _scene
        ..renderScale = widget.fullBodyFraming ? .44 : (widget.compact ? .64 : .74)
        ..exposure = 1.18
        ..directionalLight = DirectionalLight(
          direction: vm.Vector3(-.45, -1, -.55),
          color: widget.fullBodyFraming
              ? vm.Vector3(.78, .87, 1.0)
              : vm.Vector3(1, .97, .92),
          intensity: widget.fullBodyFraming ? 2.35 : 3.0,
          castsShadow: false,
        );

      final model = await KillerKilledAvatarPreview._takePreparedModel(
        guessTimeLightweight: widget.fullBodyFraming,
        itemOnly: widget.itemOnly,
      );
      model
        ..name = 'avatar_preview'
        ..scale = vm.Vector3.all(widget.compact ? .92 : 1.02)
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), 0);
      _yaw = 0;
      _model = model;
      _scene.add(model);
      _applyAvatar();
      _applyPreviewTransform();
      if (mounted) {
        setState(() => _visible = true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Set<String> _focusedVisibleNodes() {
    if (!widget.itemOnly) return widget.avatar.visibleNodeNames;
    final avatar = widget.avatar;
    final visible = <String>{};

    // Item cards show ONLY the selected item. Do not render the body or dress
    // a complete character inside every card.
    switch (widget.focus) {
      case KillerKilledPreviewFocus.full:
        return avatar.visibleNodeNames;
      case KillerKilledPreviewFocus.costume:
        if (avatar.costume != null) {
          visible.add(avatar.costume!);
        } else if (avatar.outerwear != null) {
          visible.add(avatar.outerwear!);
        } else if (avatar.shirt != null) {
          visible.add(avatar.shirt!);
        } else if (avatar.bottom != null) {
          visible.add(avatar.bottom!);
        }
        break;
      case KillerKilledPreviewFocus.expression:
        visible.add(avatar.face);
        break;
      case KillerKilledPreviewFocus.head:
        if (avatar.hair != null) visible.add(avatar.hair!);
        break;
      case KillerKilledPreviewFocus.faceAccessory:
        if (avatar.faceAccessory != null) {
          visible.add(avatar.faceAccessory!);
        } else if (avatar.glasses != null) {
          visible.add(avatar.glasses!);
        }
        break;
      case KillerKilledPreviewFocus.headwear:
        if (avatar.hat != null) visible.add(avatar.hat!);
        break;
      case KillerKilledPreviewFocus.shirt:
        if (avatar.outerwear != null) {
          visible.add(avatar.outerwear!);
        } else if (avatar.shirt != null) {
          visible.add(avatar.shirt!);
        }
        break;
      case KillerKilledPreviewFocus.gloves:
        if (avatar.gloves != null) visible.add(avatar.gloves!);
        break;
      case KillerKilledPreviewFocus.bottom:
        if (avatar.bottom != null) visible.add(avatar.bottom!);
        break;
      case KillerKilledPreviewFocus.shoes:
        if (avatar.shoes != null) {
          visible.add(avatar.shoes!);
        } else if (avatar.socks) {
          visible.add('Socks_008');
        }
        break;
    }
    return visible;
  }

  void _applyAvatar() {
    final model = _model;
    if (model == null) return;
    final visible = _focusedVisibleNodes();
    for (final name in KillerKilledAvatar.customizableNodeNames) {
      final node = model.getChildByName(name);
      if (node != null) node.visible = visible.contains(name);
    }
    final body = model.getChildByName('Body_010');
    if (body != null) body.visible = !widget.itemOnly;
  }

  void _applyPreviewTransform() {
    final model = _model;
    if (model == null) return;
    final scale = (widget.compact ? .92 : 1.02) *
        widget.previewScale.clamp(.05, 10.0);
    model
      ..position = vm.Vector3(
        widget.previewOffsetX,
        widget.previewOffsetY,
        widget.previewOffsetZ,
      )
      ..scale = vm.Vector3.all(scale)
      ..rotation = vm.Quaternion.euler(
        widget.previewRotX * 3.141592653589793 / 180,
        widget.previewRotY * 3.141592653589793 / 180,
        widget.previewRotZ * 3.141592653589793 / 180,
      );
    _yaw = widget.previewRotY * 3.141592653589793 / 180;
  }

  void _rotate(double delta) {
    final model = _model;
    if (model == null) return;
    _yaw += delta;
    model.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), _yaw);
    setState(() {});
  }

  ({vm.Vector3 position, vm.Vector3 target, double fov}) _cameraSetup() {
    if (widget.previewCameraX != null &&
        widget.previewCameraY != null &&
        widget.previewCameraZ != null &&
        widget.previewTargetX != null &&
        widget.previewTargetY != null &&
        widget.previewTargetZ != null &&
        widget.previewFov != null) {
      return (
        position: vm.Vector3(
          widget.previewCameraX!,
          widget.previewCameraY!,
          widget.previewCameraZ!,
        ),
        target: vm.Vector3(
          widget.previewTargetX!,
          widget.previewTargetY!,
          widget.previewTargetZ!,
        ),
        fov: widget.previewFov!,
      );
    }
    if (widget.fullBodyFraming) {
      return (
        position: vm.Vector3(0, 1.04, 3.35),
        target: vm.Vector3(0, 1.08, 0),
        fov: 50.0,
      );
    }

    if (widget.itemOnly) {
      switch (widget.focus) {
        case KillerKilledPreviewFocus.expression:
        case KillerKilledPreviewFocus.head:
        case KillerKilledPreviewFocus.faceAccessory:
        case KillerKilledPreviewFocus.headwear:
          return (
            position: vm.Vector3(0, 1.36, 1.55),
            target: vm.Vector3(0, 1.24, 0),
            fov: 24.0,
          );
        case KillerKilledPreviewFocus.shirt:
        case KillerKilledPreviewFocus.gloves:
          return (
            position: vm.Vector3(0, .98, 1.88),
            target: vm.Vector3(0, .96, 0),
            fov: 28.0,
          );
        case KillerKilledPreviewFocus.bottom:
          return (
            position: vm.Vector3(0, .58, 1.90),
            target: vm.Vector3(0, .56, 0),
            fov: 27.0,
          );
        case KillerKilledPreviewFocus.shoes:
          return (
            position: vm.Vector3(0, .14, 1.36),
            target: vm.Vector3(0, .11, 0),
            fov: 22.0,
          );
        case KillerKilledPreviewFocus.costume:
          return (
            position: vm.Vector3(0, .88, 2.16),
            target: vm.Vector3(0, .86, 0),
            fov: 30.0,
          );
        case KillerKilledPreviewFocus.full:
          break;
      }
    }

    return (
      position: vm.Vector3(
        0,
        widget.compact ? 1.08 : 1.04,
        widget.compact ? 3.15 : 2.75,
      ),
      target: vm.Vector3(0, widget.compact ? .94 : .96, 0),
      fov: widget.compact ? 42.0 : 45.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const Center(
        child: Icon(Icons.person_rounded, color: Colors.white30, size: 70),
      );
    }
    if (_model == null) {
      return const Center(
        child: Icon(
          Icons.person_rounded,
          color: Color(0x24FFFFFF),
          size: 118,
        ),
      );
    }

    final setup = _cameraSetup();
    final view = SceneView(
      _scene,
      // Static/non-interactive wardrobe cards render on demand only. Running
      // a 60fps ticker for every visible card was a major source of heat.
      autoTick: widget.interactive && !widget.fullBodyFraming && !widget.itemOnly,
      camera: PerspectiveCamera(
        position: setup.position,
        target: setup.target,
        up: vm.Vector3(0, 1, 0),
        fovRadiansY: setup.fov * 3.141592653589793 / 180,
        fovNear: .05,
        fovFar: 50,
      ),
      warmUp: !widget.itemOnly,
    );

    final revealedView = AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: view,
    );

    if (!widget.interactive) return IgnorePointer(child: revealedView);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => _rotate(details.delta.dx * .012),
      child: revealedView,
    );
  }
}
