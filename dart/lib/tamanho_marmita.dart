import 'serializavel.dart';

// Um tamanho de marmita do Cardápio do Dia (P, M ou G) e o preço dele.
class TamanhoMarmita with ConverteJson {
  // Atributos privados (o "_" na frente): ninguém de fora da classe muda os valores.
  // Isso é o ENCAPSULAMENTO. Para ler, existem os getters lá embaixo.
  final String _sigla;
  final String _nome;
  final int _precoCentavos;

  // Construtor: recusa um tamanho que não existe ou um preço sem sentido.
  TamanhoMarmita(this._sigla, this._nome, this._precoCentavos) {
    if (!['P', 'M', 'G'].contains(_sigla)) {
      throw ArgumentError('Tamanho de marmita inválido: $_sigla');
    }
    if (_precoCentavos <= 0) {
      throw ArgumentError('O preço da marmita deve ser maior que zero.');
    }
  }

  String get sigla => _sigla;
  String get nome => _nome;
  int get precoCentavos => _precoCentavos;

  /// Cria o tamanho a partir de um Map (o caminho de volta do toMap).
  TamanhoMarmita.fromMap(Map<String, dynamic> map)
      : this(map['sigla'] as String, map['nome'] as String,
            map['precoCentavos'] as int);

  @override
  Map<String, dynamic> toMap() =>
      {'sigla': _sigla, 'nome': _nome, 'precoCentavos': _precoCentavos};
}
