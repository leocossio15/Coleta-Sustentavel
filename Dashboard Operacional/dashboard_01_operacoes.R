library(shiny)
library(bs4Dash)
library(plotly)
library(DBI)
library(RMySQL)

source("conexao.R")

ui <- bs4DashPage(
  header = bs4DashNavbar(disable = TRUE),
  
  sidebar = bs4DashSidebar(disable = TRUE),
  
  body = bs4DashBody(
    fluidRow(
      bs4ValueBoxOutput("abertas", width = 3),
      bs4ValueBoxOutput("atendimento", width = 3),
      bs4ValueBoxOutput("concluidas", width = 3),
      bs4ValueBoxOutput("urgentes", width = 3)
    ),
    
    fluidRow(
      bs4Card(
        title = "Ocorrências por Status",
        width = 6,
        status = "primary",
        solidHeader = TRUE,
        plotlyOutput("grafico_status", height = 400)
      ),
      
      bs4Card(
        title = "Ocorrências por Prioridade",
        width = 6,
        status = "warning",
        solidHeader = TRUE,
        plotlyOutput("grafico_prioridade", height = 400)
      )
    ),
    
    fluidRow(
      bs4Card(
        title = "Evolução das Ocorrências",
        width = 12,
        status = "success",
        solidHeader = TRUE,
        plotlyOutput("historico", height = 450)
      )
    )
  ),
  
  footer = bs4DashFooter()
  
)

server <- function(input, output, session){
  output$abertas <- renderbs4ValueBox({
    valor <- dbGetQuery(con,"
    SELECT COUNT(*) total FROM ocorrencia o
    JOIN status_ocorrencia s ON s.id_status = o.id_status
    WHERE s.nome_status NOT IN ('PENDENTE_VALIDACAO', 'REJEITADA')")
    bs4ValueBox(
      value = valor$total,
      subtitle = "Ocorrências",
      icon = icon("clipboard-list"),
      color = "warning",
      gradient = TRUE
    )

  })

  output$atendimento <- renderbs4ValueBox({
    valor <- dbGetQuery(con,"SELECT COUNT(*) total FROM atendimento_coleta")
    bs4ValueBox(
      value = valor$total,
      subtitle = "Atendimentos",
      icon = icon('truck'),
      color = "primary",
      gradient = TRUE
    )

  })

  output$concluidas <- renderbs4ValueBox({
    valor <- dbGetQuery(con,"
    SELECT COUNT(*) total FROM ocorrencia
    WHERE data_encerramento IS NOT NULL")

    bs4ValueBox(
      value = valor$total,
      subtitle = "Concluídas",
      icon = icon("check-circle"),
      color = "success",
      gradient = TRUE
    )

  })

  output$urgentes <- renderbs4ValueBox({
    valor <- dbGetQuery(con,"SELECT COUNT(*) total FROM ocorrencia
    WHERE prioridade='URGENTE'")
    bs4ValueBox(
      value = valor$total,
      subtitle = "Urgentes",
      icon = icon("fire"),
      color = "danger",
      gradient = TRUE
    )
  })

  output$grafico_status <- renderPlotly({
    dados <- dbGetQuery(con,"SELECT s.nome_status, COUNT(*) qtd
    FROM ocorrencia o
    JOIN status_ocorrencia s ON s.id_status=o.id_status
    GROUP BY s.nome_status")

    plot_ly(
      dados,
      x = ~nome_status,
      y = ~qtd,
      type = "bar",
      color = ~nome_status
    )%>%
      layout(
        xaxis = list(title = "Status"),
        yaxis = list(title = "Quantidade")
      )

  })

  output$grafico_prioridade <- renderPlotly({
    dados <- dbGetQuery(con,"SELECT prioridade, COUNT(*) quantidade
    FROM ocorrencia
    GROUP BY prioridade")

    plot_ly(
      dados,
      labels = ~prioridade,
      values = ~quantidade,
      type = "pie",
      hole = .55
    )
  })

  output$historico <- renderPlotly({
    dados <- dbGetQuery(con,"SELECT YEAR(data_ocorrencia) ano,
    MONTH(data_ocorrencia) mes,
    COUNT(*) quantidade
    FROM ocorrencia
    GROUP BY ano, mes
    ORDER BY ano, mes")

    dados$data <- as.Date(
      paste(dados$ano, dados$mes, "01", sep = "-")
    )

    plot_ly(
      dados,
      x = ~data,
      y = ~quantidade,
      type = "scatter",
      mode = "lines+markers"
    ) %>%
      layout(
        yaxis = list(title = "Quantidade"),
        xaxis = list(
          title = "Data",
          tickformat = "%m/%Y",
          dtick = "M1" #intervalo de 1 mês
        )
      )
  })
}

shinyApp(ui, server)
