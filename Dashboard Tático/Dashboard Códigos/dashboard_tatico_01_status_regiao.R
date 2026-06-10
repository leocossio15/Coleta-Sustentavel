library(shiny)
library(bs4Dash)
library(plotly)
library(dplyr)
library(DBI)
library(RMySQL)

source("conexao.R")

# Paleta de status alinhada à ordem do fluxo
cores_status <- c(
  "ABERTA"         = "#3498DB",
  "EM_ANALISE"     = "#F39C12",
  "EM_ATENDIMENTO" = "#9B59B6",
  "ENCERRADA"      = "#2ECC71",
  "CANCELADA"      = "#95A5A6"
)

sql_status_regiao <- "
  SELECT
    dl.regiao,
    ds.status,
    ds.ordem_fluxo,
    SUM(fo.quantidade_ocorrencias) AS total_ocorrencias
  FROM fato_ocorrencia fo
  INNER JOIN dim_localizacao dl ON fo.sk_localizacao = dl.sk_localizacao
  INNER JOIN dim_status      ds ON fo.sk_status      = ds.sk_status
  GROUP BY dl.regiao, ds.status, ds.ordem_fluxo
  ORDER BY dl.regiao, ds.ordem_fluxo
"

ui <- bs4DashPage(
  header  = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),

  body = bs4DashBody(
    fluidRow(
      bs4ValueBoxOutput("total_ocorrencias",  width = 3),
      bs4ValueBoxOutput("pct_finalizadas",    width = 3),
      bs4ValueBoxOutput("pct_abertas",        width = 3),
      bs4ValueBoxOutput("regioes_criticas",   width = 3)
    ),

    fluidRow(
      bs4Card(
        title       = "Ocorrências por Status e Região",
        width       = 8,
        status      = "primary",
        solidHeader = TRUE,
        plotlyOutput("grafico_stack", height = 450)
      ),

      bs4Card(
        title       = "Composição por Status",
        width       = 4,
        status      = "warning",
        solidHeader = TRUE,
        plotlyOutput("grafico_donut", height = 450)
      )
    ),

    fluidRow(
      bs4Card(
        title       = "Percentual de Ocorrências Encerradas por Região",
        width       = 12,
        status      = "success",
        solidHeader = TRUE,
        plotlyOutput("grafico_taxa", height = 350)
      )
    )
  ),

  footer = bs4DashFooter()
)

server <- function(input, output, session) {

  dados <- reactive({
    dbGetQuery(con, sql_status_regiao)
  })

  resumo <- reactive({
    dados() |>
      group_by(regiao) |>
      mutate(pct = round(100 * total_ocorrencias / sum(total_ocorrencias), 1))
  })

  output$total_ocorrencias <- renderbs4ValueBox({
    total <- sum(dados()$total_ocorrencias)
    bs4ValueBox(
      value    = format(total, big.mark = "."),
      subtitle = "Total de Ocorrências",
      icon     = icon("clipboard-list"),
      color    = "primary",
      gradient = TRUE
    )
  })

  output$pct_finalizadas <- renderbs4ValueBox({
    d     <- dados()
    total <- sum(d$total_ocorrencias)
    fin   <- sum(d$total_ocorrencias[d$status == "ENCERRADA"])
    bs4ValueBox(
      value    = paste0(round(100 * fin / total, 1), "%"),
      subtitle = "Encerradas",
      icon     = icon("check-circle"),
      color    = "success",
      gradient = TRUE
    )
  })

  output$pct_abertas <- renderbs4ValueBox({
    d     <- dados()
    total <- sum(d$total_ocorrencias)
    ab    <- sum(d$total_ocorrencias[d$status == "ABERTA"])
    bs4ValueBox(
      value    = paste0(round(100 * ab / total, 1), "%"),
      subtitle = "Em Aberto",
      icon     = icon("exclamation-circle"),
      color    = "warning",
      gradient = TRUE
    )
  })

  output$regioes_criticas <- renderbs4ValueBox({
    # regiões onde mais de 40% das ocorrências ainda estão abertas
    criticas <- resumo() |>
      filter(status == "ABERTA", pct > 40) |>
      nrow()
    bs4ValueBox(
      value    = criticas,
      subtitle = "Regiões com >40% em aberto",
      icon     = icon("map-marker-alt"),
      color    = "danger",
      gradient = TRUE
    )
  })

  output$grafico_stack <- renderPlotly({
    d <- resumo() |>
      arrange(ordem_fluxo)

    plot_ly(
      d,
      x      = ~regiao,
      y      = ~total_ocorrencias,
      color  = ~status,
      colors = cores_status,
      type   = "bar",
      text   = ~paste0(status, ": ", total_ocorrencias, " (", pct, "%)"),
      hoverinfo = "text"
    ) |>
      layout(
        barmode = "stack",
        xaxis   = list(title = "Região"),
        yaxis   = list(title = "Ocorrências"),
        legend  = list(title = list(text = "Status"))
      )
  })

  output$grafico_donut <- renderPlotly({
    d <- dados() |>
      group_by(status) |>
      summarise(total = sum(total_ocorrencias), .groups = "drop")

    plot_ly(
      d,
      labels = ~status,
      values = ~total,
      type   = "pie",
      hole   = 0.55,
      marker = list(colors = unname(cores_status[d$status]))
    )
  })

  output$grafico_taxa <- renderPlotly({
    taxa <- dados() |>
      group_by(regiao) |>
      summarise(
        total      = sum(total_ocorrencias),
        finalizadas = sum(total_ocorrencias[status == "ENCERRADA"]),
        .groups    = "drop"
      ) |>
      mutate(taxa_pct = round(100 * finalizadas / total, 1)) |>
      arrange(desc(taxa_pct))

    plot_ly(
      taxa,
      x         = ~reorder(regiao, taxa_pct),
      y         = ~taxa_pct,
      type      = "bar",
      text      = ~paste0(taxa_pct, "%"),
      textposition = "outside",
      marker    = list(color = "#2ECC71")
    ) |>
      layout(
        xaxis = list(title = "Região"),
        yaxis = list(title = "% Encerradas", range = c(0, 105))
      )
  })
}

shinyApp(ui, server)