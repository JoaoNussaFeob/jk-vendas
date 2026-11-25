// Funções de apoio para mostrar dinheiro, datas e percentuais no formato do Brasil.

/// Converte centavos em reais: 1671500 vira "R$ 16.715,00".
/// O banco guarda tudo em centavos (números inteiros) para não ter erro de arredondamento.
String reais(int centavos) {
  var inteiro = (centavos ~/ 100).toString(); // ~/ é a divisão inteira
  final resto = (centavos % 100).toString().padLeft(2, '0');

  // Coloca um ponto a cada três dígitos, da direita para a esquerda.
  var milhares = '';
  while (inteiro.length > 3) {
    milhares = '.${inteiro.substring(inteiro.length - 3)}$milhares';
    inteiro = inteiro.substring(0, inteiro.length - 3);
  }
  return 'R\$ $inteiro$milhares,$resto';
}

/// Data para mostrar na tela: 26/10/2026.
String dataBr(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year}';
}

/// Data no formato que o MySQL entende: 2026-10-26.
String dataMysql(DateTime data) {
  final mes = data.month.toString().padLeft(2, '0');
  final dia = data.day.toString().padLeft(2, '0');
  return '${data.year}-$mes-$dia';
}

/// Percentual com uma casa decimal: 22.22 vira "22,2%".
String percentual(double valor) {
  return '${valor.toStringAsFixed(1).replaceAll('.', ',')}%';
}

/// Peso em gramas mostrado em quilos: 5250 vira "5,250 kg".
/// O programa guarda peso em gramas (número inteiro), pelo mesmo motivo do dinheiro em centavos.
String quilos(int gramas) {
  final inteiro = gramas ~/ 1000;
  final resto = (gramas % 1000).toString().padLeft(3, '0');
  return '$inteiro,$resto kg';
}

/// Texto digitado em quilos para gramas: "5,25" ou "5.25" vira 5250.
/// Devolve null se o texto não for um número.
int? gramasDoTexto(String texto) {
  final valor = double.tryParse(texto.trim().replaceAll(',', '.'));
  if (valor == null) {
    return null;
  }
  return (valor * 1000).round();
}
