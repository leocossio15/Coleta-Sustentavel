library(shiny)
library(bs4Dash)
library(plotly)
library(dplyr)
library(DBI)
library(RMySQL)

source("conexao.R")

sql_comparativo <- "
  SELECT
    dl.regiao,
    dt.ano,
    dt.mes,
    dt.nome_mes,
    SUM(fo.quantidade_ocorrencias) AS total_ocorrencias,
    SUM(fo.volume_estimado)        AS volume_total
  FROM fato_ocorrencia fo
  INNER JOIN dim_tempo       dt ON fo.sk_tempo       = dt.sk_tempo
  INNER JOIN dim_localizacao dl ON fo.sk_localizacao = dl.sk_localizacao
  WHERE dt.data_completa >= DATE_SUB(CURDATE(), INTERVAL 2 MONTH)
  GROUP BY dl.regiao, dt.ano, dt.mes, dt.nome_mes
  ORDER BY dt.ano, dt.mes
"

ui <- bs4DashPage(
  header  = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),

  body = bs4DashBody(
    fluidRow(
      bs4ValueBoxOutput("variacao_ocorrencias", width = 4),
      bs4ValueBoxOutput("variacao_volume",      width = 4),
      bs4ValueBoxOutput("regiao_maior_alta",    width = 4)
    ),

    fluidRow(
      bs4Card(
        title       = "Ocorrências: Mês Atual vs Mês Anterior por Região",
        width       = 6,
        status      = "primary",
        solidHeader = TRUE,
        plotlyOutput("grafico_ocorrencias", height = 420)
      ),

      bs4Card(
        title       = "Volume Estimado: Mês Atual vs Mês Anterior por Região",
        width       = 6,
        status      = "warning",
        solidHeader = TRUE,
        plotlyOutput("grafico_volume", height = 420)
      )
    ),

    fluidRow(
      bs4Card(
        title       = "Variação Percentual de Ocorrências por Região",
        width       = 12,
        status      = "danger",
        solidHeader = TRUE,
        plotlyOutput("grafico_variacao", height = 380)
      )
    )
  ),

  footer = bs4DashFooter()
)

server <- function(input, output, session) {

  dados <- reactive({
    dbGetQuery(con, sql_comparativo)
  })

  comparativo <- reactive({
    mes_atual     <- format(Sys.Date(), "%Y-%m")
    mes_anterior  <- format(seq(Sys.Date(), by = "-1 month", length = 2)[2], "%Y-%m")

    d <- dados() |>
      mutate(periodo = sprintf("%04d-%02d", ano, mes))

    atual    <- d |> filter(periodo == mes_atual)    |> select(regiao, ocorrencias_atual = total_ocorrencias, volume_atual = volume_total)
    anterior <- d |> filter(periodo == mes_anterior) |> select(regiao, ocorrencias_ant   = total_ocorrencias, volume_ant   = volume_total)

    full_join(atual, anterior, by = "regiao") |>
      mutate(
        across(where(is.numeric), ~ replace(.x, is.na(.x), 0)),
        variacao_pct = round(
          ifelse(
            ocorrencias_ant == 0, NA_real_,
            100 * (ocorrencias_atual - ocorrencias_ant) / ocorrencias_ant
          ), 1
        )
      )
  })

  output$variacao_ocorrencias <- renderbs4ValueBox({
    d     <- comparativo()
    delta <- sum(d$ocorrencias_atual) - sum(d$ocorrencias_ant)
    cor   <- if (delta > 0) "danger" else "success"
    ico   <- if (delta > 0) "arrow-up" else "arrow-down"
    bs4ValueBox(
      value    = paste0(if (delta > 0) "+" else "", format(delta, big.mark = ".")),
      subtitle = "Variação de Ocorrências (mês)",
      icon     = icon(ico),
      color    = cor,
      gradient = TRUE
    )
  })

  output$variacao_volume <- renderbs4ValueBox({
    d     <- comparativo()
    delta <- round(sum(d$volume_atual) - sum(d$volume_ant), 1)
    cor   <- if (delta > 0) "danger" else "success"
    ico   <- if (delta > 0) "arrow-up" else "arrow-down"
    bs4ValueBox(
      value    = paste0(if (delta > 0) "+" else "", format(delta, big.mark = ".")),
      subtitle = "Variação de Volume Estimado (mês)",
      icon     = icon(ico),
      color    = cor,
      gradient = TRUE
    )
  })

  output$regiao_maior_alta <- renderbs4ValueBox({
    d      <- comparativo() |> filter(!is.na(variacao_pct))
    regiao <- d$regiao[which.max(d$variacao_pct)]
    pct    <- max(d$variacao_pct, na.rm = TRUE)
    bs4ValueBox(
      value    = paste0(regiao, " (+", pct, "%)"),
      subtitle = "Região com maior alta",
      icon     = icon("exclamation-triangle"),
      color    = "warning",
      gradient = TRUE
    )
  })

  output$grafico_ocorrencias <- renderPlotly({
    d <- comparativo()

    plot_ly(d, x = ~regiao) |>
      add_bars(y = ~ocorrencias_ant,   name = "Mês Anterior", marker = list(color = "#95A5A6")) |>
      add_bars(y = ~ocorrencias_atual, name = "Mês Atual",    marker = list(color = "#3498DB")) |>
      layout(
        barmode = "group",
        xaxis   = list(title = "Região"),
        yaxis   = list(title = "Ocorrências"),
        legend  = list(orientation = "h", y = -0.2)
      )
  })

  output$grafico_volume <- renderPlotly({
    d <- comparativo()

    plot_ly(d, x = ~regiao) |>
      add_bars(y = ~volume_ant,   name = "Mês Anterior", marker = list(color = "#95A5A6")) |>
      add_bars(y = ~volume_atual, name = "Mês Atual",    marker = list(color = "#F39C12")) |>
      layout(
        barmode = "group",
        xaxis   = list(title = "Região"),
        yaxis   = list(title = "Volume Estimado"),
        legend  = list(orientation = "h", y = -0.2)
      )
  })

  output$grafico_variacao <- renderPlotly({
    d <- comparativo() |>
      filter(!is.na(variacao_pct)) |>
      arrange(variacao_pct)

    cores <- ifelse(d$variacao_pct >= 0, "#E74C3C", "#2ECC71")

    plot_ly(
      d,
      x         = ~variacao_pct,
      y         = ~reorder(regiao, variacao_pct),
      type      = "bar",
      orientation = "h",
      text      = ~paste0(variacao_pct, "%"),
      textposition = "outside",
      marker    = list(color = cores)
    ) |>
      layout(
        xaxis = list(title = "Variação (%)"),
        yaxis = list(title = "")
      )
  })
}

shinyApp(ui, server)
