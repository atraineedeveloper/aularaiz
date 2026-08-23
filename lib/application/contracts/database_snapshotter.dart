import 'dart:typed_data';

abstract interface class DatabaseSnapshotter {
  Future<Uint8List> createSnapshot();
}
