library(shiny)
library(bs4Dash)
library(plotly)
library(dplyr)
library(DBI)
library(RMySQL)

source("conexao.R")

sql_volume_regiao <- "
  SELECT
    l.regiao,
    SUM(f.volume_estimado) AS volume_total
  FROM fato_ocorrencia f
  JOIN dim_localizacao l
    ON f.sk_localizacao = l.sk_localizacao
  GROUP BY l.regiao
  ORDER BY volume_total DESC
"

ui <- bs4DashPage(
  header  = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),

  body = bs4DashBody(

    fluidRow(
      bs4ValueBoxOutput("total_volume",    width = 4),
      bs4ValueBoxOutput("regiao_lider",    width = 4),
      bs4ValueBoxOutput("media_por_regiao", width = 4)
    ),

    fluidRow(
      bs4Card(
        title       = "Volume Total de Resíduos por Região",
        width       = 8,
        status      = "warning",
        solidHeader = TRUE,
        plotlyOutput("grafico_barras", height = 450)
      ),

      bs4Card(
        title       = "Participação Percentual por Região",
        width       = 4,
        status      = "primary",
        solidHeader = TRUE,
        plotlyOutput("grafico_donut", height = 450)
      )
    ),

    fluidRow(
      bs4Card(
        title       = "Dados Consolidados — Volume por Região",
        width       = 12,
        status      = "secondary",
        solidHeader = TRUE,
        DT::DTOutput("tabela_volume")
      )
    )
  ),

  footer = bs4DashFooter()
)

server <- function(input, output, session) {

  dados <- reactive({
    dbGetQuery(con, sql_volume_regiao)
  })

  output$total_volume <- renderbs4ValueBox({
    total <- sum(dados()$volume_total, na.rm = TRUE)
    bs4ValueBox(
      value    = format(round(total, 0), big.mark = "."),
      subtitle = "Volume Total Estimado (m³)",
      icon     = icon("dumpster"),
      color    = "warning",
      gradient = TRUE
    )
  })

  output$regiao_lider <- renderbs4ValueBox({
    d      <- dados()
    regiao <- d$regiao[which.max(d$volume_total)]
    vol    <- format(round(max(d$volume_total, na.rm = TRUE), 0), big.mark = ".")
    bs4ValueBox(
      value    = paste0(regiao, " (", vol, " m³)"),
      subtitle = "Região com maior volume",
      icon     = icon("map-marker-alt"),
      color    = "danger",
      gradient = TRUE
    )
  })

  output$media_por_regiao <- renderbs4ValueBox({
    media <- round(mean(dados()$volume_total, na.rm = TRUE), 0)
    bs4ValueBox(
      value    = format(media, big.mark = "."),
      subtitle = "Média de volume por região (m³)",
      icon     = icon("chart-bar"),
      color    = "info",
      gradient = TRUE
    )
  })

  output$grafico_barras <- renderPlotly({
    d <- dados() |> arrange(volume_total)

    plot_ly(
      d,
      x           = ~volume_total,
      y           = ~reorder(regiao, volume_total),
      type        = "bar",
      orientation = "h",
      marker      = list(color = "#F39C12"),
      text        = ~format(round(volume_total, 0), big.mark = "."),
      textposition = "outside",
      hovertemplate = "<b>%{y}</b><br>Volume: %{x} m³<extra></extra>"
    ) |>
      layout(
        xaxis  = list(title = "Volume Estimado (m³)"),
        yaxis  = list(title = ""),
        margin = list(r = 80)
      )
  })

  output$grafico_donut <- renderPlotly({
    d <- dados()

    plot_ly(
      d,
      labels = ~regiao,
      values = ~volume_total,
      type   = "pie",
      hole   = 0.55,
      textinfo = "label+percent"
    )
  })

  output$tabela_volume <- DT::renderDT({
    d <- dados() |>
      mutate(
        volume_total = round(volume_total, 2),
        pct = round(100 * volume_total / sum(volume_total), 1)
      ) |>
      rename(
        Região           = regiao,
        `Volume (m³)`    = volume_total,
        `Participação (%)` = pct
      )

    DT::datatable(d, options = list(pageLength = 15, dom = "tp"), rownames = FALSE)
  })
}

shinyApp(ui, server)
