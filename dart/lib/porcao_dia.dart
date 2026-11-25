import 'formato.dart';
import 'porcao.dart';
import 'serializavel.dart';

// O que a cozinha fez de uma porção num dia, em gramas: quanto preparou,
// quanto usou de sobra guardada e quanto sobrou. É aqui que o sistema toma
// decisões sobre o desperdício de comida (ODS 12, Consumo e Produção Responsáveis).
class PorcaoDia with ConverteJson {
  /// Acima deste percentual, a sobra que vai para o lixo é considerada alta.
  static const limiteSobraAlta = 20.0;

  final DateTime _data;
  final Porcao _porcao;
  int? _preparado; // vazio até a cozinha registrar
  int _reaproveitado;
  int? _sobra;

  PorcaoDia(this._data, this._porcao, this._preparado, this._reaproveitado,
      this._sobra);

  DateTime get data => _data;
  Porcao get porcao => _porcao;
  int? get preparado => _preparado;
  int get reaproveitado => _reaproveitado;
  int? get sobra => _sobra;
  bool get registrada => _sobra != null;

  /// Registra o que a cozinha informou. Só guarda se os números fizerem sentido.
  /// [disponivel] é quanto há de sobra guardada dentro da validade.
  void registrar(int preparado, int reaproveitado, int sobra,
      {int disponivel = 0}) {
    if (registrada) {
      throw StateError('${_porcao.nome} já foi registrada nesse dia.');
    }
    if (preparado < 0 || reaproveitado < 0 || sobra < 0) {
      throw ArgumentError('Os pesos não podem ser negativos.');
    }
    if (reaproveitado > 0 && !_porcao.reaproveitavel) {
      throw ArgumentError(
          '${_porcao.nome} não pode ser reaproveitada: só arroz e feijão.');
    }
    if (reaproveitado > disponivel) {
      throw ArgumentError(
          'Só tem ${quilos(disponivel)} de sobra dentro da validade.');
    }
    if (preparado + reaproveitado == 0) {
      throw ArgumentError('Informe quanto foi preparado.');
    }
    if (sobra > preparado + reaproveitado) {
      throw ArgumentError(
          'A sobra não pode ser maior que o preparado mais o reaproveitado.');
    }
    _preparado = preparado;
    _reaproveitado = reaproveitado;
    _sobra = sobra;
  }

  int get _total => (_preparado ?? 0) + _reaproveitado;

  /// O que saiu para os clientes.
  int get consumido => _total - (_sobra ?? 0);

  /// Quanto do total sobrou, de 0 a 100.
  double get percentualSobra {
    final sobra = _sobra;
    if (sobra == null) {
      throw StateError('${_porcao.nome} ainda não foi registrada.');
    }
    return sobra * 100 / _total;
  }

  /// O que vai para o lixo hoje: toda a sobra que não pode ser reaproveitada.
  /// A sobra de arroz e feijão vai para a geladeira e só vira lixo se vencer.
  int get desperdicioDoDia => _porcao.reaproveitavel ? 0 : (_sobra ?? 0);

  /// Até quando a sobra guardada pode ser usada.
  DateTime get validadeDaSobra =>
      _data.add(Duration(days: _porcao.validadeDias));

  /// A decisão do sistema sobre a sobra da porção.
  String get alerta {
    final sobra = _sobra;
    if (sobra == null) {
      return 'Porção ainda não registrada.';
    }
    if (sobra == 0) {
      return 'Acabou tudo: amanhã dá para preparar um pouco mais.';
    } else if (_porcao.reaproveitavel) {
      return 'Guarde ${quilos(sobra)} na geladeira (até 4 °C) com etiqueta: '
          'pode usar até ${dataBr(validadeDaSobra)}.';
    } else if (percentualSobra > limiteSobraAlta) {
      return 'ALERTA: sobrou ${percentual(percentualSobra)} (${quilos(sobra)}), que vai para o lixo. '
          'Prepare menos amanhã.';
    } else {
      return 'Sobra de ${percentual(percentualSobra)} (${quilos(sobra)}), dentro do esperado.';
    }
  }

  /// A porção vai como um Map dentro do Map; o peso fica em gramas.
  @override
  Map<String, dynamic> toMap() => {
        'data': dataParaTexto(_data),
        'porcao': _porcao.toMap(),
        'preparadoGramas': _preparado,
        'reaproveitadoGramas': _reaproveitado,
        'sobraGramas': _sobra,
        'desperdicioGramas': desperdicioDoDia,
      };
}
