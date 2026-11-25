// Testes das regras do negócio. Não precisam do banco: rode com "dart test".
import 'dart:convert';

import 'package:jk_vendas/catalogo_de_itens.dart';
import 'package:jk_vendas/formato.dart';
import 'package:jk_vendas/item_pedido.dart';
import 'package:jk_vendas/item_vendavel.dart';
import 'package:jk_vendas/pedido.dart';
import 'package:jk_vendas/resumo_vendas.dart';
import 'package:jk_vendas/porcao.dart';
import 'package:jk_vendas/porcao_dia.dart';
import 'package:jk_vendas/sobra_guardada.dart';
import 'package:jk_vendas/tamanho_marmita.dart';
import 'package:test/test.dart';

void main() {
  final grande = TamanhoMarmita('G', 'Grande', 2700);
  final feijoada = PratoDia(12, 'Feijoada completa', 'Carne suína');
  final tilapia =
      PratoFitness(22, 'Filé de tilápia grelhada', 'Peixe', 2700, false);
  final coca = Bebida(38, 'Coca-Cola lata', 'Refrigerante', 600, true);

  group('Preço (polimorfismo)', () {
    test('a marmita do prato do dia usa o preço do tamanho', () {
      expect(feijoada.calcularPreco(grande), 2700);
    });
    test('marmita sem tamanho é recusada com StateError', () {
      expect(() => feijoada.calcularPreco(null), throwsStateError);
    });
    test('fitness e bebida têm preço próprio', () {
      expect(tilapia.calcularPreco(null), 2700);
      expect(coca.calcularPreco(null), 600);
    });
    test('item de preço fixo não aceita tamanho', () {
      expect(() => coca.calcularPreco(grande), throwsArgumentError);
    });
    test('cada item grava a sigla certa no tamanho', () {
      expect(ItemPedido(coca, null, 1).sigla, 'B');
      expect(ItemPedido(tilapia, null, 1).sigla, 'PFF');
      expect(
          ItemPedido(
                  PratoExecutivo(
                      26, 'Contra filé grelhado', 'Carne bovina', 3000, true),
                  null,
                  1)
              .sigla,
          'PFE');
      expect(ItemPedido(feijoada, grande, 1).sigla, 'G');
    });
    test('tamanho e preço inválidos são recusados', () {
      expect(() => TamanhoMarmita('X', 'Extra', 3000), throwsArgumentError);
      expect(
          () => PratoExecutivo(
              26, 'Contra filé grelhado', 'Carne bovina', 0, true),
          throwsArgumentError);
    });
  });

  group('Pedido', () {
    test('quantidade zero ou negativa é recusada', () {
      expect(() => ItemPedido(coca, null, 0), throwsArgumentError);
      expect(() => ItemPedido(coca, null, -2), throwsArgumentError);
    });
    test('o total soma todas as linhas', () {
      final pedido = Pedido('Delivery');
      pedido.adicionarItem(ItemPedido(feijoada, grande, 2));
      pedido.adicionarItem(ItemPedido(coca, null, 1));
      expect(pedido.totalCentavos, 2 * 2700 + 600);
    });
    test('pedido sem itens não pode ser gravado', () {
      final pedido = Pedido('Balcão');
      pedido.definirPagamento('Pix');
      expect(() => pedido.validarParaGravar(), throwsStateError);
    });
    test('pedido sem forma de pagamento não pode ser gravado', () {
      final pedido = Pedido('Balcão');
      pedido.adicionarItem(ItemPedido(coca, null, 1));
      expect(() => pedido.validarParaGravar(), throwsStateError);
    });
    test('local e pagamento fora da lista são recusados', () {
      expect(() => Pedido('Mesa'), throwsArgumentError);
      expect(() => Pedido('Balcão').definirPagamento('Cheque'),
          throwsArgumentError);
    });
    test('a lista de itens não pode ser alterada de fora', () {
      final pedido = Pedido('Viagem');
      expect(() => pedido.itens.add(ItemPedido(coca, null, 1)),
          throwsUnsupportedError);
    });
  });

  group('Porções do dia (kg)', () {
    final arroz = Porcao(1, 'Arroz', 'BASE', true, 5);
    final batata = Porcao(13, 'Batata frita', 'ACOMPANHAMENTO', false, 0);
    final dia = DateTime(2026, 10, 21);

    test('mistura não pode ser reaproveitável', () {
      expect(() => Porcao(33, 'Feijoada completa', 'MISTURA', true, 5),
          throwsArgumentError);
    });
    test('a validade da sobra não passa de 5 dias (RDC 216)', () {
      expect(() => Porcao(1, 'Arroz', 'BASE', true, 6), throwsArgumentError);
    });
    test('acompanhamento não pode usar sobra guardada', () {
      expect(
          () => PorcaoDia(dia, batata, null, 0, null)
              .registrar(3000, 500, 0, disponivel: 1000),
          throwsArgumentError);
    });
    test('não reaproveita mais do que tem na geladeira', () {
      expect(
          () => PorcaoDia(dia, arroz, null, 0, null)
              .registrar(5000, 1500, 0, disponivel: 1000),
          throwsArgumentError);
    });
    test('sobra maior que o preparado mais o reaproveitado é recusada', () {
      expect(
          () => PorcaoDia(dia, arroz, null, 0, null)
              .registrar(2000, 500, 3000, disponivel: 500),
          throwsArgumentError);
    });
    test('sobra de arroz vai para a geladeira com validade de 5 dias', () {
      final porcao = PorcaoDia(dia, arroz, null, 0, null)
        ..registrar(5000, 0, 800);
      expect(porcao.desperdicioDoDia, 0);
      expect(porcao.alerta, contains('26/10/2026'));
    });
    test('sobra de acompanhamento acima de 20% gera alerta', () {
      final porcao = PorcaoDia(dia, batata, null, 0, null)
        ..registrar(4000, 0, 1000);
      expect(porcao.percentualSobra, 25);
      expect(porcao.desperdicioDoDia, 1000);
      expect(porcao.alerta, startsWith('ALERTA'));
    });
    test('usa a sobra mais antiga primeiro e não usa sobra vencida', () {
      final velha = SobraGuardada(
          1, 1, DateTime(2026, 10, 15), DateTime(2026, 10, 20), 1000, 0);
      final antiga = SobraGuardada(
          2, 1, DateTime(2026, 10, 18), DateTime(2026, 10, 23), 1000, 0);
      final nova = SobraGuardada(
          3, 1, DateTime(2026, 10, 20), DateTime(2026, 10, 25), 1000, 0);
      final plano = SobraGuardada.planejarUso([nova, velha, antiga], dia, 1500);
      expect(plano.containsKey(velha), isFalse); // venceu em 20/10
      expect(plano[antiga], 1000);
      expect(plano[nova], 500);
      expect(() => velha.usar(100, dia), throwsStateError);
    });
    test('mostra o peso em quilos', () {
      expect(quilos(5250), '5,250 kg');
      expect(gramasDoTexto('5,25'), 5250);
    });
  });

  group('Resumo do dia', () {
    final resumo = ResumoVendas([
      VendaRegistrada(1, 'Pix', 'Delivery', 'Feijoada completa', 'G', 2, 2700),
      VendaRegistrada(1, 'Pix', 'Delivery', 'Coca-Cola lata', null, 1, 600),
      VendaRegistrada(
          2, 'Dinheiro', 'Balcão', 'Feijoada completa', 'M', 1, 2400),
    ]);

    test('conta cada pedido uma vez só', () {
      expect(resumo.totalPedidos, 2);
    });
    test('receita e ticket médio', () {
      expect(resumo.receitaCentavos, 8400);
      expect(resumo.ticketMedioCentavos, 4200);
    });
    test('mapas por pagamento, local e tamanho', () {
      expect(resumo.receitaPorPagamento, {'Pix': 6000, 'Dinheiro': 2400});
      expect(resumo.pedidosPorLocal, {'Delivery': 1, 'Balcão': 1});
      expect(resumo.marmitasPorTamanho, {'P': 0, 'M': 1, 'G': 2});
    });
    test('item mais vendido', () {
      expect(resumo.itemMaisVendido, 'Feijoada completa (3)');
    });
  });

  group('Formato', () {
    test('reais com ponto de milhar e vírgula', () {
      expect(reais(1671500), 'R\$ 16.715,00');
      expect(reais(600), 'R\$ 6,00');
      expect(reais(5), 'R\$ 0,05');
    });
    test('datas e percentual', () {
      expect(dataBr(DateTime(2026, 10, 5)), '05/10/2026');
      expect(dataMysql(DateTime(2026, 10, 5)), '2026-10-05');
      expect(percentual(22.222), '22,2%');
    });
  });

  group('Herança, coleções e JSON (17/11)', () {
    final executivo =
        PratoExecutivo(26, 'Contra filé grelhado', 'Carne bovina', 3000, true);

    test('a filha herda o toMap da mãe e acrescenta os seus campos', () {
      final mapa = coca.toMap();
      expect(mapa['id'], 38); // veio de ItemVendavel
      expect(mapa['tipo'], 'BEBIDA');
      expect(mapa['precoCentavos'], 600); // veio de ItemPrecoFixo
      expect(mapa['siglaTamanho'], 'B');
      expect(feijoada.toMap()['regraDePreco'], contains('tamanho'));
    });
    test('toJson gera um JSON válido com os mesmos dados do toMap', () {
      expect(jsonDecode(tilapia.toJson()), tilapia.toMap());
    });
    test('fromMap recria a classe certa de cada item', () {
      for (final item in [feijoada, tilapia, executivo, coca]) {
        final copia = ItemVendavel.fromMap(item.toMap());
        expect(copia.runtimeType, item.runtimeType);
        expect(copia.toMap(), item.toMap());
      }
      expect(
          () => ItemVendavel.fromMap(
              {'id': 1, 'nome': 'X', 'categoria': 'Y', 'tipo': 'OUTRO'}),
          throwsArgumentError);
    });
    test('o catálogo não aceita dois itens com o mesmo id', () {
      final catalogo = CatalogoDeItens([feijoada, coca]);
      expect(() => catalogo.adicionar(coca), throwsArgumentError);
      expect(catalogo.quantidade, 2);
    });
    test('o catálogo busca, filtra pela classe, ordena e agrupa', () {
      final catalogo = CatalogoDeItens([feijoada, tilapia, executivo, coca]);
      expect(catalogo.buscarPorId(22), same(tilapia));
      expect(catalogo.buscarPorId(99), isNull);
      expect(catalogo.daClasse<Bebida>(), [coca]);
      expect(catalogo.daClasse<ItemPrecoFixo>().length, 3);
      expect(
          [for (final i in catalogo.ordenadosPorPreco()) i.id], [38, 22, 26]);
      expect(catalogo.quantidadePorTipo(),
          {'PRATO_DIA': 1, 'FITNESS': 1, 'EXECUTIVO': 1, 'BEBIDA': 1});
      expect(catalogo.precosAConfirmar(), [executivo, coca]);
      expect(catalogo.remover(38), isTrue);
      expect(catalogo.remover(38), isFalse);
    });
    test('o catálogo vai para JSON e volta igual', () {
      final catalogo = CatalogoDeItens([feijoada, tilapia, executivo, coca]);
      final copia = CatalogoDeItens.fromJson(catalogo.toJson());
      expect(copia.toJson(), catalogo.toJson());
    });
    test('o pedido leva a lista de itens dentro do JSON', () {
      final pedido = Pedido('Balcão')
        ..adicionarItem(ItemPedido(feijoada, grande, 2))
        ..adicionarItem(ItemPedido(coca, null, 1))
        ..definirPagamento('Pix');
      final mapa = jsonDecode(pedido.toJson()) as Map<String, dynamic>;
      expect(mapa['totalCentavos'], 6000);
      expect((mapa['itens'] as List).length, 2);
      expect(mapa['itens'][0]['item']['nome'], 'Feijoada completa');
      expect(mapa['itens'][1]['tamanho'], 'B');
    });
  });
}
