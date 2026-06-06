-- =========================================================
-- PROJETO: LABORATÓRIO DE DADOS PARA CIDADES SUSTENTÁVEIS
-- DASHBOARD ESTRATÉGICO
-- =========================================================

USE laboratorio_cidades_sustentaveis;


-- CONSULTA E1 - Volume de resíduos por região
-- Agrega o volume estimado total de resíduos por região administrativa.
-- Permite identificar quais áreas concentram maior pressão de descarte
-- irregular, subsidiando decisões estratégicas de alocação de recursos.

SELECT
    l.regiao,
    SUM(f.volume_estimado) AS volume_total
FROM fato_ocorrencia f
JOIN dim_localizacao l
    ON f.sk_localizacao = l.sk_localizacao
GROUP BY l.regiao
ORDER BY volume_total DESC;


-- CONSULTA E2 - Evolução mensal das ocorrências
-- Série histórica completa de ocorrências agregadas por ano e mês.
-- Permite identificar sazonalidade, tendências de crescimento ou queda
-- e comparar o desempenho entre anos distintos.

SELECT
    t.ano,
    t.mes,
    t.nome_mes,
    SUM(f.quantidade_ocorrencias) AS total_ocorrencias
FROM fato_ocorrencia f
JOIN dim_tempo t
    ON f.sk_tempo = t.sk_tempo
GROUP BY t.ano, t.mes, t.nome_mes
ORDER BY t.ano, t.mes;


-- CONSULTA E3 - Índice de reincidência por região
-- Calcula o percentual médio de reincidência por região.
-- Alta reincidência indica problema estrutural — pontos de descarte
-- habitual que exigem intervenção permanente, não apenas coletas pontuais.

SELECT
    l.regiao,
    ROUND(
        AVG(f.reincidencia) * 100,
        2
    ) AS percentual_reincidencia
FROM fato_ocorrencia f
JOIN dim_localizacao l
    ON f.sk_localizacao = l.sk_localizacao
GROUP BY l.regiao
ORDER BY percentual_reincidencia DESC;


-- CONSULTA E4 - Tempo médio de resolução por prioridade
-- Apura o tempo médio (em horas) para resolver ocorrências, segmentado
-- por nível de prioridade. Desvios em relação ao SLA estratégico de
-- referência sinalizam gargalos operacionais que demandam ajuste.

SELECT
    p.prioridade,
    ROUND(
        AVG(f.tempo_resolucao_horas),
        2
    ) AS tempo_medio_horas
FROM fato_ocorrencia f
JOIN dim_prioridade p
    ON f.sk_prioridade = p.sk_prioridade
GROUP BY p.prioridade
ORDER BY tempo_medio_horas DESC;


-- CONSULTA E5 - Tipos de resíduos mais encontrados
-- Totaliza a quantidade de resíduos por tipo, revelando o perfil do
-- descarte irregular. Subsidia políticas públicas de educação ambiental
-- direcionadas aos materiais de maior incidência.

SELECT
    r.tipo_residuo,
    SUM(f.quantidade_residuos) AS total_residuos
FROM fato_ocorrencia f
JOIN dim_residuo r
    ON f.sk_residuo = r.sk_residuo
GROUP BY r.tipo_residuo
ORDER BY total_residuos DESC;


-- CONSULTA E6 - Ranking de bairros críticos
-- Os 10 bairros com maior volume de ocorrências registradas.
-- Identifica geograficamente os pontos de maior pressão operacional,
-- orientando priorização de rotas e reforço de equipes de campo.

SELECT
    l.bairro,
    l.regiao,
    SUM(f.quantidade_ocorrencias) AS total_ocorrencias
FROM fato_ocorrencia f
JOIN dim_localizacao l
    ON f.sk_localizacao = l.sk_localizacao
GROUP BY l.bairro, l.regiao
ORDER BY total_ocorrencias DESC
LIMIT 10;


-- CONSULTA E7 - Eficiência da coleta por região
-- Taxa percentual de atendimentos realizados em relação ao total de
-- ocorrências por região. É o KPI estratégico central: taxa abaixo
-- da meta (85%) indica necessidade de revisão de capacidade ou rota.
-- NULLIF protege contra divisão por zero.

SELECT
    l.regiao,
    SUM(f.quantidade_ocorrencias) AS ocorrencias,
    SUM(f.total_atendimentos)     AS atendimentos,
    ROUND(
        (SUM(f.total_atendimentos) /
         NULLIF(SUM(f.quantidade_ocorrencias), 0)) * 100,
        2
    ) AS taxa_atendimento
FROM fato_ocorrencia f
INNER JOIN dim_localizacao l
    ON f.sk_localizacao = l.sk_localizacao
GROUP BY l.regiao
ORDER BY taxa_atendimento DESC;
