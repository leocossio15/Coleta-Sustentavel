library(shiny)
library(bs4Dash)
library(plotly)
library(dplyr)
library(tidyr)
library(DBI)
library(RMySQL)

source("conexao.R")

sql_residuos <- "
  SELECT
    dl.regiao,
    dres.tipo_residuo,
    dres.categoria,
    dres.periculosidade,
    SUM(fo.quantidade_ocorrencias) AS total_ocorrencias,
    SUM(fo.volume_estimado)        AS volume_total
  FROM fato_ocorrencia fo
  INNER JOIN dim_localizacao dl   ON fo.sk_localizacao = dl.sk_localizacao
  INNER JOIN dim_residuo     dres ON fo.sk_residuo     = dres.sk_residuo
  GROUP BY dl.regiao, dres.tipo_residuo, dres.categoria, dres.periculosidade
"

cores_periculosidade <- c("ALTA" = "#E74C3C", "MEDIA" = "#F39C12", "BAIXA" = "#2ECC71")

ui <- bs4DashPage(
  header  = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),

  body = bs4DashBody(
    fluidRow(
      bs4ValueBoxOutput("residuo_predominante", width = 4),
      bs4ValueBoxOutput("categoria_predominante", width = 4),
      bs4ValueBoxOutput("pct_alta_periculosidade", width = 4)
    ),

    fluidRow(
      bs4Card(
        title       = "Mapa de Calor: Volume por Região e Tipo de Resíduo",
        width       = 12,
        status      = "primary",
        solidHeader = TRUE,
        plotlyOutput("heatmap_residuos", height = 420)
      )
    ),

    fluidRow(
      bs4Card(
        title       = "Volume por Categoria de Resíduo",
        width       = 6,
        status      = "success",
        solidHeader = TRUE,
        plotlyOutput("treemap_categorias", height = 400)
      ),

      bs4Card(
        title       = "Ocorrências por Periculosidade e Região",
        width       = 6,
        status      = "danger",
        solidHeader = TRUE,
        plotlyOutput("periculosidade_regiao", height = 400)
      )
    )
  ),

  footer = bs4DashFooter()
)

server <- function(input, output, session) {

  dados <- reactive({
    dbGetQuery(con, sql_residuos)
  })

  output$residuo_predominante <- renderbs4ValueBox({
    d <- dados() |>
      group_by(tipo_residuo) |>
      summarise(total = sum(volume_total), .groups = "drop")
    bs4ValueBox(
      value    = d$tipo_residuo[which.max(d$total)],
      subtitle = "Tipo de resíduo com maior volume",
      icon     = icon("trash"),
      color    = "primary",
      gradient = TRUE
    )
  })

  output$categoria_predominante <- renderbs4ValueBox({
    d <- dados() |>
      group_by(categoria) |>
      summarise(total = sum(total_ocorrencias), .groups = "drop")
    bs4ValueBox(
      value    = d$categoria[which.max(d$total)],
      subtitle = "Categoria com mais ocorrências",
      icon     = icon("tags"),
      color    = "warning",
      gradient = TRUE
    )
  })

  output$pct_alta_periculosidade <- renderbs4ValueBox({
    d   <- dados()
    pct <- round(100 * sum(d$volume_total[d$periculosidade == "ALTA"]) / sum(d$volume_total), 1)
    bs4ValueBox(
      value    = paste0(pct, "%"),
      subtitle = "Volume de resíduos de alta periculosidade",
      icon     = icon("biohazard"),
      color    = "danger",
      gradient = TRUE
    )
  })

  output$heatmap_residuos <- renderPlotly({
    # Pivota para matriz região x tipo_residuo
    matriz <- dados() |>
      group_by(regiao, tipo_residuo) |>
      summarise(volume_total = sum(volume_total), .groups = "drop") |>
      pivot_wider(names_from = tipo_residuo, values_from = volume_total, values_fill = 0)

    z      <- as.matrix(matriz[, -1])
    rownames(z) <- matriz$regiao

    plot_ly(
      x         = colnames(z),
      y         = rownames(z),
      z         = z,
      type      = "heatmap",
      colorscale = "YlOrRd",
      hovertemplate = "Região: %{y}<br>Resíduo: %{x}<br>Volume: %{z}<extra></extra>"
    ) |>
      layout(
        xaxis = list(title = "Tipo de Resíduo"),
        yaxis = list(title = "Região")
      )
  })

  output$treemap_categorias <- renderPlotly({
    tipos <- dados() |>
      group_by(categoria, tipo_residuo) |>
      summarise(volume_total = sum(volume_total), .groups = "drop")

    # Plotly exige que os nós-pai também existam como linhas com parent = ""
    categorias <- tipos |>
      group_by(categoria) |>
      summarise(volume_total = sum(volume_total), .groups = "drop") |>
      mutate(tipo_residuo = categoria, categoria = "")

    treemap_data <- bind_rows(
      categorias |> select(labels = tipo_residuo, parents = categoria, volume_total),
      tipos      |> select(labels = tipo_residuo, parents = categoria, volume_total)
    )

    plot_ly(
      treemap_data,
      type         = "treemap",
      labels       = ~labels,
      parents      = ~parents,
      values       = ~volume_total,
      branchvalues = "remainder"
    )
  })

  output$periculosidade_regiao <- renderPlotly({
    d <- dados() |>
      group_by(regiao, periculosidade) |>
      summarise(total_ocorrencias = sum(total_ocorrencias), .groups = "drop")

    plot_ly(
      d,
      x      = ~regiao,
      y      = ~total_ocorrencias,
      color  = ~periculosidade,
      colors = cores_periculosidade,
      type   = "bar"
    ) |>
      layout(
        barmode = "stack",
        xaxis   = list(title = "Região"),
        yaxis   = list(title = "Ocorrências"),
        legend  = list(title = list(text = "Periculosidade"))
      )
  })
}

shinyApp(ui, server)
