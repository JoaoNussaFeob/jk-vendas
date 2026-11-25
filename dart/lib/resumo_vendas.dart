import 'serializavel.dart';

// Uma linha vendida, do jeito que vem do banco. Os campos são "final":
// depois de criada, a venda não muda (igual no banco, onde a venda é imutável).
class VendaRegistrada with ConverteJson {
  final int idPedido;
  final String formaPagamento;
  final String local;
  final String item;
  final String? tamanho;
  final int quantidade;
  final int precoUnitarioCentavos;

  VendaRegistrada(this.idPedido, this.formaPagamento, this.local, this.item,
      this.tamanho, this.quantidade, this.precoUnitarioCentavos);

  int get totalCentavos => quantidade * precoUnitarioCentavos;

  @override
  Map<String, dynamic> toMap() => {
        'idPedido': idPedido,
        'formaPagamento': formaPagamento,
        'local': local,
        'item': item,
        'tamanho': tamanho,
        'quantidade': quantidade,
        'precoUnitarioCentavos': precoUnitarioCentavos,
        'totalCentavos': totalCentavos,
      };
}

// Faz as contas das vendas de um dia usando listas, conjuntos, mapas e repetição.
class ResumoVendas {
  final List<VendaRegistrada> _vendas;

  ResumoVendas(this._vendas);

  bool get vazio => _vendas.isEmpty;

  /// Quantos pedidos diferentes. Um pedido com 3 itens aparece em 3 linhas,
  /// por isso usamos um conjunto (Set), que não guarda número repetido.
  int get totalPedidos {
    final pedidos = <int>{};
    for (final venda in _vendas) {
      pedidos.add(venda.idPedido);
    }
    return pedidos.length;
  }

  int get receitaCentavos {
    var total = 0;
    for (final venda in _vendas) {
      total += venda.totalCentavos;
    }
    return total;
  }

  int get ticketMedioCentavos {
    if (totalPedidos == 0) {
      return 0;
    }
    return (receitaCentavos / totalPedidos).round();
  }

  /// Mapa forma de pagamento -> receita em centavos.
  Map<String, int> get receitaPorPagamento {
    final mapa = <String, int>{};
    for (final venda in _vendas) {
      mapa[venda.formaPagamento] =
          (mapa[venda.formaPagamento] ?? 0) + venda.totalCentavos;
    }
    return mapa;
  }

  /// Mapa local -> quantidade de pedidos.
  Map<String, int> get pedidosPorLocal {
    final pedidos = <String, Set<int>>{};
    for (final venda in _vendas) {
      if (!pedidos.containsKey(venda.local)) {
        pedidos[venda.local] = <int>{};
      }
      pedidos[venda.local]!.add(venda.idPedido);
    }
    final contagem = <String, int>{};
    for (final local in pedidos.keys) {
      contagem[local] = pedidos[local]!.length;
    }
    return contagem;
  }

  /// Mapa tamanho -> marmitas vendidas.
  Map<String, int> get marmitasPorTamanho {
    final mapa = {'P': 0, 'M': 0, 'G': 0};
    for (final venda in _vendas) {
      final tamanho = venda.tamanho;
      // Só conta as marmitas: PFE, PFF e B ficam de fora.
      if (tamanho != null && mapa.containsKey(tamanho)) {
        mapa[tamanho] = mapa[tamanho]! + venda.quantidade;
      }
    }
    return mapa;
  }

  /// O item com mais unidades vendidas, por exemplo "Feijoada completa (12)".
  String get itemMaisVendido {
    final quantidades = <String, int>{};
    for (final venda in _vendas) {
      quantidades[venda.item] =
          (quantidades[venda.item] ?? 0) + venda.quantidade;
    }
    var melhor = '';
    var maior = 0;
    for (final item in quantidades.keys) {
      if (quantidades[item]! > maior) {
        maior = quantidades[item]!;
        melhor = item;
      }
    }
    return melhor.isEmpty ? '-' : '$melhor ($maior)';
  }
}
