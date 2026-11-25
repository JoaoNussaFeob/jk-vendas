import 'dart:io';
import 'package:mysql_client/mysql_client.dart';
import 'formato.dart';
import 'item_vendavel.dart';
import 'pedido.dart';
import 'resumo_vendas.dart';
import 'porcao.dart';
import 'porcao_dia.dart';
import 'sobra_guardada.dart';
import 'tamanho_marmita.dart';

class BancoJkVendas {
  final String _host = Platform.environment['JK_DB_HOST'] ?? '127.0.0.1';
  final int _porta =
      int.tryParse(Platform.environment['JK_DB_PORTA'] ?? '') ?? 3306;
  static const _nomeDoBanco = 'jk_vendas_porcoes';

  MySQLConnection? _conexao;

  Future<void> conectar(String usuario, String senha) async {
    final conexao = await MySQLConnection.createConnection(
      host: _host,
      port: _porta,
      userName: usuario,
      password: senha,
      databaseName: _nomeDoBanco,
    );
    await conexao.connect();
    _conexao = conexao;
  }

  Future<void> fechar() async {
    await _conexao?.close();
    _conexao = null;
  }

  MySQLConnection get _db {
    final conexao = _conexao;
    if (conexao == null || !conexao.connected) {
      throw StateError('O programa não está conectado ao banco.');
    }
    return conexao;
  }

  Future<List<TamanhoMarmita>> tamanhosDeMarmita() async {
    final resultado = await _db.execute(
      // Só P, M e G têm preço; PFE, PFF e B usam o preço do próprio item.
      'SELECT sigla, nome, preco FROM tamanho_marmita WHERE preco IS NOT NULL ORDER BY preco',
    );
    final tamanhos = <TamanhoMarmita>[];
    for (final linha in resultado.rows) {
      tamanhos.add(TamanhoMarmita(
        linha.colByName('sigla')!,
        linha.colByName('nome')!,
        _centavos(linha.colByName('preco')!),
      ));
    }
    return tamanhos;
  }

  /// Todos os itens cadastrados (pratos do dia, fitness, executivos e
  /// bebidas), na ordem do tipo e do número.
  Future<List<ItemVendavel>> todosOsItens() async {
    final resultado = await _db.execute(
      'SELECT id_item, nome, tipo, categoria, preco, confirmar '
      'FROM item ORDER BY tipo, id_item',
    );
    return [for (final linha in resultado.rows) _criarItem(linha)];
  }

  Future<List<ItemVendavel>> itensDoTipo(String tipo) async {
    final resultado = await _db.execute(
      'SELECT id_item, nome, tipo, categoria, preco, confirmar '
      'FROM item WHERE tipo = :tipo ORDER BY id_item',
      {'tipo': tipo},
    );
    final itens = <ItemVendavel>[];
    for (final linha in resultado.rows) {
      itens.add(_criarItem(linha));
    }
    return itens;
  }

  Future<List<PratoDia>> pratosDoDiaCadastrados() async {
    final resultado = await _db.execute(
      "SELECT id_item, nome, categoria FROM item WHERE tipo = 'PRATO_DIA' ORDER BY nome",
    );
    return _lerPratos(resultado);
  }

  Future<List<PratoDia>> pratosDoCardapio(DateTime data) async {
    final resultado = await _db.execute(
      'SELECT i.id_item, i.nome, i.categoria '
      'FROM cardapio_dia_item c JOIN item i ON i.id_item = c.id_item '
      'WHERE c.data = :data ORDER BY i.nome',
      {'data': dataMysql(data)},
    );
    return _lerPratos(resultado);
  }

  /// Todas as linhas vendidas numa data. O nome vem da visão vw_ditem, que
  /// já diferencia o frango do dia do frango fitness.
  Future<List<VendaRegistrada>> vendasDoDia(DateTime data) async {
    return _lerVendas(
        'WHERE DATE(p.data_hora) = :data ', {'data': dataMysql(data)});
  }

  /// Todas as linhas vendidas, de todos os dias: a mesma lista que o
  /// dashboard do Power BI usa (visão vw_fvendas).
  Future<List<VendaRegistrada>> todasAsVendas() async {
    return _lerVendas('', {});
  }

  /// Lê as linhas vendidas. [filtro] é o WHERE (vazio = todas as vendas).
  Future<List<VendaRegistrada>> _lerVendas(
      String filtro, Map<String, dynamic> parametros) async {
    final resultado = await _db.execute(
      'SELECT p.id_pedido, p.forma_pagamento, p.local_pedido, d.item, pit.tamanho, '
      '       pit.quantidade, pit.preco_unitario '
      'FROM pedido p '
      'JOIN pedido_item pit ON pit.id_pedido = p.id_pedido '
      'JOIN vw_ditem d ON d.id_item = pit.id_item '
      '$filtro'
      'ORDER BY p.id_pedido, pit.id_pedido_item',
      parametros,
    );
    final vendas = <VendaRegistrada>[];
    for (final linha in resultado.rows) {
      vendas.add(VendaRegistrada(
        int.parse(linha.colByName('id_pedido')!),
        linha.colByName('forma_pagamento')!,
        linha.colByName('local_pedido')!,
        linha.colByName('item')!,
        linha.colByName('tamanho'),
        int.parse(linha.colByName('quantidade')!),
        _centavos(linha.colByName('preco_unitario')!),
      ));
    }
    return vendas;
  }

  /// Todas as porções cadastradas (arroz, feijão, acompanhamentos e misturas).
  Future<List<Porcao>> porcoesCadastradas() async {
    final resultado = await _db.execute(
      'SELECT id_porcao, nome, tipo, reaproveitavel, validade_dias FROM porcao ORDER BY tipo, nome',
    );
    final porcoes = <Porcao>[];
    for (final linha in resultado.rows) {
      porcoes.add(_criarPorcao(linha));
    }
    return porcoes;
  }

  /// As porções de uma data (arroz, feijão, acompanhamentos e misturas) com o
  /// que já foi registrado.
  Future<List<PorcaoDia>> porcoesDoDia(DateTime data) async {
    final resultado = await _db.execute(
      'SELECT p.id_porcao, p.nome, p.tipo, p.reaproveitavel, p.validade_dias, '
      '       pd.kg_preparado, pd.kg_reaproveitado, pd.kg_sobra '
      'FROM porcao_dia pd JOIN porcao p ON p.id_porcao = pd.id_porcao '
      'WHERE pd.data = :data '
      'ORDER BY p.tipo, p.nome',
      {'data': dataMysql(data)},
    );
    final porcoes = <PorcaoDia>[];
    for (final linha in resultado.rows) {
      final preparado = linha.colByName('kg_preparado');
      final sobra = linha.colByName('kg_sobra');
      porcoes.add(PorcaoDia(
        data,
        _criarPorcao(linha),
        preparado == null ? null : _gramas(preparado),
        _gramas(linha.colByName('kg_reaproveitado')!),
        sobra == null ? null : _gramas(sobra),
      ));
    }
    return porcoes;
  }

  /// As sobras guardadas de uma porção que ainda podem ser usadas no dia
  /// (feitas antes do dia, dentro da validade e com saldo), da mais antiga para a mais nova.
  Future<List<SobraGuardada>> sobrasValidas(int idPorcao, DateTime dia) async {
    final resultado = await _db.execute(
      'SELECT id_sobra, id_porcao, data_preparo, validade, kg_guardado, kg_usado '
      'FROM sobra_guardada '
      'WHERE id_porcao = :porcao AND data_preparo < :dia AND validade >= :dia '
      '  AND kg_usado < kg_guardado '
      'ORDER BY data_preparo',
      {'porcao': idPorcao, 'dia': dataMysql(dia)},
    );
    final sobras = <SobraGuardada>[];
    for (final linha in resultado.rows) {
      sobras.add(SobraGuardada(
        int.parse(linha.colByName('id_sobra')!),
        int.parse(linha.colByName('id_porcao')!),
        DateTime.parse(linha.colByName('data_preparo')!),
        DateTime.parse(linha.colByName('validade')!),
        _gramas(linha.colByName('kg_guardado')!),
        _gramas(linha.colByName('kg_usado')!),
      ));
    }
    return sobras;
  }

  // ---------------------------------------------------------------- gravação

  /// Cria o cardápio de uma data: os pratos do dia vendidos e as porções que a
  /// cozinha vai preparar (arroz, feijão, os acompanhamentos escolhidos e a
  /// mistura de cada prato). Usa uma transação: ou grava tudo, ou nada.
  Future<void> criarCardapio(DateTime data, List<PratoDia> pratos,
      List<Porcao> acompanhamentos) async {
    if (pratos.isEmpty) {
      throw ArgumentError('Escolha pelo menos um prato para o cardápio.');
    }
    await _db.transactional((conexao) async {
      final dia = dataMysql(data);
      await conexao.execute(
        'INSERT INTO cardapio_dia (data, observacao) VALUES (:data, :observacao)',
        {'data': dia, 'observacao': 'Cadastrado pelo programa JK Vendas'},
      );
      for (final prato in pratos) {
        await conexao.execute(
          'INSERT INTO cardapio_dia_item (data, id_item) VALUES (:data, :item)',
          {'data': dia, 'item': prato.id},
        );
        // A mistura do prato (a carne, o frango...) também é uma porção do dia.
        await conexao.execute(
          'INSERT INTO porcao_dia (data, id_porcao) '
          'SELECT :data, id_porcao FROM porcao WHERE id_item = :item',
          {'data': dia, 'item': prato.id},
        );
      }
      // Arroz e feijão vão todo dia.
      await conexao.execute(
        "INSERT INTO porcao_dia (data, id_porcao) SELECT :data, id_porcao FROM porcao WHERE tipo = 'BASE'",
        {'data': dia},
      );
      for (final acompanhamento in acompanhamentos) {
        await conexao.execute(
          'INSERT INTO porcao_dia (data, id_porcao) VALUES (:data, :porcao)',
          {'data': dia, 'porcao': acompanhamento.id},
        );
      }
    });
  }

  /// Grava o pedido e os seus itens numa transação e devolve o número do pedido.
  /// A data e a hora são as do servidor MySQL (valor padrão da coluna).
  Future<int> gravarPedido(Pedido pedido) async {
    pedido.validarParaGravar();
    return _db.transactional((conexao) async {
      final resultado = await conexao.execute(
        'INSERT INTO pedido (forma_pagamento, local_pedido) VALUES (:pagamento, :local)',
        {'pagamento': pedido.formaPagamento, 'local': pedido.local},
      );
      final idPedido = resultado.lastInsertID.toInt();
      for (final linha in pedido.itens) {
        await conexao.execute(
          'INSERT INTO pedido_item (id_pedido, id_item, tamanho, quantidade, preco_unitario) '
          'VALUES (:pedido, :item, :tamanho, :quantidade, :preco)',
          {
            'pedido': idPedido,
            'item': linha.item.id,
            'tamanho': linha.sigla, // P/M/G, PFE, PFF ou B
            'quantidade': linha.quantidade,
            'preco': linha.precoUnitarioCentavos / 100, // centavos -> reais
          },
        );
      }
      return idPedido;
    });
  }

  /// Cadastra um item novo e devolve o número que o banco gerou.
  /// O item chega já criado pela classe certa (PratoDia, PratoFitness...),
  /// então o construtor já recusou nome vazio e preço errado.
  Future<int> adicionarItem(ItemVendavel item, bool precoAConfirmar) async {
    // Prato do dia não tem preço: vale o do tamanho da marmita.
    final preco = item is ItemPrecoFixo ? item.precoCentavos / 100 : null;
    return _db.transactional((conexao) async {
      final resultado = await conexao.execute(
        'INSERT INTO item (nome, tipo, categoria, preco, confirmar) '
        'VALUES (:nome, :tipo, :categoria, :preco, :confirmar)',
        {
          'nome': item.nome,
          'tipo': item.tipo,
          'categoria': item.categoria,
          'preco': preco,
          'confirmar': precoAConfirmar ? 1 : 0,
        },
      );
      final id = resultado.lastInsertID.toInt();
      // Prato do dia novo: a cozinha prepara a mistura dele em quilos.
      if (item is PratoDia) {
        await conexao.execute(
          "INSERT INTO porcao (nome, tipo, id_item) VALUES (:nome, 'MISTURA', :item)",
          {'nome': item.nome, 'item': id},
        );
      }
      return id;
    });
  }

  /// Cadastra um acompanhamento novo (só porção: ele não é vendido sozinho).
  Future<int> adicionarAcompanhamento(String nome) async {
    final porcao =
        Porcao(0, nome, 'ACOMPANHAMENTO', false, 0); // a classe confere o nome
    final resultado = await _db.execute(
      "INSERT INTO porcao (nome, tipo) VALUES (:nome, 'ACOMPANHAMENTO')",
      {'nome': porcao.nome.trim()},
    );
    return resultado.lastInsertID.toInt();
  }

  /// Grava uma porção do dia numa transação:
  /// 1. os pesos na porcao_dia (o gatilho guarda o histórico);
  /// 2. o que foi tirado de cada sobra guardada (reaproveitamento);
  /// 3. a etiqueta da sobra de hoje, se for arroz ou feijão (a validade é do gatilho).
  Future<void> salvarPorcao(
      PorcaoDia porcao, Map<SobraGuardada, int> usoDasSobras) async {
    final sobra = porcao.sobra;
    if (sobra == null) {
      throw StateError('Registre a porção antes de gravar.');
    }
    await _db.transactional((conexao) async {
      final dia = dataMysql(porcao.data);
      final resultado = await conexao.execute(
        'UPDATE porcao_dia SET kg_preparado = :preparado, kg_reaproveitado = :reaproveitado, '
        '       kg_sobra = :sobra '
        'WHERE data = :data AND id_porcao = :porcao AND kg_sobra IS NULL',
        {
          'preparado': porcao.preparado! / 1000,
          'reaproveitado': porcao.reaproveitado / 1000,
          'sobra': sobra / 1000,
          'data': dia,
          'porcao': porcao.porcao.id,
        },
      );
      if (resultado.affectedRows.toInt() == 0) {
        throw StateError(
            '${porcao.porcao.nome} já tinha sido registrada nesse dia.');
      }
      for (final entrada in usoDasSobras.entries) {
        await conexao.execute(
          'UPDATE sobra_guardada SET kg_usado = kg_usado + :kg WHERE id_sobra = :sobra',
          {'kg': entrada.value / 1000, 'sobra': entrada.key.id},
        );
      }
      if (porcao.porcao.reaproveitavel && sobra > 0) {
        await conexao.execute(
          'INSERT INTO sobra_guardada (id_porcao, data_preparo, kg_guardado) '
          'VALUES (:porcao, :data, :kg)',
          {'porcao': porcao.porcao.id, 'data': dia, 'kg': sobra / 1000},
        );
      }
    });
  }

  // ------------------------------------------------------------------- apoio

  /// O banco guarda o preço em reais ("22.00"); o programa faz as contas em
  /// centavos (2200), que é número inteiro e não tem erro de arredondamento.
  int _centavos(String reais) => (double.parse(reais) * 100).round();

  /// O banco guarda o peso em quilos ("5.250"); o programa usa gramas (5250).
  int _gramas(String kg) => (double.parse(kg) * 1000).round();

  Porcao _criarPorcao(ResultSetRow linha) {
    final dias = linha.colByName('validade_dias') ?? '0';
    return Porcao(
      int.parse(linha.colByName('id_porcao')!),
      linha.colByName('nome')!,
      linha.colByName('tipo')!,
      linha.colByName('reaproveitavel') == '1',
      int.parse(dias),
    );
  }

  List<PratoDia> _lerPratos(IResultSet resultado) {
    final pratos = <PratoDia>[];
    for (final linha in resultado.rows) {
      pratos.add(PratoDia(
        int.parse(linha.colByName('id_item')!),
        linha.colByName('nome')!,
        linha.colByName('categoria')!,
      ));
    }
    return pratos;
  }

  /// Transforma uma linha da tabela item no objeto da classe certa.
  /// Refatorado: a linha vira um Map e quem escolhe a classe é o
  /// ItemVendavel.fromMap (o mesmo usado para ler JSON), sem switch repetido.
  ItemVendavel _criarItem(ResultSetRow linha) {
    final precoTexto = linha.colByName('preco');
    return ItemVendavel.fromMap({
      'id': int.parse(linha.colByName('id_item')!),
      'nome': linha.colByName('nome')!,
      'categoria': linha.colByName('categoria')!,
      'tipo': linha.colByName('tipo'),
      'precoCentavos': precoTexto == null ? 0 : _centavos(precoTexto),
      'precoAConfirmar': linha.colByName('confirmar') == '1',
    });
  }
}
