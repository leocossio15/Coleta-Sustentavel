# =============================================================================
# ANÁLISE EXPLORATÓRIA DE DADOS — K-MEANS
# Projeto: Coleta de Resíduos Urbanos em Cidades Sustentáveis
#
# PROBLEMA:
# "Quais bairros têm maior probabilidade de reincidência de descarte
#  irregular, com base no histórico de ocorrências e perfil de resíduos?"
#
# MÉTODO: K-Means (Clustering não supervisionado)
# Justificativa: o problema não possui rótulos pré-definidos de risco.
# O K-Means identifica grupos naturais de bairros com perfis semelhantes
# a partir das métricas operacionais, sem necessidade de treinamento
# supervisionado. O resultado é interpretável: cada cluster corresponde
# a um perfil de intervenção (crítico, moderado, controlado).
# =============================================================================

pacotes <- c(
  "DBI",
  "RMySQL",
  "dplyr",
  "ggplot2",
  "cluster",
  "factoextra",
  "tidyr",
  "scales"
)

instalar_se_precisar <- function(pacote) {
  if (!requireNamespace(pacote, quietly = TRUE)) {
    install.packages(pacote, dependencies = TRUE)
  }
  library(pacote, character.only = TRUE)
}

invisible(lapply(pacotes, instalar_se_precisar))

source("conexao.R")

# =============================================================================
# PASSO 1: EXTRAÇÃO DAS FEATURES VIA OLAP
# =============================================================================
# Cada linha = um bairro. Features extraídas de fato_ocorrencia.

sql_features <- "
  SELECT
    dl.bairro,
    dl.regiao,

    -- FEATURE 1: frequência de ocorrências (volume bruto)
    COUNT(*)                                           AS frequencia_ocorrencias,

    -- FEATURE 2: taxa histórica de reincidência (%)
    ROUND(AVG(fo.reincidencia) * 100, 2)               AS taxa_reincidencia_pct,

    -- FEATURE 3: volume médio estimado por ocorrência
    ROUND(AVG(fo.volume_estimado), 2)                  AS volume_medio,

    -- FEATURE 4: tempo médio de resolução (horas)
    ROUND(AVG(fo.tempo_resolucao_horas), 2)            AS tempo_medio_resolucao_h,

    -- FEATURE 5: proporção de resíduos de alta periculosidade (%)
    ROUND(
      SUM(CASE WHEN dr.periculosidade = 'ALTA' THEN 1 ELSE 0 END)
      / COUNT(*) * 100
    , 2)                                               AS pct_alta_periculosidade,

    -- FEATURE 6: razão atendimentos/ocorrências (cobertura operacional)
    ROUND(
      SUM(fo.total_atendimentos) / NULLIF(COUNT(*), 0)
    , 2)                                               AS razao_atendimento
  FROM fato_ocorrencia fo
  INNER JOIN dim_localizacao dl  ON fo.sk_localizacao = dl.sk_localizacao
  INNER JOIN dim_residuo     dr  ON fo.sk_residuo     = dr.sk_residuo
  GROUP BY dl.bairro, dl.regiao
  HAVING COUNT(*) >= 5
"

cat("Extraindo features do data warehouse...\n")
df_raw <- dbGetQuery(con, sql_features)
cat(sprintf("Bairros com histórico suficiente: %d\n", nrow(df_raw)))

# =============================================================================
# PASSO 2: PRÉ-PROCESSAMENTO
# =============================================================================

df_clean <- df_raw |>
  mutate(
    tempo_medio_resolucao_h = ifelse(is.na(tempo_medio_resolucao_h), 0,
                                     tempo_medio_resolucao_h)
  ) |>
  filter(!is.na(taxa_reincidencia_pct))

features_cols <- c(
  "frequencia_ocorrencias",
  "taxa_reincidencia_pct",
  "volume_medio",
  "tempo_medio_resolucao_h",
  "pct_alta_periculosidade",
  "razao_atendimento"
)

df_features <- df_clean |> select(all_of(features_cols))

# Normalização Z-score: K-Means é sensível à escala.
# Sem normalização, frequencia_ocorrencias dominaria por ter maior amplitude.
df_scaled <- scale(df_features)
rownames(df_scaled) <- df_clean$bairro

cat("\nEstatísticas descritivas das features (escala original):\n")
print(summary(df_features))

# =============================================================================
# PASSO 3: MÉTODO ELBOW — ESCOLHA DO K
# =============================================================================

set.seed(42)

wcss <- sapply(2:8, function(k) {
  kmeans(df_scaled, centers = k, nstart = 25, iter.max = 100)$tot.withinss
})

df_elbow <- data.frame(k = 2:8, wcss = wcss)

p_elbow <- ggplot(df_elbow, aes(x = k, y = wcss)) +
  geom_line(color = "#3498DB", linewidth = 1) +
  geom_point(color = "#3498DB", size = 3) +
  geom_vline(xintercept = 4, linetype = "dashed", color = "#E74C3C", alpha = 0.7) +
  annotate("text", x = 4.2, y = max(wcss) * 0.85,
           label = "k = 4\n(cotovelo)", hjust = 0, size = 3.5, color = "#E74C3C") +
  scale_x_continuous(breaks = 2:8) +
  labs(
    title    = "Método Elbow — escolha do número de clusters",
    subtitle = "O cotovelo indica k ótimo: menor ganho marginal de redução da variância",
    x        = "Número de clusters (k)",
    y        = "WCSS (variância intra-cluster)"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

print(p_elbow)

# =============================================================================
# PASSO 4: TREINAMENTO DO MODELO K-MEANS (k = 4)
# =============================================================================

set.seed(42)
k_otimo <- 4

modelo_kmeans <- kmeans(df_scaled, centers = k_otimo, nstart = 50, iter.max = 200)

cat(sprintf("\nK-Means treinado com k = %d\n", k_otimo))
cat(sprintf("Variância explicada pelos clusters: %.1f%%\n",
            modelo_kmeans$betweenss / modelo_kmeans$totss * 100))

df_resultado <- df_clean |>
  mutate(cluster = as.factor(modelo_kmeans$cluster))

# =============================================================================
# PASSO 5: INTERPRETAÇÃO DOS CLUSTERS
# =============================================================================

perfil_clusters <- df_resultado |>
  group_by(cluster) |>
  summarise(
    n_bairros            = n(),
    freq_media           = round(mean(frequencia_ocorrencias), 1),
    reincidencia_media   = round(mean(taxa_reincidencia_pct), 1),
    volume_medio_med     = round(mean(volume_medio), 1),
    tempo_medio_med      = round(mean(tempo_medio_resolucao_h), 1),
    pct_perig_alta       = round(mean(pct_alta_periculosidade), 1),
    razao_atend_med      = round(mean(razao_atendimento), 2),
    .groups = "drop"
  ) |>
  arrange(desc(reincidencia_media), desc(freq_media))

cat("\nPerfil médio por cluster (escala original):\n")
print(perfil_clusters)

# Atribuição de rótulos: maior score composto = CRÍTICO
niveis_risco <- perfil_clusters |>
  mutate(
    score = reincidencia_media * 0.6 + (freq_media / max(freq_media)) * 40,
    risco = case_when(
      score == max(score)                                              ~ "CRÍTICO",
      reincidencia_media >= median(perfil_clusters$reincidencia_media) ~ "ESTRUTURAL",
      freq_media >= median(perfil_clusters$freq_media)                 ~ "OPERACIONAL",
      TRUE                                                             ~ "CONTROLADO"
    )
  ) |>
  select(cluster, risco)

df_resultado <- df_resultado |>
  left_join(niveis_risco, by = "cluster")

cat("\nDistribuição de bairros por nível de risco:\n")
print(table(df_resultado$risco))

# =============================================================================
# PASSO 6: VISUALIZAÇÕES
# =============================================================================

cores_risco <- c(
  "CRÍTICO"     = "#E74C3C",
  "ESTRUTURAL"  = "#F39C12",
  "OPERACIONAL" = "#3498DB",
  "CONTROLADO"  = "#2ECC71"
)

# 6.1 Scatter principal: frequência vs reincidência, colorido por cluster
p_scatter <- ggplot(
  df_resultado,
  aes(x = frequencia_ocorrencias, y = taxa_reincidencia_pct, color = risco)
) +
  geom_point(size = 3, alpha = 0.8) +
  scale_color_manual(values = cores_risco, name = "Perfil de risco") +
  labs(
    title    = "Segmentação de bairros por perfil de reincidência (K-Means, k = 4)",
    subtitle = "Cada ponto = um bairro. Posição indica volume de ocorrências e taxa de reincidência",
    x        = "Frequência de ocorrências (total histórico)",
    y        = "Taxa de reincidência (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"), legend.position = "bottom")

print(p_scatter)

# 6.2 Boxplot: variação da reincidência dentro de cada cluster
p_box <- ggplot(
  df_resultado,
  aes(x = reorder(risco, taxa_reincidencia_pct, median),
      y = taxa_reincidencia_pct, fill = risco)
) +
  geom_boxplot(alpha = 0.8, outlier.shape = 21) +
  scale_fill_manual(values = cores_risco) +
  labs(
    title = "Distribuição da taxa de reincidência por cluster",
    x     = "Perfil de risco",
    y     = "Taxa de reincidência (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"), legend.position = "none")

print(p_box)

# 6.3 Top bairros críticos
top_criticos <- df_resultado |>
  filter(risco == "CRÍTICO") |>
  arrange(desc(taxa_reincidencia_pct), desc(frequencia_ocorrencias)) |>
  slice_head(n = 15)

p_criticos <- ggplot(
  top_criticos,
  aes(x = taxa_reincidencia_pct,
      y = reorder(bairro, taxa_reincidencia_pct),
      fill = regiao)
) +
  geom_bar(stat = "identity", alpha = 0.85) +
  geom_text(aes(label = paste0(taxa_reincidencia_pct, "%")),
            hjust = -0.1, size = 3) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title    = "Top 15 bairros CRÍTICOS por taxa de reincidência",
    subtitle = "Bairros que exigem intervenção prioritária imediata",
    x        = "Taxa de reincidência (%)",
    y        = "",
    fill     = "Região"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"))

print(p_criticos)

# =============================================================================
# RESULTADO FINAL
# =============================================================================

cat("\n=== RELATÓRIO K-MEANS — PERFIS DE RISCO ===\n")
cat("Variância explicada: ",
    round(modelo_kmeans$betweenss / modelo_kmeans$totss * 100, 1), "%\n\n")

relatorio_final <- df_resultado |>
  arrange(risco, desc(taxa_reincidencia_pct)) |>
  select(bairro, regiao, risco, frequencia_ocorrencias,
         taxa_reincidencia_pct, pct_alta_periculosidade)

print(relatorio_final)

cat("\nInterpretação dos clusters:\n")
cat("  CRÍTICO     → alta freq. + alta reincidência  → intervenção urgente\n")
cat("  ESTRUTURAL  → baixa freq. + alta reincidência → problema comportamental\n")
cat("  OPERACIONAL → alta freq. + baixa reincidência → déficit de capacidade\n")
cat("  CONTROLADO  → baixa freq. + baixa reincidência → monitoramento rotineiro\n")