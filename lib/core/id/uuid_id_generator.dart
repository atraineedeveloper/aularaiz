import 'package:aularaiz/core/id/id_generator.dart';
import 'package:uuid/uuid.dart';

final class UuidIdGenerator implements IdGenerator {
  UuidIdGenerator({Uuid? uuid}) : _uuid = uuid ?? Uuid();

  final Uuid _uuid;

  @override
  String newId() => _uuid.v4();
}
