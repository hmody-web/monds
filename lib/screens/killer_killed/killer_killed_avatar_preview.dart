import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/killer_killed_avatar.dart';

class KillerKilledAvatarPreview extends StatefulWidget {
  const KillerKilledAvatarPreview({
    super.key,
    required this.avatar,
    this.interactive = true,
    this.compact = false,
    this.fullBodyFraming = false,
  });

  final KillerKilledAvatar avatar;
  final bool interactive;
  final bool compact;
  final bool fullBodyFraming;

  static Future<void>? _sceneResourcesFuture;
  static Future<Node>? _preloadedModelFuture;
  static Future<Node>? _preloadedGuessTimeModelFuture;

  /// Starts preparing the 3D engine and the character model before the preview
  /// is actually opened. The app home screen calls this in advance so entering
  /// Guess Time can show the avatar almost immediately on slower phones.
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

  static Future<Node> _takePreparedModel({required bool guessTimeLightweight}) async {
    await _ensureSceneResources();
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
    if (oldWidget.avatar != widget.avatar) {
      _applyAvatar();
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
      );
      model
        ..name = 'avatar_preview'
        ..scale = vm.Vector3.all(widget.compact ? .92 : 1.02)
        // The GLB root carries an initial transform. The first drag used to
        // overwrite it, which is why the avatar suddenly faced forward only
        // after touching it. Normalize it immediately instead.
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), 0);
      _yaw = 0;
      _model = model;
      _scene.add(model);
      _applyAvatar();
      if (mounted) {
        setState(() => _visible = true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  void _applyAvatar() {
    final model = _model;
    if (model == null) return;
    final visible = widget.avatar.visibleNodeNames;
    for (final name in KillerKilledAvatar.customizableNodeNames) {
      final node = model.getChildByName(name);
      if (node != null) node.visible = visible.contains(name);
    }
    final body = model.getChildByName('Body_010');
    if (body != null) body.visible = true;
  }

  void _rotate(double delta) {
    final model = _model;
    if (model == null) return;
    _yaw += delta;
    model.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), _yaw);
    setState(() {});
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

    final fullBody = widget.fullBodyFraming;
    final cameraPosition = fullBody
        ? vm.Vector3(0, 1.04, 3.35)
        : vm.Vector3(
            0,
            widget.compact ? 1.08 : 1.04,
            widget.compact ? 3.15 : 2.75,
          );
    // Full-body mode keeps the wider framing that prevents head clipping,
    // while aiming higher so the character sits lower in the frame and its
    // feet visually meet the pedestal instead of floating above it.
    final cameraTarget = fullBody
        ? vm.Vector3(0, 1.08, 0)
        : vm.Vector3(0, widget.compact ? .94 : .96, 0);
    final cameraFov = fullBody ? 50.0 : (widget.compact ? 42.0 : 45.0);

    final view = SceneView(
      _scene,
      // Full-body Guess Time lobby previews are static unless the user drags.
      // Do not keep a 60fps renderer running just to show a standing model.
      autoTick: !widget.fullBodyFraming,
      cameraBuilder: (_) => PerspectiveCamera(
        position: cameraPosition,
        target: cameraTarget,
        up: vm.Vector3(0, 1, 0),
        fovRadiansY: cameraFov * 3.141592653589793 / 180,
        fovNear: .05,
        fovFar: 50,
      ),
      warmUp: true,
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
