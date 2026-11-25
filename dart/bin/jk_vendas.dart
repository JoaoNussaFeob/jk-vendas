import 'package:jk_vendas/banco_jk_vendas.dart';
import 'package:jk_vendas/teclado.dart';
import 'package:jk_vendas/telas.dart';

// Programa principal do JK Vendas: conecta no MySQL e mostra o menu.
// Para rodar, dentro da pasta dart: dart pub get e depois dart run
Future<void> main() async {
  print('===========================================');
  print('   JK VENDAS · JK Bar e Restaurante');
  print('===========================================');

  // 1. Conexão. A senha é digitada aqui e não fica gravada no código.
  final banco = BancoJkVendas();
  try {
    final usuario = lerTexto('Usuário do MySQL (Enter = root): ');
    final senha = lerSenha('Senha do MySQL: ');
    await banco.conectar(usuario.isEmpty ? 'root' : usuario, senha);
  } on FimDaEntrada {
    return;
  } catch (erro) {
    print('Não foi possível conectar no MySQL: $erro');
    print(
        'Confira se o MySQL está ligado, o usuário, a senha e se o banco jk_vendas_porcoes existe.');
    return;
  }
  print('Conectado ao banco jk_vendas_porcoes.');

  // 2. Menu. A estrutura do-while mostra o menu pelo menos uma vez e
  //    repete até a pessoa escolher 0.
  var opcao = '';
  do {
    print('\n================ MENU ================');
    print('1. Novo pedido');
    print('2. Ver as vendas do dia');
    print('3. Porções do dia (kg preparado e sobra)');
    print('4. Montar o cardápio do dia');
    print('5. Exportar o catálogo em JSON');
    print('0. Sair');
    try {
      opcao = lerTexto('Escolha: ');
      switch (opcao) {
        case '1':
          await telaNovoPedido(banco);
        case '2':
          await telaVendasDoDia(banco);
        case '3':
          await telaPorcoesDoDia(banco);
        case '4':
          await telaMontarCardapio(banco);
        case '5':
          await telaExportarCatalogo(banco);
        case '0':
          print('Até logo!');
        default:
          print('Opção inválida. Digite 0, 1, 2, 3, 4 ou 5.');
      }
    } on FimDaEntrada {
      opcao = '0'; // o teclado acabou: sai do menu
    } on ArgumentError catch (erro) {
      print('Dado inválido: ${erro.message}');
    } on StateError catch (erro) {
      print('Não foi possível continuar: ${erro.message}');
    } catch (erro) {
      // Erros do MySQL, por exemplo um gatilho recusando a operação.
      print('Erro do banco de dados: $erro');
    }
  } while (opcao != '0');

  // 3. Fecha a conexão antes de sair.
  await banco.fechar();
}
