# Case Técnico: Retenção no Palavritas | the news

> **Analista de Dados (Produto & Growth)** - Este repositório documenta uma investigação sobre o que faz usuários voltarem a jogar o **Palavritas**, o jogo de palavras diário da newsletter **the news**. O foco não é código: é entender comportamento, encontrar alavancas reais de retenção e transformar insights em ações para o time de Produto.

---

## O que o case pede

Este case avalia cinco critérios, e cada entrega deste repositório responde diretamente a um deles:

| Critério | O que é avaliado | Onde está a resposta |
|---|---|---|
| **Limpeza** | Identificou e tratou os problemas antes de analisar? Documentou as decisões? | `notebooks/01_limpeza_e_diagnostico.ipynb` + seção abaixo |
| **Raciocínio analítico** | Foi além do óbvio? Questionou a pergunta antes de responder? | `notebooks/02_analise_e_cruzamentos.ipynb` + seção de achados |
| **Comunicação** | O documento pode ser lido pelo Head de Produto sem jargão técnico? | Este README + Dashboard executivo |
| **Propositivo** | Chegou em uma recomendação com hipótese e critério de sucesso? | Propostas 1 e 2 abaixo |
| **Profundidade** | Explorou múltiplas variáveis ou ficou só na superfície? | +10 variáveis testadas, validação estatística com Qui-Quadrado |

---

## O problema de negócio

Todo dia, milhares de leitores abrem a newsletter e encaram uma palavra. Alguns voltam no dia seguinte. Outros somem depois da primeira partida. A pergunta central deste case é simples e difícil ao mesmo tempo:

**O que determina se alguém continua jogando?**

Para responder, utilizei duas métricas de retenção:

| Métrica | Campo | O que mede |
|---|---|---|
| **D1** | `played_next_day` | O usuário voltou a jogar no dia seguinte? |
| **D30** | `active_d30` | O usuário permaneceu ativo 30 dias após aquela sessão? |

---

## Fontes de dados

| Arquivo | Conteúdo | Volume |
|---|---|---|
| `palavritas_sessions.csv` | Logs de cada partida jogada | ~41 mil linhas |
| `palavritas_attempts.csv` | Logs de cada chute dentro da partida | ~147 mil linhas |
| `user_profile.csv` | Respostas de pesquisa de perfil (amostra) | ~800 usuários |

Os arquivos brutos estão em `data/raw/` e **não devem ser alterados**. Toda transformação gera versões documentadas em `data/processed/`.

---

## Estrutura do repositório

```
palavritas-retention-case/
|
+-- data/
|   +-- raw/                                    # CSVs originais - NAO ALTERAR
|   |   +-- palavritas_sessions.csv
|   |   +-- palavritas_attempts.csv
|   |   +-- user_profile.csv
|   +-- processed/
|       +-- palavritas_sessions_silver.csv      # Sessoes limpas
|       +-- palavritas_attempts_silver.csv      # Tentativas limpas
|       +-- user_profile_silver.csv             # Perfil normalizado
|       +-- palavritas_analytics_gold.csv       # Tabela fato para BI (39.850 linhas)
|
+-- docker/                                     # Configuracao de ambiente containerizado
|   +-- docker-compose.yml
|
+-- docs/                                       # Documentacao adicional do case
|
+-- images/                                     # Capturas do dashboard exportado
|   +-- dashboard_pt1.png                       # Atos 1 e 2: Baseline e Comportamento no Tabuleiro
|   +-- dashboard_pt2.png                       # Ato 3: Sinergia do Ecossistema e Propostas
|
+-- notebooks/
|   +-- 01_limpeza_e_diagnostico.ipynb          # Pipeline de limpeza e decisoes documentadas
|   +-- 02_analise_e_cruzamentos.ipynb          # Analise exploratoria, testes e export
|
+-- output/                                     # Artefatos gerados (graficos, exports)
|
+-- sql/                                        # Queries que alimentam cada visual do dashboard
|   +-- 01_kpi_total_sessoes.sql
|   +-- 02_kpi_retencao_global_d1.sql
|   +-- 03_kpi_retencao_global_d30.sql
|   +-- 04_retencao_por_resultado_d1.sql
|   +-- 05_top10_palavras_dificeis_d1.sql
|   +-- 06_bottom10_palavras_faceis_d1.sql
|   +-- 07_impacto_newsletter_d30.sql
|
+-- src/                                        # Codigo-fonte auxiliar
+-- requirements.txt
+-- README.md
```

> **Ponto de entrada recomendado:** comece pelo `README.md` para entender o raciocínio geral, depois abra os notebooks na ordem numérica: limpeza, análise, exportação da tabela gold e, por fim, o dashboard.

---

## Limpeza e documentação das decisões

Antes de qualquer análise, os dados precisavam ser confiáveis. O pipeline de limpeza foi construído em **Python com Pandas** e está documentado no notebook `notebooks/01_limpeza_e_diagnostico.ipynb`.

### O que foi encontrado no diagnóstico

Foi identificada a presença de aproximadamente **1.200 sessões duplicadas** e **750 tentativas duplicadas**, registros idênticos que inflariam qualquer métrica de volume e comprometeriam a qualidade das análises. Além disso, foram detectados **30 tempos negativos** no campo `time_to_complete_sec`, valores fisicamente impossíveis que indicam erros de captura no sistema de log. Também foi encontrada a ocorrência de **63 sessões sem resultado** (campo `result` nulo), partidas incompletas que não correspondem a uma experiência de jogo encerrada e que, por isso, não contribuem para o entendimento do comportamento do usuário. Por fim, foi identificada a presença de inconsistências de formatação em campos textuais, incluindo variações de capitalização, espaços extras e datas em formatos mistos que, se não tratadas, geram ruído nas comparações entre grupos.

### Decisões de tratamento e seus racionais

Cada decisão foi tomada considerando o impacto analítico sobre as métricas de retenção, não apenas a organização interna dos dados:

| Problema | Ação | Racional de negócio |
|---|---|---|
| Duplicatas | Remoção via `drop_duplicates()` | Evitar contar a mesma partida duas vezes e distorcer taxas de retenção |
| Tempos negativos | Conversão para valor absoluto | O tempo gasto existe; o sinal estava invertido. Descartar seria perder sessões válidas |
| Resultado nulo | Exclusão da sessão | Sem `win` ou `lose`, não há experiência de jogo completa para analisar |
| Texto inconsistente | Normalização (lowercase, trim) | "iOS", "ios" e " IOS " são o mesmo dispositivo e comparar sem essa normalização gera ruído nos agrupamentos |

A remoção das duplicatas foi aplicada após confirmar que os registros eram de fato idênticos em todas as colunas relevantes, e não variações legítimas de sessão. A conversão dos tempos negativos para valor absoluto foi adotada após verificar que os valores, ignorado o sinal, estavam dentro da distribuição esperada para partidas reais. A exclusão das sessões sem resultado foi a decisão com maior impacto em volume, mas necessária para garantir que toda análise de retenção partisse de uma experiência de jogo concluída.

### Regra de negócio crítica: tentativas inválidas

O Palavritas permite de **1 a 6 tentativas** por partida. Durante o diagnóstico, foi identificada a presença de sessões com **0, 7 ou 8 tentativas**, valores que não correspondem às regras do produto. Esses registros foram interpretados como bugs de log ou sessões corrompidas e removidos da base analítica.

Essa decisão tem impacto direto na qualidade dos resultados: sessões com 0 tentativas apresentam retenção D1 de apenas 12,5%, enquanto sessões com 8 tentativas formam amostras minúsculas e estatisticamente instáveis. Incluir esses registros contaminaria qualquer conclusão sobre a mecânica do jogo e enviesaria os testes estatísticos aplicados.

**Resultado final do pipeline de limpeza:** **39.850 sessões válidas** prontas para análise.

### Cruzamento com perfil de usuário

Foi encontrado que a pesquisa de perfil cobre apenas cerca de 800 usuários, uma fração pequena da base total de sessões. Para não descartar 97% dos dados de retenção, foi aplicado um **LEFT JOIN** entre as sessões válidas e o perfil, utilizando `user_id` como chave de ligação.

Foi atribuído o marcador **`sem_pesquisa`** em todos os campos demográficos dos usuários sem resposta na pesquisa. Essa decisão permitiu analisar a retenção na base completa (39.850 sessões) e realizar cruzamentos com variáveis de perfil quando disponíveis, sem introduzir viés de seleção. O notebook `notebooks/02_analise_e_cruzamentos.ipynb` documenta esse cruzamento e exporta a tabela final consolidada.

---

## Raciocínio analítico: o que foi testado e o que foi descoberto

A tentação em análises de retenção é ir direto ao óbvio: "usuários mais jovens retêm mais?" ou "quem ganha mais dinheiro joga mais?". Optei por ir além disso. Testei dezenas de variáveis agrupadas em quatro blocos, com o objetivo de identificar o que de fato explica o comportamento de retorno ao jogo.

### Variáveis que não explicam retenção

| Bloco | Variáveis testadas | Resultado |
|---|---|---|
| **Demográficas** | Faixa salarial, setor de atuação, idade, cidade | Taxas de D30 entre ~30% e 34%, variação dentro da margem de ruído |
| **Técnicas** | iOS vs Android | D1 de 22,28% (iOS) vs 21,98% (Android), diferença irrelevante |
| **Temporais** | Turno do dia (manhã, tarde, noite) | D1 entre 22,0% e 22,6%, o horário não muda o hábito |
| **Hábitos externos** | Frequência semanal de delivery (iFood, Rappi) | D30 entre 31% e 33%, o hábito de consumo externo não prediz o retorno ao jogo |

**Conclusão:** o Palavritas é um produto **universal**. Não existe um perfil demográfico ideal de jogador. A retenção não vive nos atributos do usuário, vive na **experiência do jogo em si**.

---

### Os três gatilhos reais de retenção

#### 1. A Mecânica da Frustração

| Resultado da partida | Retorno D1 |
|---|---|
| **Perdeu** (`lose`) | **22,49%** |
| **Ganhou** (`win`) | **21,91%** |

Identifiquei que quem perde volta ligeiramente mais do que quem ganha. A diferença é pequena em pontos percentuais, mas consistente ao longo das coortes analisadas. Do ponto de vista do design de jogos de palavra, faz sentido: a derrota gera um sentimento de "quase lá" que puxa o usuário de volta no dia seguinte, enquanto vitórias fáceis satisfazem e encerram o ciclo. Derrotas por pouco criam **gancho emocional** e motivam a revanche.

#### 2. O Peso do Vocabulário

Nem toda palavra retém igual. Agrupei as palavras com volume significativo (acima de 100 sessões) e comparei as taxas de retorno D1 entre os grupos:

| Tipo | Exemplos | Retorno D1 |
|---|---|---|
| **Palavras difíceis e inusitadas** | "pazão", "nixão", "preto", "jogos" | ~24% |
| **Palavras fáceis e comuns** | "tempo", "nuvem", "fraco", "rosto" | ~20% |

Palavras que desafiam o vocabulário, seja por serem incomuns ou por exigirem raciocínio lateral, geram mais engajamento no dia seguinte. O usuário não resolve e esquece. Ele **quer a revanche**.

#### 3. Sinergia de Ecossistema

Identifiquei que usuários que **abriram a newsletter antes de jogar** apresentam retenção D30 significativamente superior aos demais. Esse achado foi submetido a validação estatística, detalhada na seção a seguir.

---

## Validação estatística

A relação entre a leitura da newsletter e a retenção de longo prazo não é uma percepção qualitativa. Apliquei o **Teste Qui-Quadrado de Independência** (`scipy.stats.chi2_contingency`), cruzando a variável `newsletter_open_before_game` com `active_d30`, para verificar se a associação observada poderia ser explicada pelo acaso.

| | Não abriu newsletter | Abriu newsletter |
|---|---|---|
| **Retenção D30** | **30,5%** | **37,8%** |
| **p-value** | | **0,0000** |

A diferença de **7,3 pontos percentuais** é estatisticamente significativa, com p-value inferior a qualquer limiar convencional de significância. Quem lê a newsletter antes de jogar tem quase **25% mais chance** de permanecer ativo após 30 dias.

Esse resultado confirma uma hipótese central de produto: **o Palavritas não é um jogo isolado, é uma extensão do hábito de leitura da newsletter**. Quanto mais integrados os dois produtos, maior a retenção de longo prazo.

---

## Propostas acionáveis para Produto

Com base nos achados, estruturei duas propostas no formato que o time de Produto pode avaliar e executar:

---

### Proposta 1: Curadoria Dinâmica de Dificuldade (Foco em D1)

**Hipótese:** palavras intencionalmente difíceis e inusitadas geram o sentimento de revanche e aumentam o retorno D1, porque o usuário não encerra a partida com a sensação de resolução completa e quer tentar de novo no dia seguinte.

**Ação proposta:** proponho implementar uma curadoria editorial de palavras com dificuldade escalonada, alternando palavras desafiadoras (como "pazão" e "nixão") a cada três dias, intercaladas com palavras de dificuldade média para evitar frustração excessiva e abandono.

**Critério de sucesso:** espero um aumento de **+2 p.p. na taxa de D1** nas semanas com palavras de alta dificuldade, comparado com a baseline atual (~22%), medido por coorte de `word_date`.

---

### Proposta 2: O Loop Gamificado (Foco em D30)

**Hipótese:** identifiquei que usuários que leem a newsletter antes de jogar retêm 7,3 p.p. a mais em D30. Integrar os dois produtos de forma explícita e intencional amplifica esse efeito ao criar um fluxo natural de leitura para jogo.

**Ação proposta:** proponho adicionar um **atalho gamificado ao final da leitura da newsletter**, como um botão "Jogue o Palavritas de hoje" com preview da palavra ou contagem regressiva, criando um ponto de entrada direto do conteúdo editorial para a mecânica do jogo.

**Critério de sucesso:** espero um aumento de **+5 p.p. na taxa de D30** entre usuários expostos ao atalho, comparado com o grupo controle (fluxo atual sem atalho), em teste A/B de 30 dias.

---

## Dashboard Analítico

O painel executivo foi desenvolvido em **Metabase** com a tabela gold `palavritas_analytics_gold.csv` (39.850 sessões, uma por linha) como fonte de dados única.

O dashboard foi estruturado em **3 atos narrativos**, espelhando o raciocínio analítico documentado neste README:

### Ato 1: Saúde Geral do Produto e Baseline de Retenção

Estabelece o volume total analisado e define as linhas de base que todo o restante da análise utiliza como referência para comparações.

| KPI | Valor |
|---|---|
| Total de Sessões Analisadas | **39.899** |
| Retenção Global D30 | **31,93%** |
| Retenção Global D1 | **22,14%** |

### Ato 2: Comportamento no Tabuleiro (Retenção D1)

Responde o que faz o jogador voltar no dia seguinte. O ato inclui um gráfico de barras com a retenção D1 por resultado da partida (`lose` 22,49% vs `win` 21,91%), evidenciando a Mecânica da Frustração. Também apresenta uma tabela ranqueada com as Top 10 palavras que mais retêm (com volume mínimo de 100 partidas), encabeçada por "preto" (24,63%), "jogos" (24,32%) e "pazão" (23,97%). Por fim, um gráfico de barras apresenta as 5 palavras com menor retenção, representando palavras de fácil resolução com taxas em torno de 20%.

![Dashboard - Atos 1 e 2: Baseline de Retenção e Comportamento no Tabuleiro](images/dashboard_pt1.png)

### Ato 3: A Sinergia do Ecossistema e Próximos Passos

Cruza o comportamento de leitura da newsletter com a sobrevivência de longo prazo (D30). Um gráfico de barras horizontais exibe a retenção D30 por hábito de leitura, comparando "Lê antes de jogar" (37,8%) com "Não lê antes" (30,5%), diferença de 7,3 p.p. validada estatisticamente. As Propostas 1 e 2 são apresentadas no próprio painel como cards acionáveis para o time de Produto, com racional, ação sugerida e critério de sucesso mensurado.

![Dashboard - Ato 3: Sinergia do Ecossistema e Propostas Acionáveis](images/dashboard_pt2.png)

---

## Como reproduzir

```bash
# 1. Clone o repositorio e configure o ambiente
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 2. Abra os notebooks na ordem
jupyter notebook

# 3. Execute nessa sequencia:
#    01_limpeza_e_diagnostico.ipynb  -> gera os arquivos silver
#    02_analise_e_cruzamentos.ipynb  -> gera palavritas_analytics_gold.csv

# 4. Conecte o arquivo gold ao Metabase para visualizar o dashboard
```

---

## Stack utilizada

| Ferramenta | Uso |
|---|---|
| **Python + Pandas** | Limpeza, transformação e cruzamento de dados |
| **NumPy** | Operações numéricas auxiliares |
| **SciPy (chi2_contingency)** | Teste Qui-Quadrado de independência para validação estatística dos achados |
| **Matplotlib + Seaborn** | Visualizações exploratórias nos notebooks |
| **Jupyter** | Documentação reprodutível das análises |
| **Metabase** | Dashboard executivo interativo |

---

*Case Técnico - Analista de Dados (Produto & Growth) | the news*