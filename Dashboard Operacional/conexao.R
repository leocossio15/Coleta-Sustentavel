library(DBI)
library(RMySQL)

con <- dbConnect(
  MySQL(),
  dbname = "laboratorio_cidades_sustentaveis",
  host = "localhost",
  port = 3306,
  user = "root",
  password = "123456"
)

shiny::onStop(function() {
  if (DBI::dbIsValid(con)) {
    DBI::dbDisconnect(con)
  }
})
