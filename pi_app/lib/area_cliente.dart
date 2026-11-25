import 'package:flutter/material.dart';
import 'package:jk_vendas/formato.dart';
import 'package:jk_vendas/item_pedido.dart';
import 'package:jk_vendas/item_vendavel.dart';
import 'package:jk_vendas/pedido.dart';
import 'package:jk_vendas/tamanho_marmita.dart';

import 'comum.dart';

// =============================================================================
// ÁREA DO CLIENTE: vê o cardápio de hoje, monta o carrinho e faz o pedido.
// O pedido é gravado igual ao do programa de terminal (gravarPedido).
// =============================================================================
class AreaDoCliente extends StatefulWidget {
  const AreaDoCliente({super.key});

  @override
  State<AreaDoCliente> createState() => _AreaDoClienteState();
}

class _AreaDoClienteState extends State<AreaDoCliente> {
  bool _carregando = true;
  List<TamanhoMarmita> _tamanhos = [];
  List<PratoDia> _pratosDeHoje = [];
  List<ItemVendavel> _executivos = [];
  List<ItemVendavel> _fitness = [];
  List<ItemVendavel> _bebidas = [];

  // O carrinho: as linhas que vão virar o pedido.
  final List<ItemPedido> _carrinho = [];
  String _local = Pedido.locais.first;
  String _pagamento = 'Pix';
  bool _gravando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  // Lê do banco tudo o que aparece no cardápio.
  Future<void> _carregar() async {
    try {
      _tamanhos = await banco.tamanhosDeMarmita();
      _pratosDeHoje = await banco.pratosDoCardapio(DateTime.now());
      _executivos = await banco.itensDoTipo('EXECUTIVO');
      _fitness = await banco.itensDoTipo('FITNESS');
      _bebidas = await banco.itensDoTipo('BEBIDA');
    } catch (e) {
      if (mounted) avisar(context, textoDoErro(e), erro: true);
    }
    if (mounted) setState(() => _carregando = false);
  }

  int get _totalCentavos {
    var total = 0;
    for (final linha in _carrinho) {
      total += linha.totalCentavos;
    }
    return total;
  }

  // Abre a janela para escolher o tamanho (só marmita) e a quantidade.
  Future<void> _adicionar(ItemVendavel item) async {
    TamanhoMarmita? tamanho = item.precisaDeTamanho ? _tamanhos[1] : null; // começa no M
    var quantidade = 1;

    final linha = await showDialog<ItemPedido>(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, atualizar) => AlertDialog(
          title: Text(item.descricao),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.precisaDeTamanho) ...[
                const Text('Tamanho da marmita'),
                const SizedBox(height: 8),
                SegmentedButton<TamanhoMarmita>(
                  segments: [
                    for (final t in _tamanhos)
                      ButtonSegment(
                        value: t,
                        label: Text('${t.sigla} · ${reais(t.precoCentavos)}'),
                      ),
                  ],
                  selected: {tamanho!},
                  onSelectionChanged: (escolha) => atualizar(() => tamanho = escolha.first),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: quantidade > 1 ? () => atualizar(() => quantidade--) : null,
                  ),
                  Text('$quantidade', style: const TextStyle(fontSize: 22)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => atualizar(() => quantidade++),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Cancelar')),
            FilledButton(
              // O ItemPedido calcula o preço da hora (polimorfismo) e confere a quantidade.
              onPressed: () => Navigator.pop(contexto, ItemPedido(item, tamanho, quantidade)),
              child: const Text('Pôr no carrinho'),
            ),
          ],
        ),
      ),
    );
    if (linha != null) setState(() => _carrinho.add(linha));
  }

  Future<void> _fazerPedido() async {
    setState(() => _gravando = true);
    try {
      final pedido = Pedido(_local);
      for (final linha in _carrinho) {
        pedido.adicionarItem(linha);
      }
      pedido.definirPagamento(_pagamento);
      final numero = await banco.gravarPedido(pedido); // transação: tudo ou nada
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (contexto) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: Text('Pedido nº $numero feito!'),
          content: Text(
            'Total: ${reais(pedido.totalCentavos)}\n'
            '$_local · $_pagamento',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(contexto), child: const Text('OK')),
          ],
        ),
      );
      setState(() => _carrinho.clear());
    } catch (e) {
      if (mounted) avisar(context, textoDoErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _gravando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cardápio de hoje · ${dataBr(DateTime.now())}')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _cardapio()),
                const VerticalDivider(width: 1),
                SizedBox(width: 360, child: _painelDoCarrinho()),
              ],
            ),
    );
  }

  // Lado esquerdo: o cardápio dividido em partes.
  Widget _cardapio() {
    final precosMarmita = [for (final t in _tamanhos) '${t.sigla} ${reais(t.precoCentavos)}']
        .join(' · ');
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Titulo('Prato do dia (marmita)'),
        if (_pratosDeHoje.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Hoje ainda não tem prato do dia: a dona precisa montar o cardápio.'),
          ),
        for (final prato in _pratosDeHoje) _linhaDoCardapio(prato, precosMarmita),
        const Titulo('Executivos (PFE)'),
        for (final item in _executivos) _linhaDoCardapio(item, reais(item.calcularPreco(null))),
        const Titulo('Fitness (PFF)'),
        for (final item in _fitness) _linhaDoCardapio(item, reais(item.calcularPreco(null))),
        const Titulo('Bebidas (B)'),
        for (final item in _bebidas) _linhaDoCardapio(item, reais(item.calcularPreco(null))),
      ],
    );
  }

  Widget _linhaDoCardapio(ItemVendavel item, String preco) {
    return ListTile(
      title: Text(item.descricao),
      subtitle: Text(preco),
      trailing: IconButton.filledTonal(
        icon: const Icon(Icons.add_shopping_cart),
        onPressed: () => _adicionar(item),
      ),
    );
  }

  // Lado direito: o carrinho, o local, o pagamento e o botão de fazer o pedido.
  Widget _painelDoCarrinho() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Titulo('Carrinho'),
        Expanded(
          child: _carrinho.isEmpty
              ? const Center(child: Text('Escolha os itens no cardápio.'))
              : ListView(
                  children: [
                    for (var i = 0; i < _carrinho.length; i++)
                      ListTile(
                        dense: true,
                        title: Text(_carrinho[i].descricao),
                        subtitle: Text(reais(_carrinho[i].totalCentavos)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => _carrinho.removeAt(i)),
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _local,
                decoration: const InputDecoration(labelText: 'Local', border: OutlineInputBorder()),
                items: [for (final l in Pedido.locais) DropdownMenuItem(value: l, child: Text(l))],
                onChanged: (valor) => setState(() => _local = valor!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _pagamento,
                decoration: const InputDecoration(
                  labelText: 'Pagamento',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final p in Pedido.formasDePagamento)
                    DropdownMenuItem(value: p, child: Text(p)),
                ],
                onChanged: (valor) => setState(() => _pagamento = valor!),
              ),
              const SizedBox(height: 16),
              Text(
                'Total: ${reais(_totalCentavos)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: Text(_gravando ? 'Gravando...' : 'Fazer pedido'),
                style: FilledButton.styleFrom(
                  backgroundColor: marromJK,
                  padding: const EdgeInsets.all(18),
                ),
                onPressed: _carrinho.isEmpty || _gravando ? null : _fazerPedido,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
