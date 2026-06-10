library(shiny)
library(bs4Dash)
library(plotly)
library(dplyr)
library(DBI)
library(RMySQL)

source("conexao.R")

sql_evolucao_mensal <- "
  SELECT
    t.ano,
    t.mes,
    t.nome_mes,
    SUM(f.quantidade_ocorrencias) AS total_ocorrencias
  FROM fato_ocorrencia f
  JOIN dim_tempo t
    ON f.sk_tempo = t.sk_tempo
  GROUP BY t.ano, t.mes, t.nome_mes
  ORDER BY t.ano, t.mes
"

ui <- bs4DashPage(
  header  = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),

  body = bs4DashBody(

    fluidRow(
      bs4ValueBoxOutput("total_historico",  width = 3),
      bs4ValueBoxOutput("mes_pico",         width = 3),
      bs4ValueBoxOutput("mes_menor",        width = 3),
      bs4ValueBoxOutput("variacao_recente", width = 3)
    ),

    fluidRow(
      bs4Card(
        title       = "Série Histórica de Ocorrências por Mês",
        width       = 12,
        status      = "primary",
        solidHeader = TRUE,
        plotlyOutput("grafico_serie", height = 420)
      )
    ),

    fluidRow(
      bs4Card(
        title       = "Ocorrências Anuais por Mês (comparativo de anos)",
        width       = 8,
        status      = "info",
        solidHeader = TRUE,
        plotlyOutput("grafico_anual", height = 380)
      ),

      bs4Card(
        title       = "Total por Ano",
        width       = 4,
        status      = "success",
        solidHeader = TRUE,
        plotlyOutput("grafico_total_ano", height = 380)
      )
    )
  ),

  footer = bs4DashFooter()
)

server <- function(input, output, session) {

  dados <- reactive({
    dbGetQuery(con, sql_evolucao_mensal) |>
      arrange(ano, mes) |>
      mutate(periodo = paste0(ano, "-", sprintf("%02d", mes)))
  })

  output$total_historico <- renderbs4ValueBox({
    total <- sum(dados()$total_ocorrencias, na.rm = TRUE)
    bs4ValueBox(
      value    = format(total, big.mark = "."),
      subtitle = "Total histórico de ocorrências",
      icon     = icon("clipboard-list"),
      color    = "primary",
      gradient = TRUE
    )
  })

  output$mes_pico <- renderbs4ValueBox({
    d   <- dados()
    idx <- which.max(d$total_ocorrencias)
    bs4ValueBox(
      value    = paste0(d$nome_mes[idx], "/", d$ano[idx]),
      subtitle = paste0("Mês de maior volume (", format(d$total_ocorrencias[idx], big.mark = "."), " oc.)"),
      icon     = icon("arrow-up"),
      color    = "danger",
      gradient = TRUE
    )
  })

  output$mes_menor <- renderbs4ValueBox({
    d   <- dados()
    idx <- which.min(d$total_ocorrencias)
    bs4ValueBox(
      value    = paste0(d$nome_mes[idx], "/", d$ano[idx]),
      subtitle = paste0("Mês de menor volume (", format(d$total_ocorrencias[idx], big.mark = "."), " oc.)"),
      icon     = icon("arrow-down"),
      color    = "success",
      gradient = TRUE
    )
  })

  output$variacao_recente <- renderbs4ValueBox({
    d <- dados()
    # Compara os dois últimos meses disponíveis
    n     <- nrow(d)
    if (n >= 2) {
      delta <- d$total_ocorrencias[n] - d$total_ocorrencias[n - 1]
      pct   <- round(100 * delta / d$total_ocorrencias[n - 1], 1)
      cor   <- if (delta > 0) "danger" else "success"
      ico   <- if (delta > 0) "arrow-up" else "arrow-down"
      label <- paste0(if (delta > 0) "+" else "", pct, "%")
    } else {
      label <- "—"; cor <- "secondary"; ico <- "minus"
    }
    bs4ValueBox(
      value    = label,
      subtitle = "Variação no último mês disponível",
      icon     = icon(ico),
      color    = cor,
      gradient = TRUE
    )
  })

  output$grafico_serie <- renderPlotly({
    d <- dados()

    plot_ly(
      d,
      x    = ~periodo,
      y    = ~total_ocorrencias,
      type = "scatter",
      mode = "lines+markers",
      line   = list(color = "#3498DB", width = 2),
      marker = list(color = "#3498DB", size  = 5),
      hovertemplate = "<b>%{x}</b><br>Ocorrências: %{y}<extra></extra>"
    ) |>
      layout(
        xaxis  = list(title = "Período", tickangle = -45),
        yaxis  = list(title = "Ocorrências"),
        margin = list(b = 80)
      )
  })

  output$grafico_anual <- renderPlotly({
    d <- dados()

    plot_ly(
      d,
      x      = ~mes,
      y      = ~total_ocorrencias,
      color  = ~as.character(ano),
      type   = "scatter",
      mode   = "lines+markers",
      hovertemplate = "Mês %{x} | %{y} oc.<extra></extra>"
    ) |>
      layout(
        xaxis  = list(title = "Mês", tickvals = 1:12, ticktext = month.abb),
        yaxis  = list(title = "Ocorrências"),
        legend = list(title = list(text = "Ano"))
      )
  })

  output$grafico_total_ano <- renderPlotly({
    d <- dados() |>
      group_by(ano) |>
      summarise(total = sum(total_ocorrencias), .groups = "drop") |>
      arrange(ano)

    plot_ly(
      d,
      x      = ~as.character(ano),
      y      = ~total,
      type   = "bar",
      marker = list(color = "#2ECC71"),
      text   = ~format(total, big.mark = "."),
      textposition = "outside"
    ) |>
      layout(
        xaxis = list(title = "Ano"),
        yaxis = list(title = "Total de Ocorrências")
      )
  })
}

shinyApp(ui, server)
