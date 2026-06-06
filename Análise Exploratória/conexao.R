library(DBI)
library(RMySQL)

con <- dbConnect(
  MySQL(),
  dbname   = "laboratorio_cidades_sustentaveis",
  host     = "localhost",
  port     = 3306,
  user     = "analise",
  password = "123456"
)