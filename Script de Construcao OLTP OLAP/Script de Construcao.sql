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
-- =========================================================
-- PROJETO: LABORATÓRIO DE DADOS PARA CIDADES SUSTENTÁVEIS
-- SCRIPT DE AJUSTES — REVISÃO PÓS FEEDBACK
-- =========================================================

USE laboratorio_cidades_sustentaveis;

-- =========================================================
-- [CRIADO] Tabela: denunciante
-- Autentica o cidadão via CPF sem expor sua identidade.
-- =========================================================

CREATE TABLE denunciante (
    id_denunciante  INT          PRIMARY KEY AUTO_INCREMENT,

    cpf_hash        CHAR(64)     NOT NULL UNIQUE,
    /*
      CPF armazenado EXCLUSIVAMENTE como hash irreversível.
      O CPF em texto claro NUNCA é gravado no banco.
      Finalidade: verificar bloqueio na próxima tentativa de denúncia
      sem armazenar dado pessoal bruto.
    */
    bloqueado       BOOLEAN      NOT NULL DEFAULT FALSE,
    data_bloqueio   DATETIME     NULL,
    motivo_bloqueio VARCHAR(255) NULL
    /*
      Preenchido quando bloqueado = TRUE.
      Valor esperado: 'DENUNCIA_FALSA_CONFIRMADA'
    */
);

/*
REGRAS DE NEGÓCIO — DENUNCIANTE:
  1. Para registrar uma ocorrência como cidadão, é obrigatório
     autenticar com CPF. O sistema computa o hash antes de
     persistir — nunca o dado bruto chega ao banco.

  2. A coluna cpf_hash possui permissão de leitura restrita
     a DBA/auditoria (GRANT SELECT ON denunciante.cpf_hash
     apenas para role de auditoria). Perfis operacionais e
     analíticos não têm acesso a essa coluna.

  3. Quando uma ocorrência é marcada como REJEITADA com
     motivo_rejeicao = 'DENUNCIA_FALSA_CONFIRMADA', a camada
     de aplicação executa:
       UPDATE denunciante
       SET bloqueado = TRUE,
           data_bloqueio = NOW(),
           motivo_bloqueio = 'DENUNCIA_FALSA_CONFIRMADA'
       WHERE id_denunciante = :id;

  4. Na próxima tentativa de registro, o sistema computa o hash
     do CPF informado e consulta:
       SELECT bloqueado FROM denunciante WHERE cpf_hash = :hash;
     Se bloqueado = TRUE, o acesso é negado.
     Como o CPF em claro nunca saiu do servidor de aplicação,
     nenhum dado pessoal foi exposto na consulta.

  5. O CPF único impede a criação de múltiplas contas para o
     mesmo denunciante — o hash UNIQUE garante isso em nível
     de banco.

  6. A "anonimidade operacional" é preservada: nenhum relatório,
     dashboard ou consulta de nível operacional/tático/estratégico
     exibe o id_denunciante ou o cpf_hash. Os dashboards exibem
     apenas volume de ocorrências por localização.
*/

-- =========================================================
-- [ALTERADO] Tabela: ocorrencia
-- Duas novas colunas.
-- =========================================================

-- Vincula a ocorrência ao denunciante cidadão
ALTER TABLE ocorrencia
    ADD COLUMN id_denunciante INT NULL,
    ADD CONSTRAINT fk_ocorrencia_denunciante
        FOREIGN KEY (id_denunciante)
        REFERENCES denunciante(id_denunciante);

/*
  NULL = ocorrência registrada internamente por servidor público
         (fluxo existente, sem alteração).
  NOT NULL = ocorrência originada por denúncia cidadã autenticada.
*/

-- Registra o motivo quando uma ocorrência é rejeitada
ALTER TABLE ocorrencia
    ADD COLUMN motivo_rejeicao VARCHAR(255) NULL;

/*
  Obrigatório (regra de aplicação) quando:
    status = 'REJEITADA'  → valores: 'DENUNCIA_FALSA_CONFIRMADA',
                            'SEM_EVIDENCIA_SUFICIENTE',
                            'FORA_DA_AREA_DE_COBERTURA', ou texto livre.
    status = 'DUPLICADA'  → id da ocorrência original deve constar
                            também em observacao.

  Quando motivo_rejeicao = 'DENUNCIA_FALSA_CONFIRMADA' e
  id_denunciante IS NOT NULL, a aplicação bloqueia o denunciante
  conforme regra da tabela denunciante.
*/

-- =========================================================
-- [ALTERADO] Dados: status_ocorrencia
-- Define o fluxo completo de validação. Alteração de dados,
-- não de estrutura — a tabela já existe com os campos corretos.
-- =========================================================

INSERT INTO status_ocorrencia (nome_status, descricao, ordem_fluxo) VALUES
('PENDENTE_VALIDACAO',
 'Ocorrência recém-registrada. Aguarda análise de responsável técnico antes de entrar no fluxo operacional. Não aparece em dashboards operacionais nem gera atendimento.',
 1),
('ABERTA',
 'Ocorrência validada e confirmada por responsável. Entra no fluxo de atendimento.',
 2),
('EM_ATENDIMENTO',
 'Atendimento de coleta agendado ou em execução.',
 3),
('ENCERRADA',
 'Coleta concluída e ponto saneado.',
 4),
('REJEITADA',
 'Ocorrência analisada e descartada. Motivo registrado obrigatoriamente em motivo_rejeicao.',
 5),
('DUPLICADA',
 'Ocorrência identificada como duplicata de registro já existente para o mesmo ponto e período. ID da original registrado em observacao.',
 6);

/*
REGRA DE NEGÓCIO — FLUXO DE VALIDAÇÃO:
  Toda ocorrência, independente da origem (cidadão ou servidor),
  nasce com status PENDENTE_VALIDACAO.
  Somente após validação manual por responsável técnico ela avança
  para ABERTA — esse passo é a barreira contra desinformação.
  Ocorrências em status PENDENTE_VALIDACAO são filtradas fora de
  todos os dashboards e da análise de dados.
*/


-- =========================================================
-- [ALTERADO] Tabela: tipo_residuo
-- Duas colunas para conformidade legal com CONAMA e ABNT.
-- =========================================================

ALTER TABLE tipo_residuo
    ADD COLUMN cor_padrao_conama VARCHAR(20) NULL,
    /*
      Resolução CONAMA 275/2001 — padrão de cores da coleta seletiva:
        AZUL     → papel e papelão
        VERMELHO → plástico
        VERDE    → vidro
        AMARELO  → metal
        MARROM   → resíduos orgânicos
        CINZA    → rejeito (não reciclável)
        LARANJA  → resíduos perigosos
        BRANCO   → serviços de saúde
      Alimenta a sinalização visual dos pontos de descarte no mapa.
    */

    ADD COLUMN classe_nbr VARCHAR(20) NULL;
    /*
      NBR ABNT 10.004/2004 — classificação por periculosidade:
        CLASSE_I   → perigosos       (= periculosidade ALTA)
        CLASSE_II_A → não inertes    (= periculosidade MEDIA)
        CLASSE_II_B → inertes        (= periculosidade BAIXA)
      O campo periculosidade existente (CHECK BAIXA/MEDIA/ALTA)
      é mantido sem alteração — classe_nbr documenta a
      correspondência normativa, sem substituir o campo original.
    */

/*
NOTA — PNRS (Lei 12.305/2010, Art. 13):
  A coluna "categoria" de tipo_residuo deve ser populada com os
  tipos definidos pela lei: DOMICILIAR, PÚBLICO, SERVIÇOS_DE_SAÚDE,
  INDUSTRIAL, CONSTRUÇÃO_CIVIL, AGROSILVOPASTORIL, MINERAÇÃO.
  Isso é restrição de conteúdo dos dados, não de estrutura DDL.
  Nenhuma alteração de coluna necessária.
*/