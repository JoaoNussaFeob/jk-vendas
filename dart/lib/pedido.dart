import 'item_pedido.dart';
import 'serializavel.dart';

// O pedido junta os itens vendidos, o local e a forma de pagamento.
class Pedido with ConverteJson {
  // Os mesmos valores aceitos pelo banco (colunas ENUM).
  // "static" quer dizer que a lista é da classe, igual para todos os pedidos.
  static const locais = ['Balcão', 'Viagem', 'Delivery'];
  static const formasDePagamento = ['Dinheiro', 'Pix', 'Cartão', 'Fiado'];

  final String _local;
  String? _formaPagamento; // escolhida só no fim do pedido
  final List<ItemPedido> _itens = [];

  Pedido(this._local) {
    if (!locais.contains(_local)) {
      throw ArgumentError('Local inválido: $_local');
    }
  }

  String get local => _local;
  String? get formaPagamento => _formaPagamento;

  /// Devolve uma cópia que não pode ser alterada: ninguém de fora mexe na
  /// lista direto. Para incluir um item, só pelo método adicionarItem.
  List<ItemPedido> get itens => List.unmodifiable(_itens);

  void adicionarItem(ItemPedido item) {
    _itens.add(item);
  }

  void definirPagamento(String forma) {
    if (!formasDePagamento.contains(forma)) {
      throw ArgumentError('Forma de pagamento inválida: $forma');
    }
    _formaPagamento = forma;
  }

  /// Soma de todas as linhas, em centavos.
  int get totalCentavos {
    var total = 0;
    for (final item in _itens) {
      total += item.totalCentavos;
    }
    return total;
  }

  /// Confere se o pedido pode ser gravado. Gravar um pedido incompleto é um
  /// erro de estado (StateError): o problema não é um valor, é o momento.
  void validarParaGravar() {
    if (_itens.isEmpty) {
      throw StateError('O pedido precisa ter pelo menos um item.');
    }
    if (_formaPagamento == null) {
      throw StateError('Escolha a forma de pagamento antes de gravar.');
    }
  }

  /// A lista de itens vira uma lista de Maps (coleção de objetos -> JSON).
  @override
  Map<String, dynamic> toMap() => {
        'local': _local,
        'formaPagamento': _formaPagamento,
        'itens': listaParaMaps(_itens),
        'totalCentavos': totalCentavos,
      };
}
