import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'area_cliente.dart';
import 'area_dona.dart';
import 'comum.dart';

// Senha digitada na entrada. Fica só na memória: nunca vai para o código
// nem para um arquivo. A área da dona pede de novo e compara com ela.
String _senhaDoBanco = '';

void main() {
  runApp(const AppJK());
}

class AppJK extends StatelessWidget {
  const AppJK({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JK Vendas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: marromJK, useMaterial3: true),
      // Calendário e textos padrão em português.
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const TelaEntrada(),
    );
  }
}

// -----------------------------------------------------------------------------
// TELA 1: ENTRADA. O funcionário abre o app no caixa e digita a senha do MySQL.
// -----------------------------------------------------------------------------
class TelaEntrada extends StatefulWidget {
  const TelaEntrada({super.key});

  @override
  State<TelaEntrada> createState() => _TelaEntradaState();
}

class _TelaEntradaState extends State<TelaEntrada> {
  final _campoSenha = TextEditingController();
  String? _erro;
  bool _conectando = false;

  Future<void> _entrar() async {
    setState(() {
      _conectando = true;
      _erro = null;
    });
    try {
      await banco.conectar('root', _campoSenha.text);
      _senhaDoBanco = _campoSenha.text;
      if (!mounted) return;
      // pushReplacement: troca de tela sem deixar "voltar" para a entrada.
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TelaInicial()));
    } catch (e) {
      setState(() => _erro = 'Não conectou no MySQL. Confira a senha e se o MySQL está ligado.');
    } finally {
      if (mounted) setState(() => _conectando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restaurant, size: 64, color: marromJK),
              const SizedBox(height: 12),
              const Text(
                'JK Bar e Restaurante',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _campoSenha,
                obscureText: true, // esconde a senha com bolinhas
                decoration: const InputDecoration(
                  labelText: 'Senha do MySQL',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _entrar(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _conectando ? null : _entrar,
                  child: Text(_conectando ? 'Conectando...' : 'Entrar'),
                ),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(_erro!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TELA 2: INÍCIO. Escolhe entre a área do cliente e a área da dona.
// -----------------------------------------------------------------------------
class TelaInicial extends StatelessWidget {
  const TelaInicial({super.key});

  // A área da dona pede a senha de novo: o cliente não entra lá.
  Future<void> _abrirAreaDaDona(BuildContext context) async {
    final campo = TextEditingController();
    final liberado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Área da dona'),
        content: TextField(
          controller: campo,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Senha'),
          onSubmitted: (_) => Navigator.pop(contexto, campo.text == _senhaDoBanco),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, campo.text == _senhaDoBanco),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    if (!context.mounted || liberado == null) return;
    if (liberado) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AreaDaDona()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha errada.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JK Vendas'),
        backgroundColor: marromJK,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Wrap(
          spacing: 32,
          runSpacing: 32,
          children: [
            _BotaoGrande(
              icone: Icons.shopping_bag,
              texto: 'Sou cliente\nFazer pedido',
              aoClicar: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AreaDoCliente())),
            ),
            _BotaoGrande(
              icone: Icons.lock,
              texto: 'Área da dona\nCardápio, porções e vendas',
              aoClicar: () => _abrirAreaDaDona(context),
            ),
          ],
        ),
      ),
    );
  }
}

// Um botão grande e quadrado, usado na tela inicial.
class _BotaoGrande extends StatelessWidget {
  final IconData icone;
  final String texto;
  final VoidCallback aoClicar;

  const _BotaoGrande({required this.icone, required this.texto, required this.aoClicar});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 200,
      child: FilledButton(
        onPressed: aoClicar,
        style: FilledButton.styleFrom(
          backgroundColor: marromJK,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 56),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
