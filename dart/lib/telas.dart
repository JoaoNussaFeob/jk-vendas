import 'dart:io';

import 'banco_jk_vendas.dart';
import 'catalogo_de_itens.dart';
import 'formato.dart';
import 'item_pedido.dart';
import 'item_vendavel.dart';
import 'pedido.dart';
import 'resumo_vendas.dart';
import 'porcao.dart';
import 'porcao_dia.dart';
import 'sobra_guardada.dart';
import 'tamanho_marmita.dart';
import 'teclado.dart';

// Cada função "tela" é uma opção do menu. Ela faz as perguntas, monta os
// objetos do negócio (que validam os dados) e pede ao banco para ler ou gravar.

// =============================================================== 1. NOVO PEDIDO
Future<void> telaNovoPedido(BancoJkVendas banco) async {
  print('\n--- NOVO PEDIDO ---');
  final local =
      lerOpcao('Local do pedido:', Pedido.locais, opcaoZero: 'Cancelar');
  if (local == 0) {
    print('Pedido cancelado.');
    return;
  }
  final pedido = Pedido(Pedido.locais[local - 1]);
  final pratosDeHoje = await banco.pratosDoCardapio(DateTime.now());
  final tamanhos = await banco.tamanhosDeMarmita();

  // Repete até a pessoa escolher 0 (fechar o pedido).
  var adicionando = true;
  while (adicionando) {
    final tipo = lerOpcao(
      '\nAdicionar ao pedido (total: ${reais(pedido.totalCentavos)}):',
      ['Marmita do prato do dia', 'Prato fitness', 'Executivo', 'Bebida'],
      opcaoZero: 'Fechar o pedido',
    );
    switch (tipo) {
      case 0:
        adicionando = false;
      case 1:
        _adicionarMarmita(pedido, pratosDeHoje, tamanhos);
      case 2:
        _adicionarItemPrecoFixo(pedido, await banco.itensDoTipo('FITNESS'));
      case 3:
        _adicionarItemPrecoFixo(pedido, await banco.itensDoTipo('EXECUTIVO'));
      case 4:
        _adicionarItemPrecoFixo(pedido, await banco.itensDoTipo('BEBIDA'));
    }
  }

  if (pedido.itens.isEmpty) {
    print('Pedido sem itens: nada foi gravado.');
    return;
  }
  print('\nResumo do pedido (${pedido.local}):');
  for (final linha in pedido.itens) {
    print('  ${linha.descricao.padRight(42)} ${reais(linha.totalCentavos)}');
  }
  print('  ${'TOTAL'.padRight(42)} ${reais(pedido.totalCentavos)}');

  final pagamento = lerOpcao('Forma de pagamento:', Pedido.formasDePagamento,
      opcaoZero: 'Cancelar o pedido');
  if (pagamento == 0) {
    print('Pedido cancelado.');
    return;
  }
  pedido.definirPagamento(Pedido.formasDePagamento[pagamento - 1]);
  if (!confirmar('Gravar o pedido de ${reais(pedido.totalCentavos)}?')) {
    print('Pedido cancelado.');
    return;
  }
  final numero = await banco.gravarPedido(pedido);
  print('Pedido nº $numero gravado. Total: ${reais(pedido.totalCentavos)}');
}

void _adicionarMarmita(
    Pedido pedido, List<PratoDia> pratos, List<TamanhoMarmita> tamanhos) {
  if (pratos.isEmpty) {
    print(
        'Hoje ainda não tem cardápio do dia. Monte o cardápio na opção 4 do menu.');
    return;
  }
  final nomes = <String>[];
  for (final prato in pratos) {
    nomes.add(prato.nome);
  }
  final escolhaPrato = lerOpcao('Prato do dia:', nomes);
  if (escolhaPrato == 0) {
    return;
  }
  final opcoesTamanho = <String>[];
  for (final tamanho in tamanhos) {
    opcoesTamanho.add(
        '${tamanho.nome} (${tamanho.sigla}) · ${reais(tamanho.precoCentavos)}');
  }
  final escolhaTamanho = lerOpcao('Tamanho da marmita:', opcoesTamanho);
  if (escolhaTamanho == 0) {
    return;
  }
  final quantidade = lerInteiro('Quantidade: ');
  _incluir(pedido, pratos[escolhaPrato - 1], tamanhos[escolhaTamanho - 1],
      quantidade);
}

void _adicionarItemPrecoFixo(Pedido pedido, List<ItemVendavel> itens) {
  final opcoes = <String>[];
  var temPrecoDeTeste = false;
  for (final item in itens) {
    var texto =
        '${item.descricao.padRight(32)} ${reais(item.calcularPreco(null))}';
    // "is" confere a classe do objeto. Se for ItemPrecoFixo, dá para ler precoAConfirmar.
    if (item is ItemPrecoFixo && item.precoAConfirmar) {
      texto += ' *';
      temPrecoDeTeste = true;
    }
    opcoes.add(texto);
  }
  final titulo = temPrecoDeTeste
      ? 'Escolha o item (* = preço de teste, a confirmar com o restaurante):'
      : 'Escolha o item:';
  final escolha = lerOpcao(titulo, opcoes);
  if (escolha == 0) {
    return;
  }
  final quantidade = lerInteiro('Quantidade: ');
  _incluir(pedido, itens[escolha - 1], null, quantidade);
}

/// Cria a linha do pedido. Se a classe recusar o dado, mostra o motivo
/// e volta para a lista, sem derrubar o pedido inteiro.
void _incluir(
    Pedido pedido, ItemVendavel item, TamanhoMarmita? tamanho, int quantidade) {
  try {
    final linha = ItemPedido(item, tamanho, quantidade);
    pedido.adicionarItem(linha);
    print('Adicionado: ${linha.descricao} = ${reais(linha.totalCentavos)}');
  } on ArgumentError catch (erro) {
    print('Não foi adicionado: ${erro.message}');
  } on StateError catch (erro) {
    print('Não foi adicionado: ${erro.message}');
  }
}

// ======================================================= 2. VER AS VENDAS DO DIA
Future<void> telaVendasDoDia(BancoJkVendas banco) async {
  print('\n--- VENDAS DO DIA ---');
  final data = lerData('Data (Enter = hoje, ou dd/mm/aaaa): ');
  final resumo = ResumoVendas(await banco.vendasDoDia(data));
  if (resumo.vazio) {
    print('Nenhuma venda em ${dataBr(data)}.');
    return;
  }
  print('\nVendas de ${dataBr(data)}');
  print('Pedidos: ${resumo.totalPedidos}');
  print('Receita: ${reais(resumo.receitaCentavos)}');
  print('Ticket médio: ${reais(resumo.ticketMedioCentavos)}');

  print('\nPor forma de pagamento:');
  final porPagamento = resumo.receitaPorPagamento;
  for (final forma in Pedido.formasDePagamento) {
    print('  ${forma.padRight(10)} ${reais(porPagamento[forma] ?? 0)}');
  }
  print('\nPedidos por local:');
  final porLocal = resumo.pedidosPorLocal;
  for (final local in Pedido.locais) {
    print('  ${local.padRight(10)} ${porLocal[local] ?? 0}');
  }
  final marmitas = resumo.marmitasPorTamanho;
  print(
      '\nMarmitas: P ${marmitas['P']} · M ${marmitas['M']} · G ${marmitas['G']}');
  print('Item mais vendido: ${resumo.itemMaisVendido}');
}

// ====================================================== 3. PORÇÕES DO DIA (KG)
Future<void> telaPorcoesDoDia(BancoJkVendas banco) async {
  print('\n--- PORÇÕES DO DIA ---');
  final data = lerData('Data (Enter = hoje, ou dd/mm/aaaa): ');
  final porcoes = await banco.porcoesDoDia(data);
  if (porcoes.isEmpty) {
    print(
        'Não há cardápio em ${dataBr(data)}. Monte o cardápio na opção 4 do menu.');
    return;
  }
  print(
      'Para cada porção, digite os quilos (ex.: 5,25). Enter sem digitar nada pula a porção.');
  print(
      'Só arroz e feijão podem usar sobra guardada (até ${Porcao.validadeMaximaDias} dias, RDC 216/2004).');

  final paraReduzir = <String>[];
  for (final porcao in porcoes) {
    print('\n${porcao.porcao.nome} (${porcao.porcao.tipoTexto})');
    if (porcao.registrada) {
      print('  Já registrada: ${quilos(porcao.preparado!)} feitos, '
          '${quilos(porcao.reaproveitado)} reaproveitados, ${quilos(porcao.sobra!)} de sobra.');
      continue;
    }
    // Sobras guardadas que ainda valem nesse dia (só arroz e feijão).
    var sobras = <SobraGuardada>[];
    var disponivel = 0;
    if (porcao.porcao.reaproveitavel) {
      sobras = await banco.sobrasValidas(porcao.porcao.id, data);
      for (final s in sobras) {
        disponivel += s.saldo;
        print(
            '  Na geladeira: ${quilos(s.saldo)} de ${dataBr(s.dataPreparo)}, vale até ${dataBr(s.validade)}');
      }
    }

    // Repete a pergunta até os números fecharem ou a pessoa pular a porção.
    while (true) {
      final texto = lerTexto('  Kg preparado hoje: ');
      if (texto.isEmpty) {
        break;
      }
      final preparado = gramasDoTexto(texto);
      var reaproveitado = 0;
      if (porcao.porcao.reaproveitavel && disponivel > 0) {
        reaproveitado =
            gramasDoTexto(lerTexto('  Kg de sobra guardada usado: ')) ?? -1;
      }
      final sobra = gramasDoTexto(lerTexto('  Kg que sobrou: '));
      if (preparado == null || sobra == null || reaproveitado < 0) {
        print('  Digite os quilos com números, por exemplo 5,25.');
        continue;
      }
      try {
        // Primeiro confere de onde sai o reaproveitado, depois registra e grava.
        final uso = SobraGuardada.planejarUso(sobras, data, reaproveitado);
        porcao.registrar(preparado, reaproveitado, sobra,
            disponivel: disponivel);
        await banco.salvarPorcao(porcao, uso);
      } on ArgumentError catch (erro) {
        print('  Não foi salvo: ${erro.message}');
        continue;
      }
      print('  Salvo. ${porcao.alerta}');
      if (!porcao.porcao.reaproveitavel &&
          porcao.percentualSobra > PorcaoDia.limiteSobraAlta) {
        paraReduzir.add(porcao.porcao.nome);
      }
      break;
    }
  }

  // Resumo do dia: o que foi para o lixo hoje (o arroz e o feijão vão para a geladeira).
  var total = 0;
  var lixo = 0;
  for (final porcao in porcoes) {
    if (porcao.registrada) {
      total += porcao.preparado! + porcao.reaproveitado;
      lixo += porcao.desperdicioDoDia;
    }
  }
  if (total > 0) {
    print(
        '\nResumo de ${dataBr(data)}: ${quilos(lixo)} foram para o lixo de ${quilos(total)} '
        '(${percentual(lixo * 100 / total)}).');
    if (paraReduzir.isEmpty) {
      print(
          'Nenhuma porção passou de ${percentual(PorcaoDia.limiteSobraAlta)} de sobra.');
    } else {
      print('Preparar menos: ${paraReduzir.join(', ')}.');
    }
  }
}

// ================================================= 4. MONTAR O CARDÁPIO DO DIA
Future<void> telaMontarCardapio(BancoJkVendas banco) async {
  print('\n--- MONTAR O CARDÁPIO DO DIA ---');
  final data = lerData('Data do cardápio (Enter = hoje, ou dd/mm/aaaa): ');
  final atuais = await banco.pratosDoCardapio(data);
  if (atuais.isNotEmpty) {
    print('O cardápio de ${dataBr(data)} já existe:');
    for (final prato in atuais) {
      print('  - ${prato.nome}');
    }
    return;
  }

  final todos = await banco.pratosDoDiaCadastrados();
  print('Pratos do dia cadastrados:');
  for (var i = 0; i < todos.length; i++) {
    print('  ${(i + 1).toString().padLeft(2)}. ${todos[i].nome}');
  }
  final texto =
      lerTexto('Números dos pratos, separados por vírgula (ex.: 1, 8, 9): ');

  final escolhidos = <PratoDia>[];
  final numerosVistos = <int>{}; // conjunto: ignora número repetido
  for (final parte in texto.split(',')) {
    final numero = int.tryParse(parte.trim());
    if (numero == null || numero < 1 || numero > todos.length) {
      throw ArgumentError('Número de prato inválido: "${parte.trim()}".');
    }
    if (numerosVistos.add(numero)) {
      escolhidos.add(todos[numero - 1]);
    }
  }

  // Acompanhamentos do dia (arroz e feijão entram sozinhos).
  final acompanhamentos = [
    for (final p in await banco.porcoesCadastradas())
      if (p.tipo == 'ACOMPANHAMENTO') p
  ];
  print('Acompanhamentos cadastrados (arroz e feijão já entram todo dia):');
  for (var i = 0; i < acompanhamentos.length; i++) {
    print('  ${(i + 1).toString().padLeft(2)}. ${acompanhamentos[i].nome}');
  }
  final textoAcomp = lerTexto(
      'Números dos acompanhamentos, separados por vírgula (Enter = nenhum): ');
  final acompEscolhidos = <Porcao>[];
  final acompVistos = <int>{};
  for (final parte in textoAcomp.split(',')) {
    if (parte.trim().isEmpty) {
      continue;
    }
    final numero = int.tryParse(parte.trim());
    if (numero == null || numero < 1 || numero > acompanhamentos.length) {
      throw ArgumentError(
          'Número de acompanhamento inválido: "${parte.trim()}".');
    }
    if (acompVistos.add(numero)) {
      acompEscolhidos.add(acompanhamentos[numero - 1]);
    }
  }

  print('Cardápio de ${dataBr(data)}:');
  for (final prato in escolhidos) {
    print('  - ${prato.nome}');
  }
  print('Acompanha: arroz e feijão${[
    for (final a in acompEscolhidos) ', ${a.nome.toLowerCase()}'
  ].join()}.');
  if (!confirmar('Gravar este cardápio?')) {
    print('Nada foi gravado.');
    return;
  }
  await banco.criarCardapio(data, escolhidos, acompEscolhidos);
  print('Cardápio gravado com ${escolhidos.length} prato(s).');
}

// ================================================ 5. EXPORTAR O CATÁLOGO (JSON)
/// Lê todos os itens do banco, monta a coleção (CatalogoDeItens) e grava o
/// catálogo inteiro em JSON no arquivo catalogo_jk_vendas.json.
Future<void> telaExportarCatalogo(BancoJkVendas banco) async {
  print('\n--- EXPORTAR O CATÁLOGO EM JSON ---');
  final catalogo = CatalogoDeItens(await banco.todosOsItens());
  if (catalogo.vazio) {
    print('Não há itens cadastrados.');
    return;
  }
  print('Itens no catálogo: ${catalogo.quantidade}');
  for (final grupo in catalogo.quantidadePorTipo().entries) {
    print('  ${grupo.key.padRight(10)} ${grupo.value}');
  }
  print('Preços a confirmar: ${catalogo.precosAConfirmar().length}');
  const arquivo = 'catalogo_jk_vendas.json';
  File(arquivo).writeAsStringSync(catalogo.toJsonFormatado());
  print('Catálogo gravado em $arquivo.');
}
