library(shiny)
library(bs4Dash)
library(plotly)
library(dplyr)
library(DBI)
library(RMySQL)

source("conexao.R")

sql_eficiencia <- "
  SELECT
    l.regiao,
    SUM(f.quantidade_ocorrencias) AS ocorrencias,
    SUM(f.total_atendimentos)     AS atendimentos,
    ROUND(
      (SUM(f.total_atendimentos) /
       NULLIF(SUM(f.quantidade_ocorrencias), 0)) * 100,
      2
    ) AS taxa_atendimento
  FROM fato_ocorrencia f
  INNER JOIN dim_localizacao l
    ON f.sk_localizacao = l.sk_localizacao
  GROUP BY l.regiao
  ORDER BY taxa_atendimento DESC
"

# Meta estratégica de atendimento: 85%
META_ATENDIMENTO <- 85

ui <- bs4DashPage(
  header  = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),

  body = bs4DashBody(

    fluidRow(
      bs4ValueBoxOutput("eficiencia_global",   width = 3),
      bs4ValueBoxOutput("regiao_melhor",       width = 3),
      bs4ValueBoxOutput("regiao_pior",         width = 3),
      bs4ValueBoxOutput("regioes_abaixo_meta", width = 3)
    ),

    fluidRow(
      bs4Card(
        title       = "Taxa de Atendimento por Região (%)",
        width       = 8,
        status      = "success",
        solidHeader = TRUE,
        plotlyOutput("grafico_eficiencia", height = 450)
      ),

      bs4Card(
        title       = "Ocorrências vs Atendimentos por Região",
        width       = 4,
        status      = "primary",
        solidHeader = TRUE,
        plotlyOutput("grafico_gap", height = 450)
      )
    ),

    fluidRow(
      bs4Card(
        title       = "Dados Consolidados — Eficiência por Região",
        width       = 12,
        status      = "secondary",
        solidHeader = TRUE,
        DT::DTOutput("tabela_eficiencia")
      )
    )
  ),

  footer = bs4DashFooter()
)

server <- function(input, output, session) {

  dados <- reactive({
    dbGetQuery(con, sql_eficiencia)
  })

  eficiencia_global <- reactive({
    d <- dados()
    round(100 * sum(d$atendimentos, na.rm = TRUE) /
            sum(d$ocorrencias, na.rm = TRUE), 2)
  })

  output$eficiencia_global <- renderbs4ValueBox({
    ef  <- eficiencia_global()
    cor <- if (ef >= META_ATENDIMENTO) "success" else "danger"
    bs4ValueBox(
      value    = paste0(ef, "%"),
      subtitle = paste0("Eficiência global (meta: ", META_ATENDIMENTO, "%)"),
      icon     = icon("check-circle"),
      color    = cor,
      gradient = TRUE
    )
  })

  output$regiao_melhor <- renderbs4ValueBox({
    d   <- dados()
    idx <- which.max(d$taxa_atendimento)
    bs4ValueBox(
      value    = paste0(d$regiao[idx], " (", d$taxa_atendimento[idx], "%)"),
      subtitle = "Região com maior eficiência",
      icon     = icon("trophy"),
      color    = "success",
      gradient = TRUE
    )
  })

  output$regiao_pior <- renderbs4ValueBox({
    d   <- dados()
    idx <- which.min(d$taxa_atendimento)
    bs4ValueBox(
      value    = paste0(d$regiao[idx], " (", d$taxa_atendimento[idx], "%)"),
      subtitle = "Região com menor eficiência",
      icon     = icon("exclamation-triangle"),
      color    = "danger",
      gradient = TRUE
    )
  })

  output$regioes_abaixo_meta <- renderbs4ValueBox({
    n <- sum(dados()$taxa_atendimento < META_ATENDIMENTO, na.rm = TRUE)
    bs4ValueBox(
      value    = n,
      subtitle = paste0("Regiões abaixo da meta de ", META_ATENDIMENTO, "%"),
      icon     = icon("times-circle"),
      color    = if (n > 0) "warning" else "success",
      gradient = TRUE
    )
  })

  output$grafico_eficiencia <- renderPlotly({
    d <- dados() |>
      arrange(taxa_atendimento) |>
      mutate(
        cor = ifelse(taxa_atendimento >= META_ATENDIMENTO, "#2ECC71", "#E74C3C")
      )

    plot_ly(
      d,
      x           = ~taxa_atendimento,
      y           = ~reorder(regiao, taxa_atendimento),
      type        = "bar",
      orientation = "h",
      marker      = list(color = ~cor),
      text        = ~paste0(taxa_atendimento, "%"),
      textposition = "outside",
      hovertemplate = "<b>%{y}</b><br>Taxa: %{x}%<extra></extra>"
    ) |>
      layout(
        shapes = list(list(
          type = "line",
          x0   = META_ATENDIMENTO, x1 = META_ATENDIMENTO,
          y0   = -0.5,             y1 = nrow(d) - 0.5,
          line = list(color = "#2C3E50", dash = "dash", width = 1.5)
        )),
        annotations = list(list(
          x    = META_ATENDIMENTO, y = nrow(d) - 0.3,
          text = paste0("Meta: ", META_ATENDIMENTO, "%"),
          showarrow = FALSE,
          font = list(color = "#2C3E50", size = 11)
        )),
        xaxis  = list(title = "Taxa de Atendimento (%)", range = c(0, 115)),
        yaxis  = list(title = ""),
        margin = list(r = 60)
      )
  })

  output$grafico_gap <- renderPlotly({
    d <- dados() |> arrange(desc(ocorrencias))

    plot_ly(d, x = ~regiao) |>
      add_bars(
        y    = ~ocorrencias,
        name = "Ocorrências",
        marker = list(color = "#3498DB"),
        text = ~format(ocorrencias, big.mark = "."),
        textposition = "outside"
      ) |>
      add_bars(
        y    = ~atendimentos,
        name = "Atendimentos",
        marker = list(color = "#2ECC71"),
        text = ~format(atendimentos, big.mark = "."),
        textposition = "outside"
      ) |>
      layout(
        barmode = "group",
        xaxis   = list(title = "Região", tickangle = -30),
        yaxis   = list(title = "Quantidade"),
        legend  = list(orientation = "h", y = -0.25),
        margin  = list(b = 80)
      )
  })

  output$tabela_eficiencia <- DT::renderDT({
    d <- dados() |>
      arrange(desc(taxa_atendimento)) |>
      mutate(gap = ocorrencias - atendimentos) |>
      rename(
        Região               = regiao,
        Ocorrências          = ocorrencias,
        Atendimentos         = atendimentos,
        `Taxa (%)`           = taxa_atendimento,
        `Gap (não atendidos)` = gap
      )

    DT::datatable(d, options = list(pageLength = 15, dom = "tp"), rownames = FALSE)
  })
}

shinyApp(ui, server)
