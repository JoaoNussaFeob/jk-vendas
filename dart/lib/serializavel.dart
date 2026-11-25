import 'dart:convert';

// =============================================================================
// INTERFACE Serializavel: um "contrato". Toda classe que implementa essa
// interface promete saber se transformar em:
//   - toMap()  -> um Map (chave: valor), fácil de gravar, enviar ou testar;
//   - toJson() -> o mesmo conteúdo em texto JSON.
//
// "abstract interface class" quer dizer: não vira objeto sozinha e só pode
// ser usada com "implements" (é um contrato, não uma classe mãe).
// =============================================================================
abstract interface class Serializavel {
  Map<String, dynamic> toMap();
  String toJson();
}

// =============================================================================
// MIXIN ConverteJson: reaproveitamento de código. O toJson é igual para todas
// as classes (é só codificar o Map em JSON), então ele é escrito UMA vez aqui.
// Quem usa "with ConverteJson" só precisa escrever o seu toMap.
// =============================================================================
mixin ConverteJson implements Serializavel {
  @override
  String toJson() => jsonEncode(toMap());

  /// O mesmo JSON, com quebras de linha e recuo, para mostrar na tela.
  String toJsonFormatado() =>
      const JsonEncoder.withIndent('  ').convert(toMap());
}

/// Converte uma lista (ou qualquer coleção) de objetos em uma lista de Maps.
List<Map<String, dynamic>> listaParaMaps(Iterable<Serializavel> objetos) {
  return [for (final objeto in objetos) objeto.toMap()];
}

/// Datas vão para o JSON no formato 2026-10-26 (sem hora).
String dataParaTexto(DateTime data) => data.toIso8601String().substring(0, 10);
