// =============================================================================
// Atividade do projeto de extensão (03/11/2026) · Prof. Luís Gustavo
// Aplicação Final da Lógica
//
// Este programa lê a lista de vendas do banco jk_vendas_porcoes, calcula a
// SOMA, a MÉDIA, o MAIOR e o MENOR valor e compara cada resultado com o
// indicador (KPI) que o dashboard do Power BI mostra.
//
// Cada "venda" é um pedido. Um pedido com 3 itens aparece em 3 linhas no
// banco, então primeiro juntamos as linhas do mesmo pedido (com um Map) e
// depois fazemos as contas com repetição (for), sem usar funções prontas.
//
// Ligação com o dashboard (medidas DAX do Power BI):
//   soma        -> Receita Total  = SUM(fVendas[Valor Total])
//   quantidade  -> Total de Pedidos
//   média       -> Ticket Médio   = DIVIDE([Receita Total], [Total de Pedidos])
//   maior valor -> Maior Pedido   = MAXX(pedidos, [Receita Total])
//   menor valor -> Menor Pedido   = MINX(pedidos, [Receita Total])
//
// Como rodar, dentro da pasta dart:  dart run bin/validar_kpis.dart
// =============================================================================
import 'package:jk_vendas/banco_jk_vendas.dart';
import 'package:jk_vendas/formato.dart';
import 'package:jk_vendas/resumo_vendas.dart';
import 'package:jk_vendas/teclado.dart';

// -----------------------------------------------------------------------------
// Os valores que os cartões do dashboard mostram com a carga de dados original
// (sql/jk_vendas.sql + sql/carga_dados.sql). Dinheiro em centavos.
// Se o banco ganhar vendas novas, clique em Atualizar no Power BI e troque
// estes números pelos que o dashboard mostrar.
// -----------------------------------------------------------------------------
class KpisDoDashboard {
  static const totalDePedidos = 400; // Total de Pedidos
  static const receitaTotal = 1671500; // Receita Total: R$ 16.715,00
  static const ticketMedio = 4179; // Ticket Médio: R$ 41,79
  static const maiorPedido = 13300; // Maior Pedido: R$ 133,00
  static const menorPedido = 400; // Menor Pedido: R$ 4,00
}

// -----------------------------------------------------------------------------
// A lógica dos cálculos. Recebe a lista de vendas (pedido -> valor em
// centavos) e calcula cada indicador com uma repetição.
// -----------------------------------------------------------------------------
class IndicadoresDeVendas {
  // Atributo privado (encapsulamento): número do pedido -> valor do pedido.
  final Map<int, int> _vendas;

  IndicadoresDeVendas(Map<int, int> vendas)
      : _vendas = Map.unmodifiable(vendas) {
    // Sem vendas não existe média, maior nem menor: é um erro de estado.
    if (_vendas.isEmpty) {
      throw StateError('A lista de vendas está vazia: não há o que calcular.');
    }
  }

  /// Junta as linhas vendidas do mesmo pedido. Exemplo: um pedido com uma
  /// marmita G (R$ 27,00) e uma coca (R$ 6,00) vira uma venda de R$ 33,00.
  static Map<int, int> agruparPorPedido(List<VendaRegistrada> linhas) {
    final vendas = <int, int>{};
    for (final linha in linhas) {
      vendas[linha.idPedido] =
          (vendas[linha.idPedido] ?? 0) + linha.totalCentavos;
    }
    return vendas;
  }

  /// Quantas vendas (pedidos) tem a lista.
  int get quantidade => _vendas.length;

  /// SOMA: percorre a lista e vai acumulando o valor de cada venda.
  int get soma {
    var total = 0;
    for (final valor in _vendas.values) {
      total += valor;
    }
    return total;
  }

  /// MÉDIA: a soma dividida pela quantidade. Fica com as casas decimais
  /// (em centavos), porque 1671500 / 400 = 4178,75.
  double get media => soma / quantidade;

  /// A média arredondada para centavos, como o dashboard mostra (R$ 41,79).
  int get mediaEmCentavos => media.round();

  /// MAIOR VALOR: começa com a primeira venda e troca sempre que achar uma
  /// maior. Devolve o número do pedido, para sabermos qual foi.
  int get pedidoDeMaiorValor {
    var escolhido = _vendas.keys.first;
    for (final pedido in _vendas.keys) {
      if (_vendas[pedido]! > _vendas[escolhido]!) {
        escolhido = pedido;
      }
    }
    return escolhido;
  }

  /// MENOR VALOR: a mesma ideia, trocando quando achar uma venda menor.
  int get pedidoDeMenorValor {
    var escolhido = _vendas.keys.first;
    for (final pedido in _vendas.keys) {
      if (_vendas[pedido]! < _vendas[escolhido]!) {
        escolhido = pedido;
      }
    }
    return escolhido;
  }

  int get maior => _vendas[pedidoDeMaiorValor]!;
  int get menor => _vendas[pedidoDeMenorValor]!;
}

// -----------------------------------------------------------------------------
// Validação: compara o que a lógica calculou com o que o dashboard mostra.
// -----------------------------------------------------------------------------

/// Mostra uma linha da tabela de comparação e devolve true se os valores
/// forem iguais.
bool conferir(
    String indicador, String calculado, String dashboard, bool iguais) {
  final resultado = iguais ? 'OK' : 'DIFERENTE';
  print('${indicador.padRight(32)}${calculado.padRight(16)}'
      '${dashboard.padRight(16)}$resultado');
  return iguais;
}

/// Média em reais com 4 casas, para mostrar a conta antes do arredondamento:
/// 4178.75 centavos vira "41,7875".
String mediaExata(double centavos) =>
    (centavos / 100).toStringAsFixed(4).replaceAll('.', ',');

void mostrarResultados(IndicadoresDeVendas kpis, int linhasLidas) {
  print('\nLista de vendas: $linhasLidas linhas vendidas, '
      'agrupadas em ${kpis.quantidade} pedidos.');

  print('\n---------------------- CÁLCULOS ----------------------');
  print('Soma ......... ${reais(kpis.soma)}');
  print('Média ........ ${reais(kpis.mediaEmCentavos)}  '
      '(${reais(kpis.soma)} / ${kpis.quantidade} = '
      '${mediaExata(kpis.media)}, arredondado)');
  print('Maior valor .. ${reais(kpis.maior)}  '
      '(pedido nº ${kpis.pedidoDeMaiorValor})');
  print('Menor valor .. ${reais(kpis.menor)}  '
      '(pedido nº ${kpis.pedidoDeMenorValor})');

  print('\n------------ COMPARAÇÃO COM O DASHBOARD ------------');
  print('${'Indicador'.padRight(32)}${'Dart'.padRight(16)}'
      '${'Dashboard'.padRight(16)}Resultado');
  // Lista com o resultado de cada conferência (true = igual).
  final resultados = [
    conferir(
        'Quantidade (Total de Pedidos)',
        '${kpis.quantidade}',
        '${KpisDoDashboard.totalDePedidos}',
        kpis.quantidade == KpisDoDashboard.totalDePedidos),
    conferir(
        'Soma (Receita Total)',
        reais(kpis.soma),
        reais(KpisDoDashboard.receitaTotal),
        kpis.soma == KpisDoDashboard.receitaTotal),
    conferir(
        'Média (Ticket Médio)',
        reais(kpis.mediaEmCentavos),
        reais(KpisDoDashboard.ticketMedio),
        kpis.mediaEmCentavos == KpisDoDashboard.ticketMedio),
    conferir(
        'Maior valor (Maior Pedido)',
        reais(kpis.maior),
        reais(KpisDoDashboard.maiorPedido),
        kpis.maior == KpisDoDashboard.maiorPedido),
    conferir(
        'Menor valor (Menor Pedido)',
        reais(kpis.menor),
        reais(KpisDoDashboard.menorPedido),
        kpis.menor == KpisDoDashboard.menorPedido),
  ];

  var certos = 0;
  for (final certo in resultados) {
    if (certo) {
      certos++;
    }
  }
  print('\nResultado: $certos de ${resultados.length} indicadores '
      'conferem com o dashboard.');
  if (certos == resultados.length) {
    print('Os cálculos da lógica em Dart estão validados.');
  } else {
    print('Algum valor não bateu. Se vocês gravaram vendas novas, o '
        'dashboard também mudou: clique em Atualizar no Power BI e troque os '
        'números da classe KpisDoDashboard, ou rode de novo jk_vendas.sql e '
        'carga_dados.sql para voltar à carga original.');
  }
}

Future<void> main() async {
  print('==================================================');
  print('   JK VENDAS · Validação dos KPIs do dashboard');
  print('==================================================');

  // 1. Conexão. A senha é digitada na hora e não fica no código.
  final banco = BancoJkVendas();
  try {
    final usuario = lerTexto('Usuário do MySQL (Enter = root): ');
    final senha = lerSenha('Senha do MySQL: ');
    await banco.conectar(usuario.isEmpty ? 'root' : usuario, senha);
  } on FimDaEntrada {
    return;
  } catch (erro) {
    print('Não foi possível conectar no MySQL: $erro');
    return;
  }

  try {
    // 2. Entrada: as linhas vendidas, do jeito que estão no banco.
    final linhas = await banco.todasAsVendas();

    // 3. Processamento: junta as linhas por pedido e faz as contas.
    final kpis =
        IndicadoresDeVendas(IndicadoresDeVendas.agruparPorPedido(linhas));

    // 4. Saída: mostra os cálculos e compara com o dashboard.
    mostrarResultados(kpis, linhas.length);
  } on StateError catch (erro) {
    print('Não foi possível calcular: ${erro.message}');
  } catch (erro) {
    print('Erro do banco de dados: $erro');
  } finally {
    await banco.fechar();
  }
}
