USE laboratorio_cidades_sustentaveis;

SET FOREIGN_KEY_CHECKS = 0;


-- LIMPEZA OLAP
TRUNCATE TABLE fato_ocorrencia;

TRUNCATE TABLE dim_tempo;
TRUNCATE TABLE dim_localizacao;
TRUNCATE TABLE dim_residuo;
TRUNCATE TABLE dim_status;
TRUNCATE TABLE dim_responsavel;
TRUNCATE TABLE dim_prioridade;
TRUNCATE TABLE dim_ponto_monitorado;

SET FOREIGN_KEY_CHECKS = 1;


-- DIM_TEMPO
INSERT INTO dim_tempo (
    data_completa,
    dia,
    mes,
    nome_mes,
    trimestre,
    semestre,
    ano,
    dia_semana,
    fim_semana
)
SELECT DISTINCT

    DATE(o.data_ocorrencia),

    DAY(o.data_ocorrencia),

    MONTH(o.data_ocorrencia),

    MONTHNAME(o.data_ocorrencia),

    QUARTER(o.data_ocorrencia),

    IF(MONTH(o.data_ocorrencia) <= 6, 1, 2),

    YEAR(o.data_ocorrencia),

    DAYNAME(o.data_ocorrencia),

    IF(DAYOFWEEK(o.data_ocorrencia) IN (1,7), TRUE, FALSE)

FROM ocorrencia o;


-- DIM_LOCALIZACAO
INSERT INTO dim_localizacao (
    regiao,
    bairro,
    logradouro,
    cep,
    latitude,
    longitude
)
SELECT DISTINCT

    ra.nome_regiao,
    b.nome_bairro,
    CONCAT(l.tipo_logradouro, ' ', l.nome_logradouro),
    l.cep,
    pm.latitude,
    pm.longitude

FROM ponto_monitorado pm

INNER JOIN logradouro l
    ON pm.id_logradouro = l.id_logradouro

INNER JOIN bairro b
    ON l.id_bairro = b.id_bairro

INNER JOIN regiao_administrativa ra
    ON b.id_regiao = ra.id_regiao;


-- DIM_RESIDUO
INSERT INTO dim_residuo (
    tipo_residuo,
    categoria,
    periculosidade,
    descricao
)
SELECT DISTINCT
    nome_tipo,
    categoria,
    periculosidade,
    descricao
FROM tipo_residuo;


-- DIM_STATUS
INSERT INTO dim_status (
    status,
    ordem_fluxo
)
SELECT DISTINCT
    nome_status,
    ordem_fluxo
FROM status_ocorrencia;


-- DIM_RESPONSAVEL
INSERT INTO dim_responsavel (
    nome,
    cargo
)
SELECT DISTINCT
    nome,
    cargo
FROM responsavel;


-- DIM_PRIORIDADE
INSERT INTO dim_prioridade (
    prioridade
)
SELECT DISTINCT
    prioridade
FROM ocorrencia;


-- DIM_PONTO_MONITORADO
INSERT INTO dim_ponto_monitorado (
    id_ponto_origem,
    referencia,
    ativo,
    data_cadastro
)
SELECT DISTINCT
    id_ponto,
    referencia,
    ativo,
    data_cadastro
FROM ponto_monitorado;


-- FATO_OCORRENCIA
INSERT INTO fato_ocorrencia (

    sk_tempo,
    sk_localizacao,
    sk_residuo,
    sk_status,
    sk_responsavel,
    sk_prioridade,
    sk_ponto,

    quantidade_ocorrencias,
    volume_estimado,
    quantidade_residuos,
    tempo_resolucao_horas,
    reincidencia,
    total_atendimentos
)

SELECT
    -- DIMENSÕES
    dt.sk_tempo,

    dl.sk_localizacao,

    dr.sk_residuo,

    ds.sk_status,

    dresp.sk_responsavel,

    dp.sk_prioridade,

    dpm.sk_ponto,


    -- MÉTRICAS
    1 AS quantidade_ocorrencias,

    IFNULL(orw.volume_total, 0) AS volume_estimado,

    IFNULL(orw.quantidade_total, 0) AS quantidade_residuos,

    IF(
        o.data_encerramento IS NOT NULL,

        TIMESTAMPDIFF(
            HOUR,
            o.data_abertura,
            o.data_encerramento
        ),

        NULL
    ) AS tempo_resolucao_horas,

    IF(
        (
            SELECT COUNT(*)
            FROM ocorrencia o2
            WHERE o2.id_ponto = o.id_ponto
        ) > 1,

        TRUE,
        FALSE
    ) AS reincidencia,

    IFNULL(ac.total_atendimentos, 0)

FROM ocorrencia o


-- JOIN TEMPO
INNER JOIN dim_tempo dt
    ON dt.data_completa = DATE(o.data_ocorrencia)


-- JOIN PONTO
INNER JOIN ponto_monitorado pm
    ON o.id_ponto = pm.id_ponto

INNER JOIN dim_ponto_monitorado dpm
    ON dpm.id_ponto_origem = pm.id_ponto


-- JOIN LOCALIZAÇÃO
INNER JOIN logradouro l
    ON pm.id_logradouro = l.id_logradouro

INNER JOIN bairro b
    ON l.id_bairro = b.id_bairro

INNER JOIN regiao_administrativa ra
    ON b.id_regiao = ra.id_regiao

INNER JOIN dim_localizacao dl
    ON dl.regiao = ra.nome_regiao
    AND dl.bairro = b.nome_bairro
    AND dl.logradouro = CONCAT(
        l.tipo_logradouro,
        ' ',
        l.nome_logradouro
    )


-- JOIN STATUS
INNER JOIN status_ocorrencia so
    ON o.id_status = so.id_status

INNER JOIN dim_status ds
    ON ds.status = so.nome_status


-- JOIN RESPONSÁVEL
LEFT JOIN responsavel r
    ON o.id_responsavel = r.id_responsavel

LEFT JOIN dim_responsavel dresp
    ON dresp.nome = r.nome


-- JOIN PRIORIDADE
INNER JOIN dim_prioridade dp
    ON dp.prioridade = o.prioridade


-- JOIN RESÍDUO
INNER JOIN (

    SELECT

        orr.id_ocorrencia,

        tr.nome_tipo,

        SUM(orr.volume_estimado) AS volume_total,

        SUM(orr.quantidade) AS quantidade_total

    FROM ocorrencia_residuo orr

    INNER JOIN tipo_residuo tr
        ON orr.id_tipo_residuo = tr.id_tipo_residuo

    GROUP BY
        orr.id_ocorrencia,
        tr.nome_tipo

) orw
    ON orw.id_ocorrencia = o.id_ocorrencia

INNER JOIN dim_residuo dr
    ON dr.tipo_residuo = orw.nome_tipo


-- TOTAL DE ATENDIMENTOS
LEFT JOIN (

    SELECT
        id_ocorrencia,
        COUNT(*) AS total_atendimentos

    FROM atendimento_coleta

    GROUP BY id_ocorrencia

) ac
    ON ac.id_ocorrencia = o.id_ocorrencia;


-- VALIDAÇÃO
SELECT
    COUNT(*) AS total_fatos
FROM fato_ocorrencia;

SELECT
    SUM(volume_estimado) AS volume_total
FROM fato_ocorrencia;

SELECT
    AVG(tempo_resolucao_horas) AS media_resolucao
FROM fato_ocorrencia;