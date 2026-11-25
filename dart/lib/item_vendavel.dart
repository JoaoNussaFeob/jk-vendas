import 'serializavel.dart';
import 'tamanho_marmita.dart';

// =============================================================================
// ItemVendavel é a classe MÃE de tudo o que o restaurante vende.
//
// Ela é ABSTRATA: não existe um "item" genérico, só pratos e bebidas. Por isso
// não dá para fazer ItemVendavel(...); só as classes filhas viram objetos.
//
// Cada filha diz o seu tipo e calcula o preço do seu jeito. Quando o programa
// chama item.calcularPreco(...), o Dart roda a versão da filha certa: isso é o
// POLIMORFISMO.
//
// Ela também usa o mixin ConverteJson (que implementa a interface
// Serializavel): todas as filhas HERDAM o toMap e o toJson daqui e só
// acrescentam os campos que são delas.
//
//   ItemVendavel (abstrata)
//   ├── PratoDia ............ preço vem do tamanho da marmita
//   └── ItemPrecoFixo (abstrata) ... preço próprio
//       ├── PratoFitness ...... tamanho PFF (prato feito fitness)
//       ├── PratoExecutivo .... tamanho PFE (prato feito executivo)
//       └── Bebida ............ tamanho B
// =============================================================================
abstract class ItemVendavel with ConverteJson {
  // As categorias aceitas pelo banco (coluna ENUM da tabela item).
  static const categoriasDePrato = [
    'Carne bovina',
    'Carne suína',
    'Frango',
    'Peixe',
    'Ovos',
    'Massa'
  ];
  static const categoriasDeBebida = ['Refrigerante', 'Cerveja', 'Água', 'Suco'];

  final int _id;
  final String _nome;
  final String _categoria;

  ItemVendavel(this._id, this._nome, this._categoria) {
    if (_nome.trim().isEmpty) {
      throw ArgumentError('O item precisa ter um nome.');
    }
  }

  /// O caminho de volta do toMap: recebe um Map e cria a classe CERTA,
  /// olhando o campo "tipo". É um construtor "factory": ele escolhe qual
  /// objeto devolver. O banco também usa este construtor (sem repetir código).
  factory ItemVendavel.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as int;
    final nome = map['nome'] as String;
    final categoria = map['categoria'] as String;
    final preco = (map['precoCentavos'] ?? 0) as int;
    final aConfirmar = (map['precoAConfirmar'] ?? false) as bool;

    switch (map['tipo']) {
      case 'PRATO_DIA':
        return PratoDia(id, nome, categoria);
      case 'FITNESS':
        return PratoFitness(id, nome, categoria, preco, aConfirmar);
      case 'EXECUTIVO':
        return PratoExecutivo(id, nome, categoria, preco, aConfirmar);
      case 'BEBIDA':
        return Bebida(id, nome, categoria, preco, aConfirmar);
      default:
        throw ArgumentError('Tipo de item desconhecido: ${map['tipo']}');
    }
  }

  int get id => _id;
  String get nome => _nome;
  String get categoria => _categoria;

  /// O tipo gravado no banco: PRATO_DIA, FITNESS, EXECUTIVO ou BEBIDA.
  /// Não tem corpo aqui: cada filha é obrigada a responder (método abstrato).
  String get tipo;

  /// Só a marmita do prato do dia é vendida com tamanho.
  bool get precisaDeTamanho => false;

  /// Nome mostrado no menu.
  String get descricao => nome;

  /// Preço de UMA unidade, em centavos. Também é abstrato.
  int calcularPreco(TamanhoMarmita? tamanho);

  /// Os campos que TODO item tem. As filhas chamam super.toMap() e
  /// acrescentam os delas (reaproveitamento por herança).
  @override
  Map<String, dynamic> toMap() => {
        'id': _id,
        'nome': _nome,
        'categoria': _categoria,
        'tipo': tipo,
      };
}

// -----------------------------------------------------------------------------
// Prato do dia: não tem preço próprio. O preço é o do tamanho da marmita.
// -----------------------------------------------------------------------------
class PratoDia extends ItemVendavel {
  // "super." manda o valor direto para o construtor da classe mãe.
  PratoDia(super.id, super.nome, super.categoria);

  @override
  String get tipo => 'PRATO_DIA';

  @override
  bool get precisaDeTamanho => true;

  @override
  int calcularPreco(TamanhoMarmita? tamanho) {
    // Sem tamanho não existe preço: é um erro de estado (StateError).
    if (tamanho == null) {
      throw StateError(
          'A marmita do prato do dia precisa de tamanho (P, M ou G).');
    }
    return tamanho.precoCentavos;
  }

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(), // id, nome, categoria e tipo vêm da classe mãe
        'regraDePreco': 'tamanho da marmita (P, M ou G)',
      };
}

// -----------------------------------------------------------------------------
// Itens com preço próprio. Também é abstrata: só junta o que fitness,
// executivo e bebida têm em comum, para não repetir o mesmo código três vezes.
// -----------------------------------------------------------------------------
abstract class ItemPrecoFixo extends ItemVendavel {
  final int _precoCentavos;
  final bool _precoAConfirmar;

  ItemPrecoFixo(super.id, super.nome, super.categoria, this._precoCentavos,
      this._precoAConfirmar) {
    if (_precoCentavos <= 0) {
      throw ArgumentError('O preço de $nome deve ser maior que zero.');
    }
  }

  int get precoCentavos => _precoCentavos;

  /// true quando o preço ainda é de teste e precisa ser confirmado com o restaurante.
  bool get precoAConfirmar => _precoAConfirmar;

  @override
  int calcularPreco(TamanhoMarmita? tamanho) {
    if (tamanho != null) {
      throw ArgumentError('Só a marmita do prato do dia tem tamanho.');
    }
    return _precoCentavos;
  }

  /// Sigla gravada na coluna tamanho do pedido. Abstrata: cada filha diz a sua.
  String get siglaTamanho;

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'precoCentavos': _precoCentavos,
        'precoAConfirmar': _precoAConfirmar,
        'siglaTamanho': siglaTamanho,
      };
}

// As três filhas ficaram pequenas: o construtor só repassa os dados (super.)
// e cada uma diz o seu tipo e a sua sigla. O toMap e o toJson são herdados.
class PratoFitness extends ItemPrecoFixo {
  PratoFitness(super.id, super.nome, super.categoria, super.precoCentavos,
      super.precoAConfirmar);

  @override
  String get tipo => 'FITNESS';

  @override
  String get siglaTamanho => 'PFF';
}

class PratoExecutivo extends ItemPrecoFixo {
  PratoExecutivo(super.id, super.nome, super.categoria, super.precoCentavos,
      super.precoAConfirmar);

  @override
  String get tipo => 'EXECUTIVO';

  @override
  String get siglaTamanho => 'PFE';
}

class Bebida extends ItemPrecoFixo {
  Bebida(super.id, super.nome, super.categoria, super.precoCentavos,
      super.precoAConfirmar);

  @override
  String get tipo => 'BEBIDA';

  @override
  String get siglaTamanho => 'B';
}
