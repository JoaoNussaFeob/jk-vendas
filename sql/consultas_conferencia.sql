-- =====================================================================
--  JK VENDAS - 10 CONSULTAS DE CONFERÊNCIA
--  Rode depois do jk_vendas.sql e do carga_dados.sql.
--  Embaixo de cada consulta está o resultado que deve aparecer.
--  Os números são dos dados simulados da planilha.
-- =====================================================================

SET NAMES utf8mb4;
USE jk_vendas_porcoes;

-- 1. Quantos registros cada tabela tem (COUNT)
SELECT (SELECT COUNT(*) FROM item)               AS itens,
       (SELECT COUNT(*) FROM cardapio_dia)       AS dias,
       (SELECT COUNT(*) FROM cardapio_dia_item)  AS pratos_nos_dias,
       (SELECT COUNT(*) FROM porcao)             AS porcoes,
       (SELECT COUNT(*) FROM porcao_dia)         AS porcoes_nos_dias,
       (SELECT COUNT(*) FROM sobra_guardada)     AS sobras_guardadas,
       (SELECT COUNT(*) FROM pedido)             AS pedidos,
       (SELECT COUNT(*) FROM pedido_item)        AS itens_dos_pedidos,
       (SELECT COUNT(*) FROM registro_alteracao) AS alteracoes;
-- Resultado esperado:
--   itens | dias | pratos_nos_dias | porcoes | porcoes_nos_dias | sobras_guardadas | pedidos | itens_dos_pedidos | alteracoes
--      57 |   14 |              68 |      41 |              122 |               28 |     400 |               840 |        270
-- (as 270 alterações são as porções lançadas pela carga: kg preparado, kg sobra e,
--  no arroz e no feijão, kg reaproveitado)

-- 2. Receita total, ticket médio, maior e menor pedido (SUM, AVG, MAX, MIN)
SELECT COUNT(*)             AS pedidos,
       SUM(total)           AS receita_total,
       ROUND(AVG(total), 2) AS ticket_medio,
       MAX(total)           AS maior_pedido,
       MIN(total)           AS menor_pedido
  FROM (SELECT p.id_pedido,
               SUM(pit.quantidade * pit.preco_unitario) AS total
          FROM pedido p
          JOIN pedido_item pit ON pit.id_pedido = p.id_pedido
         GROUP BY p.id_pedido) AS totais;
-- Resultado esperado:
--   pedidos | receita_total | ticket_medio | maior_pedido | menor_pedido
--       400 |      16715.00 |        41.79 |       133.00 |         4.00

-- 3. Pedidos e receita por dia (visão vw_fvendas)
SELECT f.data,
       ELT(DAYOFWEEK(f.data), 'dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb') AS dia,
       COUNT(DISTINCT f.id_pedido) AS pedidos,
       SUM(f.valor_total)          AS receita
  FROM vw_fvendas f
 GROUP BY f.data
 ORDER BY f.data;
-- Resultado esperado (14 linhas; sábado e domingo têm mais movimento):
--   2026-10-13 | ter | 26 | 1131.00
--   2026-10-14 | qua | 26 |  941.00
--   2026-10-15 | qui | 24 |  972.00
--   2026-10-16 | sex | 29 | 1160.00
--   2026-10-17 | sáb | 37 | 1705.00
--   2026-10-18 | dom | 36 | 1566.00
--   2026-10-19 | seg | 21 |  903.00
--   2026-10-20 | ter | 26 | 1149.00
--   2026-10-21 | qua | 28 | 1047.00
--   2026-10-22 | qui | 25 | 1014.00
--   2026-10-23 | sex | 30 | 1200.00
--   2026-10-24 | sáb | 34 | 1490.00
--   2026-10-25 | dom | 37 | 1410.00
--   2026-10-26 | seg | 21 | 1027.00

-- 4. Vendas por tamanho (JOIN com tamanho_marmita)
--    P, M e G são as marmitas; PFE, PFF e B usam o preço do próprio item.
SELECT t.sigla,
       t.nome,
       SUM(pit.quantidade) AS unidades,
       SUM(pit.quantidade * pit.preco_unitario) AS receita
  FROM pedido_item pit
  JOIN tamanho_marmita t ON t.sigla = pit.tamanho
 GROUP BY t.sigla, t.nome
 ORDER BY FIELD(t.sigla, 'P', 'M', 'G', 'PFE', 'PFF', 'B');
-- Resultado esperado:
--   P   | Pequena                               |  69 | 1518.00
--   M   | Média                                 | 143 | 3432.00
--   G   | Grande                                | 134 | 3618.00
--   PFE | Prato feito executivo (preço do item) |  98 | 2940.00
--   PFF | Prato feito fitness (preço do item)   |  98 | 2311.00
--   B   | Bebida (preço do item)                | 421 | 2896.00

-- 5. Os 5 pratos do dia mais vendidos (JOIN com item)
--    dias_no_cardapio mostra quantos dias o prato foi oferecido.
SELECT i.nome AS prato_do_dia,
       SUM(pit.quantidade) AS marmitas,
       (SELECT COUNT(*) FROM cardapio_dia_item c WHERE c.id_item = i.id_item) AS dias_no_cardapio
  FROM pedido_item pit
  JOIN item i ON i.id_item = pit.id_item
 WHERE i.tipo = 'PRATO_DIA'
 GROUP BY i.id_item, i.nome
 ORDER BY marmitas DESC, prato_do_dia
 LIMIT 5;
-- Resultado esperado:
--   Filé de frango empanado | 66 | 14
--   Filé de frango grelhado | 56 | 14
--   Feijoada completa       | 46 |  5   <- a que mais vende por dia
--   Omelete com queijo      | 29 | 13
--   Fraldinha na pressão    | 25 |  3

-- 6. Vendas por forma de pagamento (JOIN, COUNT, SUM)
SELECT p.forma_pagamento,
       COUNT(DISTINCT p.id_pedido) AS pedidos,
       SUM(pit.quantidade * pit.preco_unitario) AS receita
  FROM pedido p
  JOIN pedido_item pit ON pit.id_pedido = p.id_pedido
 GROUP BY p.forma_pagamento
 ORDER BY receita DESC;
-- Resultado esperado:
--   Pix      | 201 | 8782.00
--   Cartão   | 112 | 4589.00
--   Dinheiro |  48 | 1678.00
--   Fiado    |  39 | 1666.00

-- 7. Ticket médio e maior pedido por local (AVG, MAX)
SELECT t.local_pedido,
       COUNT(*)               AS pedidos,
       ROUND(AVG(t.total), 2) AS ticket_medio,
       MAX(t.total)           AS maior_pedido
  FROM (SELECT p.id_pedido,
               p.local_pedido,
               SUM(pit.quantidade * pit.preco_unitario) AS total
          FROM pedido p
          JOIN pedido_item pit ON pit.id_pedido = p.id_pedido
         GROUP BY p.id_pedido, p.local_pedido) AS t
 GROUP BY t.local_pedido
 ORDER BY pedidos DESC;
-- Resultado esperado (o delivery leva mais refeições por pedido):
--   Balcão   | 167 | 35.15 |  82.00
--   Delivery | 148 | 50.97 | 133.00
--   Viagem   |  85 | 38.84 | 108.00

-- 8. Bebidas vendidas por categoria (JOIN com item)
--    Os preços das bebidas ainda são de teste.
SELECT i.categoria,
       SUM(pit.quantidade) AS unidades,
       SUM(pit.quantidade * pit.preco_unitario) AS receita
  FROM pedido_item pit
  JOIN item i ON i.id_item = pit.id_item
 WHERE i.tipo = 'BEBIDA'
 GROUP BY i.categoria
 ORDER BY unidades DESC;
-- Resultado esperado:
--   Cerveja      | 172 | 1350.00
--   Refrigerante | 146 |  928.00
--   Suco         |  56 |  410.00
--   Água         |  47 |  208.00

-- 9. Porções do dia por tipo (visão vw_fporcao, SUM): o desperdício, ligado à ODS 12
--    Só arroz e feijão são reaproveitados (até 5 dias, RDC 216/2004 item 4.8.17).
SELECT d.tipo,
       SUM(f.kg_preparado)                                                            AS kg_preparado,
       SUM(f.kg_reaproveitado)                                                        AS kg_reaproveitado,
       SUM(f.kg_sobra)                                                                AS kg_sobra,
       SUM(f.kg_desperdicio)                                                          AS kg_desperdicio,
       ROUND(100 * SUM(f.kg_desperdicio) / SUM(f.kg_preparado + f.kg_reaproveitado), 1) AS pct_desperdicio
  FROM vw_fporcao f
  JOIN vw_dporcao d ON d.id_porcao = f.id_porcao
 GROUP BY d.tipo
 ORDER BY pct_desperdicio DESC;
-- Resultado esperado:
--   Mistura                | 65.750 |  0.000 | 15.360 | 15.360 | 23.4
--   Acompanhamento         | 47.750 |  0.000 |  8.620 |  8.620 | 18.1
--   Base (arroz e feijão)  | 115.750 | 20.330 | 22.180 |  1.850 |  1.4
-- No total: 229,25 kg preparados, 20,33 kg reaproveitados e 25,83 kg desperdiçados (10,3%).
-- O arroz e o feijão sobram bastante (22,18 kg), mas quase tudo volta para a panela
-- nos dias seguintes; só 1,85 kg venceu na geladeira.

-- 10. Conferência das sobras guardadas: o que foi reaproveitado (kg_reaproveitado
--     nas porções do dia) tem que ser igual ao que saiu da geladeira (kg_usado),
--     e nenhuma sobra pode ter sido usada depois da validade.
SELECT (SELECT SUM(kg_reaproveitado) FROM porcao_dia)  AS kg_reaproveitado,
       (SELECT SUM(kg_usado) FROM sobra_guardada)      AS kg_usado_da_geladeira,
       (SELECT COUNT(*) FROM sobra_guardada
         WHERE validade <> DATE_ADD(data_preparo, INTERVAL 5 DAY)) AS validades_erradas;
-- Resultado esperado:
--   itens | dias | pratos_nos_dias | porcoes | porcoes_nos_dias | sobras_guardadas | pedidos | itens_dos_pedidos | alteracoes
--      57 |   14 |              68 |      41 |              122 |               28 |     400 |               840 |        270
-- (as 270 alterações são as porções lançadas pela carga: kg preparado, kg sobra e,
--  no arroz e no feijão, kg reaproveitado)0
