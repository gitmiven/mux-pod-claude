import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/providers/connection_provider.dart';

void main() {
  Connection base() => Connection(
        id: 'c1',
        name: 'demo',
        host: 'example.com',
        username: 'user',
        createdAt: DateTime.utc(2026, 1, 1),
      );

  group('Connection.tmuxSocket', () {
    test('defaults to null', () {
      expect(base().tmuxSocket, isNull);
    });

    test('round-trips through toJson/fromJson when set', () {
      final c = base().copyWith(tmuxSocket: 'fleet');
      final restored = Connection.fromJson(c.toJson());
      expect(restored.tmuxSocket, 'fleet');
    });

    test('a socket path round-trips too', () {
      final c = base().copyWith(tmuxSocket: '/tmp/tmux-1000/fleet');
      final restored = Connection.fromJson(c.toJson());
      expect(restored.tmuxSocket, '/tmp/tmux-1000/fleet');
    });

    test('absent JSON key loads as null (backward compatible)', () {
      final legacy = base().toJson()..remove('tmuxSocket');
      final restored = Connection.fromJson(legacy);
      expect(restored.tmuxSocket, isNull);
    });

    test('copyWith carries the existing value when not overridden', () {
      final c = base().copyWith(tmuxSocket: 'fleet');
      final renamed = c.copyWith(name: 'renamed');
      expect(renamed.tmuxSocket, 'fleet');
    });
  });
}
