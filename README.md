# Case Técnico — Retenção no Palavritas | the news

> **Analista de Dados (Produto & Growth)** — Este repositório documenta uma investigação sobre o que faz usuários voltarem a jogar o **Palavritas**, o jogo de palavras diário da newsletter **the news**. O foco não é código: é entender comportamento, encontrar alavancas reais de retenção e transformar insights em ações para o time de Produto.

---

## O problema de negócio

Todo dia, milhares de leitores abrem a newsletter e encaram uma palavra. Alguns voltam no dia seguinte. Outros somem depois da primeira partida. A pergunta central deste case é simples — e difícil:

**O que determina se alguém continua jogando?**

Para responder, trabalhamos com duas métricas de retenção:

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

## Limpeza e documentação das decisões

Antes de qualquer análise, os dados precisavam ser confiáveis. O pipeline de limpeza foi construído em **Python com Pandas** e está documentado no notebook `notebooks/01_limpeza_e_diagnostico.ipynb`.

### O que encontramos no diagnóstico

- **~1.200 sessões duplicadas** e **~750 tentativas duplicadas** — registros idênticos que inflariam qualquer métrica de volume.
- **30 tempos negativos** em `time_to_complete_sec` — impossíveis fisicamente; sinal de erro de captura no log.
- **63 sessões sem resultado** (`result` nulo) — partidas incompletas que não representam uma experiência de jogo encerrada.
- Inconsistências de formatação (maiúsculas/minúsculas, espaços extras, datas em formatos mistos).

### Decisões de tratamento — e por quê

Cada decisão foi tomada pensando no impacto analítico, não só na "beleza" do dataset:

| Problema | Ação | Racional de negócio |
|---|---|---|
| Duplicatas | Remoção via `drop_duplicates()` | Evitar contar a mesma partida duas vezes e distorcer taxas de retenção |
| Tempos negativos | Conversão para valor absoluto | O tempo gasto existe; o sinal estava invertido. Descartar seria perder sessões válidas |
| Resultado nulo | Exclusão da sessão | Sem `win` ou `lose`, não há experiência de jogo completa para analisar |
| Texto inconsistente | Normalização (lowercase, trim) | "iOS", "ios" e " IOS " são o mesmo dispositivo — comparar sem isso gera ruído |

### Regra de negócio crítica: tentativas inválidas

O Palavritas permite de **1 a 6 tentativas** por partida. Encontramos sessões com **0, 7 ou 8 tentativas** — valores que não deveriam existir no produto real. Interpretamos esses registros como **bugs de log ou sessões corrompidas** e os removemos da base analítica.

Essa decisão não é capricho estatístico: incluir uma sessão com 0 tentativas (retenção D1 de apenas 12,5%) ou 8 tentativas (amostra minúscula e distorcida) contaminaria qualquer conclusão sobre a mecânica do jogo.

**Resultado:** **39.850 sessões válidas** prontas para análise.

### Cruzamento com perfil de usuário

A pesquisa de perfil cobre apenas ~800 usuários — uma fração pequena da base total. Para não descartar 97% dos dados de retenção, aplicamos um **LEFT JOIN** entre as sessões válidas e o perfil, usando `user_id` como chave.

Usuários sem resposta na pesquisa receberam o marcador **`sem_pesquisa`** em todos os campos demográficos. Assim, conseguimos:

- Analisar retenção na base completa (39.850 sessões)
- Cruzar com variáveis de perfil quando disponível, sem viés de seleção

O notebook `notebooks/02_analise_e_cruzamentos.ipynb` consolida esse cruzamento e exporta a tabela final.

---

## Raciocínio analítico — o que testamos e o que descobrimos

A tentação em análises de retenção é ir direto ao óbvio: "usuários mais jovens retêm mais?" ou "quem ganha mais dinheiro joga mais?". Fomos além. Testamos dezenas de variáveis agrupadas em quatro blocos:

### Variáveis que NÃO explicam retenção

| Bloco | Variáveis testadas | Resultado |
|---|---|---|
| **Demográficas** | Faixa salarial, setor de atuação, idade, cidade | Taxas de D30 entre ~30% e 34% — variação dentro da margem de ruído |
| **Técnicas** | iOS vs Android | D1 de 22,28% (iOS) vs 21,98% (Android) — diferença irrelevante |
| **Temporais** | Turno do dia (manhã, tarde, noite) | D1 entre 22,0% e 22,6% — o horário não muda o hábito |
| **Hábitos externos** | Frequência semanal de delivery (iFood, Rappi) | D30 entre 31% e 33% — comer delivery não prediz se alguém volta ao jogo |

**Conclusão:** O Palavritas é um produto **universal**. Não existe um "perfil ideal de jogador" demográfico. A retenção não vive no CPF do usuário — vive na **experiência do jogo**.

---

### Os três gatilhos reais de retenção

#### 1. A Mecânica da Frustração

| Resultado da partida | Retorno D1 |
|---|---|
| **Perdeu** (`lose`) | **22,49%** |
| **Ganhou** (`win`) | **21,91%** |

Quem perde volta *ligeiramente* mais do que quem ganha. A diferença é pequena em pontos percentuais, mas consistente — e faz sentido para quem conhece jogos de palavra: a derrota gera um sentimento de **"quase lá"** que puxa o usuário de volta no dia seguinte. Vitórias fáceis satisfazem; derrotas por pouco criam **gancho emocional**.

#### 2. O Peso do Vocabulário

Nem toda palavra retém igual. Agrupamos palavras com volume significativo (>100 sessões) e comparamos:

| Tipo | Exemplos | Retorno D1 |
|---|---|---|
| **Palavras difíceis e inusitadas** | "pazão", "nixão", "preto", "jogos" | **~24%** |
| **Palavras fáceis e comuns** | "tempo", "nuvem", "fraco", "rosto" | **~20%** |

Palavras que desafiam o vocabulário — seja por serem incomuns ou por exigirem raciocínio lateral — geram mais engajamento no dia seguinte. O usuário não "resolve e esquece"; ele **quer a revanche**.

#### 3. Sinergia de Ecossistema

Usuários que **abriram a newsletter antes de jogar** apresentam retenção D30 significativamente superior. Esse achado merece validação estatística — detalhada na seção seguinte.

---

## Validação estatística (bônus)

A relação entre newsletter e retenção **não é achismo**. Aplicamos um **Teste Qui-Quadrado de Independência** (`scipy.stats.chi2_contingency`) cruzando `newsletter_open_before_game` × `active_d30`.

| | Não abriu newsletter | Abriu newsletter |
|---|---|---|
| **Retenção D30** | **30,5%** | **37,8%** |
| **p-value** | — | **0,0000** |

A diferença de **7,3 pontos percentuais** é estatisticamente significativa. Quem lê a newsletter antes de jogar tem quase **25% mais chance** de permanecer ativo após 30 dias.

Isso confirma uma hipótese de produto poderosa: **o Palavritas não é um jogo isolado — é uma extensão do hábito de leitura da newsletter**. Quanto mais integrados os dois produtos, maior a retenção.

---

## Propostas acionáveis para Produto

Com base nos achados, estruturamos duas propostas no formato que o time de Produto pode pegar e executar:

---

### Proposta 1 — Rotação de Dificuldade Dinâmica

**Hipótese:** Palavras intencionalmente difíceis e inusitadas geram o sentimento de "revanche" e aumentam o retorno D1, porque o usuário não resolve a partida de forma satisfatória e quer tentar de novo.

**Ação:** Implementar uma curadoria editorial de palavras com dificuldade escalonada — alternando palavras desafiadoras (como "pazão", "nixão") a cada 3 dias, intercaladas com palavras de dificuldade média para não frustrar em excesso.

**Critério de Sucesso:** Aumento de **+2 p.p. na taxa de D1** nas semanas com palavras de alta dificuldade, comparado com a baseline atual (~22%), medido por coorte de `word_date`.

---

### Proposta 2 — Sinergia de Ecossistema

**Hipótese:** Usuários que leem a newsletter antes de jogar retêm 7,3 p.p. a mais em D30. Integrar os dois produtos de forma explícita amplifica esse efeito.

**Ação:** Adicionar um **atalho gamificado ao final da leitura da newsletter** — por exemplo, um botão "Jogue o Palavritas de hoje" com preview da palavra ou contagem regressiva — criando um fluxo natural de newsletter → jogo.

**Critério de Sucesso:** Aumento de **+5 p.p. na taxa de D30** entre usuários expostos ao atalho, comparado com o grupo controle (fluxo atual sem atalho), em teste A/B de 30 dias.

---

## Em Desenvolvimento: Dashboard Analítico

O projeto está na reta final. As etapas concluídas:

- [x] Limpeza e diagnóstico dos dados
- [x] Análise exploratória e cruzamentos
- [x] Validação estatística
- [x] Propostas acionáveis para Produto
- [ ] **Dashboard interativo (última etapa)**

A base final limpa e consolidada — `data/processed/palavritas_analytics_gold.csv` (**39.850 linhas**, uma sessão por linha) — já está exportada e pronta para conexão com uma ferramenta de BI (**Looker Studio**, **Metabase** ou similar).

O painel executivo permitirá ao time de Produto:

- Acompanhar D1 e D30 em tempo real por coorte
- Comparar retenção por palavra, resultado da partida e abertura de newsletter
- Monitorar o impacto das propostas após implementação

Esta é a última entrega bônus do case.

---

## Estrutura do repositório

```
├── data/
│   ├── raw/                              # CSVs originais (intocáveis)
│   └── processed/
│       ├── palavritas_sessions_silver.csv
│       ├── palavritas_attempts_silver.csv
│       ├── user_profile_silver.csv
│       └── palavritas_analytics_gold.csv   # Tabela fato para BI
├── notebooks/
│   ├── 01_limpeza_e_diagnostico.ipynb    # Pipeline de limpeza
│   └── 02_analise_e_cruzamentos.ipynb    # Análise, testes e export
├── requirements.txt
└── README.md
```

---

## Como reproduzir

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
jupyter notebook
```

Abra os notebooks na ordem numérica para seguir o raciocínio completo: limpeza → análise → exportação da tabela gold.

---

## Stack utilizada

| Ferramenta | Uso |
|---|---|
| **Python + Pandas** | Limpeza, transformação e cruzamento de dados |
| **NumPy** | Operações numéricas |
| **SciPy** | Teste Qui-Quadrado de independência |
| **Matplotlib + Seaborn** | Visualizações exploratórias |
| **Jupyter** | Documentação reprodutível das análises |

---

*Case em desenvolvimento — Analista de Dados (Produto & Growth) | the news*
