
SET NAMES utf8mb4;
DROP DATABASE IF EXISTS jk_vendas_porcoes;
CREATE DATABASE jk_vendas_porcoes CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE jk_vendas_porcoes;

-- =====================================================================
-- PARTE 1 - TABELAS
-- =====================================================================

-- 1. ITEM: tudo o que o restaurante vende
CREATE TABLE item (
  id_item        INT AUTO_INCREMENT PRIMARY KEY,
  nome           VARCHAR(100) NOT NULL,
  tipo           ENUM('PRATO_DIA','FITNESS','EXECUTIVO','BEBIDA') NOT NULL,
  categoria      ENUM('Carne bovina','Carne suína','Frango','Peixe','Ovos','Massa',
                      'Refrigerante','Cerveja','Água','Suco') NOT NULL,
  preco          DECIMAL(10,2),                    -- em reais; vazio no prato do dia: o preço é o do tamanho
  confirmar      BOOLEAN NOT NULL DEFAULT FALSE,   -- TRUE = valor de teste, confirmar com o restaurante
  UNIQUE (nome, tipo),
  CONSTRAINT chk_item_preco CHECK (
    (tipo = 'PRATO_DIA' AND preco IS NULL) OR
    (tipo <> 'PRATO_DIA' AND preco IS NOT NULL AND preco > 0)
  ),
  CONSTRAINT chk_item_bebida CHECK (
    (tipo = 'BEBIDA'  AND categoria IN     ('Refrigerante','Cerveja','Água','Suco')) OR
    (tipo <> 'BEBIDA' AND categoria NOT IN ('Refrigerante','Cerveja','Água','Suco'))
  )
);

-- 2. TAMANHO_MARMITA: como cada item é vendido
--    P, M e G: marmita do prato do dia, com o preço de cada tamanho.
--    PFE (prato feito executivo), PFF (prato feito fitness) e B (bebida):
--    sem preço aqui, porque vale o preço do próprio item.
CREATE TABLE tamanho_marmita (
  sigla VARCHAR(3)    PRIMARY KEY,
  nome  VARCHAR(50)   NOT NULL UNIQUE,
  preco DECIMAL(10,2),
  CONSTRAINT chk_tamanho_sigla CHECK (sigla IN ('P','M','G','PFE','PFF','B')),
  CONSTRAINT chk_tamanho_preco CHECK (
    (sigla IN ('P','M','G') AND preco IS NOT NULL AND preco > 0) OR
    (sigla NOT IN ('P','M','G') AND preco IS NULL)
  )
);

-- 3. CARDAPIO_DIA: um registro por dia
CREATE TABLE cardapio_dia (
  data       DATE PRIMARY KEY,
  observacao VARCHAR(255)
);

-- 4. CARDAPIO_DIA_ITEM: os pratos do dia vendidos em cada data (marmita P, M ou G).
--    A sobra não fica mais aqui: ela é medida em kg, por porção (tabelas 8 a 10).
CREATE TABLE cardapio_dia_item (
  data    DATE NOT NULL,
  id_item INT  NOT NULL,
  PRIMARY KEY (data, id_item),
  FOREIGN KEY (data)    REFERENCES cardapio_dia (data) ON DELETE CASCADE,
  FOREIGN KEY (id_item) REFERENCES item (id_item)
);

-- 5. PEDIDO: cada venda
CREATE TABLE pedido (
  id_pedido       INT AUTO_INCREMENT PRIMARY KEY,
  data_hora       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  forma_pagamento ENUM('Dinheiro','Pix','Cartão','Fiado') NOT NULL,
  local_pedido    ENUM('Balcão','Viagem','Delivery') NOT NULL
);

-- 6. PEDIDO_ITEM: os itens de cada pedido
CREATE TABLE pedido_item (
  id_pedido_item          INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido               INT     NOT NULL,
  id_item                 INT     NOT NULL,
  tamanho                 VARCHAR(3) NOT NULL, -- P/M/G (prato do dia), PFE, PFF ou B
  quantidade              INT     NOT NULL,
  preco_unitario          DECIMAL(10,2) NOT NULL, -- preço em reais na hora da venda
  FOREIGN KEY (id_pedido) REFERENCES pedido (id_pedido),
  FOREIGN KEY (id_item)   REFERENCES item (id_item),
  FOREIGN KEY (tamanho)   REFERENCES tamanho_marmita (sigla),
  CONSTRAINT chk_pi_quantidade CHECK (quantidade > 0),
  CONSTRAINT chk_pi_preco      CHECK (preco_unitario > 0)
);

-- 7. REGISTRO_ALTERACAO: histórico das mudanças de preço e das porções (auditoria).
--    É preenchida sozinha pelos gatilhos da parte 2. Não tem chave estrangeira
--    porque guarda linhas de várias tabelas e precisa durar mesmo se a linha mudar.
CREATE TABLE registro_alteracao (
  id_registro  INT AUTO_INCREMENT PRIMARY KEY,
  tabela       VARCHAR(30)  NOT NULL,  -- tabela alterada
  registro     VARCHAR(30)  NOT NULL,  -- chave da linha alterada
  campo        VARCHAR(30)  NOT NULL,  -- coluna alterada
  valor_antigo VARCHAR(30),
  valor_novo   VARCHAR(30),
  usuario      VARCHAR(100) NOT NULL,  -- usuário do MySQL que fez a mudança
  alterado_em  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 8. PORCAO: o que a cozinha prepara por dia, medido em quilos.
--    BASE (arroz e feijão), ACOMPANHAMENTO (batata frita, farofa...) e
--    MISTURA (a carne, o frango ou a omelete do prato do dia, ligada ao item vendido).
--    Só arroz e feijão podem ser reaproveitados: até 5 dias depois do preparo,
--    guardados na geladeira a 4 °C ou menos (ANVISA, RDC 216/2004, item 4.8.17).
CREATE TABLE porcao (
  id_porcao      INT AUTO_INCREMENT PRIMARY KEY,
  nome           VARCHAR(100) NOT NULL UNIQUE,
  tipo           ENUM('BASE','ACOMPANHAMENTO','MISTURA') NOT NULL,
  id_item        INT UNIQUE,                      -- só na mistura: o prato do dia que ela vira
  reaproveitavel BOOLEAN NOT NULL DEFAULT FALSE,
  validade_dias  INT     NOT NULL DEFAULT 0,      -- dias que a sobra pode ser usada
  FOREIGN KEY (id_item) REFERENCES item (id_item),
  CONSTRAINT chk_porcao_mistura CHECK (
    (tipo = 'MISTURA' AND id_item IS NOT NULL AND reaproveitavel = FALSE) OR
    (tipo <> 'MISTURA' AND id_item IS NULL)
  ),
  CONSTRAINT chk_porcao_validade CHECK (
    (reaproveitavel = TRUE  AND validade_dias BETWEEN 1 AND 5) OR
    (reaproveitavel = FALSE AND validade_dias = 0)
  )
);

-- 9. PORCAO_DIA: o que foi feito de cada porção em cada dia, em kg.
--    kg_reaproveitado é a sobra de dias anteriores usada hoje (só arroz e feijão).
--    Os valores ficam vazios até a cozinha registrar no fim do dia.
CREATE TABLE porcao_dia (
  data             DATE NOT NULL,
  id_porcao        INT  NOT NULL,
  kg_preparado     DECIMAL(7,3),
  kg_reaproveitado DECIMAL(7,3) NOT NULL DEFAULT 0,
  kg_sobra         DECIMAL(7,3),
  PRIMARY KEY (data, id_porcao),
  FOREIGN KEY (data)      REFERENCES cardapio_dia (data) ON DELETE CASCADE,
  FOREIGN KEY (id_porcao) REFERENCES porcao (id_porcao),
  CONSTRAINT chk_pd_valores CHECK (
    (kg_preparado IS NULL OR kg_preparado >= 0) AND kg_reaproveitado >= 0
  ),
  CONSTRAINT chk_pd_sobra CHECK (
    kg_sobra IS NULL OR
    (kg_preparado IS NOT NULL AND kg_sobra >= 0 AND kg_sobra <= kg_preparado + kg_reaproveitado)
  )
);

-- 10. SOBRA_GUARDADA: a "etiqueta" da sobra de arroz ou feijão que foi para a geladeira.
--     A RDC 216 pede nome, data de preparo e validade. A validade é calculada pelo
--     gatilho (data de preparo + validade_dias da porção). kg_usado é o quanto já
--     foi reaproveitado; o que sobrar depois da validade é desperdício.
CREATE TABLE sobra_guardada (
  id_sobra     INT AUTO_INCREMENT PRIMARY KEY,
  id_porcao    INT          NOT NULL,
  data_preparo DATE         NOT NULL,
  validade     DATE         NOT NULL,
  kg_guardado  DECIMAL(7,3) NOT NULL,
  kg_usado     DECIMAL(7,3) NOT NULL DEFAULT 0,
  UNIQUE (id_porcao, data_preparo),
  FOREIGN KEY (id_porcao) REFERENCES porcao (id_porcao),
  CONSTRAINT chk_sg_kg CHECK (kg_guardado > 0 AND kg_usado >= 0 AND kg_usado <= kg_guardado)
);

-- =====================================================================
-- PARTE 2 - GATILHOS
-- =====================================================================

-- 2.1 Uma venda registrada não pode ser alterada nem apagada
CREATE TRIGGER trg_pedido_sem_alteracao
BEFORE UPDATE ON pedido
FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Venda já registrada não pode ser alterada';

CREATE TRIGGER trg_pedido_sem_exclusao
BEFORE DELETE ON pedido
FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Venda já registrada não pode ser apagada';

CREATE TRIGGER trg_pedido_item_sem_alteracao
BEFORE UPDATE ON pedido_item
FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Item de venda já registrado não pode ser alterado';

CREATE TRIGGER trg_pedido_item_sem_exclusao
BEFORE DELETE ON pedido_item
FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Item de venda já registrado não pode ser apagado';

-- 2.2 O tamanho precisa combinar com o tipo do item:
--     prato do dia = P, M ou G; executivo = PFE; fitness = PFF; bebida = B.
-- O DELIMITER troca o fim do comando para $$, porque o gatilho tem vários ; dentro.
DELIMITER $$
CREATE TRIGGER trg_pedido_item_confere_tamanho
BEFORE INSERT ON pedido_item
FOR EACH ROW
BEGIN
  DECLARE v_tipo VARCHAR(20);
  SELECT tipo INTO v_tipo FROM item WHERE id_item = NEW.id_item;
  IF NOT ((v_tipo = 'PRATO_DIA' AND NEW.tamanho IN ('P','M','G'))
       OR (v_tipo = 'EXECUTIVO' AND NEW.tamanho = 'PFE')
       OR (v_tipo = 'FITNESS'   AND NEW.tamanho = 'PFF')
       OR (v_tipo = 'BEBIDA'    AND NEW.tamanho = 'B')) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tamanho não combina com o tipo do item';
  END IF;
END$$
DELIMITER ;

-- 2.3 Toda mudança de preço e das porções do dia fica guardada em registro_alteracao.
--     O operador <=> compara levando o vazio (NULL) em conta.
CREATE TRIGGER trg_item_registra_preco
AFTER UPDATE ON item
FOR EACH ROW
INSERT INTO registro_alteracao (tabela, registro, campo, valor_antigo, valor_novo, usuario)
SELECT 'item', NEW.id_item, 'preco', OLD.preco, NEW.preco, USER()
  FROM DUAL
 WHERE NOT (OLD.preco <=> NEW.preco);

CREATE TRIGGER trg_tamanho_registra_preco
AFTER UPDATE ON tamanho_marmita
FOR EACH ROW
INSERT INTO registro_alteracao (tabela, registro, campo, valor_antigo, valor_novo, usuario)
SELECT 'tamanho_marmita', NEW.sigla, 'preco', OLD.preco, NEW.preco, USER()
  FROM DUAL
 WHERE NOT (OLD.preco <=> NEW.preco);

CREATE TRIGGER trg_porcao_registra_alteracao
AFTER UPDATE ON porcao_dia
FOR EACH ROW
INSERT INTO registro_alteracao (tabela, registro, campo, valor_antigo, valor_novo, usuario)
SELECT 'porcao_dia', CONCAT(NEW.data, ' / ', NEW.id_porcao), 'kg_preparado',
       OLD.kg_preparado, NEW.kg_preparado, USER()
  FROM DUAL
 WHERE NOT (OLD.kg_preparado <=> NEW.kg_preparado)
UNION ALL
SELECT 'porcao_dia', CONCAT(NEW.data, ' / ', NEW.id_porcao), 'kg_reaproveitado',
       OLD.kg_reaproveitado, NEW.kg_reaproveitado, USER()
  FROM DUAL
 WHERE NOT (OLD.kg_reaproveitado <=> NEW.kg_reaproveitado)
UNION ALL
SELECT 'porcao_dia', CONCAT(NEW.data, ' / ', NEW.id_porcao), 'kg_sobra',
       OLD.kg_sobra, NEW.kg_sobra, USER()
  FROM DUAL
 WHERE NOT (OLD.kg_sobra <=> NEW.kg_sobra);

-- 2.4 Só arroz e feijão podem ser reaproveitados (porções com reaproveitavel = TRUE).
DELIMITER $$
CREATE TRIGGER trg_porcao_dia_confere_insercao
BEFORE INSERT ON porcao_dia
FOR EACH ROW
BEGIN
  IF NEW.kg_reaproveitado > 0
     AND (SELECT reaproveitavel FROM porcao WHERE id_porcao = NEW.id_porcao) = FALSE THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Essa porção não pode ser reaproveitada';
  END IF;
END$$

CREATE TRIGGER trg_porcao_dia_confere_alteracao
BEFORE UPDATE ON porcao_dia
FOR EACH ROW
BEGIN
  IF NEW.kg_reaproveitado > 0
     AND (SELECT reaproveitavel FROM porcao WHERE id_porcao = NEW.id_porcao) = FALSE THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Essa porção não pode ser reaproveitada';
  END IF;
END$$

-- 2.5 A etiqueta: recusa sobra guardada de porção que não se reaproveita e
--     calcula a validade (data de preparo + dias da porção, no máximo 5: RDC 216).
CREATE TRIGGER trg_sobra_guardada_validade
BEFORE INSERT ON sobra_guardada
FOR EACH ROW
BEGIN
  DECLARE v_pode BOOLEAN;
  DECLARE v_dias INT;
  SELECT reaproveitavel, validade_dias INTO v_pode, v_dias
    FROM porcao WHERE id_porcao = NEW.id_porcao;
  IF v_pode = FALSE THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Essa porção não pode ser guardada para reaproveitar';
  END IF;
  SET NEW.validade = DATE_ADD(NEW.data_preparo, INTERVAL v_dias DAY);
END$$
DELIMITER ;

-- =====================================================================
-- PARTE 3 - VISÕES PARA O POWER BI (valores em reais)
-- =====================================================================

-- vw_ditem: dimensão dos itens. Fitness e executivo ganham o tipo no nome
-- para não se misturar com o prato do dia de mesmo nome nos gráficos.
CREATE VIEW vw_ditem AS
SELECT id_item,
       CASE tipo
         WHEN 'FITNESS'   THEN CONCAT(nome, ' (fitness)')
         WHEN 'EXECUTIVO' THEN CONCAT(nome, ' (executivo)')
         ELSE nome
       END AS item,
       CASE tipo
         WHEN 'PRATO_DIA' THEN 'Prato do dia'
         WHEN 'FITNESS'   THEN 'Fitness'
         WHEN 'EXECUTIVO' THEN 'Executivo'
         ELSE 'Bebida'
       END AS tipo,
       categoria,
       preco,
       confirmar
  FROM item;

-- vw_fvendas: fato das vendas (uma linha por item vendido)
CREATE VIEW vw_fvendas AS
SELECT pit.id_pedido_item,
       p.id_pedido,
       DATE(p.data_hora) AS data,
       TIME(p.data_hora) AS hora,
       pit.id_item,
       pit.tamanho,
       pit.quantidade,
       pit.preco_unitario,
       CAST(pit.quantidade * pit.preco_unitario AS DECIMAL(10,2)) AS valor_total,
       p.forma_pagamento,
       p.local_pedido
  FROM pedido_item pit
  JOIN pedido p ON p.id_pedido = pit.id_pedido;

-- vw_fporcao: fato das porções do dia (só as já registradas), em kg.
-- Desperdício:
--   - mistura e acompanhamento: toda a sobra (não se reaproveita);
--   - arroz e feijão: a parte da sobra que não foi guardada na geladeira
--     mais o que foi guardado e venceu sem ser usado (validade já passou).
CREATE VIEW vw_fporcao AS
SELECT pd.data,
       pd.id_porcao,
       p.id_item,
       pd.kg_preparado,
       pd.kg_reaproveitado,
       pd.kg_sobra,
       pd.kg_preparado + pd.kg_reaproveitado - pd.kg_sobra AS kg_consumido,
       CASE
         WHEN p.reaproveitavel = FALSE THEN pd.kg_sobra
         ELSE pd.kg_sobra - COALESCE(g.kg_guardado, 0)
              + CASE WHEN g.validade < CURDATE() THEN g.kg_guardado - g.kg_usado ELSE 0 END
       END AS kg_desperdicio,
       COALESCE(g.kg_usado, 0) AS kg_reaproveitado_depois,
       CASE WHEN g.validade >= CURDATE() THEN g.kg_guardado - g.kg_usado ELSE 0 END AS kg_ainda_na_geladeira,
       g.validade
  FROM porcao_dia pd
  JOIN porcao p ON p.id_porcao = pd.id_porcao
  LEFT JOIN sobra_guardada g ON g.id_porcao = pd.id_porcao AND g.data_preparo = pd.data
 WHERE pd.kg_sobra IS NOT NULL;

-- vw_dporcao: dimensão das porções, com o tipo em português.
CREATE VIEW vw_dporcao AS
SELECT id_porcao,
       nome AS porcao,
       CASE tipo
         WHEN 'BASE'           THEN 'Base (arroz e feijão)'
         WHEN 'ACOMPANHAMENTO' THEN 'Acompanhamento'
         ELSE 'Mistura'
       END AS tipo,
       CASE WHEN reaproveitavel THEN 'Reaproveitável' ELSE 'Não reaproveitável' END AS reaproveitamento,
       validade_dias
  FROM porcao;

-- =====================================================================
-- PARTE 4 - DADOS DO CARDÁPIO
-- =====================================================================

-- 1. TAMANHO_MARMITA (preços das marmitas: dos cardápios)
INSERT INTO tamanho_marmita (sigla, nome, preco) VALUES
('P',   'Pequena',                                 22.00),
('M',   'Média',                                   24.00),
('G',   'Grande',                                  27.00),
('PFE', 'Prato feito executivo (preço do item)',   NULL),
('PFF', 'Prato feito fitness (preço do item)',     NULL),
('B',   'Bebida (preço do item)',                  NULL);

-- 2. ITEM
-- 2.1 Pratos do dia, na ordem em que aparecem nos cardápios (sem preço: vale o da marmita)
INSERT INTO item (id_item, nome, tipo, categoria) VALUES
(1,  'Carne bovina assada',                   'PRATO_DIA', 'Carne bovina'),
(2,  'Isca de tilápia empanada',              'PRATO_DIA', 'Peixe'),
(3,  'Filé de frango grelhado',               'PRATO_DIA', 'Frango'),
(4,  'Filé de frango empanado',               'PRATO_DIA', 'Frango'),
(5,  'Omelete com queijo',                    'PRATO_DIA', 'Ovos'),
(6,  'Ponta de peito na pressão',             'PRATO_DIA', 'Carne bovina'),
(7,  'Lasanha à bolonhesa',                   'PRATO_DIA', 'Massa'),
(8,  'Sobrecoxa assada com lâminas de bacon', 'PRATO_DIA', 'Frango'),
(9,  'Carne maluca',                          'PRATO_DIA', 'Carne bovina'),
(10, 'Lagarto ao molho madeira',              'PRATO_DIA', 'Carne bovina'),
(11, 'Linguiça toscana assada',               'PRATO_DIA', 'Carne suína'),
(12, 'Feijoada completa',                     'PRATO_DIA', 'Carne suína'),
(13, 'Bife bovino à milanesa',                'PRATO_DIA', 'Carne bovina'),
(14, 'Carne de panela',                       'PRATO_DIA', 'Carne bovina'),
(15, 'Panqueca de carne bovina',              'PRATO_DIA', 'Massa'),
(16, 'Tutu de feijão com bife bovino',        'PRATO_DIA', 'Carne bovina'),
(17, 'Fraldinha na pressão',                  'PRATO_DIA', 'Carne bovina'),
(18, 'Costelinha suína no molho barbecue',    'PRATO_DIA', 'Carne suína'),
(19, 'Parmegiana de filé bovino',             'PRATO_DIA', 'Carne bovina'),
(20, 'Parmegiana de filé de frango',          'PRATO_DIA', 'Frango'),
(21, 'Cupim na manteiga',                     'PRATO_DIA', 'Carne bovina');

-- 2.2 Fitness (preços dos cardápios). A carne moída é citada no guia,
--     mas não aparece nas fotos: confirmar.
INSERT INTO item (id_item, nome, tipo, categoria, preco, confirmar) VALUES
(22, 'Filé de tilápia grelhada', 'FITNESS', 'Peixe',        27.00, FALSE),
(23, 'Filé de frango grelhado',  'FITNESS', 'Frango',       22.00, FALSE),
(24, 'Omelete com queijo',       'FITNESS', 'Ovos',         22.00, FALSE),
(25, 'Carne moída',              'FITNESS', 'Carne bovina', 24.00, TRUE);

-- 2.3 Executivos: qualquer proteína (contra filé, alcatra, tilápia ou frango)
--     com qualquer preparo (grelhado, empanado ou parmegiana), todos os dias.
--     Preço de teste: confirmar com o restaurante.
INSERT INTO item (id_item, nome, tipo, categoria, preco, confirmar) VALUES
(26, 'Contra filé grelhado',     'EXECUTIVO', 'Carne bovina', 30.00, TRUE),
(27, 'Contra filé empanado',     'EXECUTIVO', 'Carne bovina', 30.00, TRUE),
(28, 'Contra filé à parmegiana', 'EXECUTIVO', 'Carne bovina', 30.00, TRUE),
(29, 'Alcatra grelhada',         'EXECUTIVO', 'Carne bovina', 30.00, TRUE),
(30, 'Alcatra empanada',         'EXECUTIVO', 'Carne bovina', 30.00, TRUE),
(31, 'Alcatra à parmegiana',     'EXECUTIVO', 'Carne bovina', 30.00, TRUE),
(32, 'Tilápia grelhada',         'EXECUTIVO', 'Peixe',        30.00, TRUE),
(33, 'Tilápia empanada',         'EXECUTIVO', 'Peixe',        30.00, TRUE),
(34, 'Tilápia à parmegiana',     'EXECUTIVO', 'Peixe',        30.00, TRUE),
(35, 'Frango grelhado',          'EXECUTIVO', 'Frango',       30.00, TRUE),
(36, 'Frango empanado',          'EXECUTIVO', 'Frango',       30.00, TRUE),
(37, 'Frango à parmegiana',      'EXECUTIVO', 'Frango',       30.00, TRUE);

-- 2.4 Bebidas do guia, com preço de teste: confirmar com o restaurante.
--     Fanta Laranja e Sprite ocupam o lugar dos dois refrigerantes sem nome
--     confirmado; Brahma, Skol e Heineken são as marcas sugeridas no guia.
INSERT INTO item (id_item, nome, tipo, categoria, preco, confirmar) VALUES
(38, 'Coca-Cola lata',          'BEBIDA', 'Refrigerante',   6.00, TRUE),
(39, 'Coca-Cola 1 L',           'BEBIDA', 'Refrigerante', 10.00, TRUE),
(40, 'Coca-Cola 2 L',           'BEBIDA', 'Refrigerante', 14.00, TRUE),
(41, 'Coca-Cola Zero lata',     'BEBIDA', 'Refrigerante',   6.00, TRUE),
(42, 'Coca-Cola Zero 1 L',      'BEBIDA', 'Refrigerante', 10.00, TRUE),
(43, 'Coca-Cola Zero 2 L',      'BEBIDA', 'Refrigerante', 14.00, TRUE),
(44, 'Guaraná Antarctica lata', 'BEBIDA', 'Refrigerante',   6.00, TRUE),
(45, 'Pepsi lata',              'BEBIDA', 'Refrigerante',   6.00, TRUE),
(46, 'Fanta Laranja lata',      'BEBIDA', 'Refrigerante',   6.00, TRUE),
(47, 'Sprite lata',             'BEBIDA', 'Refrigerante',   6.00, TRUE),
(48, 'Brahma lata',             'BEBIDA', 'Cerveja',        6.00, TRUE),
(49, 'Brahma long neck',        'BEBIDA', 'Cerveja',        8.00, TRUE),
(50, 'Skol lata',               'BEBIDA', 'Cerveja',        6.00, TRUE),
(51, 'Skol long neck',          'BEBIDA', 'Cerveja',        8.00, TRUE),
(52, 'Heineken lata',           'BEBIDA', 'Cerveja',        8.00, TRUE),
(53, 'Heineken long neck',      'BEBIDA', 'Cerveja',      10.00, TRUE),
(54, 'Água mineral sem gás',    'BEBIDA', 'Água',           4.00, TRUE),
(55, 'Água mineral com gás',    'BEBIDA', 'Água',           5.00, TRUE),
(56, 'Suco natural',            'BEBIDA', 'Suco',           8.00, TRUE),
(57, 'Suco de lata',            'BEBIDA', 'Suco',           6.00, TRUE);

-- 3. CARDAPIO_DIA: 14 dias seguidos. Os pratos são os dos 14 cardápios do dia
--    das fotos (foto N = N-ésima foto); as datas são simuladas.
INSERT INTO cardapio_dia (data, observacao) VALUES
('2026-10-13', 'Cardápio da foto 1 (data simulada)'),
('2026-10-14', 'Cardápio da foto 3 (data simulada)'),
('2026-10-15', 'Cardápio da foto 5 (data simulada)'),
('2026-10-16', 'Cardápio da foto 6 (data simulada)'),
('2026-10-17', 'Cardápio da foto 7 (data simulada)'),
('2026-10-18', 'Cardápio da foto 9 (data simulada)'),
('2026-10-19', 'Cardápio da foto 12 (data simulada)'),
('2026-10-20', 'Cardápio da foto 13 (data simulada)'),
('2026-10-21', 'Cardápio da foto 14 (data simulada)'),
('2026-10-22', 'Cardápio da foto 15 (data simulada)'),
('2026-10-23', 'Cardápio da foto 17 (data simulada)'),
('2026-10-24', 'Cardápio da foto 18 (data simulada)'),
('2026-10-25', 'Cardápio da foto 19 (data simulada)'),
('2026-10-26', 'Cardápio da foto 20 (data simulada)');

-- 4. CARDAPIO_DIA_ITEM: os pratos do dia vendidos em cada data.
INSERT INTO cardapio_dia_item (data, id_item) VALUES
-- 13/10: carne bovina assada, isca de tilápia, frango grelhado, frango empanado, omelete
('2026-10-13', 1), ('2026-10-13', 2), ('2026-10-13', 3), ('2026-10-13', 4), ('2026-10-13', 5),
-- 14/10: ponta de peito, frango grelhado, frango empanado, omelete
('2026-10-14', 6), ('2026-10-14', 3), ('2026-10-14', 4), ('2026-10-14', 5),
-- 15/10: lasanha, sobrecoxa, frango grelhado, frango empanado, omelete
('2026-10-15', 7), ('2026-10-15', 8), ('2026-10-15', 3), ('2026-10-15', 4), ('2026-10-15', 5),
-- 16/10: carne maluca, frango grelhado, frango empanado, omelete
('2026-10-16', 9), ('2026-10-16', 3), ('2026-10-16', 4), ('2026-10-16', 5),
-- 17/10: lagarto, linguiça toscana, frango grelhado, frango empanado, omelete
('2026-10-17', 10), ('2026-10-17', 11), ('2026-10-17', 3), ('2026-10-17', 4), ('2026-10-17', 5),
-- 18/10: feijoada, bife à milanesa, frango grelhado, frango empanado, omelete
('2026-10-18', 12), ('2026-10-18', 13), ('2026-10-18', 3), ('2026-10-18', 4), ('2026-10-18', 5),
-- 19/10: carne de panela, frango grelhado, frango empanado, omelete
('2026-10-19', 14), ('2026-10-19', 3), ('2026-10-19', 4), ('2026-10-19', 5),
-- 20/10: ponta de peito, frango grelhado, frango empanado, omelete
('2026-10-20', 6), ('2026-10-20', 3), ('2026-10-20', 4), ('2026-10-20', 5),
-- 21/10: feijoada, panqueca, frango grelhado, frango empanado, omelete
('2026-10-21', 12), ('2026-10-21', 15), ('2026-10-21', 3), ('2026-10-21', 4), ('2026-10-21', 5),
-- 22/10: feijoada, panqueca, frango grelhado, frango empanado, omelete
('2026-10-22', 12), ('2026-10-22', 15), ('2026-10-22', 3), ('2026-10-22', 4), ('2026-10-22', 5),
-- 23/10: feijoada, tutu com bife, fraldinha, frango grelhado, frango empanado, omelete
('2026-10-23', 12), ('2026-10-23', 16), ('2026-10-23', 17), ('2026-10-23', 3), ('2026-10-23', 4), ('2026-10-23', 5),
-- 24/10: fraldinha, costelinha suína, frango grelhado, frango empanado, omelete
('2026-10-24', 17), ('2026-10-24', 18), ('2026-10-24', 3), ('2026-10-24', 4), ('2026-10-24', 5),
-- 25/10: feijoada, parmegiana bovina, parmegiana de frango, frango grelhado, frango empanado, omelete
('2026-10-25', 12), ('2026-10-25', 19), ('2026-10-25', 20), ('2026-10-25', 3), ('2026-10-25', 4), ('2026-10-25', 5),
-- 26/10: cupim, fraldinha, isca de tilápia, frango grelhado, frango empanado
('2026-10-26', 21), ('2026-10-26', 17), ('2026-10-26', 2), ('2026-10-26', 3), ('2026-10-26', 4);

-- 5. PORCAO: arroz e feijão (reaproveitáveis por 5 dias), os acompanhamentos das
--    fotos e as misturas (uma para cada prato do dia, ligada ao item vendido).
INSERT INTO porcao (id_porcao, nome, tipo, id_item, reaproveitavel, validade_dias) VALUES
(1, 'Arroz',  'BASE', NULL, TRUE, 5),
(2, 'Feijão', 'BASE', NULL, TRUE, 5),
(3, 'Brócolis com bacon', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(4, 'Macarronese', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(5, 'Batata doce frita', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(6, 'Legumes na manteiga', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(7, 'Batata canoa frita', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(8, 'Creme de milho', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(9, 'Purê de batata', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(10, 'Croquete de carne', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(11, 'Couve-flor gratinada', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(12, 'Banana empanada', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(13, 'Batata frita', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(14, 'Farofa da casa', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(15, 'Abobrinha empanada', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(16, 'Repolho com bacon', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(17, 'Batata sauté', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(18, 'Nhoque ao molho de tomate', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(19, 'Salada de alface e tomate', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(20, 'Mix de legumes', 'ACOMPANHAMENTO', NULL, FALSE, 0),
(21, 'Carne bovina assada', 'MISTURA', 1, FALSE, 0),
(22, 'Isca de tilápia empanada', 'MISTURA', 2, FALSE, 0),
(23, 'Filé de frango grelhado', 'MISTURA', 3, FALSE, 0),
(24, 'Filé de frango empanado', 'MISTURA', 4, FALSE, 0),
(25, 'Omelete com queijo', 'MISTURA', 5, FALSE, 0),
(26, 'Ponta de peito na pressão', 'MISTURA', 6, FALSE, 0),
(27, 'Lasanha à bolonhesa', 'MISTURA', 7, FALSE, 0),
(28, 'Sobrecoxa assada com lâminas de bacon', 'MISTURA', 8, FALSE, 0),
(29, 'Carne maluca', 'MISTURA', 9, FALSE, 0),
(30, 'Lagarto ao molho madeira', 'MISTURA', 10, FALSE, 0),
(31, 'Linguiça toscana assada', 'MISTURA', 11, FALSE, 0),
(32, 'Feijoada completa', 'MISTURA', 12, FALSE, 0),
(33, 'Bife bovino à milanesa', 'MISTURA', 13, FALSE, 0),
(34, 'Carne de panela', 'MISTURA', 14, FALSE, 0),
(35, 'Panqueca de carne bovina', 'MISTURA', 15, FALSE, 0),
(36, 'Tutu de feijão com bife bovino', 'MISTURA', 16, FALSE, 0),
(37, 'Fraldinha na pressão', 'MISTURA', 17, FALSE, 0),
(38, 'Costelinha suína no molho barbecue', 'MISTURA', 18, FALSE, 0),
(39, 'Parmegiana de filé bovino', 'MISTURA', 19, FALSE, 0),
(40, 'Parmegiana de filé de frango', 'MISTURA', 20, FALSE, 0),
(41, 'Cupim na manteiga', 'MISTURA', 21, FALSE, 0);

-- 6. PORCAO_DIA: as porções de cada dia (arroz, feijão, os acompanhamentos da foto
--    e as misturas dos pratos do dia). Os quilos ficam vazios até a cozinha registrar.
INSERT INTO porcao_dia (data, id_porcao) VALUES
-- 13/10 (foto 1)
('2026-10-13', 1), ('2026-10-13', 2), ('2026-10-13', 3), ('2026-10-13', 4), ('2026-10-13', 21), ('2026-10-13', 22), ('2026-10-13', 23), ('2026-10-13', 24), ('2026-10-13', 25),
-- 14/10 (foto 3)
('2026-10-14', 1), ('2026-10-14', 2), ('2026-10-14', 5), ('2026-10-14', 6), ('2026-10-14', 26), ('2026-10-14', 23), ('2026-10-14', 24), ('2026-10-14', 25),
-- 15/10 (foto 5)
('2026-10-15', 1), ('2026-10-15', 2), ('2026-10-15', 7), ('2026-10-15', 8), ('2026-10-15', 27), ('2026-10-15', 28), ('2026-10-15', 23), ('2026-10-15', 24), ('2026-10-15', 25),
-- 16/10 (foto 6)
('2026-10-16', 1), ('2026-10-16', 2), ('2026-10-16', 9), ('2026-10-16', 10), ('2026-10-16', 29), ('2026-10-16', 23), ('2026-10-16', 24), ('2026-10-16', 25),
-- 17/10 (foto 7)
('2026-10-17', 1), ('2026-10-17', 2), ('2026-10-17', 11), ('2026-10-17', 12), ('2026-10-17', 30), ('2026-10-17', 31), ('2026-10-17', 23), ('2026-10-17', 24), ('2026-10-17', 25),
-- 18/10 (foto 9)
('2026-10-18', 1), ('2026-10-18', 2), ('2026-10-18', 13), ('2026-10-18', 14), ('2026-10-18', 32), ('2026-10-18', 33), ('2026-10-18', 23), ('2026-10-18', 24), ('2026-10-18', 25),
-- 19/10 (foto 12)
('2026-10-19', 1), ('2026-10-19', 2), ('2026-10-19', 15), ('2026-10-19', 16), ('2026-10-19', 34), ('2026-10-19', 23), ('2026-10-19', 24), ('2026-10-19', 25),
-- 20/10 (foto 13)
('2026-10-20', 1), ('2026-10-20', 2), ('2026-10-20', 17), ('2026-10-20', 16), ('2026-10-20', 26), ('2026-10-20', 23), ('2026-10-20', 24), ('2026-10-20', 25),
-- 21/10 (foto 14)
('2026-10-21', 1), ('2026-10-21', 2), ('2026-10-21', 13), ('2026-10-21', 14), ('2026-10-21', 32), ('2026-10-21', 35), ('2026-10-21', 23), ('2026-10-21', 24), ('2026-10-21', 25),
-- 22/10 (foto 15)
('2026-10-22', 1), ('2026-10-22', 2), ('2026-10-22', 13), ('2026-10-22', 14), ('2026-10-22', 32), ('2026-10-22', 35), ('2026-10-22', 23), ('2026-10-22', 24), ('2026-10-22', 25),
-- 23/10 (foto 17)
('2026-10-23', 1), ('2026-10-23', 2), ('2026-10-23', 32), ('2026-10-23', 36), ('2026-10-23', 37), ('2026-10-23', 23), ('2026-10-23', 24), ('2026-10-23', 25),
-- 24/10 (foto 18)
('2026-10-24', 1), ('2026-10-24', 2), ('2026-10-24', 7), ('2026-10-24', 18), ('2026-10-24', 37), ('2026-10-24', 38), ('2026-10-24', 23), ('2026-10-24', 24), ('2026-10-24', 25),
-- 25/10 (foto 19)
('2026-10-25', 1), ('2026-10-25', 2), ('2026-10-25', 13), ('2026-10-25', 19), ('2026-10-25', 32), ('2026-10-25', 39), ('2026-10-25', 40), ('2026-10-25', 23), ('2026-10-25', 24), ('2026-10-25', 25),
-- 26/10 (foto 20)
('2026-10-26', 1), ('2026-10-26', 2), ('2026-10-26', 7), ('2026-10-26', 20), ('2026-10-26', 41), ('2026-10-26', 37), ('2026-10-26', 22), ('2026-10-26', 23), ('2026-10-26', 24);
