USE laboratorio_cidades_sustentaveis;

SET FOREIGN_KEY_CHECKS = 0;


-- LIMPEZA
TRUNCATE TABLE vistoria_ponto;
TRUNCATE TABLE atendimento_coleta;
TRUNCATE TABLE ocorrencia_residuo;
TRUNCATE TABLE ocorrencia;

TRUNCATE TABLE ponto_monitorado;
TRUNCATE TABLE logradouro;
TRUNCATE TABLE bairro;
TRUNCATE TABLE regiao_administrativa;

TRUNCATE TABLE tipo_residuo;
TRUNCATE TABLE status_ocorrencia;
TRUNCATE TABLE responsavel;
TRUNCATE TABLE denunciante;

SET FOREIGN_KEY_CHECKS = 1;


-- REGIÕES
INSERT INTO regiao_administrativa(nome_regiao, descricao)
VALUES
('Centro', 'Região central'),
('Norte', 'Região norte'),
('Sul', 'Região sul'),
('Leste', 'Região leste'),
('Oeste', 'Região oeste'),
('Industrial', 'Área industrial'),
('Orla', 'Região costeira'),
('Rural', 'Zona rural'),
('Expansão', 'Área de expansão urbana'),
('Histórica', 'Região histórica');


-- BAIRROS
DELIMITER $$

CREATE PROCEDURE inserir_bairros()
BEGIN

    DECLARE i INT DEFAULT 1;
    DECLARE reg INT;

    WHILE i <= 60 DO

        SET reg = FLOOR(1 + RAND() * 10);

        INSERT INTO bairro(
            id_regiao,
            nome_bairro,
            cep_principal
        )
        VALUES (
            reg,
            CONCAT('Bairro_', i),
            CONCAT(
                FLOOR(10000 + RAND()*89999),
                '-',
                FLOOR(100 + RAND()*899)
            )
        );

        SET i = i + 1;

    END WHILE;

END $$

DELIMITER ;

CALL inserir_bairros();


-- LOGRADOUROS
DELIMITER $$

CREATE PROCEDURE inserir_logradouros()
BEGIN

    DECLARE i INT DEFAULT 1;
    DECLARE bairro_id INT;

    WHILE i <= 400 DO

        SET bairro_id = FLOOR(1 + RAND() * 60);

        INSERT INTO logradouro(
            id_bairro,
            tipo_logradouro,
            nome_logradouro,
            cep
        )
        VALUES (
            bairro_id,
            ELT(
                FLOOR(1 + RAND()*5),
                'Rua',
                'Avenida',
                'Travessa',
                'Alameda',
                'Praça'
            ),
            CONCAT('Logradouro_', i),
            CONCAT(
                FLOOR(10000 + RAND()*89999),
                '-',
                FLOOR(100 + RAND()*899)
            )
        );

        SET i = i + 1;

    END WHILE;

END $$

DELIMITER ;

CALL inserir_logradouros();


-- PONTOS MONITORADOS
DELIMITER $$

CREATE PROCEDURE inserir_pontos()
BEGIN

    DECLARE i INT DEFAULT 1;
    DECLARE log_id INT;

    WHILE i <= 2000 DO

        SET log_id = FLOOR(1 + RAND() * 400);

        INSERT INTO ponto_monitorado(
            id_logradouro,
            numero,
            complemento,
            referencia,
            latitude,
            longitude,
            ativo,
            data_cadastro
        )
        VALUES (
            log_id,
            FLOOR(1 + RAND()*999),
            CONCAT('Comp_', i),
            CONCAT('Próximo ao ponto ', i),

            -12.90 + (RAND()/10),
            -38.50 + (RAND()/10),

            IF(RAND() > 0.1, TRUE, FALSE),

            DATE_SUB(
                CURDATE(),
                INTERVAL FLOOR(RAND()*1500) DAY
            )
        );

        SET i = i + 1;

    END WHILE;

END $$

DELIMITER ;

CALL inserir_pontos();


-- TIPOS DE RESÍDUOS
-- [AJUSTADO] Adicionados cor_padrao_conama e classe_nbr conforme CONAMA 275/2001 e NBR ABNT 10.004/2004
INSERT INTO tipo_residuo(
    nome_tipo,
    categoria,
    periculosidade,
    descricao,
    cor_padrao_conama,
    classe_nbr
)
VALUES
('Entulho',    'Construção',   'MEDIA', 'Restos de obra',                'CINZA',    'CLASSE_II_A'),
('Plástico',   'Reciclável',   'BAIXA', 'Material plástico',             'VERMELHO', 'CLASSE_II_B'),
('Vidro',      'Reciclável',   'MEDIA', 'Fragmentos de vidro',           'VERDE',    'CLASSE_II_A'),
('Metal',      'Reciclável',   'BAIXA', 'Sucata metálica',               'AMARELO',  'CLASSE_II_B'),
('Madeira',    'Orgânico',     'BAIXA', 'Restos de madeira',             'CINZA',    'CLASSE_II_B'),
('Pneu',       'Especial',     'ALTA',  'Pneus descartados',             'LARANJA',  'CLASSE_I'),
('Hospitalar', 'Saúde',        'ALTA',  'Lixo hospitalar',               'BRANCO',   'CLASSE_I'),
('Eletrônico', 'Tecnológico',  'MEDIA', 'Equipamentos eletrônicos',      'LARANJA',  'CLASSE_II_A'),
('Óleo',       'Químico',      'ALTA',  'Óleo descartado',               'LARANJA',  'CLASSE_I'),
('Podas',      'Orgânico',     'BAIXA', 'Restos vegetais',               'MARROM',   'CLASSE_II_B');


-- STATUS
-- [AJUSTADO] Substituídos pelos status corretos do fluxo revisado (Script Parte 2)
INSERT INTO status_ocorrencia(
    nome_status,
    descricao,
    ordem_fluxo
)
VALUES
('PENDENTE_VALIDACAO',
 'Ocorrência recém-registrada. Aguarda análise de responsável técnico antes de entrar no fluxo operacional.',
 1),
('ABERTA',
 'Ocorrência validada e confirmada por responsável. Entra no fluxo de atendimento.',
 2),
('EM_ATENDIMENTO',
 'Atendimento de coleta agendado ou em execução.',
 3),
('ENCERRADA',
 'Coleta concluída e ponto saneado.',
 4),
('REJEITADA',
 'Ocorrência analisada e descartada. Motivo registrado obrigatoriamente em motivo_rejeicao.',
 5),
('DUPLICADA',
 'Ocorrência identificada como duplicata de registro já existente para o mesmo ponto e período.',
 6);


-- RESPONSÁVEIS
DELIMITER $$

CREATE PROCEDURE inserir_responsaveis()
BEGIN

    DECLARE i INT DEFAULT 1;

    WHILE i <= 80 DO

        INSERT INTO responsavel(
            nome,
            cargo,
            telefone,
            email
        )
        VALUES (

            CONCAT('Responsavel_', i),

            ELT(
                FLOOR(1 + RAND()*5),
                'Fiscal Ambiental',
                'Coordenador',
                'Analista',
                'Supervisor',
                'Agente Urbano'
            ),

            CONCAT(
                '(71)9',
                FLOOR(1000 + RAND()*8999),
                '-',
                FLOOR(1000 + RAND()*8999)
            ),

            CONCAT(
                'resp',
                i,
                '@cidade.gov.br'
            )
        );

        SET i = i + 1;

    END WHILE;

END $$

DELIMITER ;

CALL inserir_responsaveis();


-- DENUNCIANTES
-- [NOVO] Popula tabela criada na Parte 2 com hashes fictícios representando CPFs anonimizados
-- Denunciantes ativos (ids 1-9)
INSERT INTO denunciante (cpf_hash, bloqueado)
VALUES
(SHA2('111.111.111-11', 256), FALSE),
(SHA2('222.222.222-22', 256), FALSE),
(SHA2('333.333.333-33', 256), FALSE),
(SHA2('444.444.444-44', 256), FALSE),
(SHA2('555.555.555-55', 256), FALSE),
(SHA2('666.666.666-66', 256), FALSE),
(SHA2('777.777.777-77', 256), FALSE),
(SHA2('888.888.888-88', 256), FALSE),
(SHA2('999.999.999-99', 256), FALSE);

-- Denunciante bloqueado por denúncia falsa confirmada (id 10)
INSERT INTO denunciante (cpf_hash, bloqueado, data_bloqueio, motivo_bloqueio)
VALUES (SHA2('000.000.000-00', 256), TRUE, NOW(), 'DENUNCIA_FALSA_CONFIRMADA');


-- OCORRÊNCIAS
-- [AJUSTADO] Range de status atualizado para 1-6 (eram 1-5).
--             data_encerramento preenchida para status 4 (ENCERRADA) e 5 (REJEITADA).
DELIMITER $$

CREATE PROCEDURE inserir_ocorrencias()
BEGIN

    DECLARE i INT DEFAULT 1;

    DECLARE ponto_id INT;
    DECLARE status_id INT;
    DECLARE resp_id INT;
    DECLARE den_id INT;

    DECLARE dt DATETIME;

    WHILE i <= 15000 DO

        SET ponto_id  = FLOOR(1 + RAND()*2000);
        SET status_id = FLOOR(1 + RAND()*6);   -- [AJUSTADO] era RAND()*5
        SET resp_id   = FLOOR(1 + RAND()*80);

        -- Aproximadamente 30% das ocorrências são de denunciantes cidadãos (id 1-9; id 10 está bloqueado)
        SET den_id = IF(RAND() < 0.3, FLOOR(1 + RAND()*9), NULL);

        SET dt = DATE_SUB(
            NOW(),
            INTERVAL FLOOR(RAND()*1000) DAY
        );

        INSERT INTO ocorrencia(
            id_ponto,
            id_status,
            id_responsavel,
            id_denunciante,
            data_abertura,
            data_ocorrencia,
            descricao,
            data_encerramento,
            prioridade,
            observacao,
            url_anexo
        )
        VALUES (

            ponto_id,
            status_id,
            resp_id,
            den_id,

            dt,

            DATE_SUB(
                dt,
                INTERVAL FLOOR(RAND()*48) HOUR
            ),

            CONCAT(
                'Descarte irregular identificado no ponto ',
                ponto_id
            ),

            -- [AJUSTADO] Preenche data_encerramento para ENCERRADA (4) e REJEITADA (5)
            IF(
                status_id IN (4, 5),
                DATE_ADD(
                    dt,
                    INTERVAL FLOOR(RAND()*10) DAY
                ),
                NULL
            ),

            ELT(
                FLOOR(1 + RAND()*4),
                'BAIXA',
                'MEDIA',
                'ALTA',
                'URGENTE'
            ),

            'Ocorrência gerada automaticamente',

            CONCAT(
                'https://anexo.fake/imagem_',
                i,
                '.jpg'
            )
        );

        SET i = i + 1;

    END WHILE;

END $$

DELIMITER ;

CALL inserir_ocorrencias();


-- [AJUSTADO] Popula motivo_rejeicao para ocorrências com status REJEITADA
UPDATE ocorrencia o
INNER JOIN status_ocorrencia s ON o.id_status = s.id_status
SET o.motivo_rejeicao = ELT(
    FLOOR(1 + RAND()*3),
    'DENUNCIA_FALSA_CONFIRMADA',
    'SEM_EVIDENCIA_SUFICIENTE',
    'FORA_DA_AREA_DE_COBERTURA'
)
WHERE s.nome_status = 'REJEITADA';


-- OCORRÊNCIA RESÍDUO
DELIMITER $$

CREATE PROCEDURE inserir_ocorrencia_residuo()
BEGIN

    DECLARE i INT DEFAULT 1;

    DECLARE ocorrencia_id INT;
    DECLARE residuo_id INT;

    WHILE i <= 25000 DO

        SET ocorrencia_id = FLOOR(1 + RAND()*15000);
        SET residuo_id = FLOOR(1 + RAND()*10);

        INSERT INTO ocorrencia_residuo(
            id_ocorrencia,
            id_tipo_residuo,
            volume_estimado,
            unidade_medida,
            quantidade
        )
        VALUES (

            ocorrencia_id,
            residuo_id,

            ROUND(
                1 + (RAND()*500),
                2
            ),

            ELT(
                FLOOR(1 + RAND()*3),
                'KG',
                'M3',
                'LITROS'
            ),

            FLOOR(1 + RAND()*100)
        );

        SET i = i + 1;

    END WHILE;

END $$

DELIMITER ;

CALL inserir_ocorrencia_residuo();


-- ATENDIMENTOS
DELIMITER $$

CREATE PROCEDURE inserir_atendimentos()
BEGIN

    DECLARE i INT DEFAULT 1;

    WHILE i <= 10000 DO

        INSERT INTO atendimento_coleta(
            id_ocorrencia,
            id_responsavel,
            data_agendada,
            data_inicio,
            data_fim,
            volume_removido,
            unidade_medida,
            status_atendimento,
            observacao
        )
        VALUES (

            FLOOR(1 + RAND()*15000),

            FLOOR(1 + RAND()*80),

            NOW() - INTERVAL FLOOR(RAND()*500) DAY,

            NOW() - INTERVAL FLOOR(RAND()*400) DAY,

            NOW() - INTERVAL FLOOR(RAND()*300) DAY,

            ROUND(
                1 + RAND()*300,
                2
            ),

            'KG',

            ELT(
                FLOOR(1 + RAND()*4),
                'AGENDADO',
                'EM_EXECUCAO',
                'FINALIZADO',
                'CANCELADO'
            ),

            'Atendimento executado'
        );

        SET i = i + 1;

    END WHILE;

END $$

DELIMITER ;

CALL inserir_atendimentos();


-- VISTORIAS
DELIMITER $$

CREATE PROCEDURE inserir_vistorias()
BEGIN

    DECLARE i INT DEFAULT 1;

    WHILE i <= 8000 DO

        INSERT INTO vistoria_ponto(
            id_ponto,
            id_responsavel,
            data_vistoria,
            nivel_acumulo,
            condicao_local,
            observacao
        )
        VALUES (

            FLOOR(1 + RAND()*2000),

            FLOOR(1 + RAND()*80),

            NOW() - INTERVAL FLOOR(RAND()*1000) DAY,

            ELT(
                FLOOR(1 + RAND()*4),
                'BAIXO',
                'MEDIO',
                'ALTO',
                'CRITICO'
            ),

            ELT(
                FLOOR(1 + RAND()*4),
                'Regular',
                'Crítico',
                'Necessita limpeza',
                'Monitoramento contínuo'
            ),

            'Vistoria realizada'
        );

        SET i = i + 1;

    END WHILE;

END $$

DELIMITER ;

CALL inserir_vistorias();


-- FIM
SELECT 'POPULAÇÃO CONCLUÍDA' AS STATUS;