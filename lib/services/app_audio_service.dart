import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class AppAudioService {
  AppAudioService._();

  static const String _shotAsset = 'audio/mrfriends-pistol-shot-233473.mp3';
  static const String _walkAsset = 'audio/freeeverythingxx-walking-up-the-stairs-268464.mp3';
  static const String _clickAsset = 'audio/u_u4pf5h7zip-click-345983.mp3';
  static const String _musicAsset = 'audio/ncprime-noncopyright-music-pianos-295174.mp3';
  static const String _deathAsset = 'audio/410184-Monster_Within_-Hunter_-Hit-Accu-Damage02.mp3';
  static const String _damageAsset = 'audio/403621-HARD_FLESH_IMPACT_-Sharp_Metal_Object_Body_Hit_-Juicy_Gore_Blood_Spill_-04_004004_.mp3';

  static final AudioPlayer _clickPlayer = AudioPlayer();
  static final AudioPlayer _shotPlayer = AudioPlayer();
  static final AudioPlayer _walkPlayer = AudioPlayer();
  static final AudioPlayer _musicPlayer = AudioPlayer();
  static final AudioPlayer _deathPlayer = AudioPlayer();
  static final AudioPlayer _damagePlayer = AudioPlayer();

  static bool _globalPrepared = false;
  static bool _arenaPrepared = false;
  static bool _walking = false;
  static bool _musicPlaying = false;

  /// Arena input occupies large touch areas, so the app-wide tap layer is
  /// suppressed while the arena is open. Arena buttons trigger click sounds
  /// explicitly instead.
  static bool suppressGlobalClick = false;

  static Future<void> prepareGlobalClick() async {
    if (_globalPrepared) return;
    try {
      await _clickPlayer.setReleaseMode(ReleaseMode.stop);
      await _clickPlayer.setSource(AssetSource(_clickAsset));
      await _clickPlayer.setVolume(.82);
      _globalPrepared = true;
    } catch (_) {
      // Audio must never prevent the app from opening.
    }
  }

  static Future<void> preloadArenaAudio() async {
    if (_arenaPrepared) return;
    await prepareGlobalClick();
    try {
      await Future.wait([
        _shotPlayer.setReleaseMode(ReleaseMode.stop),
        _walkPlayer.setReleaseMode(ReleaseMode.loop),
        _musicPlayer.setReleaseMode(ReleaseMode.loop),
        _deathPlayer.setReleaseMode(ReleaseMode.stop),
        _damagePlayer.setReleaseMode(ReleaseMode.stop),
      ]);
      await Future.wait([
        _shotPlayer.setSource(AssetSource(_shotAsset)),
        _walkPlayer.setSource(AssetSource(_walkAsset)),
        _musicPlayer.setSource(AssetSource(_musicAsset)),
        _deathPlayer.setSource(AssetSource(_deathAsset)),
        _damagePlayer.setSource(AssetSource(_damageAsset)),
      ]);
      await Future.wait([
        _shotPlayer.setVolume(.86),
        _walkPlayer.setVolume(1.0),
        _musicPlayer.setVolume(.15),
        _deathPlayer.setVolume(.92),
        _damagePlayer.setVolume(.90),
      ]);
      _arenaPrepared = true;
    } catch (_) {
      // The game remains playable even if a platform audio backend fails.
    }
  }

  static Future<void> playClick() async {
    try {
      if (!_globalPrepared) await prepareGlobalClick();
      await _clickPlayer.stop();
      await _clickPlayer.resume();
    } catch (_) {}
  }

  static Future<void> playPistolShot() async {
    try {
      if (!_arenaPrepared) await preloadArenaAudio();
      await _shotPlayer.stop();
      await _shotPlayer.resume();
    } catch (_) {}
  }

  static Future<void> playDamageHit() async {
    try {
      if (!_arenaPrepared) await preloadArenaAudio();
      await _damagePlayer.stop();
      await _damagePlayer.resume();
    } catch (_) {}
  }

  static Future<void> playDeath() async {
    try {
      if (!_arenaPrepared) await preloadArenaAudio();
      await _deathPlayer.stop();
      await _deathPlayer.resume();
    } catch (_) {}
  }

  static Future<void> startWalking() async {
    if (_walking) return;
    _walking = true;
    try {
      if (!_arenaPrepared) await preloadArenaAudio();
      await _walkPlayer.resume();
    } catch (_) {
      _walking = false;
    }
  }

  static Future<void> stopWalking() async {
    if (!_walking) return;
    _walking = false;
    try {
      await _walkPlayer.stop();
    } catch (_) {}
  }

  static Future<void> startKillerKilledMusic() async {
    if (_musicPlaying) return;
    _musicPlaying = true;
    try {
      if (!_arenaPrepared) await preloadArenaAudio();
      await _musicPlayer.setVolume(.15);
      await _musicPlayer.resume();
    } catch (_) {
      _musicPlaying = false;
    }
  }

  static Future<void> stopKillerKilledMusic() async {
    if (!_musicPlaying) return;
    _musicPlaying = false;
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }

  static Future<void> stopArenaAudio() async {
    await Future.wait([
      stopWalking(),
      stopKillerKilledMusic(),
      _shotPlayer.stop(),
      _damagePlayer.stop(),
      _deathPlayer.stop(),
    ]);
  }
}
