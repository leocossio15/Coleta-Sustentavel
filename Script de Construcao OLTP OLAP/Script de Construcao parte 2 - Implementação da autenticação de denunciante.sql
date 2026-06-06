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

    ADD COLUMN classe_nbr VARCHAR(10) NULL;
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