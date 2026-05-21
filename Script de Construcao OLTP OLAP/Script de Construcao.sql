-- =========================================================
-- PROJETO: LABORATÓRIO DE DADOS PARA CIDADES SUSTENTÁVEIS
-- SCRIPT COMPLETO - OLTP + OLAP
-- =========================================================

CREATE DATABASE laboratorio_cidades_sustentaveis;

USE laboratorio_cidades_sustentaveis;

-- =========================================================
-- ===================== OLTP ==============================
-- =========================================================

CREATE TABLE regiao_administrativa (
    id_regiao INT PRIMARY KEY AUTO_INCREMENT,
    nome_regiao VARCHAR(100) NOT NULL UNIQUE,
    descricao VARCHAR(255)
);

CREATE TABLE bairro (
    id_bairro INT PRIMARY KEY AUTO_INCREMENT,
    id_regiao INT NOT NULL,
    nome_bairro VARCHAR(100) NOT NULL,
    cep_principal VARCHAR(10),

    CONSTRAINT fk_bairro_regiao
        FOREIGN KEY (id_regiao)
        REFERENCES regiao_administrativa(id_regiao)
);

CREATE TABLE logradouro (
    id_logradouro INT PRIMARY KEY AUTO_INCREMENT,
    id_bairro INT NOT NULL,
    tipo_logradouro VARCHAR(30) NOT NULL,
    nome_logradouro VARCHAR(120) NOT NULL,
    cep VARCHAR(10),

    CONSTRAINT fk_logradouro_bairro
        FOREIGN KEY (id_bairro)
        REFERENCES bairro(id_bairro)
);

CREATE TABLE ponto_monitorado (
    id_ponto INT PRIMARY KEY AUTO_INCREMENT,
    id_logradouro INT NOT NULL,

    numero VARCHAR(10),
    complemento VARCHAR(100),
    referencia VARCHAR(150),

    latitude DECIMAL(10,7) NOT NULL,
    longitude DECIMAL(10,7) NOT NULL,

    ativo BOOLEAN NOT NULL DEFAULT TRUE,

    data_cadastro DATE NOT NULL,

    CONSTRAINT fk_ponto_logradouro
        FOREIGN KEY (id_logradouro)
        REFERENCES logradouro(id_logradouro)
);

CREATE TABLE tipo_residuo (
    id_tipo_residuo INT PRIMARY KEY AUTO_INCREMENT,

    nome_tipo VARCHAR(80) NOT NULL UNIQUE,

    categoria VARCHAR(50) NOT NULL,

    periculosidade VARCHAR(20) NOT NULL,

    descricao VARCHAR(255),

    CONSTRAINT chk_periculosidade
        CHECK (
            periculosidade IN (
                'BAIXA',
                'MEDIA',
                'ALTA'
            )
        )
);

CREATE TABLE status_ocorrencia (
    id_status INT PRIMARY KEY AUTO_INCREMENT,

    nome_status VARCHAR(50) NOT NULL UNIQUE,

    descricao VARCHAR(255),

    ordem_fluxo INT NOT NULL
);

CREATE TABLE responsavel (
    id_responsavel INT PRIMARY KEY AUTO_INCREMENT,

    nome VARCHAR(120) NOT NULL,

    cargo VARCHAR(80) NOT NULL,

    telefone VARCHAR(20),

    email VARCHAR(120) UNIQUE
);

CREATE TABLE ocorrencia (
    id_ocorrencia INT PRIMARY KEY AUTO_INCREMENT,

    id_ponto INT NOT NULL,

    id_status INT NOT NULL,

    id_responsavel INT,

    data_abertura DATETIME NOT NULL,

    data_ocorrencia DATETIME NOT NULL,

    descricao TEXT NOT NULL,

    data_encerramento DATETIME,

    prioridade VARCHAR(20) NOT NULL,

    observacao VARCHAR(255),

    url_anexo VARCHAR(100),

    CONSTRAINT fk_ocorrencia_ponto
        FOREIGN KEY (id_ponto)
        REFERENCES ponto_monitorado(id_ponto),

    CONSTRAINT fk_ocorrencia_status
        FOREIGN KEY (id_status)
        REFERENCES status_ocorrencia(id_status),

    CONSTRAINT fk_ocorrencia_responsavel
        FOREIGN KEY (id_responsavel)
        REFERENCES responsavel(id_responsavel),

    CONSTRAINT chk_prioridade
        CHECK (
            prioridade IN (
                'BAIXA',
                'MEDIA',
                'ALTA',
                'URGENTE'
            )
        )
);

CREATE TABLE ocorrencia_residuo (
    id_ocorrencia_residuo INT PRIMARY KEY AUTO_INCREMENT,

    id_ocorrencia INT NOT NULL,

    id_tipo_residuo INT NOT NULL,

    volume_estimado DECIMAL(10,2),

    unidade_medida VARCHAR(20),

    quantidade INT NOT NULL,

    CONSTRAINT fk_ocorrencia_residuo_ocorrencia
        FOREIGN KEY (id_ocorrencia)
        REFERENCES ocorrencia(id_ocorrencia),

    CONSTRAINT fk_ocorrencia_residuo_tipo
        FOREIGN KEY (id_tipo_residuo)
        REFERENCES tipo_residuo(id_tipo_residuo)
);

CREATE TABLE atendimento_coleta (
    id_atendimento INT PRIMARY KEY AUTO_INCREMENT,

    id_ocorrencia INT NOT NULL,

    id_responsavel INT NOT NULL,

    data_agendada DATETIME,

    data_inicio DATETIME,

    data_fim DATETIME,

    volume_removido DECIMAL(10,2),

    unidade_medida VARCHAR(20),

    status_atendimento VARCHAR(30) NOT NULL,

    observacao TEXT,

    CONSTRAINT fk_atendimento_ocorrencia
        FOREIGN KEY (id_ocorrencia)
        REFERENCES ocorrencia(id_ocorrencia),

    CONSTRAINT fk_atendimento_responsavel
        FOREIGN KEY (id_responsavel)
        REFERENCES responsavel(id_responsavel)
);

CREATE TABLE vistoria_ponto (
    id_vistoria INT PRIMARY KEY AUTO_INCREMENT,

    id_ponto INT NOT NULL,

    id_responsavel INT NOT NULL,

    data_vistoria DATETIME NOT NULL,

    nivel_acumulo VARCHAR(20) NOT NULL,

    condicao_local VARCHAR(100) NOT NULL,

    observacao TEXT,

    CONSTRAINT fk_vistoria_ponto
        FOREIGN KEY (id_ponto)
        REFERENCES ponto_monitorado(id_ponto),

    CONSTRAINT fk_vistoria_responsavel
        FOREIGN KEY (id_responsavel)
        REFERENCES responsavel(id_responsavel)
);

-- =========================================================
-- ===================== OLAP ==============================
-- =========================================================

CREATE TABLE dim_tempo (
    sk_tempo INT PRIMARY KEY AUTO_INCREMENT,
    data_completa DATE,
    dia INT,
    mes INT,
    nome_mes VARCHAR(20),
    trimestre INT,
    semestre INT,
    ano INT,
    dia_semana VARCHAR(20),
    fim_semana BOOLEAN
);

CREATE TABLE dim_localizacao (
    sk_localizacao INT PRIMARY KEY AUTO_INCREMENT,
    regiao VARCHAR(100),
    bairro VARCHAR(100),
    logradouro VARCHAR(120),
    cep VARCHAR(10),
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7)
);

CREATE TABLE dim_residuo (
    sk_residuo INT PRIMARY KEY AUTO_INCREMENT,
    tipo_residuo VARCHAR(80),
    categoria VARCHAR(50),
    periculosidade VARCHAR(20),
    descricao VARCHAR(255)
);

CREATE TABLE dim_status (
    sk_status INT PRIMARY KEY AUTO_INCREMENT,
    status VARCHAR(50),
    ordem_fluxo INT
);

CREATE TABLE dim_responsavel (
    sk_responsavel INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(120),
    cargo VARCHAR(80)
);

CREATE TABLE dim_prioridade (
    sk_prioridade INT PRIMARY KEY AUTO_INCREMENT,
    prioridade VARCHAR(20)
);

CREATE TABLE dim_ponto_monitorado (
    sk_ponto INT PRIMARY KEY AUTO_INCREMENT,
    id_ponto_origem INT,
    referencia VARCHAR(150),
    ativo BOOLEAN,
    data_cadastro DATE
);

CREATE TABLE fato_ocorrencia (
    id_fato_ocorrencia INT PRIMARY KEY AUTO_INCREMENT,

    sk_tempo INT NOT NULL,
    sk_localizacao INT NOT NULL,
    sk_residuo INT NOT NULL,
    sk_status INT NOT NULL,
    sk_responsavel INT,
    sk_prioridade INT NOT NULL,
    sk_ponto INT NOT NULL,

    quantidade_ocorrencias INT,
    volume_estimado DECIMAL(10,2),
    quantidade_residuos INT,
    tempo_resolucao_horas DECIMAL(10,2),
    reincidencia BOOLEAN,
    total_atendimentos INT,

    CONSTRAINT fk_fato_tempo
        FOREIGN KEY (sk_tempo)
        REFERENCES dim_tempo(sk_tempo),

    CONSTRAINT fk_fato_localizacao
        FOREIGN KEY (sk_localizacao)
        REFERENCES dim_localizacao(sk_localizacao),

    CONSTRAINT fk_fato_residuo
        FOREIGN KEY (sk_residuo)
        REFERENCES dim_residuo(sk_residuo),

    CONSTRAINT fk_fato_status
        FOREIGN KEY (sk_status)
        REFERENCES dim_status(sk_status),

    CONSTRAINT fk_fato_responsavel
        FOREIGN KEY (sk_responsavel)
        REFERENCES dim_responsavel(sk_responsavel),

    CONSTRAINT fk_fato_prioridade
        FOREIGN KEY (sk_prioridade)
        REFERENCES dim_prioridade(sk_prioridade),

    CONSTRAINT fk_fato_ponto
        FOREIGN KEY (sk_ponto)
        REFERENCES dim_ponto_monitorado(sk_ponto)
);

-- =========================================================
-- FIM DO SCRIPT
-- =========================================================