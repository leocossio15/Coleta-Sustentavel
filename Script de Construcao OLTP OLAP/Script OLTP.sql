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
INSERT INTO tipo_residuo(
    nome_tipo,
    categoria,
    periculosidade,
    descricao
)
VALUES
('Entulho', 'Construção', 'MEDIA', 'Restos de obra'),
('Plástico', 'Reciclável', 'BAIXA', 'Material plástico'),
('Vidro', 'Reciclável', 'MEDIA', 'Fragmentos de vidro'),
('Metal', 'Reciclável', 'BAIXA', 'Sucata metálica'),
('Madeira', 'Orgânico', 'BAIXA', 'Restos de madeira'),
('Pneu', 'Especial', 'ALTA', 'Pneus descartados'),
('Hospitalar', 'Saúde', 'ALTA', 'Lixo hospitalar'),
('Eletrônico', 'Tecnológico', 'MEDIA', 'Equipamentos eletrônicos'),
('Óleo', 'Químico', 'ALTA', 'Óleo descartado'),
('Podas', 'Orgânico', 'BAIXA', 'Restos vegetais');


-- STATUS
INSERT INTO status_ocorrencia(
    nome_status,
    descricao,
    ordem_fluxo
)
VALUES
('ABERTA', 'Ocorrência aberta', 1),
('EM_ANALISE', 'Em análise', 2),
('EM_ATENDIMENTO', 'Equipe acionada', 3),
('FINALIZADA', 'Ocorrência encerrada', 4),
('CANCELADA', 'Ocorrência cancelada', 5);


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


-- OCORRÊNCIAS
DELIMITER $$

CREATE PROCEDURE inserir_ocorrencias()
BEGIN

    DECLARE i INT DEFAULT 1;

    DECLARE ponto_id INT;
    DECLARE status_id INT;
    DECLARE resp_id INT;

    DECLARE dt DATETIME;

    WHILE i <= 15000 DO

        SET ponto_id = FLOOR(1 + RAND()*2000);
        SET status_id = FLOOR(1 + RAND()*5);
        SET resp_id = FLOOR(1 + RAND()*80);

        SET dt = DATE_SUB(
            NOW(),
            INTERVAL FLOOR(RAND()*1000) DAY
        );

        INSERT INTO ocorrencia(
            id_ponto,
            id_status,
            id_responsavel,
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

            dt,

            DATE_SUB(
                dt,
                INTERVAL FLOOR(RAND()*48) HOUR
            ),

            CONCAT(
                'Descarte irregular identificado no ponto ',
                ponto_id
            ),

            IF(
                status_id = 4,
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