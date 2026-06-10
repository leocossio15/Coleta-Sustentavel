library(shiny)
library(bs4Dash)
library(plotly)
library(dplyr)
library(DBI)
library(RMySQL)

source("conexao.R")

sql_reincidencia <- "
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
  ORDER BY percentual_reincidencia DESC
"

ui <- bs4DashPage(
  header  = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),

  body = bs4DashBody(

    fluidRow(
      bs4ValueBoxOutput("media_global",     width = 4),
      bs4ValueBoxOutput("regiao_critica",   width = 4),
      bs4ValueBoxOutput("regioes_acima",    width = 4)
    ),

    fluidRow(
      bs4Card(
        title       = "Índice de Reincidência por Região (%)",
        width       = 8,
        status      = "danger",
        solidHeader = TRUE,
        plotlyOutput("grafico_reincidencia", height = 450)
      ),

      bs4Card(
        title       = "Classificação por Nível de Reincidência",
        width       = 4,
        status      = "warning",
        solidHeader = TRUE,
        plotlyOutput("grafico_classificacao", height = 450)
      )
    ),

    fluidRow(
      bs4Card(
        title       = "Dados Detalhados por Região",
        width       = 12,
        status      = "secondary",
        solidHeader = TRUE,
        DT::DTOutput("tabela_reincidencia")
      )
    )
  ),

  footer = bs4DashFooter()
)

server <- function(input, output, session) {

  dados <- reactive({
    dbGetQuery(con, sql_reincidencia)
  })

  # Limiar de alerta: regiões acima da média global
  media_global <- reactive({
    round(mean(dados()$percentual_reincidencia, na.rm = TRUE), 2)
  })

  output$media_global <- renderbs4ValueBox({
    bs4ValueBox(
      value    = paste0(media_global(), "%"),
      subtitle = "Média global de reincidência",
      icon     = icon("redo"),
      color    = "warning",
      gradient = TRUE
    )
  })

  output$regiao_critica <- renderbs4ValueBox({
    d      <- dados()
    regiao <- d$regiao[which.max(d$percentual_reincidencia)]
    pct    <- max(d$percentual_reincidencia, na.rm = TRUE)
    bs4ValueBox(
      value    = paste0(regiao, " (", pct, "%)"),
      subtitle = "Região com maior reincidência",
      icon     = icon("exclamation-triangle"),
      color    = "danger",
      gradient = TRUE
    )
  })

  output$regioes_acima <- renderbs4ValueBox({
    n <- sum(dados()$percentual_reincidencia > media_global(), na.rm = TRUE)
    bs4ValueBox(
      value    = n,
      subtitle = paste0("Regiões acima da média (", media_global(), "%)"),
      icon     = icon("map-marker-alt"),
      color    = "info",
      gradient = TRUE
    )
  })

  output$grafico_reincidencia <- renderPlotly({
    d <- dados() |>
      arrange(percentual_reincidencia) |>
      mutate(
        cor = ifelse(
          percentual_reincidencia >= media_global(),
          "#E74C3C", "#F39C12"
        )
      )

    plot_ly(
      d,
      x           = ~percentual_reincidencia,
      y           = ~reorder(regiao, percentual_reincidencia),
      type        = "bar",
      orientation = "h",
      marker      = list(color = ~cor),
      text        = ~paste0(percentual_reincidencia, "%"),
      textposition = "outside",
      hovertemplate = "<b>%{y}</b><br>Reincidência: %{x}%<extra></extra>"
    ) |>
      layout(
        shapes = list(list(
          type = "line",
          x0   = media_global(), x1 = media_global(),
          y0   = -0.5, y1 = nrow(d) - 0.5,
          line = list(color = "#2C3E50", dash = "dash", width = 1.5)
        )),
        xaxis  = list(title = "Reincidência (%)"),
        yaxis  = list(title = ""),
        margin = list(r = 80)
      )
  })

  output$grafico_classificacao <- renderPlotly({
    d <- dados() |>
      mutate(
        nivel = case_when(
          percentual_reincidencia >= 40 ~ "Alto (≥40%)",
          percentual_reincidencia >= 25 ~ "Médio (25–40%)",
          TRUE                          ~ "Baixo (<25%)"
        )
      ) |>
      group_by(nivel) |>
      summarise(n = n(), .groups = "drop")

    cores_nivel <- c(
      "Alto (≥40%)"    = "#E74C3C",
      "Médio (25–40%)" = "#F39C12",
      "Baixo (<25%)"   = "#2ECC71"
    )

    plot_ly(
      d,
      labels = ~nivel,
      values = ~n,
      type   = "pie",
      hole   = 0.5,
      marker = list(colors = unname(cores_nivel[d$nivel])),
      textinfo = "label+value"
    )
  })

  output$tabela_reincidencia <- DT::renderDT({
    d <- dados() |>
      arrange(desc(percentual_reincidencia)) |>
      rename(
        Região                   = regiao,
        `Reincidência (%)`       = percentual_reincidencia
      )

    DT::datatable(d, options = list(pageLength = 15, dom = "tp"), rownames = FALSE)
  })
}

shinyApp(ui, server)
