import 'dart:convert';

import 'item_vendavel.dart';
import 'serializavel.dart';

// =============================================================================
// CatalogoDeItens: gerencia uma COLEÇÃO de objetos (a lista de tudo o que o
// restaurante vende). Ela guarda a lista privada e oferece métodos para
// adicionar, remover, buscar, filtrar, ordenar e agrupar, além de converter
// o catálogo inteiro em Map/JSON e de volta.
//
// Como a lista é de ItemVendavel (a classe mãe), cabem nela pratos do dia,
// pratos fitness, executivos e bebidas: herança + polimorfismo numa coleção.
// =============================================================================
class CatalogoDeItens with ConverteJson {
  // Encapsulamento: ninguém de fora mexe na lista direto.
  final List<ItemVendavel> _itens = [];

  CatalogoDeItens([Iterable<ItemVendavel> itens = const []]) {
    for (final item in itens) {
      adicionar(item);
    }
  }

  /// Cria o catálogo a partir do texto JSON (o caminho de volta do toJson).
  /// Cada Map da lista vira a classe certa por ItemVendavel.fromMap.
  factory CatalogoDeItens.fromJson(String json) {
    final dados = jsonDecode(json) as Map<String, dynamic>;
    final lista = dados['itens'] as List<dynamic>;
    return CatalogoDeItens([
      for (final map in lista) ItemVendavel.fromMap(map as Map<String, dynamic>)
    ]);
  }

  /// Cópia só de leitura: item novo só entra por adicionar().
  List<ItemVendavel> get itens => List.unmodifiable(_itens);

  int get quantidade => _itens.length;
  bool get vazio => _itens.isEmpty;

  /// Adiciona um item. Dois itens com o mesmo id não podem existir.
  void adicionar(ItemVendavel item) {
    if (buscarPorId(item.id) != null) {
      throw ArgumentError('Já existe um item com o id ${item.id}.');
    }
    _itens.add(item);
  }

  /// Remove pelo id. Devolve true se achou e removeu.
  bool remover(int id) {
    final antes = _itens.length;
    _itens.removeWhere((item) => item.id == id);
    return _itens.length < antes;
  }

  /// Procura pelo id. Devolve null se não encontrar.
  ItemVendavel? buscarPorId(int id) {
    for (final item in _itens) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  /// Itens cujo nome contém o texto (sem diferenciar maiúscula e minúscula).
  List<ItemVendavel> buscarPorNome(String texto) {
    final procurado = texto.toLowerCase();
    return _itens
        .where((item) => item.nome.toLowerCase().contains(procurado))
        .toList();
  }

  /// Só os itens de uma classe. Exemplo: daClasse<Bebida>() devolve as
  /// bebidas, e daClasse<ItemPrecoFixo>() devolve fitness, executivo e bebida
  /// (porque todas herdam de ItemPrecoFixo).
  List<T> daClasse<T extends ItemVendavel>() => _itens.whereType<T>().toList();

  /// Itens de preço fixo do mais barato para o mais caro.
  List<ItemPrecoFixo> ordenadosPorPreco() {
    final lista = daClasse<ItemPrecoFixo>();
    lista.sort((a, b) => a.precoCentavos.compareTo(b.precoCentavos));
    return lista;
  }

  /// Agrupa os itens pelo tipo: PRATO_DIA -> [...], BEBIDA -> [...].
  Map<String, List<ItemVendavel>> agrupadosPorTipo() {
    final grupos = <String, List<ItemVendavel>>{};
    for (final item in _itens) {
      grupos.putIfAbsent(item.tipo, () => []).add(item);
    }
    return grupos;
  }

  /// Quantos itens de cada tipo.
  Map<String, int> quantidadePorTipo() => {
        for (final grupo in agrupadosPorTipo().entries)
          grupo.key: grupo.value.length
      };

  /// Itens com preço de teste, que ainda precisam ser confirmados.
  List<ItemPrecoFixo> precosAConfirmar() =>
      daClasse<ItemPrecoFixo>().where((item) => item.precoAConfirmar).toList();

  @override
  Map<String, dynamic> toMap() => {
        'quantidade': quantidade,
        'quantidadePorTipo': quantidadePorTipo(),
        'itens': listaParaMaps(_itens),
      };
}
