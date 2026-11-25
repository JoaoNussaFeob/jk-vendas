import 'package:flutter/material.dart';
import 'package:jk_vendas/banco_jk_vendas.dart';
import 'package:jk_vendas/formato.dart';

// O que todas as telas usam: a conexão, a cor do JK, avisos e a escolha de data.

// Uma conexão só para o app inteiro. Ela abre na tela de entrada.
final banco = BancoJkVendas();

// Cor marrom do JK (a mesma do cabeçalho da planilha).
const marromJK = Color(0xFF5C2E1E);

// Mostra um aviso rápido na parte de baixo da tela.
void avisar(BuildContext context, String texto, {bool erro = false}) {
  // Tira o aviso anterior antes, para o novo aparecer na hora.
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(texto), backgroundColor: erro ? Colors.red.shade700 : null),
  );
}

// Transforma o erro em um texto para a pessoa ler.
// ArgumentError e StateError são os erros que as nossas classes lançam.
String textoDoErro(Object erro) {
  if (erro is ArgumentError) return '${erro.message}';
  if (erro is StateError) return erro.message;
  return 'Erro no banco: $erro';
}

// Botão que mostra a data escolhida e abre o calendário.
class SeletorDeData extends StatelessWidget {
  final DateTime data;
  final ValueChanged<DateTime> aoMudar;

  const SeletorDeData({super.key, required this.data, required this.aoMudar});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_month),
      label: Text(dataBr(data)),
      onPressed: () async {
        final escolhida = await showDatePicker(
          context: context,
          initialDate: data,
          firstDate: DateTime(2026),
          lastDate: DateTime(2030),
        );
        if (escolhida != null) aoMudar(escolhida);
      },
    );
  }
}

// Título de uma parte da tela.
class Titulo extends StatelessWidget {
  final String texto;

  const Titulo(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: marromJK),
      ),
    );
  }
}
