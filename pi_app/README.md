# JK Vendas: aplicativo (Flutter)

Aplicativo com telas do JK Bar e Restaurante. Ele grava no mesmo banco MySQL `jk_vendas` que o programa de terminal e usa **as mesmas classes** da pasta `../dart` (o `pubspec.yaml` aponta para lá, não há cópia).

## Telas

| Tela | Arquivo | O que faz | Classes usadas |
| --- | --- | --- | --- |
| Entrada | `lib/main.dart` | Pede a senha do MySQL e conecta. A senha fica só na memória. | `BancoJkVendas` |
| Início | `lib/main.dart` | Botões **Sou cliente** e **Área da dona**. A área da dona pede a senha de novo. | |
| Área do cliente | `lib/area_cliente.dart` | Cardápio de hoje (prato do dia em P/M/G, executivos PFE, fitness PFF, bebidas B), carrinho, local, pagamento e **Fazer pedido**. | `ItemPedido`, `Pedido`, `gravarPedido` |
| Montar o cardápio | `lib/area_dona.dart` | Escolhe a data e marca os pratos do dia. | `PratoDia`, `criarCardapio` |
| Registrar a sobra | `lib/area_dona.dart` | Preparadas e sobra de cada prato, com o alerta de 20%. | `SobraPrato`, `salvarSobra` |
| Vendas do dia | `lib/area_dona.dart` | Pedidos, receita, ticket médio, por pagamento, por local, marmitas e itens vendidos. | `ResumoVendas`, `vendasDoDia` |
| Adicionar item | `lib/area_dona.dart` | Cadastra prato do dia, executivo, fitness ou bebida. Cada tipo vira um objeto de uma classe diferente (polimorfismo). | `PratoDia`, `PratoExecutivo`, `PratoFitness`, `Bebida`, `adicionarItem` |
| (apoio) | `lib/comum.dart` | A conexão, a cor do JK, os avisos e o calendário. | |

## Como rodar

Precisa do Flutter (`flutter doctor`) e, no Mac, do Xcode; no Windows, do Visual Studio Community com "Desenvolvimento para desktop com C++". O banco precisa estar criado (`sql/jk_vendas.sql` e `sql/carga_dados.sql`).

```bash
flutter pub get
flutter run -d macos
```

No Windows, use `flutter run -d windows`. O endereço do MySQL pode mudar com `JK_DB_HOST` e `JK_DB_PORTA`, igual ao programa de terminal.

## Limite (para dizer na apresentação)

O app conecta **direto no MySQL**, então ele roda no computador do restaurante (caixa ou totem). Um app no celular do cliente precisaria de um servidor (API) no meio, para a senha do banco não ficar dentro do app.
