// =============================================================================
// Atividade do projeto de extensão (17/11/2026) · Prof. Nivaldo
// POO Avançada: Herança, Coleções de Objetos e Refatoração
//
// Demonstração que roda SEM o banco:  dart run bin/poo_avancada.dart
//
// 1. Herança e interface: os itens herdam o toMap/toJson de ItemVendavel
//    (que usa o mixin ConverteJson, da interface Serializavel).
// 2. Coleção de objetos: CatalogoDeItens adiciona, busca, filtra, ordena e
//    agrupa uma lista com pratos e bebidas misturados.
// 3. Conversão: toMap, toJson e o caminho de volta (fromMap / fromJson).
//
// Com o banco, a opção 5 do menu principal (dart run) exporta o catálogo
// real em JSON, usando as mesmas classes.
// =============================================================================
import 'package:jk_vendas/catalogo_de_itens.dart';
import 'package:jk_vendas/formato.dart';
import 'package:jk_vendas/item_pedido.dart';
import 'package:jk_vendas/item_vendavel.dart';
import 'package:jk_vendas/pedido.dart';
import 'package:jk_vendas/tamanho_marmita.dart';

void titulo(String texto) {
  print('\n=== $texto ${'=' * (60 - texto.length)}');
}

void main() {
  // Itens reais do cardápio do JK (sql/jk_vendas.sql).
  final catalogo = CatalogoDeItens([
    PratoDia(12, 'Feijoada completa', 'Carne suína'),
    PratoDia(20, 'Parmegiana de filé de frango', 'Frango'),
    PratoFitness(22, 'Filé de tilápia grelhada', 'Peixe', 2700, false),
    PratoFitness(23, 'Filé de frango grelhado', 'Frango', 2200, false),
    PratoExecutivo(26, 'Contra filé grelhado', 'Carne bovina', 3000, true),
    Bebida(38, 'Coca-Cola lata', 'Refrigerante', 600, true),
    Bebida(40, 'Coca-Cola 2 L', 'Refrigerante', 1400, true),
  ]);

  titulo('1. HERANÇA: o mesmo toMap, campos a mais nas filhas');
  // PratoDia acrescenta a regra de preço; ItemPrecoFixo acrescenta preço e sigla.
  print(catalogo.buscarPorId(12)!.toJson());
  print(catalogo.buscarPorId(38)!.toJson());

  titulo('2. COLEÇÃO DE OBJETOS');
  print('Itens no catálogo: ${catalogo.quantidade}');
  print('Por tipo: ${catalogo.quantidadePorTipo()}');
  print('Busca por "frango": '
      '${[for (final i in catalogo.buscarPorNome('frango')) i.nome]}');
  print('Só as bebidas (daClasse<Bebida>): '
      '${[for (final b in catalogo.daClasse<Bebida>()) b.nome]}');
  print('Preço fixo, do mais barato ao mais caro:');
  for (final item in catalogo.ordenadosPorPreco()) {
    print('  ${reais(item.precoCentavos).padLeft(9)}  ${item.nome}');
  }
  print('Preços a confirmar: '
      '${[for (final i in catalogo.precosAConfirmar()) i.nome]}');

  try {
    catalogo.adicionar(Bebida(38, 'Outra coca', 'Refrigerante', 600, false));
  } on ArgumentError catch (erro) {
    print('Item repetido recusado: ${erro.message}');
  }
  catalogo.remover(40);
  print('Depois de remover o item 40: ${catalogo.quantidade} itens');

  titulo('3. OBJETO DENTRO DE OBJETO: pedido em JSON');
  final grande = TamanhoMarmita('G', 'Grande', 2700);
  final pedido = Pedido('Delivery')
    ..adicionarItem(ItemPedido(catalogo.buscarPorId(12)!, grande, 2))
    ..adicionarItem(ItemPedido(catalogo.buscarPorId(38)!, null, 2))
    ..definirPagamento('Pix');
  print(pedido.toJsonFormatado());
  print('Total do pedido: ${reais(pedido.totalCentavos)}');

  titulo('4. IDA E VOLTA: toJson -> fromJson');
  final json = catalogo.toJson();
  final copia = CatalogoDeItens.fromJson(json);
  print('JSON com ${json.length} caracteres virou um catálogo com '
      '${copia.quantidade} itens.');
  for (final item in copia.itens) {
    // runtimeType mostra que cada Map voltou como a classe certa.
    print('  ${item.runtimeType.toString().padRight(15)} ${item.nome}');
  }
  print('JSON igual ao original? ${copia.toJson() == json}');
}
