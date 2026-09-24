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
  });

  final KillerKilledAvatar avatar;
  final bool interactive;
  final bool compact;

  @override
  State<KillerKilledAvatarPreview> createState() =>
      _KillerKilledAvatarPreviewState();
}

class _KillerKilledAvatarPreviewState extends State<KillerKilledAvatarPreview> {
  final Scene _scene = Scene();
  Node? _model;
  Object? _error;
  double _yaw = 0;

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
      await Scene.initializeStaticResources();
      _scene
        ..renderScale = widget.compact ? .72 : .90
        ..exposure = 1.18
        ..directionalLight = DirectionalLight(
          direction: vm.Vector3(-.45, -1, -.55),
          color: vm.Vector3(1, .97, .92),
          intensity: 3.0,
          castsShadow: false,
        );

      final model = await Node.fromGlbAsset(
        'assets/models/creative_character_free.glb',
      );
      model
        ..name = 'avatar_preview'
        ..scale = vm.Vector3.all(widget.compact ? .92 : 1.02);
      _model = model;
      _scene.add(model);
      _applyAvatar();
      if (mounted) setState(() {});
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
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF5ED9C7),
          ),
        ),
      );
    }

    final view = SceneView(
      _scene,
      cameraBuilder: (_) => PerspectiveCamera(
        position: vm.Vector3(0, widget.compact ? 1.08 : 1.04, widget.compact ? 3.15 : 2.75),
        target: vm.Vector3(0, widget.compact ? .94 : .96, 0),
        up: vm.Vector3(0, 1, 0),
        fovRadiansY: (widget.compact ? 42 : 45) * 3.141592653589793 / 180,
        fovNear: .05,
        fovFar: 50,
      ),
      warmUp: true,
    );

    if (!widget.interactive) return IgnorePointer(child: view);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => _rotate(details.delta.dx * .012),
      child: view,
    );
  }
}
