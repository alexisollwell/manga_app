/// Form field validators used across the app.
library;

class Validators {
  Validators._();

  /// Validate manga title
  static String? titulo(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El título es obligatorio';
    }
    if (value.trim().length > 255) {
      return 'El título no puede exceder 255 caracteres';
    }
    return null;
  }

  /// Validate total volume count
  static String? cantidadTomos(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La cantidad de tomos es obligatoria';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Ingresa un número válido';
    }
    if (parsed < 1) {
      return 'La cantidad debe ser al menos 1';
    }
    if (parsed > 9999) {
      return 'La cantidad no puede exceder 9999';
    }
    return null;
  }

  /// Validate user alias
  static String? alias(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre es obligatorio';
    }
    if (value.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    if (value.trim().length > 30) {
      return 'El nombre no puede exceder 30 caracteres';
    }
    return null;
  }
}
