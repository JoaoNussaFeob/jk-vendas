import 'dart:io';

// Leitura do teclado. Todas as perguntas do programa passam por aqui.

/// Exceção do próprio programa: avisa que a entrada do teclado acabou
/// (por exemplo, Ctrl+D no terminal). O menu usa isso para sair com calma.
class FimDaEntrada implements Exception {}

/// Mostra a pergunta e devolve o que foi digitado, sem espaços nas pontas.
String lerTexto(String pergunta) {
  stdout.write(pergunta);
  final linha = stdin.readLineSync();
  if (linha == null) {
    throw FimDaEntrada();
  }
  return linha.trim();
}

/// Lê um número inteiro. Repete a pergunta até a pessoa digitar um número.
int lerInteiro(String pergunta) {
  while (true) {
    final numero = int.tryParse(lerTexto(pergunta));
    if (numero != null) {
      return numero;
    }
    print('Digite um número inteiro.');
  }
}

/// Mostra as opções numeradas e devolve o número escolhido.
/// O 0 é sempre a saída (voltar, fechar ou cancelar, conforme a tela).
int lerOpcao(String titulo, List<String> opcoes,
    {String opcaoZero = 'Voltar'}) {
  print(titulo);
  // Alinha os números quando a lista passa de 9 opções (" 9." e "10.").
  final largura = opcoes.length.toString().length;
  for (var i = 0; i < opcoes.length; i++) {
    print('  ${(i + 1).toString().padLeft(largura)}. ${opcoes[i]}');
  }
  print('  ${'0'.padLeft(largura)}. $opcaoZero');
  while (true) {
    final escolha = lerInteiro('Escolha: ');
    if (escolha >= 0 && escolha <= opcoes.length) {
      return escolha;
    }
    print('Escolha um número de 0 a ${opcoes.length}.');
  }
}

/// Lê uma data no formato dd/mm/aaaa. Enter sem digitar nada = hoje.
DateTime lerData(String pergunta) {
  while (true) {
    final texto = lerTexto(pergunta);
    if (texto.isEmpty) {
      final agora = DateTime.now();
      return DateTime(agora.year, agora.month, agora.day);
    }
    final partes = texto.split('/');
    if (partes.length == 3) {
      final dia = int.tryParse(partes[0]);
      final mes = int.tryParse(partes[1]);
      final ano = int.tryParse(partes[2]);
      if (dia != null && mes != null && ano != null) {
        final data = DateTime(ano, mes, dia);
        // DateTime(2026, 2, 30) vira 2 de março; por isso conferimos de volta.
        if (data.day == dia && data.month == mes && data.year == ano) {
          return data;
        }
      }
    }
    print('Data inválida. Use dd/mm/aaaa, por exemplo 26/10/2026.');
  }
}

/// Lê a senha sem mostrar o que é digitado (quando há um terminal de verdade).
String lerSenha(String pergunta) {
  stdout.write(pergunta);
  final temTerminal = stdin.hasTerminal;
  if (temTerminal) {
    stdin.echoMode = false;
  }
  final senha = stdin.readLineSync();
  if (temTerminal) {
    stdin.echoMode = true;
    stdout.writeln();
  }
  if (senha == null) {
    throw FimDaEntrada();
  }
  return senha;
}

/// Pergunta de sim ou não. Só "s" confirma.
bool confirmar(String pergunta) {
  return lerTexto('$pergunta (s/n): ').toLowerCase() == 's';
}
