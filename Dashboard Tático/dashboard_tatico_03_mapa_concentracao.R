library(shiny)
library(bs4Dash)
library(plotly)
library(leaflet)
library(dplyr)
library(geobr)
library(sf)
library(DBI)
library(RMySQL)

source("conexao.R")

# Carrega shapefiles de Salvador (BA) uma única vez ao iniciar o app.
# bairros_sf é usado no spatial join para obter nomes reais de bairros a partir
# das coordenadas simuladas. municipio_sf serve como contorno de referência no mapa.
bairros_sf <- tryCatch(
  geobr::read_neighborhood(year = 2010, showProgress = FALSE) |>
    dplyr::filter(code_muni == 2927408) |>
    sf::st_transform(crs = 4326),
  error = function(e) NULL
)

municipio_sf <- tryCatch(
  geobr::read_municipality(code_muni = 2927408, year = 2020, showProgress = FALSE) |>
    sf::st_transform(crs = 4326),
  error = function(e) NULL
)

sql_concentracao <- "
  SELECT
    dl.regiao,
    dl.bairro,
    dl.latitude,
    dl.longitude,
    SUM(fo.quantidade_ocorrencias)      AS total_ocorrencias,
    SUM(fo.volume_estimado)             AS volume_total,
    SUM(fo.reincidencia)                AS reincidentes,
    COUNT(DISTINCT fo.sk_ponto)         AS pontos_distintos
  FROM fato_ocorrencia fo
  INNER JOIN dim_localizacao dl ON fo.sk_localizacao = dl.sk_localizacao
  WHERE dl.latitude IS NOT NULL AND dl.longitude IS NOT NULL
  GROUP BY dl.regiao, dl.bairro, dl.latitude, dl.longitude
"

# Faz o spatial join entre os pontos do banco e os polígonos de bairros do IBGE.
# Retorna o data.frame com a coluna name_neighborhood (nome real) adicionada.
# Quando bairros_sf não estiver disponível, usa o nome simulado como fallback.
enriquecer_com_bairro_real <- function(df, bairros_sf) {
  if (is.null(bairros_sf) || nrow(df) == 0) {
    return(mutate(df, bairro_real = bairro))
  }

  pontos_sf <- sf::st_as_sf(df, coords = c("longitude", "latitude"), crs = 4326)

  joined <- sf::st_join(pontos_sf, bairros_sf["name_neighborhood"], left = TRUE)

  df |>
    mutate(bairro_real = dplyr::coalesce(joined$name_neighborhood, bairro))
}

ui <- bs4DashPage(
  header  = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),

  body = bs4DashBody(
    fluidRow(
      bs4ValueBoxOutput("total_bairros",   width = 3),
      bs4ValueBoxOutput("bairro_critico",  width = 3),
      bs4ValueBoxOutput("media_bairro",    width = 3),
      bs4ValueBoxOutput("pct_reincidente", width = 3)
    ),

    fluidRow(
      bs4Card(
        title       = "Mapa de Concentração de Ocorrências",
        width       = 8,
        status      = "primary",
        solidHeader = TRUE,
        maximizable = TRUE,
        closable    = FALSE,
        leafletOutput("mapa_concentracao", height = 520)
      ),

      bs4Card(
        title       = "Top 10 Bairros por Volume",
        width       = 4,
        status      = "danger",
        solidHeader = TRUE,
        plotlyOutput("top_bairros", height = 520)
      )
    ),

    fluidRow(
      bs4Card(
        title       = "Total de Ocorrências por Região",
        width       = 12,
        status      = "warning",
        solidHeader = TRUE,
        plotlyOutput("por_regiao", height = 350)
      )
    )
  ),

  footer = bs4DashFooter()
)

server <- function(input, output, session) {

  dados_raw <- reactive({
    dbGetQuery(con, sql_concentracao)
  })

  # Enriquecimento com bairro real feito uma vez e cacheado
  dados <- reactive({
    enriquecer_com_bairro_real(dados_raw(), bairros_sf)
  })

  output$total_bairros <- renderbs4ValueBox({
    bs4ValueBox(
      value    = n_distinct(dados()$bairro_real),
      subtitle = "Bairros com Ocorrências",
      icon     = icon("map"),
      color    = "primary",
      gradient = TRUE
    )
  })

  output$bairro_critico <- renderbs4ValueBox({
    d      <- dados() |> group_by(bairro_real) |> summarise(total = sum(total_ocorrencias), .groups = "drop")
    bairro <- d$bairro_real[which.max(d$total)]
    bs4ValueBox(
      value    = bairro,
      subtitle = "Bairro com mais ocorrências",
      icon     = icon("exclamation-circle"),
      color    = "danger",
      gradient = TRUE
    )
  })

  output$media_bairro <- renderbs4ValueBox({
    media <- dados() |>
      group_by(bairro_real) |>
      summarise(total = sum(total_ocorrencias), .groups = "drop") |>
      summarise(m = round(mean(total), 0)) |>
      pull(m)
    bs4ValueBox(
      value    = format(media, big.mark = "."),
      subtitle = "Média de ocorrências por bairro",
      icon     = icon("chart-bar"),
      color    = "info",
      gradient = TRUE
    )
  })

  output$pct_reincidente <- renderbs4ValueBox({
    d   <- dados()
    pct <- round(100 * sum(d$reincidentes) / sum(d$total_ocorrencias), 1)
    bs4ValueBox(
      value    = paste0(pct, "%"),
      subtitle = "Taxa de Reincidência",
      icon     = icon("redo"),
      color    = "warning",
      gradient = TRUE
    )
  })

  output$mapa_concentracao <- renderLeaflet({
    d <- dados() |>
      group_by(bairro_real, regiao, latitude, longitude) |>
      summarise(
        total_ocorrencias = sum(total_ocorrencias),
        volume_total      = round(sum(volume_total), 1),
        .groups           = "drop"
      ) |>
      mutate(raio = 4 + 16 * (total_ocorrencias - min(total_ocorrencias)) /
               (max(total_ocorrencias) - min(total_ocorrencias) + 1))

    mapa <- leaflet(d) |>
      addProviderTiles(providers$CartoDB.DarkMatter)

    if (!is.null(bairros_sf)) {
      mapa <- mapa |>
        addPolygons(
          data        = bairros_sf,
          fill        = FALSE,
          color       = "#7F8C8D",
          weight      = 1,
          opacity     = 0.5,
          label       = ~name_neighborhood
        )
    }

    if (!is.null(municipio_sf)) {
      mapa <- mapa |>
        addPolygons(
          data    = municipio_sf,
          fill    = FALSE,
          color   = "#00bc8c",
          weight  = 2,
          opacity = 0.9
        )
    }

    mapa |>
      addCircleMarkers(
        lng         = ~longitude,
        lat         = ~latitude,
        radius      = ~raio,
        color       = "#E74C3C",
        fillColor   = "#E74C3C",
        fillOpacity = 0.7,
        stroke      = FALSE,
        popup       = ~paste0(
          "<b>Bairro:</b> ",       bairro_real, "<br>",
          "<b>Região:</b> ",       regiao,      "<br>",
          "<b>Ocorrências:</b> ",  format(total_ocorrencias, big.mark = "."), "<br>",
          "<b>Volume:</b> ",       volume_total
        )
      )
  })

  output$top_bairros <- renderPlotly({
    d <- dados() |>
      group_by(bairro_real) |>
      summarise(volume_total = sum(volume_total), .groups = "drop") |>
      slice_max(volume_total, n = 10)

    plot_ly(
      d,
      x           = ~volume_total,
      y           = ~reorder(bairro_real, volume_total),
      type        = "bar",
      orientation = "h",
      marker      = list(color = "#E74C3C")
    ) |>
      layout(
        xaxis = list(title = "Volume Total Estimado"),
        yaxis = list(title = "")
      )
  })

  output$por_regiao <- renderPlotly({
    d <- dados() |>
      group_by(regiao) |>
      summarise(
        total_ocorrencias = sum(total_ocorrencias),
        volume_total      = sum(volume_total),
        .groups           = "drop"
      ) |>
      arrange(desc(total_ocorrencias))

    plot_ly(d) |>
      add_bars(
        x = ~regiao, y = ~total_ocorrencias,
        name = "Ocorrências", marker = list(color = "#3498DB")
      ) |>
      add_lines(
        x = ~regiao, y = ~volume_total,
        name = "Volume Total", yaxis = "y2",
        line = list(color = "#F39C12", width = 3), mode = "lines+markers"
      ) |>
      layout(
        yaxis  = list(title = "Ocorrências"),
        yaxis2 = list(title = "Volume Total", overlaying = "y", side = "right"),
        xaxis  = list(title = "Região"),
        legend = list(orientation = "h", y = -0.2)
      )
  })
}

shinyApp(ui, server)
