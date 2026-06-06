library(shiny)
library(bs4Dash)
library(plotly)
library(dplyr)
library(DBI)
library(RMySQL)

source("conexao.R")

sql_ranking_bairros <- "
  SELECT
    l.bairro,
    l.regiao,
    SUM(f.quantidade_ocorrencias) AS total_ocorrencias
  FROM fato_ocorrencia f
  JOIN dim_localizacao l
    ON f.sk_localizacao = l.sk_localizacao
  GROUP BY l.bairro, l.regiao
  ORDER BY total_ocorrencias DESC
  LIMIT 10
"

# Paleta de cores por região — gerada dinamicamente no server
cores_regiao <- c(
  "#3498DB", "#E74C3C", "#2ECC71", "#F39C12", "#9B59B6",
  "#1ABC9C", "#E67E22", "#34495E", "#E91E63", "#00BCD4"
)

ui <- bs4DashPage(
  header  = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),

  body = bs4DashBody(

    fluidRow(
      bs4ValueBoxOutput("bairro_critico",     width = 4),
      bs4ValueBoxOutput("total_top10",        width = 4),
      bs4ValueBoxOutput("regioes_no_top10",   width = 4)
    ),

    fluidRow(
      bs4Card(
        title       = "Top 10 Bairros Críticos por Ocorrências",
        width       = 8,
        status      = "danger",
        solidHeader = TRUE,
        plotlyOutput("grafico_ranking", height = 450)
      ),

      bs4Card(
        title       = "Distribuição por Região entre os 10 Críticos",
        width       = 4,
        status      = "warning",
        solidHeader = TRUE,
        plotlyOutput("grafico_regiao", height = 450)
      )
    ),

    fluidRow(
      bs4Card(
        title       = "Dados Detalhados — Top 10 Bairros",
        width       = 12,
        status      = "secondary",
        solidHeader = TRUE,
        DT::DTOutput("tabela_bairros")
      )
    )
  ),

  footer = bs4DashFooter()
)

server <- function(input, output, session) {

  dados <- reactive({
    d <- dbGetQuery(con, sql_ranking_bairros)
    # Posição no ranking
    d$ranking <- seq_len(nrow(d))
    d
  })

  output$bairro_critico <- renderbs4ValueBox({
    d <- dados()
    bs4ValueBox(
      value    = d$bairro[1],
      subtitle = paste0("Bairro mais crítico (", format(d$total_ocorrencias[1], big.mark = "."), " oc.)"),
      icon     = icon("exclamation-circle"),
      color    = "danger",
      gradient = TRUE
    )
  })

  output$total_top10 <- renderbs4ValueBox({
    total <- sum(dados()$total_ocorrencias, na.rm = TRUE)
    bs4ValueBox(
      value    = format(total, big.mark = "."),
      subtitle = "Total de ocorrências nos 10 bairros críticos",
      icon     = icon("map-marker-alt"),
      color    = "warning",
      gradient = TRUE
    )
  })

  output$regioes_no_top10 <- renderbs4ValueBox({
    n <- n_distinct(dados()$regiao)
    bs4ValueBox(
      value    = n,
      subtitle = "Regiões representadas no top 10",
      icon     = icon("layer-group"),
      color    = "info",
      gradient = TRUE
    )
  })

  output$grafico_ranking <- renderPlotly({
    d <- dados() |> arrange(total_ocorrencias)

    # Atribui cor por região
    regioes  <- unique(dados()$regiao)
    mapa_cor <- setNames(cores_regiao[seq_along(regioes)], regioes)
    d$cor    <- mapa_cor[d$regiao]

    plot_ly(
      d,
      x           = ~total_ocorrencias,
      y           = ~reorder(bairro, total_ocorrencias),
      type        = "bar",
      orientation = "h",
      marker      = list(color = ~cor),
      text        = ~format(total_ocorrencias, big.mark = "."),
      textposition = "outside",
      hovertemplate = "<b>%{y}</b><br>Região: %{customdata}<br>Ocorrências: %{x}<extra></extra>",
      customdata  = ~regiao
    ) |>
      layout(
        xaxis  = list(title = "Total de Ocorrências"),
        yaxis  = list(title = ""),
        margin = list(r = 80)
      )
  })

  output$grafico_regiao <- renderPlotly({
    d <- dados() |>
      group_by(regiao) |>
      summarise(total = sum(total_ocorrencias), bairros = n(), .groups = "drop") |>
      arrange(desc(total))

    regioes  <- d$regiao
    mapa_cor <- setNames(cores_regiao[seq_along(regioes)], regioes)

    plot_ly(
      d,
      labels = ~regiao,
      values = ~total,
      type   = "pie",
      hole   = 0.45,
      marker = list(colors = unname(mapa_cor[d$regiao])),
      textinfo = "label+percent",
      hovertemplate = "<b>%{label}</b><br>%{value} oc.<extra></extra>"
    )
  })

  output$tabela_bairros <- DT::renderDT({
    d <- dados() |>
      select(ranking, bairro, regiao, total_ocorrencias) |>
      rename(
        `#`                   = ranking,
        Bairro                = bairro,
        Região                = regiao,
        `Total Ocorrências`   = total_ocorrencias
      )

    DT::datatable(d, options = list(pageLength = 10, dom = "tp"), rownames = FALSE)
  })
}

shinyApp(ui, server)
