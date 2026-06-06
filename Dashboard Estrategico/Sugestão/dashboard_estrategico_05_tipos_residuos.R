library(shiny)
library(bs4Dash)
library(plotly)
library(dplyr)
library(DBI)
library(RMySQL)

source("conexao.R")

sql_tipos_residuos <- "
  SELECT
    r.tipo_residuo,
    SUM(f.quantidade_residuos) AS total_residuos
  FROM fato_ocorrencia f
  JOIN dim_residuo r
    ON f.sk_residuo = r.sk_residuo
  GROUP BY r.tipo_residuo
  ORDER BY total_residuos DESC
"

ui <- bs4DashPage(
  header  = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),

  body = bs4DashBody(

    fluidRow(
      bs4ValueBoxOutput("tipo_predominante",   width = 4),
      bs4ValueBoxOutput("total_residuos",      width = 4),
      bs4ValueBoxOutput("total_tipos",         width = 4)
    ),

    fluidRow(
      bs4Card(
        title       = "Ranking de Tipos de Resíduos por Quantidade",
        width       = 8,
        status      = "danger",
        solidHeader = TRUE,
        plotlyOutput("grafico_ranking", height = 480)
      ),

      bs4Card(
        title       = "Participação Percentual",
        width       = 4,
        status      = "warning",
        solidHeader = TRUE,
        plotlyOutput("grafico_proporcao", height = 480)
      )
    ),

    fluidRow(
      bs4Card(
        title       = "Dados Consolidados por Tipo de Resíduo",
        width       = 12,
        status      = "secondary",
        solidHeader = TRUE,
        DT::DTOutput("tabela_residuos")
      )
    )
  ),

  footer = bs4DashFooter()
)

server <- function(input, output, session) {

  dados <- reactive({
    dbGetQuery(con, sql_tipos_residuos) |>
      mutate(pct = round(100 * total_residuos / sum(total_residuos), 1))
  })

  output$tipo_predominante <- renderbs4ValueBox({
    d <- dados()
    bs4ValueBox(
      value    = d$tipo_residuo[1],
      subtitle = paste0("Tipo mais descartado (", d$total_residuos[1], " unid.)"),
      icon     = icon("trash"),
      color    = "danger",
      gradient = TRUE
    )
  })

  output$total_residuos <- renderbs4ValueBox({
    total <- sum(dados()$total_residuos, na.rm = TRUE)
    bs4ValueBox(
      value    = format(total, big.mark = "."),
      subtitle = "Total de resíduos registrados",
      icon     = icon("recycle"),
      color    = "warning",
      gradient = TRUE
    )
  })

  output$total_tipos <- renderbs4ValueBox({
    bs4ValueBox(
      value    = nrow(dados()),
      subtitle = "Tipos de resíduos distintos",
      icon     = icon("tags"),
      color    = "info",
      gradient = TRUE
    )
  })

  output$grafico_ranking <- renderPlotly({
    d <- dados() |> arrange(total_residuos)

    plot_ly(
      d,
      x           = ~total_residuos,
      y           = ~reorder(tipo_residuo, total_residuos),
      type        = "bar",
      orientation = "h",
      marker      = list(
        color = colorRampPalette(c("#F8C471", "#E74C3C"))(nrow(d))
      ),
      text        = ~format(total_residuos, big.mark = "."),
      textposition = "outside",
      hovertemplate = "<b>%{y}</b><br>Qtd: %{x}<br>%{customdata}%<extra></extra>",
      customdata  = ~pct
    ) |>
      layout(
        xaxis  = list(title = "Quantidade de Resíduos"),
        yaxis  = list(title = ""),
        margin = list(r = 80)
      )
  })

  output$grafico_proporcao <- renderPlotly({
    d <- dados()

    plot_ly(
      d,
      labels   = ~tipo_residuo,
      values   = ~total_residuos,
      type     = "pie",
      hole     = 0.0,
      textinfo = "label+percent",
      hovertemplate = "<b>%{label}</b><br>%{value} unid. (%{percent})<extra></extra>"
    ) |>
      layout(
        showlegend = FALSE
      )
  })

  output$tabela_residuos <- DT::renderDT({
    d <- dados() |>
      rename(
        `Tipo de Resíduo`    = tipo_residuo,
        `Total de Resíduos`  = total_residuos,
        `Participação (%)`   = pct
      )

    DT::datatable(d, options = list(pageLength = 15, dom = "tp"), rownames = FALSE)
  })
}

shinyApp(ui, server)
