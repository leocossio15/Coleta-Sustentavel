-- =========================================================
-- PROJETO: LABORATÓRIO DE DADOS PARA CIDADES SUSTENTÁVEIS
-- DASHBOARD TÁTICO
-- =========================================================

USE laboratorio_cidades_sustentaveis;


-- CONSULTA 1 - Distribuição das ocorrências por status e região
-- Retrata onde as ocorrências estão travadas e onde fluem,
-- dando ao gestor uma visão do estado atual do pipeline por área.

SELECT
    dl.regiao,
    ds.status,
    SUM(fo.quantidade_ocorrencias) AS total_ocorrencias,
    ROUND(
        100.0 * SUM(fo.quantidade_ocorrencias) /
        SUM(SUM(fo.quantidade_ocorrencias)) OVER (PARTITION BY dl.regiao),
        2
    ) AS pct_na_regiao
FROM fato_ocorrencia  fo
INNER JOIN dim_localizacao dl ON fo.sk_localizacao = dl.sk_localizacao
INNER JOIN dim_status      ds ON fo.sk_status      = ds.sk_status
GROUP BY
    dl.regiao,
    ds.status,
    ds.ordem_fluxo
ORDER BY
    dl.regiao,
    ds.ordem_fluxo;


-- CONSULTA 2 - Comparativo mensal: mês atual vs mês anterior
-- Mostra se o cenário está melhorando ou piorando em volume de
-- ocorrências e resíduos, por região.

SELECT
    dl.regiao,
    SUM(CASE WHEN dt.ano  = YEAR(CURDATE())
              AND dt.mes  = MONTH(CURDATE())
             THEN fo.quantidade_ocorrencias ELSE 0 END) AS ocorrencias_mes_atual,
    SUM(CASE WHEN dt.data_completa >= DATE_SUB(CURDATE(), INTERVAL 2 MONTH)
              AND dt.data_completa <  DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
             THEN fo.quantidade_ocorrencias ELSE 0 END) AS ocorrencias_mes_anterior,
    SUM(CASE WHEN dt.ano  = YEAR(CURDATE())
              AND dt.mes  = MONTH(CURDATE())
             THEN fo.volume_estimado ELSE 0 END)        AS volume_mes_atual,
    SUM(CASE WHEN dt.data_completa >= DATE_SUB(CURDATE(), INTERVAL 2 MONTH)
              AND dt.data_completa <  DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
             THEN fo.volume_estimado ELSE 0 END)        AS volume_mes_anterior
FROM fato_ocorrencia  fo
INNER JOIN dim_tempo       dt ON fo.sk_tempo       = dt.sk_tempo
INNER JOIN dim_localizacao dl ON fo.sk_localizacao = dl.sk_localizacao
GROUP BY
    dl.regiao
ORDER BY
    ocorrencias_mes_atual DESC;


-- CONSULTA 3 - Concentração de ocorrências por bairro
-- Identifica quais bairros acumulam mais volume e ocorrências,
-- revelando os pontos de maior pressão sobre a operação.

SELECT
    dl.regiao,
    dl.bairro,
    SUM(fo.quantidade_ocorrencias) AS total_ocorrencias,
    SUM(fo.volume_estimado)        AS volume_total,
    ROUND(AVG(fo.volume_estimado), 2) AS volume_medio_por_ocorrencia,
    SUM(fo.reincidencia)           AS ocorrencias_reincidentes
FROM fato_ocorrencia  fo
INNER JOIN dim_localizacao dl ON fo.sk_localizacao = dl.sk_localizacao
GROUP BY
    dl.regiao,
    dl.bairro
ORDER BY
    total_ocorrencias DESC;


-- CONSULTA 4 - Composição do descarte por tipo de resíduo e região
-- Mostra o que predomina em cada área, permitindo entender
-- o perfil de descarte irregular por região.

SELECT
    dl.regiao,
    dres.tipo_residuo,
    dres.categoria,
    dres.periculosidade,
    SUM(fo.quantidade_ocorrencias) AS total_ocorrencias,
    SUM(fo.volume_estimado)        AS volume_total,
    ROUND(
        100.0 * SUM(fo.volume_estimado) /
        SUM(SUM(fo.volume_estimado)) OVER (PARTITION BY dl.regiao),
        2
    ) AS pct_volume_na_regiao
FROM fato_ocorrencia  fo
INNER JOIN dim_localizacao dl   ON fo.sk_localizacao = dl.sk_localizacao
INNER JOIN dim_residuo     dres ON fo.sk_residuo     = dres.sk_residuo
GROUP BY
    dl.regiao,
    dres.tipo_residuo,
    dres.categoria,
    dres.periculosidade
ORDER BY
    dl.regiao,
    volume_total DESC;


-- CONSULTA 5 - Carga de trabalho por responsável e cargo
-- Retrata como as ocorrências estão distribuídas entre as equipes,
-- sem julgamento de desempenho — apenas o retrato da alocação atual.

SELECT
    dr.cargo,
    dr.nome,
    SUM(fo.quantidade_ocorrencias)                       AS total_ocorrencias,
    SUM(fo.total_atendimentos)                           AS total_atendimentos,
    COUNT(DISTINCT fo.sk_localizacao)                    AS regioes_atendidas,
    ROUND(AVG(fo.tempo_resolucao_horas), 2)              AS media_horas_resolucao
FROM fato_ocorrencia  fo
INNER JOIN dim_responsavel dr ON fo.sk_responsavel = dr.sk_responsavel
GROUP BY
    dr.cargo,
    dr.nome
ORDER BY
    dr.cargo,
    total_ocorrencias DESC;
