library(shiny)
library(bs4Dash)
library(plotly)
library(dplyr)
library(tidyr)
library(DBI)
library(RMySQL)

source("conexao.R")

sql_equipes <- "
  SELECT
    dr.cargo,
    dr.nome,
    SUM(fo.quantidade_ocorrencias)          AS total_ocorrencias,
    SUM(fo.total_atendimentos)              AS total_atendimentos,
    COUNT(DISTINCT fo.sk_localizacao)       AS regioes_atendidas,
    ROUND(AVG(fo.tempo_resolucao_horas), 2) AS media_horas_resolucao
  FROM fato_ocorrencia fo
  INNER JOIN dim_responsavel dr ON fo.sk_responsavel = dr.sk_responsavel
  GROUP BY dr.cargo, dr.nome
"

sql_cargo_regiao <- "
  SELECT
    dr.cargo,
    dl.regiao,
    SUM(fo.quantidade_ocorrencias) AS total_ocorrencias
  FROM fato_ocorrencia fo
  INNER JOIN dim_responsavel dr ON fo.sk_responsavel = dr.sk_responsavel
  INNER JOIN dim_localizacao dl ON fo.sk_localizacao = dl.sk_localizacao
  GROUP BY dr.cargo, dl.regiao
"

ui <- bs4DashPage(
  header  = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),

  body = bs4DashBody(
    fluidRow(
      bs4ValueBoxOutput("total_responsaveis", width = 3),
      bs4ValueBoxOutput("total_cargos",       width = 3),
      bs4ValueBoxOutput("media_ocorr_resp",   width = 3),
      bs4ValueBoxOutput("cargo_mais_carga",   width = 3)
    ),

    fluidRow(
      bs4Card(
        title       = "Distribuição de Ocorrências por Cargo",
        width       = 6,
        status      = "primary",
        solidHeader = TRUE,
        plotlyOutput("ocorr_por_cargo", height = 400)
      ),

      bs4Card(
        title       = "Tempo Médio para Resolver uma Ocorrência por Cargo (horas)",
        width       = 6,
        status      = "warning",
        solidHeader = TRUE,
        plotlyOutput("horas_por_cargo", height = 400)
      )
    ),

    fluidRow(
      bs4Card(
        title       = "Top 20 Responsáveis por Carga de Ocorrências",
        width       = 8,
        status      = "info",
        solidHeader = TRUE,
        plotlyOutput("top_responsaveis", height = 420)
      ),

      bs4Card(
        title       = "Ocorrências por Cargo e Região",
        width       = 4,
        status      = "success",
        solidHeader = TRUE,
        plotlyOutput("heatmap_cargo_regiao", height = 420)
      )
    )
  ),

  footer = bs4DashFooter()
)

server <- function(input, output, session) {

  dados <- reactive({
    dbGetQuery(con, sql_equipes)
  })

  por_cargo <- reactive({
    dados() |>
      group_by(cargo) |>
      summarise(
        responsaveis      = n_distinct(nome),
        total_ocorrencias = sum(total_ocorrencias),
        total_atendimentos = sum(total_atendimentos),
        media_horas       = round(mean(media_horas_resolucao, na.rm = TRUE), 1),
        regioes_atendidas = max(regioes_atendidas),
        .groups           = "drop"
      ) |>
      mutate(ocorr_por_pessoa = round(total_ocorrencias / responsaveis, 1))
  })

  output$total_responsaveis <- renderbs4ValueBox({
    bs4ValueBox(
      value    = n_distinct(dados()$nome),
      subtitle = "Responsáveis Ativos",
      icon     = icon("users"),
      color    = "primary",
      gradient = TRUE
    )
  })

  output$total_cargos <- renderbs4ValueBox({
    bs4ValueBox(
      value    = n_distinct(dados()$cargo),
      subtitle = "Cargos Distintos",
      icon     = icon("id-badge"),
      color    = "info",
      gradient = TRUE
    )
  })

  output$media_ocorr_resp <- renderbs4ValueBox({
    media <- round(mean(dados()$total_ocorrencias), 0)
    bs4ValueBox(
      value    = format(media, big.mark = "."),
      subtitle = "Média de ocorrências por responsável",
      icon     = icon("chart-bar"),
      color    = "warning",
      gradient = TRUE
    )
  })

  output$cargo_mais_carga <- renderbs4ValueBox({
    d     <- por_cargo()
    cargo <- d$cargo[which.max(d$ocorr_por_pessoa)]
    bs4ValueBox(
      value    = cargo,
      subtitle = "Cargo com maior carga per capita",
      icon     = icon("user-tie"),
      color    = "danger",
      gradient = TRUE
    )
  })

  output$ocorr_por_cargo <- renderPlotly({
    d <- por_cargo() |> arrange(desc(total_ocorrencias))

    plot_ly(
      d,
      x    = ~reorder(cargo, total_ocorrencias),
      y    = ~total_ocorrencias,
      type = "bar",
      text = ~paste0(cargo, "<br>", format(total_ocorrencias, big.mark = "."), " ocorrências<br>",
                     responsaveis, " responsáveis<br>", ocorr_por_pessoa, " p/pessoa"),
      hoverinfo = "text",
      marker = list(color = "#3498DB")
    ) |>
      layout(
        xaxis = list(title = "Cargo"),
        yaxis = list(title = "Total de Ocorrências")
      )
  })

  output$horas_por_cargo <- renderPlotly({
    d <- por_cargo() |> arrange(desc(media_horas))

    plot_ly(
      d,
      x           = ~media_horas,
      y           = ~reorder(cargo, media_horas),
      type        = "bar",
      orientation = "h",
      marker      = list(color = "#F39C12"),
      text        = ~paste0(media_horas, "h"),
      textposition = "outside"
    ) |>
      layout(
        xaxis = list(title = "Média de Horas"),
        yaxis = list(title = "")
      )
  })

  output$top_responsaveis <- renderPlotly({
    d <- dados() |>
      slice_max(total_ocorrencias, n = 20) |>
      arrange(total_ocorrencias)

    plot_ly(
      d,
      x           = ~total_ocorrencias,
      y           = ~reorder(nome, total_ocorrencias),
      color       = ~cargo,
      type        = "bar",
      orientation = "h",
      text        = ~paste0(nome, " (", cargo, "): ", format(total_ocorrencias, big.mark = ".")),
      hoverinfo   = "text"
    ) |>
      layout(
        barmode = "overlay",
        xaxis   = list(title = "Total de Ocorrências"),
        yaxis   = list(title = ""),
        legend  = list(title = list(text = "Cargo"))
      )
  })

  output$heatmap_cargo_regiao <- renderPlotly({
    d <- dbGetQuery(con, sql_cargo_regiao)

    # Pivota para matriz cargo × região
    matriz <- tidyr::pivot_wider(
      d,
      names_from  = regiao,
      values_from = total_ocorrencias,
      values_fill = 0
    )

    z        <- as.matrix(matriz[, -1])
    rownames(z) <- matriz$cargo

    plot_ly(
      x         = colnames(z),
      y         = rownames(z),
      z         = z,
      type      = "heatmap",
      colorscale = "Blues",
      hovertemplate = "Cargo: %{y}<br>Região: %{x}<br>Ocorrências: %{z}<extra></extra>"
    ) |>
      layout(
        xaxis = list(title = "Região", tickangle = -35),
        yaxis = list(title = "")
      )
  })
}

shinyApp(ui, server)
