import 'serializavel.dart';

// Uma porção que a cozinha prepara por dia, medida em quilos: arroz, feijão,
// um acompanhamento (batata frita, farofa...) ou a mistura de um prato do dia.
class Porcao with ConverteJson {
  /// Prazo máximo para usar a sobra guardada na geladeira a 4 °C ou menos
  /// (ANVISA, RDC 216/2004, item 4.8.17).
  static const validadeMaximaDias = 5;

  // Os mesmos valores da coluna ENUM do banco.
  static const tipos = ['BASE', 'ACOMPANHAMENTO', 'MISTURA'];

  final int _id;
  final String _nome;
  final String _tipo;
  final bool _reaproveitavel;
  final int _validadeDias;

  Porcao(this._id, this._nome, this._tipo, this._reaproveitavel,
      this._validadeDias) {
    if (_nome.trim().isEmpty) {
      throw ArgumentError('A porção precisa ter um nome.');
    }
    if (!tipos.contains(_tipo)) {
      throw ArgumentError('Tipo de porção inválido: $_tipo');
    }
    // Carne e mistura não se reaproveitam.
    if (_tipo == 'MISTURA' && _reaproveitavel) {
      throw ArgumentError('Mistura não pode ser reaproveitada.');
    }
    if (_reaproveitavel &&
        (_validadeDias < 1 || _validadeDias > validadeMaximaDias)) {
      throw ArgumentError(
          'A validade da sobra deve ficar entre 1 e $validadeMaximaDias dias.');
    }
    if (!_reaproveitavel && _validadeDias != 0) {
      throw ArgumentError(
          'Porção que não se reaproveita não tem validade de sobra.');
    }
  }

  int get id => _id;
  String get nome => _nome;
  String get tipo => _tipo;
  bool get reaproveitavel => _reaproveitavel;
  int get validadeDias => _validadeDias;

  /// O tipo do jeito que aparece na tela.
  String get tipoTexto {
    if (_tipo == 'BASE') {
      return 'Base';
    } else if (_tipo == 'ACOMPANHAMENTO') {
      return 'Acompanhamento';
    } else {
      return 'Mistura';
    }
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': _id,
        'nome': _nome,
        'tipo': _tipo,
        'reaproveitavel': _reaproveitavel,
        'validadeDias': _validadeDias,
      };
}
