import 'package:flutter/material.dart';

String friendlyErrorMessage(
  BuildContext context,
  Object? error, {
  required String fallback,
}) {
  final english = Localizations.localeOf(context).languageCode == 'en';
  final detail = error.toString().toLowerCase();
  if (detail.contains('unique') || detail.contains('constraint failed')) {
    return english
        ? 'That value is already being used. Review the information and try again.'
        : 'Ese dato ya está en uso. Revisa la información e inténtalo de nuevo.';
  }
  if (detail.contains('locked') || detail.contains('busy')) {
    return english
        ? 'The local database is busy. Close other AulaRaíz windows and try again.'
        : 'La base local está ocupada. Cierra otras ventanas de AulaRaíz e inténtalo de nuevo.';
  }
  if (detail.contains('readonly') || detail.contains('permission')) {
    return english
        ? 'AulaRaíz cannot write to its data folder. Check Windows permissions.'
        : 'AulaRaíz no puede escribir en su carpeta de datos. Revisa los permisos de Windows.';
  }
  if (detail.contains('disk') && detail.contains('full')) {
    return english
        ? 'There is not enough disk space to save the change.'
        : 'No hay suficiente espacio en disco para guardar el cambio.';
  }
  return fallback;
}
