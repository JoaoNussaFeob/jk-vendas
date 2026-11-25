import 'package:flutter/material.dart';
import 'package:jk_vendas/formato.dart';
import 'package:jk_vendas/item_vendavel.dart';
import 'package:jk_vendas/resumo_vendas.dart';
import 'package:jk_vendas/porcao.dart';
import 'package:jk_vendas/porcao_dia.dart';
import 'package:jk_vendas/sobra_guardada.dart';

import 'comum.dart';

// =============================================================================
// ÁREA DA DONA: o menu com as quatro tarefas. Só entra quem sabe a senha.
// =============================================================================
class AreaDaDona extends StatelessWidget {
  const AreaDaDona({super.key});

  @override
  Widget build(BuildContext context) {
    final opcoes = [
      (Icons.menu_book, 'Montar o cardápio do dia', const TelaMontarCardapio()),
      (Icons.scale, 'Porções do dia (kg)', const TelaPorcoes()),
      (Icons.bar_chart, 'Ver as vendas do dia', const TelaVendas()),
      (Icons.add_circle_outline, 'Adicionar item', const TelaAdicionarItem()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Área da dona')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (icone, texto, tela) in opcoes)
            Card(
              child: ListTile(
                leading: Icon(icone, color: marromJK, size: 32),
                title: Text(texto, style: const TextStyle(fontSize: 18)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => tela)),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// 1. MONTAR O CARDÁPIO DO DIA: escolhe os pratos do dia de uma data.
// =============================================================================
class TelaMontarCardapio extends StatefulWidget {
  const TelaMontarCardapio({super.key});

  @override
  State<TelaMontarCardapio> createState() => _TelaMontarCardapioState();
}

class _TelaMontarCardapioState extends State<TelaMontarCardapio> {
  DateTime _data = DateTime.now();
  List<PratoDia> _todos = []; // todos os pratos do dia cadastrados
  List<PratoDia> _jaNoCardapio = []; // o cardápio que a data já tem
  final Set<int> _escolhidos = {}; // Set: o mesmo prato não entra duas vezes
  List<Porcao> _acompanhamentos = []; // acompanhamentos cadastrados
  final Set<int> _acompEscolhidos = {};
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      _todos = await banco.pratosDoDiaCadastrados();
      _jaNoCardapio = await banco.pratosDoCardapio(_data);
      _acompanhamentos = [
        for (final p in await banco.porcoesCadastradas())
          if (p.tipo == 'ACOMPANHAMENTO') p,
      ];
      _escolhidos.clear();
      _acompEscolhidos.clear();
    } catch (e) {
      if (mounted) avisar(context, textoDoErro(e), erro: true);
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _salvar() async {
    final pratos = [
      for (final p in _todos)
        if (_escolhidos.contains(p.id)) p,
    ];
    final acompanhamentos = [
      for (final a in _acompanhamentos)
        if (_acompEscolhidos.contains(a.id)) a,
    ];
    try {
      await banco.criarCardapio(_data, pratos, acompanhamentos); // transação: tudo ou nada
      if (!mounted) return;
      avisar(context, 'Cardápio de ${dataBr(_data)} salvo com ${pratos.length} prato(s).');
      await _carregar();
    } catch (e) {
      if (mounted) avisar(context, textoDoErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Montar o cardápio do dia')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('Data: ', style: TextStyle(fontSize: 16)),
                      SeletorDeData(
                        data: _data,
                        aoMudar: (d) {
                          _data = d;
                          _carregar();
                        },
                      ),
                    ],
                  ),
                ),
                // Se a data já tem cardápio, só mostra (o banco não deixa repetir a data).
                if (_jaNoCardapio.isNotEmpty) ...[
                  Titulo('${dataBr(_data)} já tem cardápio'),
                  for (final prato in _jaNoCardapio)
                    ListTile(
                      leading: const Icon(Icons.check, color: Colors.green),
                      title: Text(prato.nome),
                    ),
                ] else ...[
                  const Titulo('Marque os pratos do dia'),
                  for (final prato in _todos)
                    CheckboxListTile(
                      title: Text(prato.nome),
                      subtitle: Text(prato.categoria),
                      value: _escolhidos.contains(prato.id),
                      onChanged: (marcado) => setState(() {
                        if (marcado == true) {
                          _escolhidos.add(prato.id);
                        } else {
                          _escolhidos.remove(prato.id);
                        }
                      }),
                    ),
                  const Titulo('Acompanhamentos (arroz e feijão já entram todo dia)'),
                  for (final acomp in _acompanhamentos)
                    CheckboxListTile(
                      title: Text(acomp.nome),
                      value: _acompEscolhidos.contains(acomp.id),
                      onChanged: (marcado) => setState(() {
                        if (marcado == true) {
                          _acompEscolhidos.add(acomp.id);
                        } else {
                          _acompEscolhidos.remove(acomp.id);
                        }
                      }),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: Text('Salvar cardápio (${_escolhidos.length} prato(s))'),
                      onPressed: _escolhidos.isEmpty ? null : _salvar,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

// =============================================================================
// 2. PORÇÕES DO DIA (KG): para cada porção, quanto foi feito, quanto foi usado de
// sobra guardada (só arroz e feijão) e quanto sobrou. A classe PorcaoDia confere
// os números e decide o alerta; a SobraGuardada escolhe a sobra mais antiga (ODS 12).
// =============================================================================
class TelaPorcoes extends StatefulWidget {
  const TelaPorcoes({super.key});

  @override
  State<TelaPorcoes> createState() => _TelaPorcoesState();
}

class _TelaPorcoesState extends State<TelaPorcoes> {
  DateTime _data = DateTime.now();
  List<PorcaoDia> _porcoes = [];
  // Sobras guardadas que valem nesse dia, por porção (só arroz e feijão).
  final Map<int, List<SobraGuardada>> _sobras = {};
  // Três campos por porção: preparado, reaproveitado e sobra (em kg).
  final Map<int, TextEditingController> _preparado = {};
  final Map<int, TextEditingController> _reaproveitado = {};
  final Map<int, TextEditingController> _sobrou = {};
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      _porcoes = await banco.porcoesDoDia(_data);
      _sobras.clear();
      for (final p in _porcoes) {
        final id = p.porcao.id;
        _preparado[id] = TextEditingController();
        _reaproveitado[id] = TextEditingController();
        _sobrou[id] = TextEditingController();
        if (p.porcao.reaproveitavel && !p.registrada) {
          _sobras[id] = await banco.sobrasValidas(id, _data);
        }
      }
    } catch (e) {
      if (mounted) avisar(context, textoDoErro(e), erro: true);
    }
    if (mounted) setState(() => _carregando = false);
  }

  int _disponivel(int idPorcao) {
    var total = 0;
    for (final s in _sobras[idPorcao] ?? <SobraGuardada>[]) {
      total += s.saldo;
    }
    return total;
  }

  Future<void> _salvar(PorcaoDia p) async {
    final id = p.porcao.id;
    final preparado = gramasDoTexto(_preparado[id]!.text);
    final textoReap = _reaproveitado[id]!.text.trim();
    final reaproveitado = textoReap.isEmpty ? 0 : gramasDoTexto(textoReap);
    final sobra = gramasDoTexto(_sobrou[id]!.text);
    if (preparado == null || reaproveitado == null || sobra == null) {
      avisar(context, 'Digite os quilos com números, por exemplo 5,25.', erro: true);
      return;
    }
    try {
      // A classe recusa números errados; a sobra mais antiga é usada primeiro.
      final uso = SobraGuardada.planejarUso(_sobras[id] ?? [], _data, reaproveitado);
      p.registrar(preparado, reaproveitado, sobra, disponivel: _disponivel(id));
      await banco.salvarPorcao(p, uso); // transação; o gatilho guarda o histórico
      if (!mounted) return;
      setState(() {});
      avisar(context, '${p.porcao.nome}: ${p.alerta}');
    } catch (e) {
      if (mounted) avisar(context, textoDoErro(e), erro: true);
      await _carregar(); // relê do banco para a tela não ficar diferente dele
    }
  }

  @override
  Widget build(BuildContext context) {
    var total = 0;
    var lixo = 0;
    for (final p in _porcoes) {
      if (p.registrada) {
        total += p.preparado! + p.reaproveitado;
        lixo += p.desperdicioDoDia;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Porções do dia (kg)')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Text('Data: ', style: TextStyle(fontSize: 16)),
                    SeletorDeData(
                      data: _data,
                      aoMudar: (d) {
                        _data = d;
                        _carregar();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Só arroz e feijão podem ser reaproveitados: até ${Porcao.validadeMaximaDias} dias '
                  'na geladeira a 4 °C ou menos (ANVISA, RDC 216/2004).',
                ),
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Foram para o lixo hoje: ${quilos(lixo)} de ${quilos(total)} '
                      '(${percentual(lixo * 100 / total)}).',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: marromJK),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_porcoes.isEmpty) const Text('Essa data não tem cardápio do dia.'),
                for (final p in _porcoes) _cartaoDaPorcao(p),
              ],
            ),
    );
  }

  Widget _campo(TextEditingController? controle, String rotulo) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: controle,
        decoration: InputDecoration(labelText: rotulo, suffixText: 'kg'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }

  Widget _cartaoDaPorcao(PorcaoDia p) {
    final id = p.porcao.id;
    // A cor do alerta segue a decisão da classe: vermelho quando sobrou demais e vai para o lixo.
    final vermelho =
        p.registrada && !p.porcao.reaproveitavel && p.percentualSobra > PorcaoDia.limiteSobraAlta;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${p.porcao.nome} · ${p.porcao.tipoTexto}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            if (p.registrada) ...[
              Text(
                'Preparado ${quilos(p.preparado!)} · reaproveitado ${quilos(p.reaproveitado)} · '
                'sobrou ${quilos(p.sobra!)}',
              ),
              const SizedBox(height: 4),
              Text(
                p.alerta,
                style: TextStyle(
                  color: vermelho ? Colors.red : Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              for (final s in _sobras[id] ?? <SobraGuardada>[])
                Text(
                  'Na geladeira: ${quilos(s.saldo)} de ${dataBr(s.dataPreparo)}, '
                  'vale até ${dataBr(s.validade)}',
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  _campo(_preparado[id], 'Preparado'),
                  if (p.porcao.reaproveitavel && _disponivel(id) > 0)
                    _campo(_reaproveitado[id], 'Reaproveitado'),
                  _campo(_sobrou[id], 'Sobrou'),
                  FilledButton(onPressed: () => _salvar(p), child: const Text('Salvar')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3. VER AS VENDAS DO DIA: as contas são feitas pela classe ResumoVendas.
// =============================================================================
class TelaVendas extends StatefulWidget {
  const TelaVendas({super.key});

  @override
  State<TelaVendas> createState() => _TelaVendasState();
}

class _TelaVendasState extends State<TelaVendas> {
  DateTime _data = DateTime.now();
  List<VendaRegistrada> _vendas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      _vendas = await banco.vendasDoDia(_data);
    } catch (e) {
      if (mounted) avisar(context, textoDoErro(e), erro: true);
    }
    if (mounted) setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    final resumo = ResumoVendas(_vendas);
    return Scaffold(
      appBar: AppBar(title: const Text('Vendas do dia')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Text('Data: ', style: TextStyle(fontSize: 16)),
                    SeletorDeData(
                      data: _data,
                      aoMudar: (d) {
                        _data = d;
                        _carregar();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (resumo.vazio)
                  const Text('Nenhuma venda nessa data.')
                else ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _numero('Pedidos', '${resumo.totalPedidos}'),
                      _numero('Receita', reais(resumo.receitaCentavos)),
                      _numero('Ticket médio', reais(resumo.ticketMedioCentavos)),
                      _numero('Mais vendido', resumo.itemMaisVendido),
                    ],
                  ),
                  const Titulo('Por forma de pagamento'),
                  for (final forma in resumo.receitaPorPagamento.keys)
                    ListTile(
                      dense: true,
                      title: Text(forma),
                      trailing: Text(reais(resumo.receitaPorPagamento[forma]!)),
                    ),
                  const Titulo('Pedidos por local'),
                  for (final local in resumo.pedidosPorLocal.keys)
                    ListTile(
                      dense: true,
                      title: Text(local),
                      trailing: Text('${resumo.pedidosPorLocal[local]}'),
                    ),
                  const Titulo('Marmitas por tamanho'),
                  for (final tamanho in resumo.marmitasPorTamanho.keys)
                    ListTile(
                      dense: true,
                      title: Text(tamanho),
                      trailing: Text('${resumo.marmitasPorTamanho[tamanho]}'),
                    ),
                  const Titulo('Itens vendidos'),
                  for (final v in _vendas)
                    ListTile(
                      dense: true,
                      leading: Text('nº ${v.idPedido}'),
                      title: Text('${v.quantidade}x ${v.item}'),
                      subtitle: Text('${v.tamanho} · ${v.local} · ${v.formaPagamento}'),
                      trailing: Text(reais(v.totalCentavos)),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _numero(String rotulo, String valor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo),
            Text(
              valor,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: marromJK),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 4. ADICIONAR ITEM: cria o objeto da classe certa (polimorfismo) e grava.
// =============================================================================
class TelaAdicionarItem extends StatefulWidget {
  const TelaAdicionarItem({super.key});

  @override
  State<TelaAdicionarItem> createState() => _TelaAdicionarItemState();
}

class _TelaAdicionarItemState extends State<TelaAdicionarItem> {
  static const _tipos = {
    'PRATO_DIA': 'Prato do dia',
    'EXECUTIVO': 'Executivo',
    'FITNESS': 'Fitness',
    'BEBIDA': 'Bebida',
    'ACOMPANHAMENTO': 'Acompanhamento (porção da cozinha)',
  };

  final _nome = TextEditingController();
  final _preco = TextEditingController();
  String _tipo = 'PRATO_DIA';
  String _categoria = ItemVendavel.categoriasDePrato.first;
  bool _aConfirmar = false;

  List<String> get _categorias =>
      _tipo == 'BEBIDA' ? ItemVendavel.categoriasDeBebida : ItemVendavel.categoriasDePrato;

  // "29,90" vira 2990 centavos. Texto que não é número vira 0 (a classe recusa).
  int _centavos(String texto) {
    final valor = double.tryParse(texto.replaceAll(',', '.')) ?? 0;
    return (valor * 100).round();
  }

  // Cada tipo vira um objeto de uma classe diferente. O id é 0 porque quem
  // gera o número é o banco (AUTO_INCREMENT).
  ItemVendavel _criarItem() {
    final nome = _nome.text.trim();
    final preco = _centavos(_preco.text);
    switch (_tipo) {
      case 'EXECUTIVO':
        return PratoExecutivo(0, nome, _categoria, preco, _aConfirmar);
      case 'FITNESS':
        return PratoFitness(0, nome, _categoria, preco, _aConfirmar);
      case 'BEBIDA':
        return Bebida(0, nome, _categoria, preco, _aConfirmar);
      default:
        return PratoDia(0, nome, _categoria);
    }
  }

  Future<void> _salvar() async {
    try {
      // Acompanhamento não é vendido sozinho: vira só uma porção (em kg).
      if (_tipo == 'ACOMPANHAMENTO') {
        final numero = await banco.adicionarAcompanhamento(_nome.text);
        if (!mounted) return;
        avisar(context, '${_nome.text.trim()} cadastrado como porção número $numero.');
        _nome.clear();
        return;
      }
      final item = _criarItem(); // o construtor recusa nome vazio e preço zero
      final numero = await banco.adicionarItem(item, _aConfirmar);
      if (!mounted) return;
      avisar(context, '${item.nome} cadastrado com o número $numero.');
      _nome.clear();
      _preco.clear();
    } catch (e) {
      if (mounted) avisar(context, textoDoErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar item')),
      body: Center(
        child: SizedBox(
          width: 420,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _nome,
                decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                items: [
                  for (final tipo in _tipos.keys)
                    DropdownMenuItem(value: tipo, child: Text(_tipos[tipo]!)),
                ],
                onChanged: (valor) => setState(() {
                  _tipo = valor!;
                  _categoria = _categorias.first; // bebida e prato têm categorias diferentes
                }),
              ),
              const SizedBox(height: 12),
              if (_tipo == 'ACOMPANHAMENTO')
                const Text(
                  'Acompanhamento não tem preço nem categoria: ele vai junto com a marmita '
                  'e é controlado em quilos nas porções do dia. Não pode ser reaproveitado.',
                )
              else ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(_tipo), // recria a lista quando o tipo muda
                  initialValue: _categoria,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    border: OutlineInputBorder(),
                  ),
                  items: [for (final c in _categorias) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (valor) => setState(() => _categoria = valor!),
                ),
                const SizedBox(height: 12),
                // Prato do dia não tem preço: vale o do tamanho da marmita.
                if (_tipo == 'PRATO_DIA')
                  const Text('Prato do dia não tem preço próprio: vale o da marmita (P, M ou G).')
                else ...[
                  TextField(
                    controller: _preco,
                    decoration: const InputDecoration(
                      labelText: 'Preço (ex.: 29,90)',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  CheckboxListTile(
                    title: const Text('Preço de teste (confirmar com o restaurante)'),
                    value: _aConfirmar,
                    onChanged: (v) => setState(() => _aConfirmar = v!),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Cadastrar item'),
                onPressed: _salvar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
