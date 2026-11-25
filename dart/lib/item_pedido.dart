import 'item_vendavel.dart';
import 'serializavel.dart';
import 'tamanho_marmita.dart';

// Uma linha do pedido: qual item, em que tamanho (se for marmita) e quantos.
class ItemPedido with ConverteJson {
  final ItemVendavel _item;
  final TamanhoMarmita?
      _tamanho; // o "?" diz que pode ficar vazio (bebida não tem tamanho)
  final int _quantidade;
  int _precoUnitarioCentavos = 0;

  ItemPedido(this._item, this._tamanho, this._quantidade) {
    // Valor recebido errado: ArgumentError.
    if (_quantidade <= 0) {
      throw ArgumentError('A quantidade deve ser maior que zero.');
    }
    // O preço é calculado agora e fica guardado: é o preço da hora da venda.
    // Cada tipo de item calcula do seu jeito (polimorfismo).
    _precoUnitarioCentavos = _item.calcularPreco(_tamanho);
  }

  ItemVendavel get item => _item;
  TamanhoMarmita? get tamanho => _tamanho;
  int get quantidade => _quantidade;
  int get precoUnitarioCentavos => _precoUnitarioCentavos;
  int get totalCentavos => _quantidade * _precoUnitarioCentavos;

  /// Sigla da coluna tamanho no banco: P/M/G na marmita; PFE, PFF ou B nos
  /// itens de preço fixo (cada filha de ItemPrecoFixo diz a sua).
  String get sigla {
    final tamanho = _tamanho;
    if (tamanho != null) {
      return tamanho.sigla;
    }
    return (_item as ItemPrecoFixo).siglaTamanho;
  }

  /// Texto da linha, por exemplo: "2x Feijoada completa (G)".
  String get descricao {
    final tamanho = _tamanho;
    final complemento = tamanho == null ? '' : ' (${tamanho.sigla})';
    return '${_quantidade}x ${_item.descricao}$complemento';
  }

  /// O item vai como um Map dentro do Map (objeto dentro de objeto).
  @override
  Map<String, dynamic> toMap() => {
        'item': _item.toMap(),
        'tamanho': sigla,
        'quantidade': _quantidade,
        'precoUnitarioCentavos': _precoUnitarioCentavos,
        'totalCentavos': totalCentavos,
      };
}
