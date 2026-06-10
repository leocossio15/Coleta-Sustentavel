# Contextualização

O crescimento urbano acelerado tem ampliado os desafios relacionados à gestão de resíduos sólidos nas cidades. Um dos principais problemas é a falta de integração entre dados operacionais, monitoramento territorial e ferramentas inteligentes de análise urbana.

Em muitos municípios, o descarte irregular e o acúmulo frequente de lixo em determinadas regiões impactam diretamente:

- Saúde pública  
- Mobilidade urbana  
- Drenagem das cidades  
- Preservação ambiental  
- Qualidade de vida da população  

Além disso, a ausência de monitoramento eficiente dificulta o planejamento das ações de limpeza urbana e a identificação de áreas críticas. Na maioria dos cenários, os registros de coleta são descentralizados e limitados a controles operacionais básicos, sem aproveitamento analítico dos dados gerados diariamente.

Como consequência, surgem problemas como:

- Aumento dos custos operacionais  
- Desperdício de recursos públicos  
- Reincidência de descarte irregular  
- Baixa eficiência nas ações preventivas da gestão urbana  

Diante desse contexto, este projeto propõe o desenvolvimento de um ecossistema open-source de banco de dados voltado ao monitoramento inteligente da coleta urbana e à identificação de padrões de acúmulo de resíduos sólidos.

A proposta integra:

- Ambientes transacionais (OLTP)  
- Estruturas analíticas multidimensionais (OLAP)  
- Dashboards gerenciais  
- Técnicas de mineração de dados  

O objetivo é transformar registros operacionais em informações estratégicas para apoiar a gestão pública.

O sistema será responsável pela coleta e análise de dados relacionados a:

- Ocorrências de descarte irregular  
- Localização de pontos críticos  
- Frequência de reincidência  
- Tipos de resíduos  
- Volume acumulado  
- Tempo de resolução  

Com isso, será possível realizar análises descritivas, diagnósticas e preditivas, permitindo identificar regiões mais vulneráveis e prever áreas com maior probabilidade de reincidência.

No contexto da mineração de dados, o projeto permitirá aplicar técnicas de:

- Classificação  
- Previsão  
- Descoberta de padrões  

Essas análises contribuirão para categorizar áreas críticas por nível de risco, prever novos acúmulos de resíduos e identificar fatores associados ao descarte irregular.

Os resultados poderão auxiliar na elaboração de planos de ação mais eficientes, no direcionamento de políticas públicas e na otimização das estratégias de limpeza urbana e sustentabilidade municipal.

## Objetivos de Desenvolvimento Sustentável (ODS)

O projeto está alinhado principalmente com:

- **ODS 11 – Cidades e Comunidades Sustentáveis**  
  Uso estratégico de dados e tecnologia para cidades mais organizadas, resilientes e sustentáveis.

- **ODS 12 – Consumo e Produção Responsáveis**  
  Incentivo a práticas adequadas de descarte e gestão de resíduos.

- **ODS 13 – Ação Contra a Mudança Global do Clima**  
  Redução dos impactos ambientais causados pelo acúmulo inadequado de resíduos sólidos urbanos.

## Governança das Denúncias e Proteção do Denunciante

Como parte do processo de monitoramento urbano, o sistema permite o registro de denúncias relacionadas ao descarte irregular de resíduos. Considerando que essas informações podem impactar diretamente análises, indicadores e decisões da gestão pública, foram definidos mecanismos para garantir a confiabilidade dos dados e a proteção da identidade dos denunciantes.

### Autenticação e Responsabilização

- Todo denunciante deve possuir identificação única no sistema.
- Cada denúncia fica associada a um usuário autenticado.
- O objetivo é reduzir fraudes, denúncias falsas e tentativas de manipulação dos indicadores urbanos.
- A autenticação permite responsabilização em casos de uso indevido da plataforma, sem comprometer a privacidade do cidadão.

### Proteção da Identidade

- Os dados de identificação do denunciante não são exibidos em consultas operacionais.
- Relatórios, dashboards e análises utilizam apenas informações da ocorrência e da localização.
- A identidade do denunciante permanece restrita aos mecanismos internos de validação e segurança.
- O sistema busca equilibrar responsabilização e privacidade, garantindo que a origem da denúncia possa ser verificada sem exposição pública do usuário.

### Validação das Ocorrências

Toda denúncia passa por um fluxo de validação antes de integrar as análises do sistema:

1. Pendente de Validação
2. Aprovada
3. Em Atendimento
4. Encerrada
5. Rejeitada
6. Duplicada

Somente ocorrências validadas participam dos indicadores, dashboards e análises gerenciais utilizados para apoio à tomada de decisão.

### Tratamento de Denúncias Falsas

- Denúncias comprovadamente falsas podem resultar no bloqueio do usuário para novos registros.
- O bloqueio não representa exclusão da conta nem remoção dos dados armazenados.
- O usuário permanece cadastrado no sistema, porém fica impedido de registrar novas denúncias enquanto a restrição estiver ativa.
- Essa medida foi adotada como mecanismo de prevenção à desinformação e proteção da qualidade dos dados utilizados nas análises urbanas.
- O objetivo não é punir o cidadão, mas preservar a confiabilidade das informações que subsidiam ações e políticas públicas.

### Revisão Administrativa

- Usuários bloqueados podem solicitar reavaliação da decisão.
- O bloqueio pode ser revertido após análise administrativa realizada pelos responsáveis pela plataforma.
- Esse procedimento busca evitar penalizações indevidas decorrentes de possíveis erros de avaliação.
- A existência de mecanismos de recurso garante maior equilíbrio entre controle de qualidade dos dados e tratamento justo dos usuários.

### Considerações Acadêmicas

Para fins de modelagem de banco de dados e desenvolvimento da disciplina, o projeto adota uma versão simplificada desse processo, representando mecanismos básicos de autenticação, validação, auditoria e prevenção de fraudes.

Em um cenário real de implantação, recomenda-se complementar a solução com:

- Auditorias periódicas;
- Análise de reincidência;
- Mecanismos formais de recurso;
- Integração com canais de atendimento;
- Políticas institucionais de governança de dados;
- Procedimentos específicos de conformidade com a LGPD.

Essa abordagem permite representar adequadamente os controles necessários para garantir a qualidade das informações sem aumentar excessivamente a complexidade do modelo de dados proposto para o projeto acadêmico.