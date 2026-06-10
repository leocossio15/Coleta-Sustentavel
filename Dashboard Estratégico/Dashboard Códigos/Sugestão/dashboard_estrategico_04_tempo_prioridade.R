library(shiny)
library(bs4Dash)
library(plotly)
library(dplyr)
library(DBI)
library(RMySQL)

source("conexao.R")

sql_tempo_prioridade <- "
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
  ORDER BY tempo_medio_horas DESC
"

# Referência de SLA estratégico por prioridade (horas)
sla_referencia <- c(
  "URGENTE" = 12,
  "ALTA"    = 24,
  "MEDIA"   = 48,
  "BAIXA"   = 72
)

ui <- bs4DashPage(
  header  = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),

  body = bs4DashBody(

    fluidRow(
      bs4ValueBoxOutput("media_geral",        width = 3),
      bs4ValueBoxOutput("prioridade_lenta",   width = 3),
      bs4ValueBoxOutput("prioridade_rapida",  width = 3),
      bs4ValueBoxOutput("n_acima_sla",        width = 3)
    ),

    fluidRow(
      bs4Card(
        title       = "Tempo Médio de Resolução por Prioridade (horas)",
        width       = 7,
        status      = "warning",
        solidHeader = TRUE,
        plotlyOutput("grafico_tempo", height = 420)
      ),

      bs4Card(
        title       = "Comparativo com SLA de Referência",
        width       = 5,
        status      = "danger",
        solidHeader = TRUE,
        plotlyOutput("grafico_sla", height = 420)
      )
    ),

    fluidRow(
      bs4Card(
        title       = "Dados Consolidados por Prioridade",
        width       = 12,
        status      = "secondary",
        solidHeader = TRUE,
        DT::DTOutput("tabela_tempo")
      )
    )
  ),

  footer = bs4DashFooter()
)

server <- function(input, output, session) {

  dados <- reactive({
    d <- dbGetQuery(con, sql_tempo_prioridade)
    # Adiciona SLA e calcula desvio
    d$sla_horas  <- sla_referencia[d$prioridade]
    d$desvio_sla <- round(d$tempo_medio_horas - d$sla_horas, 2)
    d
  })

  output$media_geral <- renderbs4ValueBox({
    bs4ValueBox(
      value    = paste0(round(mean(dados()$tempo_medio_horas, na.rm = TRUE), 1), "h"),
      subtitle = "Tempo médio global de resolução",
      icon     = icon("clock"),
      color    = "primary",
      gradient = TRUE
    )
  })

  output$prioridade_lenta <- renderbs4ValueBox({
    d   <- dados()
    idx <- which.max(d$tempo_medio_horas)
    bs4ValueBox(
      value    = paste0(d$prioridade[idx], " (", d$tempo_medio_horas[idx], "h)"),
      subtitle = "Prioridade com maior tempo médio",
      icon     = icon("hourglass-end"),
      color    = "danger",
      gradient = TRUE
    )
  })

  output$prioridade_rapida <- renderbs4ValueBox({
    d   <- dados()
    idx <- which.min(d$tempo_medio_horas)
    bs4ValueBox(
      value    = paste0(d$prioridade[idx], " (", d$tempo_medio_horas[idx], "h)"),
      subtitle = "Prioridade com menor tempo médio",
      icon     = icon("hourglass-start"),
      color    = "success",
      gradient = TRUE
    )
  })

  output$n_acima_sla <- renderbs4ValueBox({
    d <- dados()
    n <- sum(!is.na(d$desvio_sla) & d$desvio_sla > 0)
    bs4ValueBox(
      value    = n,
      subtitle = "Prioridades acima do SLA de referência",
      icon     = icon("exclamation-circle"),
      color    = if (n > 0) "danger" else "success",
      gradient = TRUE
    )
  })

  output$grafico_tempo <- renderPlotly({
    d <- dados() |>
      arrange(desc(tempo_medio_horas)) |>
      mutate(
        cor = ifelse(
          !is.na(desvio_sla) & desvio_sla > 0,
          "#E74C3C", "#2ECC71"
        )
      )

    plot_ly(
      d,
      x           = ~tempo_medio_horas,
      y           = ~reorder(prioridade, tempo_medio_horas),
      type        = "bar",
      orientation = "h",
      marker      = list(color = ~cor),
      text        = ~paste0(tempo_medio_horas, "h"),
      textposition = "outside",
      hovertemplate = "<b>%{y}</b><br>Tempo médio: %{x}h<extra></extra>"
    ) |>
      layout(
        xaxis  = list(title = "Horas"),
        yaxis  = list(title = ""),
        margin = list(r = 60)
      )
  })

  output$grafico_sla <- renderPlotly({
    d <- dados() |>
      filter(!is.na(sla_horas)) |>
      arrange(prioridade)

    plot_ly(d, x = ~prioridade) |>
      add_bars(
        y    = ~sla_horas,
        name = "SLA Referência",
        marker = list(color = "#95A5A6"),
        text = ~paste0(sla_horas, "h"),
        textposition = "outside"
      ) |>
      add_bars(
        y    = ~tempo_medio_horas,
        name = "Tempo Real",
        marker = list(color = "#E74C3C"),
        text = ~paste0(tempo_medio_horas, "h"),
        textposition = "outside"
      ) |>
      layout(
        barmode = "group",
        xaxis   = list(title = "Prioridade"),
        yaxis   = list(title = "Horas"),
        legend  = list(orientation = "h", y = -0.2)
      )
  })

  output$tabela_tempo <- DT::renderDT({
    d <- dados() |>
      select(prioridade, tempo_medio_horas, sla_horas, desvio_sla) |>
      rename(
        Prioridade          = prioridade,
        `Tempo Médio (h)`   = tempo_medio_horas,
        `SLA Ref. (h)`      = sla_horas,
        `Desvio do SLA (h)` = desvio_sla
      )

    DT::datatable(d, options = list(pageLength = 10, dom = "tp"), rownames = FALSE)
  })
}

shinyApp(ui, server)
