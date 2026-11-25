import 'formato.dart';
import 'serializavel.dart';

// A "etiqueta" da sobra de arroz ou feijão que foi para a geladeira.
// A RDC 216/2004 pede o nome, a data de preparo e a validade.
class SobraGuardada with ConverteJson {
  final int _id;
  final int _idPorcao;
  final DateTime _dataPreparo;
  final DateTime _validade;
  final int _gramasGuardadas;
  int _gramasUsadas;

  SobraGuardada(this._id, this._idPorcao, this._dataPreparo, this._validade,
      this._gramasGuardadas, this._gramasUsadas) {
    if (_gramasGuardadas <= 0) {
      throw ArgumentError('A sobra guardada precisa ter peso.');
    }
    if (_gramasUsadas < 0 || _gramasUsadas > _gramasGuardadas) {
      throw ArgumentError(
          'O que foi usado deve ficar entre 0 e o que foi guardado.');
    }
  }

  int get id => _id;
  int get idPorcao => _idPorcao;
  DateTime get dataPreparo => _dataPreparo;
  DateTime get validade => _validade;
  int get gramasGuardadas => _gramasGuardadas;
  int get gramasUsadas => _gramasUsadas;

  /// O que ainda está na geladeira.
  int get saldo => _gramasGuardadas - _gramasUsadas;

  /// Pode ser usada no dia: depois do dia do preparo, até a validade, e se ainda tem.
  bool podeUsarEm(DateTime dia) =>
      dia.isAfter(_dataPreparo) && !dia.isAfter(_validade) && saldo > 0;

  /// Tira da geladeira. Usar sobra vencida é um erro de estado (StateError).
  void usar(int gramas, DateTime dia) {
    if (dia.isAfter(_validade)) {
      throw StateError(
          'A sobra de ${dataBr(_dataPreparo)} venceu em ${dataBr(_validade)}.');
    }
    if (gramas <= 0 || gramas > saldo) {
      throw ArgumentError('Só tem ${quilos(saldo)} nessa sobra.');
    }
    _gramasUsadas += gramas;
  }

  /// Decide de quais sobras tirar o que vai ser reaproveitado no dia:
  /// sempre a mais antiga primeiro, para nada vencer na geladeira.
  /// Devolve um mapa sobra -> gramas tiradas dela.
  static Map<SobraGuardada, int> planejarUso(
      List<SobraGuardada> sobras, DateTime dia, int gramas) {
    final validas = [
      for (final s in sobras)
        if (s.podeUsarEm(dia)) s
    ];
    validas.sort((a, b) => a._dataPreparo.compareTo(b._dataPreparo));
    var total = 0;
    for (final s in validas) {
      total += s.saldo;
    }
    if (gramas > total) {
      throw ArgumentError(
          'Só tem ${quilos(total)} de sobra dentro da validade.');
    }
    final plano = <SobraGuardada, int>{};
    var falta = gramas;
    for (final s in validas) {
      if (falta == 0) {
        break;
      }
      final tirar = falta < s.saldo ? falta : s.saldo;
      plano[s] = tirar;
      falta -= tirar;
    }
    return plano;
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': _id,
        'idPorcao': _idPorcao,
        'dataPreparo': dataParaTexto(_dataPreparo),
        'validade': dataParaTexto(_validade),
        'gramasGuardadas': _gramasGuardadas,
        'gramasUsadas': _gramasUsadas,
        'saldoGramas': saldo,
      };
}
