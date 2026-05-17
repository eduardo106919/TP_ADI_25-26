// main.typ

#import "lib.typ": conf

#show: conf.with(
  titulo: "Conceção de Modelos de Aprendizagem e Decisão",
  uc: "Aprendizagem e Decisão Inteligentes",
  sigla: "ADI",
  grupo: "34",
  ano: "2025/2026",
  alunos: (
    (id: "A106919", nome: "Eduardo Freitas Fernandes"),
    (id: "A107326", nome: "Guilherme Santos da Costa"),
    (id: "A106888", nome: "José Mário Raimundo Lima"),
    (id: "A107375", nome: "Pedro Nuno de Bastos Pinho Costa"),
  ),
)

= Introdução

Este relatório descreve o trabalho desenvolvido no âmbito da unidade curricular de Aprendizagem e Decisão Inteligentes (ADI), do 3.º ano da Licenciatura em Engenharia Informática da Universidade do Minho, referente ao ano letivo 2025/2026.

O trabalho engloba duas tarefas distintas, abordadas em simultâneo com recurso à plataforma KNIME:

- *Production Dataset* — análise de um dataset de produção de energia em redes de distribuição, com desenvolvimento de modelos de classificação e regressão;
- *AI Job Market Dataset* — seleção e análise de um dataset do mercado de emprego em Inteligência Artificial, com conceção e otimização de diversos modelos de Machine Learning.

As secções seguintes detalham a exploração e preparação dos dados, os modelos desenvolvidos e a análise crítica dos resultados obtidos.

#pagebreak()

= _Production Dataset_

== Observações

O dataset atribuído diz respeito à produção de energia em redes de distribuição, contendo registos horários com informação meteorológica e de produção por diferentes tecnologias renováveis. A variável alvo é *Productions*, que classifica a taxa de produção em classes discretas.

O dataset é composto pelas seguintes variáveis:

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    table.header([*Variável*], [*Descrição*]),
    [Date/Time], [Timestamp horário do registo],
    [Cogeneration (kWh)], [Produção em unidades de cogeração],
    [Wind (kWh)], [Produção em unidades eólicas],
    [Photovoltaics (kWh)], [Produção em unidades fotovoltaicas],
    [Hydro (kWh)], [Produção em unidades hídricas],
    [Other Technologies (kWh)], [Produção noutras tecnologias],
    [Distribution Network (kWh)], [Produção total na rede de distribuição],
    [temperature\_2m (°C)], [Temperatura exterior a 2 metros],
    [relative\_humidity\_2m (%)], [Humidade relativa a 2 metros],
    [precipitation (mm)], [Precipitação],
    [rain (mm)], [Pluviosidade],
    [snowfall (cm)], [Queda de neve],
    [cloud\_cover (%)], [Cobertura de nuvens],
    [Wind\_Direction\_10m / 100m], [Direção do vento a 10 m e 100 m],
    [wind\_speed\_10m / 100m (km/h)], [Velocidade do vento a 10 m e 100 m],
    [direct\_radiation (W/m²)], [Radiação direta solar],
    [shortwave\_radiation (W/m²)], [Radiação de onda curta],
    [diffuse\_radiation (W/m²)], [Radiação difusa],
    [direct\_normal\_irradiance (W/m²)], [Irradiância normal direta],
    [terrestrial\_radiation (W/m²)], [Radiação terrestre],
    [*Productions*], [*Classe de taxa de produção (variável alvo)*],
  ),
  caption: [Variáveis do dataset de produção de energia.]
)
#pagebreak()
== Análise Estatística

A análise estatística foi realizada com recurso aos nós *Statistics*, *Data Explorer* e métricas de correlação (como *Rank Correlation*) no KNIME, permitindo caracterizar a distribuição das variáveis meteorológicas e energéticas, bem como identificar relações ocultas entre elas.

#figure(image("imgs/stats.png", width: 90%),
  caption: [Estatísticas descritivas das variáveis numéricas do dataset.]
)

#figure(image("imgs/stats6.png", width: 90%), caption: [Exploração detalhada da distribuição das variáveis via Data Explorer.])

As variáveis numéricas contínuas apresentam as seguintes características gerais:

- `temperature_2m (°C)` e `relative_humidity_2m (%)`: refletem uma grande amplitude térmica sazonal, com a temperatura a oscilar fortemente entre valores negativos (-0,2 °C) e picos de muito calor (36.9 °C);
- Variáveis de radiação solar (`shortwave`, `direct` e `diffuse`): apresentam uma assimetria natural muito acentuada, com medianas próximas de zero (devido aos períodos noturnos) e picos máximos elevados, o que dita a intermitência da energia fotovoltaica;
- `wind_speed_10m` e `wind_speed_100m`: velocidades do vento com distribuições típicas (enviesadas à direita), essenciais para o acionamento das turbinas eólicas;
- Produção energética (`Wind`, `Photovoltaics`, `Hydro`): mostram um elevado desvio padrão, refletindo flutuações constantes de produção ditadas pelo estado do tempo e não por débitos contínuos.

As variáveis nominais e descritivas mostram:

#figure(image("imgs/statsnom.png"),
  caption: [Estatísticas descritivas das variáveis nominais e categóricas do dataset.]
)

- A variável alvo `Productions` agrupa de forma discreta o estado da rede de distribuição de energia;
- Diversos atributos apresentam falhas na tipologia (necessitando de conversão de *String* para *Number*) ou dados nulos decorrentes de falhas de telemetria, o que motivará o tratamento de dados seguinte. No caso específico das variáveis de precipitação (`precipitation` e `rain`), os missing values foram assumidos como 0, uma vez que a ausência de registo é fisicamente compatível com ausência de precipitação.

A análise de correlação revelou redundâncias e algumas dependências lógicas fundamentais para a correta seleção de variáveis para a modelação:

- Identificaram-se fortes correlações lógicas entre a `precipitation (mm)` e a `rain (mm)`, bem como entre as três métricas de medição de radiação solar, indiciando sobreposição de informação;
- Observou-se uma forte correlação (sem significado físico) entre a variável `RowID` e as restantes variáveis do *dataset*. Por se tratar apenas de um índice automático sequencial, justificou-se a sua remoção prévia para não introduzir enviesamentos matemáticos (*data leakage*) nos classificadores.

#figure(image("imgs/spearson.png", width: 90%), caption: [Matriz de correlação de Spearman evidenciando dependências não-lineares.])





== Tratamento de Dados

A qualidade dos dados meteorológicos e de produção apresenta frequentemente falhas, provavelmente decorrentes de problemas nos sensores ou interrupções na telemetria. Por conseguinte, o pipeline de pré-processamento de dados estruturou-se em três eixos principais:

1. *Conversão de Tipos e Limpeza:* Utilização dos nós *String Replacer (Dictionary)* e *String to Number* para normalizar nomenclaturas textuais e garantir que todas as variáveis quantitativas se encontravam no formato numérico adequado (Integer ou Double) para os algoritmos de modelação.
2. *Engenharia de Variáveis (Feature Engineering):* Extração de componentes temporais cruciais a partir da coluna de data/hora transformada (como o mês, dia e hora) utilizando o nó *Extract Date&Time*. Estes metadados são essenciais para capturar o comportamento cíclico diário e sazonal da produção de energia renovável.
3. *Tratamento de Valores Omissos (Missing Values):* Como os dados representam séries temporais cronológicas, a simples eliminação de registos nulos criaria descontinuidade. Foram implementadas e validadas duas abordagens concorrentes em sub-metanós específicos:
   - *Imputação por Média (com ou sem arredondamentos):* Substituição dos valores em falta pela média estatística global da respetiva coluna.
   - *Imputação por Interpolação:* Técnica avançada e ideal para séries cronológicas contínuas, que estima o valor em falta baseando-se na tendência matemática e nos valores dos instantes imediatamente anteriores e posteriores.

O encadeamento completo e a arquitetura visual destas etapas e ramificações na plataforma KNIME encontram-se documentados na @workflow-principal-prod.

#figure(
  image("imgs/arq.png", width: 100%), 
  caption: [Workflow principal desenvolvido no KNIME para o Production Dataset, exibindo a segregação por metanós e ramificações.]
) <workflow-principal-prod>

== Modelos Desenvolvidos

A infraestrutura de modelação preditiva para o *Production Dataset* dividiu-se na resolução de dois cenários distintos de Aprendizagem Supervisionada: Classificação (para prever o estado categórico da produção) e Regressão (para prever a potência contínua em kilowatts). Os dados foram geridos através do nó *Table Partitioner* (com uma divisão clássica de 70% para treino e 30% para teste), utilizando também ciclos de validação cruzada (*X-Partitioner* e *X-Aggregator*) para garantir a estabilidade estatística dos modelos.
#pagebreak()
=== Classificação (Árvores de Decisão)

O objetivo principal consistiu em prever a classe discreta da variável alvo `Productions`. Para isso, utilizou-se o algoritmo *Decision Tree Learner*, distribuído em paralelo dentro de duas grandes abordagens de tratamento de dados (*Uso de Média* e *Uso de Interpolação*). Em cada uma destas abordagens, foram desenvolvidos e avaliados três sub-cenários de testes experimentais:

- *Análise Inicial:* Implementação base do algoritmo utilizando a parametrização por omissão sobre os dados limpos, estruturada com partições de validação cruzada para medir o erro inicial de classificação e para saber qual/quais abordagens tinham uma capacidade consideravelmente inferior às outras para focar nas melhores;

#figure(
  image("imgs/analise inicial.png", width: 100%), 
  caption: [Metanodo da análise inicial.]
)
#pagebreak()
- *Segunda Análise:* Otimização do modelo através do ajuste manual de hiperparâmetros de poda (*pruning*) e critérios de paragem por tamanho mínimo das folhas, com vista a simplificar a árvore, reduzir o sobreajuste e confirmar que as duas abordagens que passaram pela fase de análise inicial têm qualidade para avançar para uma análise mais profunda;

#figure(
  image("imgs/segundaAnalise.png", width: 85%),
  caption: [Estrutura interna desenvolvida no KNIME para o sub-metanó de "Análise Inicial" utilizando a Árvore de Decisão.]
) <metano-analise-inicial>
#pagebreak()
- *Análise Avançada:* Na análise avançada fez-se uma comparação entre as diferentes combinações de inclusão/exclusão dos atributos relativos a precipitação e chuva, após isso procedeu-se a tentar inferir a direção do vento no caso de exclusão do campo de precipitação, visto que este tinha dado as melhores previsões.

#figure(
  image("imgs/analiseAvancada.png", width: 85%),
  caption: [Estrutura interna desenvolvida no KNIME para o sub-metanó de "Análise Inicial" utilizando a Árvore de Decisão.]
) <metano-analise-inicial>


=== Regressão Linear

Em paralelo com o cenário de classificação, foi desenhado um pipeline alternativo focado na modelação contínua de valores numéricos de potência:

- *Regressão Linear Múltipla:* Desenvolvida dentro do sub-metanó `Regressões Lineares`, este modelo teve como meta estimar quantitativamente o valor numérico total de `Distribution Network (kWh)`. Utilizou como preditores independentes as variáveis climáticas contínuas (como as várias métricas de radiação, a temperatura e a velocidade do vento) para tentar traçar uma equação linear de débito energético.

#figure(image("imgs/regressao_linear1.png", width: 100%), caption: [Regressão Linear — estrutura do pipeline no KNIME.])

#figure(image("imgs/regressao_linear2.png", width: 100%), caption: [Regressão Linear — estrutura do pipeline no KNIME.])

== Análise dos Resultados

=== Resultados das Árvores de Decisão

Para a análise inicial a interpolação teve resultados de 84%, 89% e 85% respetivamente para os modelos de cima para baixo. No caso em que usámos média os resultados foram significativamente melhores, tendo ambos 88%, 93% e 93% pela mesma ordem.

Quanto à segunda análise as duas abordagens de média tiveram os mesmos valores nos modelos em que não se usou *X-Partitioner* e quando se usou o mesmo obtivemos melhores resultados ao usar arredondamentos do que média certa, sendo os resultados 93,36% contra 93,31% no modelo de que se encontra mais acima no workflow e 93,26% contra 93,13% no outro. Face a estes dados decidimos avançar com uma análise mais profunda nos dois métodos de tratamento de valores nulos por média.


#pagebreak()

= _AI Job Market Dataset_

== Origem do _Dataset_

O dataset selecionado pelo grupo — *AI Jobs Market 2025/2026* — foi obtido a partir da plataforma Kaggle e reúne informação sobre 1500 ofertas de emprego na área da Inteligência Artificial, cobrindo múltiplos países, setores e perfis profissionais. O objetivo é analisar tendências salariais, requisitos de experiência e dinâmicas do mercado de trabalho em IA, com vista à conceção de modelos de regressão e clustering.

== Observações

O dataset é composto por 1500 registos e 25 variáveis, sem valores omissos na versão original. As variáveis abrangem informação sobre o cargo, a empresa, a localização, o salário e indicadores de mercado:

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    table.header([*Variável*], [*Descrição*]),
    [job\_title], [Título do cargo],
    [job\_category], [Área da função (ex.: AI Engineering, Data Science)],
    [experience\_level], [Nível de experiência requerido (Entry, Mid, Senior, Lead)],
    [years\_of\_experience], [Anos de experiência necessários],
    [education\_required], [Habilitação mínima exigida],
    [*annual\_salary\_usd*], [*Salário anual em USD (variável alvo da regressão)*],
    [salary\_min/max\_usd], [Intervalo salarial mínimo e máximo],
    [city / country], [Localização da oferta],
    [remote\_work], [Regime de trabalho (On-site, Hybrid, Fully Remote)],
    [company\_size], [Dimensão da empresa (Startup, SME, Enterprise, Big Tech)],
    [industry], [Setor de atividade (12 setores)],
    [required\_skills], [Competências técnicas exigidas (separadas por \|)],
    [ai\_salary\_premium\_pct], [Prémio salarial face a funções equivalentes não-IA],
    [demand\_score], [Índice de procura do cargo (0–100)],
    [demand\_growth\_yoy\_pct], [Crescimento anual da procura (%)],
    [benefits\_score\_10], [Qualidade do pacote de benefícios (0–10)],
    [is\_senior], [Indicador binário — cargo sénior],
    [is\_remote\_friendly], [Indicador binário — aceita trabalho remoto],
    [is\_llm\_role], [Indicador binário — cargo focado em LLMs],
    [salary\_tier], [Classificação salarial em 5 categorias (Entry, Mid, Upper-Mid, Senior, Elite],
  ),
  caption: [Variáveis do dataset AI Jobs Market 2025/2026.]
)

== Análise Estatística

A análise estatística foi realizada com recurso aos nós *Statistics*, *Data Explorer*, *Value Counter*, *Linear Correlation* e *Rank Correlation* no KNIME, permitindo caracterizar a distribuição das variáveis e identificar relações entre elas.

#figure(image("imgs/statistics.png", width: 90%), caption: [Estatísticas descritivas das variáveis numéricas do dataset.])

#figure(image("imgs/data_explorer.png", width: 90%), caption: [Exploração detalhada da distribuição das variáveis.])

As variáveis numéricas contínuas apresentam as seguintes características gerais:

- `annual_salary_usd`: salários entre aproximadamente 90 000 e 400 000 USD, com concentração na faixa 100 000–250 000 USD;
- `demand_score`: distribuição concentrada acima de 60, com a maioria dos cargos a apresentar procura elevada;
- `years_of_experience`: maioritariamente entre 0 e 10 anos;
- `benefits_score_10`: concentrada entre 6 e 10, sem valores baixos relevantes.

As variáveis categóricas mostram:

- 12 categorias de `job_category`, com maior representação em AI Engineering;
- 12 setores de `industry`, com destaque para Finance e Technology;
- Distribuição equilibrada entre os regimes de `remote_work` (On-site, Hybrid, Fully Remote).

A análise de correlação revelou que `salary_min_usd` e `salary_max_usd` são altamente correlacionadas com `annual_salary_usd`, o que justifica a sua remoção antes da modelação para evitar data leakage.

#figure(image("imgs/linear_correlation.png", width: 90%), caption: [Matriz de correlação de Pearson entre variáveis numéricas.])

#figure(image("imgs/rank_correlation.png", width: 90%), caption: [Matriz de correlação de Spearman entre variáveis.])


== Exploração Contextual

A exploração visual foi realizada com recurso a múltiplos gráficos no KNIME, permitindo identificar padrões e relações entre variáveis de forma intuitiva.

*Salário por nível de experiência* — O nível Lead (10+ anos) apresenta o salário médio mais elevado (~235 000 USD), seguido do nível Senior (~210 000 USD), Mid (~175 000 USD) e Entry (~150 000 USD), confirmando uma progressão salarial clara com a experiência.

#figure(image("imgs/Salario_experiencia.png", width: 90%), caption: [Salário médio por nível de experiência.])
#pagebreak()
*Anos de experiência vs Salário* — O scatter plot não revela uma correlação linear clara entre os anos de experiência e o salário, com grande dispersão em todos os níveis de experiência. Isto sugere que outros fatores (empresa, localização, categoria) têm maior influência no salário do que os anos de experiência isoladamente.

#figure(image("imgs/anos_experiencia_salario.png", width: 90%), caption: [Anos de experiência vs salário anual, colorido por nível de experiência.])

*Salário por tamanho de empresa* — A Big Tech (FAANG+) apresenta a maior amplitude e mediana salarial, seguida das empresas Enterprise. As Startups têm salários mais baixos e menos dispersos.

#figure(image("imgs/salario_tamanho_empresa.png", width: 90%), caption: [Distribuição salarial por tamanho de empresa.])

*Salário médio por país* — Os EUA lideram com um salário médio de ~225 000 USD, enquanto a Índia apresenta o valor mais baixo (~135 000 USD). A maioria dos países europeus e asiáticos situa-se entre 160 000 e 200 000 USD.

#figure(image("imgs/salario_pais.png", width: 90%), caption: [Salário médio por país.])
#pagebreak()
*Demand Score vs Salário* — Os dados concentram-se em valores de demand\_score superiores a 60, sem uma tendência salarial clara associada ao score de procura. As diferentes categorias de emprego distribuem-se de forma semelhante ao longo do eixo salarial.

#figure(image("imgs/demand_score_salary.png", width: 90%), caption: [Demand score vs salário anual, colorido por categoria de emprego.])

*Distribuição por categoria de emprego* — O AI Engineering representa a maior fatia do dataset, seguido de Data Science e Robotics. Categorias como Security e Research têm representação mais reduzida.

#figure(image("imgs/job_category.png", width: 80%), caption: [Distribuição de ofertas por categoria de emprego.])

*Prémio salarial AI por categoria* — O prémio salarial face a funções equivalentes não-IA é relativamente uniforme entre categorias, situando-se entre 6% e 13%. A categoria de Data Science apresenta o valor mais baixo e Architecture e Business os valores mais elevados.

#figure(image("imgs/premio_ai_categoria.png", width: 90%), caption: [Prémio salarial AI médio por categoria de emprego.])
#pagebreak()
*Benefícios vs Salário* — Não existe correlação visível entre a qualidade dos benefícios e o salário, com os dados distribuídos uniformemente acima de um score de benefícios de 6.

#figure(image("imgs/beneficios_vs_salario.png", width: 90%), caption: [Score de benefícios vs salário anual.])

*Funções LLM por indústria* — Automotive, Finance e Government lideram em número de funções LLM, enquanto Consulting tem a menor presença. A distribuição é relativamente equilibrada entre setores.

#figure(image("imgs/llm_industria.png", width: 90%), caption: [Número de funções LLM por setor de indústria.])

*Crescimento de procura por categoria* — ML Operations destaca-se com um crescimento anual de procura muito acima das restantes categorias (~52%), seguido de AI Engineering (~40%). As restantes categorias apresentam crescimentos entre 15% e 31%.

#figure(image("imgs/crescimento_procura_categoria.png", width: 90%), caption: [Crescimento anual de procura (%) por categoria de emprego.])
#pagebreak()
== Tratamento de Dados

=== Criação de Variáveis

Antes do pré-processamento foram criadas três variáveis adicionais:

- *`salary_range`*: amplitude salarial calculada como `salary_max_usd - salary_min_usd`, capturando a variabilidade salarial de cada oferta;
- *`num_skills`*: número de competências técnicas listadas em `required_skills`, contadas pelo separador `|`;
- *`exp_mismatch`*: indicador de desajuste entre o nível de experiência declarado e os anos exigidos — classifica como "Exigente" cargos Entry com mais de 2 anos, Mid com mais de 5 anos ou Lead com menos de 8 anos.

=== Pré-processamento

O pré-processamento foi implementado no KNIME com a seguinte sequência de nós:

#figure(image("imgs/processing_pipeline.png", width: 100%), caption: [Pipeline de pré-processamento implementado no KNIME.])

+ *Numeric Outliers* — deteção e substituição de outliers em `annual_salary_usd` e `demand_score` pelo método IQR com multiplicador k=1,5;
+ *Missing Value* — imputação dos valores em falta: média para variáveis numéricas (Float e Integer) e moda para variáveis categóricas (String);
+ *Column Filter* — remoção de colunas irrelevantes para a análise: `job_id`, `job_title`, `required_skills`, `salary_min_usd`, `salary_max_usd` e `city`;
+ *One to Many* — codificação das variáveis categóricas em colunas binárias (_dummy variables_): `experience_level`, `education_required`, `remote_work`, `company_size`, `industry` e `job_category`.

== Modelos Desenvolvidos

=== Clustering

O clustering foi realizado com o algoritmo *k-Means*, testando três cenários distintos de pré-processamento, com o objetivo de identificar segmentos naturais no mercado de emprego em IA. A qualidade dos clusters foi avaliada através do *Coeficiente de Silhouette*.

==== Cenário 1 — k-Means com variáveis numéricas e binárias

As variáveis selecionadas pelo *Column Filter* foram: `years_of_experience`, `annual_salary_usd`, `ai_salary_premium_pct`, `demand_score` e `is_llm_role`. Após normalização Z-score, foram testados k=2, k=3 e k=4:

#figure(
  table(
    columns: (auto, auto),
    align: (center, center),
    table.header([*k*], [*Silhouette médio*]),
    [2], [0,325],
    [3], [0,256],
    [4], [0,248],
  ),
  caption: [Resultados do clustering — Cenário 1.]
)

#figure(image("imgs/cluster1.png", width: 100%), caption: [Workflow do Cenário 1 de clustering com as variáveis selecionadas.])
#pagebreak()
==== Cenário 2 — k-Means com PCA

As mesmas variáveis do Cenário 1 foram submetidas a normalização Z-score, seguida de redução de dimensionalidade por *PCA* com 3 componentes principais. Este cenário obteve o melhor Silhouette geral, com k=2:

#figure(
  table(
    columns: (auto, auto),
    align: (center, center),
    table.header([*k*], [*Silhouette médio*]),
    [2], [0,332],
    [3], [0,286],
    [4], [0,287],
  ),
  caption: [Resultados do clustering — Cenário 2 (com PCA).]
)

#figure(image("imgs/cluster2.png", width: 100%), caption: [Workflow do Cenário 2 de clustering com PCA (3 dimensões).])

==== Cenário 3 — k-Means com seleção reduzida de variáveis

Restringindo o clustering às três variáveis numéricas mais relevantes — `annual_salary_usd`, `years_of_experience` e `demand_score` —, foram testados mais valores de k. O melhor resultado foi partilhado entre k=4 e k=5 (Silhouette = 0,288), optando-se por k=4 pela sua maior simplicidade interpretativa:

#figure(
  table(
    columns: (auto, auto),
    align: (center, center),
    table.header([*k*], [*Silhouette médio*]),
    [2], [0,280],
    [3], [0,261],
    [4], [0,288],
    [5], [0,288],
    [6], [0,265],
  ),
  caption: [Resultados do clustering — Cenário 3.]
)

#figure(image("imgs/cluster3.png", width: 100%), caption: [Workflow do Cenário 3 de clustering com seleção reduzida de variáveis.])

O melhor resultado foi obtido no Cenário 3 com k=4, onde os clusters identificados apresentaram os seguintes perfis:

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    table.header([*Cluster*], [*Perfil*]),
    [Baixa Procura e Baixo Salário], [Salário abaixo da média, pouca experiência e demand\_score muito reduzido — perfis com menor atratividade no mercado],
    [Elite Salarial], [Salário muito acima da média, experiência intermédia e demand\_score elevado — posições de topo bem remuneradas],
    [Especialistas LLM], [Salário médio-baixo, pouca experiência mas demand\_score alto — perfis júnior em áreas de grande procura como LLMs],
    [Experientes Subvalorizados], [Muitos anos de experiência mas salário abaixo do esperado — profissionais seniores em funções menos valorizadas],
  ),
  caption: [Perfis dos clusters identificados no Cenário 3 com k=4.]
)

=== Regressão

O objetivo da regressão é prever o `annual_salary_usd` com base nas restantes variáveis. Foram testados cinco cenários de pré-processamento, cada um com três algoritmos: *Árvore de Regressão Simples*, *Regressão Linear* e *Random Forest*. Os dados foram divididos em 80% treino e 20% teste (Cenários 1 e 2) ou 70% treino e 30% teste (Cenários 3, 4 e 5) através do nó *Table Partitioner*.

==== Cenário 1 — Normalização Z-score

Normalização das variáveis de entrada pelo método Z-score, excluindo o target `annual_salary_usd`.

#figure(image("imgs/regressao1.png", width: 100%), caption: [Cenário 1 — Regressão com normalização Z-score.])
#pagebreak()
==== Cenário 2 — Normalização Min-max

Normalização das variáveis de entrada pelo método Min-max, excluindo o target `annual_salary_usd`.

#figure(image("imgs/regressao2.png", width: 100%), caption: [Cenário 2 — Regressão com normalização Min-max.])

#pagebreak()
==== Cenário 3 — Numeric Binner (demand\_score)

Discretização do `demand_score` em três intervalos: Baixa Procura (\<50), Média Procura (50–75) e Alta Procura (\>75).

#figure(image("imgs/regressao3.png", width: 100%), caption: [Cenário 3 — Regressão com Numeric Binner aplicado ao demand\_score.])
#pagebreak()
==== Cenário 4 — Numeric Binner (years\_of\_experience)

Discretização do `years_of_experience` em três grupos: Júnior (\<3 anos), Mid (3–7 anos) e Sénior (\>7 anos).

#figure(image("imgs/regressao4.png", width: 100%), caption: [Cenário 4 — Regressão com Numeric Binner aplicado aos anos de experiência.])
#pagebreak()
==== Cenário 5 — PCA

Redução de dimensionalidade com PCA após normalização Z-score, antes da modelação.

#figure(image("imgs/regressao5.png", width: 100%), caption: [Cenário 5 — Regressão com PCA.])


== Análise dos Resultados

=== Clustering

O melhor Silhouette obtido foi de 0,332 no Cenário 2 (com PCA, k=2), seguido do Cenário 1 (0,325, k=2) e do Cenário 3 (0,288, k=4). Os valores moderados indicam que o mercado de emprego em IA não forma segmentos completamente discretos — as diferenças entre perfis são graduais. Ainda assim, os clusters identificados no Cenário 3 com k=4 têm interpretação clara: *Baixa Procura e Baixo Salário*, *Elite Salarial*, *Especialistas LLM* e *Experientes Subvalorizados*.
#pagebreak()
=== Regressão

Os resultados dos cinco cenários de regressão são resumidos na tabela seguinte:

#figure(
  table(
    columns: (2fr, 1.5fr, 1fr, 1.2fr, 1.2fr),
    align: (left, left, center, center, center),
    table.header([*Cenário*], [*Modelo*], [*R²*], [*MAE (USD)*], [*RMSE (USD)*]),
    table.cell(rowspan: 3)[*1* — Z-score], [Árvore Simples], [0,098], [42 113], [58 485],
    [Regressão Linear], [*0,841*], [18 314], [24 541],
    [Random Forest], [0,771], [23 969], [29 489],
    table.cell(rowspan: 3)[*2* — Min-max], [Árvore Simples], [0,097], [42 166], [58 531],
    [Regressão Linear], [0,839], [18 481], [24 683],
    [Random Forest], [0,771], [23 988], [29 484],
    table.cell(rowspan: 3)[*3* — Binner \ demand\_score], [Árvore Simples], [-0,037], [44 847], [62 448],
    [Regressão Linear], [0,808], [18 734], [26 848],
    [Random Forest], [0,741], [24 722], [31 191],
    table.cell(rowspan: 3)[*4* — Binner \ years\_exp], [Árvore Simples], [-0,044], [41 408], [59 967],
    [Regressão Linear], [0,807], [18 637], [26 906],
    [Random Forest], [0,741], [24 463], [31 236],
    table.cell(rowspan: 3)[*5* — PCA], [Árvore Simples], [0,439], [—], [—],
    [Regressão Linear], [0,797], [—], [—],
    [Random Forest], [0,727], [—], [—],
  ),
  caption: [Resultados comparativos dos modelos de regressão nos cinco cenários.]
)

A *Regressão Linear* obteve o melhor desempenho geral, com R²=0,841 no Cenário 1 (Z-score), explicando 84% da variância do salário. Os cenários com Numeric Binner (3 e 4) degradaram ligeiramente o desempenho (R²≈0,808 e 0,807), confirmando que a discretização de variáveis contínuas perde granularidade.

O *Random Forest* manteve desempenho consistente entre cenários (R²≈0,741–0,771), mas inferior à Regressão Linear, sugerindo que as relações no dataset são predominantemente lineares.

A *Árvore de Regressão Simples* obteve fraco desempenho nos Cenários 1 a 4 (R²\<0,10 ou negativo), sendo a exceção o Cenário 5 com PCA (R²=0,439), onde a redução dimensional aparentemente favoreceu a simplicidade do modelo.

O Cenário 5 com *PCA* apresentou resultados intermédios — a Regressão Linear desceu para R²=0,797 face aos 0,841 do Z-score, indicando que a compressão dimensional elimina alguma informação relevante para a previsão salarial.

#pagebreak()
= Conclusão

O trabalho permitiu aplicar, na prática, técnicas de pré-processamento, clustering e regressão sobre dois datasets distintos, com recurso ao KNIME.

No *Production Dataset*, foram desenvolvidos modelos de classificação com Árvores de Decisão e de regressão linear para prever a produção energética, explorando duas estratégias de imputação de valores em falta e incorporando variáveis temporais derivadas da data/hora.

No *AI Job Market Dataset*, o clustering com k-Means identificou quatro segmentos interpretáveis no mercado de emprego em IA (Cenário 3, k=4, Silhouette=0,288). Na regressão, a *Regressão Linear* foi o modelo com melhor desempenho em todos os cenários, atingindo R²=0,841 com normalização Z-score, confirmando que as relações entre as variáveis e o salário são predominantemente lineares. A discretização via Numeric Binner degradou ligeiramente os resultados, e o PCA beneficiou sobretudo a Árvore de Regressão Simples.

Em ambas as tarefas, ficou evidente que a qualidade do pré-processamento tem um impacto direto no desempenho dos modelos, e que a comparação sistemática de cenários é essencial para identificar a abordagem mais adequada a cada problema.
