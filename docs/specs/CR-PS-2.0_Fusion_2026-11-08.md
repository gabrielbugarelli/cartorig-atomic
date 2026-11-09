# CARTORIG — ESPECIFICAÇÃO MESTRA DE PRODUTO E EXPERIÊNCIA | FUSION

**Identificador:** `CR-PS-2.0` · **Estado:** ESPECIFICAÇÃO FINAL DE PRODUCT DESIGN — baseline definido e submetido à homologação do proprietário · **Data:** 08/11/2026  
**Produto:** CartoRig · **Ambiente de autoria:** Fusion do DaVinci Resolve Studio · **Plataforma de referência:** Windows / Resolve Studio 20  
**UI:** inglês exclusivamente · **Documento:** português · **Distribuição pretendida:** gratuita, open source, utilizável offline.  
**Objetivo deste arquivo:** contrato AUTOSSUFICIENTE do produto completo e do primeiro release proposto: funcionalidades, interações, estados, parâmetros, animações e entregáveis. Nenhuma outra especificação ou conversa é necessária para compreender ou implementar o comportamento aprovado após homologação.

> **Mandato para engenharia:** implementação completamente nova. Não presumir reaproveitamento de código, arquitetura, scripts, branches, telas ou decisões de implementação precedentes. O conhecimento acumulado serve para antecipar riscos, não para ditar a solução. Requisitos `MANDATE` derivam de decisões expressas do proprietário. Escolhas fechadas pela equipe de Product Design estão marcadas `BASELINE-PROPOSED`: não se atribui ao proprietário aprovação que não ocorreu.


> **Como utilizar este contrato:** os capítulos 0–10 apresentam regras e fichas de cada objeto e preset; os capítulos 11–18 fecham escopo, estados, integrações, testes e entrega. Se uma definição mais específica de um canal ou feature constar no complemento de escopo §§11–18, ela esclarece a ficha correspondente dos capítulos iniciais e tem precedência sobre uma enumeração resumida. Todo o conteúdo necessário está aqui.

## 0. Legenda de decisão e hierarquia normativa

| Estado | Significado |
|---|---|
| `MANDATE` | Definição expressa do produto, fornecida pelo proprietário: Fusion, Scene / Control / Motion, objetos independentes, inglês, offline e livre. |
| `BASELINE-PROPOSED` | Conjunto proposto pela equipe de produto para **release 1.0**, com comportamento e critérios completos; requer aprovação do proprietário antes de se tornar compromisso. |
| `LATER-PROPOSED` | Capacidade especificada ou candidata para release posterior; não aparece como controle ativo na v1.0. |
| `RESEARCH` | Necessita descoberta funcional e especificação própria; não pode constar como entregue. |
| `ENGINEERING-VERIFY` | Existe caminho técnico documentado, mas aceitação requer execução real no Resolve 20. Esse rótulo não transfere decisão de UX à engenharia. |

**Ordem de autoridade:** mandatos do proprietário > decisões posteriormente aprovadas > contratos do release aprovado > recomendações de produto > liberdade interna de engenharia. A versão inicial é uma **proposta fechada e testável**, não uma decisão já autorizada. A engenharia não pode tratar `BASELINE-PROPOSED` como `APPROVED`.

### 0.1. Definição de produto

CartoRig é uma ferramenta de autoria de mapas e animações cartográficas no **Fusion**, que reduz operações geográficas complexas a criação de objetos, ajuste contextual de propriedades e aplicação de movimentos editáveis. O produto abstrai o trabalho repetitivo de pesquisa, projeção e sincronização geográfica sem substituir o compositor Fusion. O editor trabalha na interface Scene e nos painéis Control e Motion dos objetos Fusion; pode continuar usando Viewer, Node Editor, Keyframes e Spline como um motion designer profissional.

**Não é:** plugin para autoria na Edit; GIS cadastral; geocodificador de ruas; navegador GPS; editor temporal separado; clone visual/código do GEOlayers; biblioteca de animações fechadas; serviço online obrigatório; sequência de macros manuais; produto dependente de IDE/terminal no uso cotidiano.

**Promessa verificável:** em uma composição Fusion, o editor encontra uma localidade, adiciona um objeto, o configura e o anima com Motion ou keyframes manuais, sem precisar montar um pipeline geográfico. O projeto continua renderizável quando a janela Scene está fechada, sem internet e após reiniciar o Resolve.

### 0.2. Princípios que não podem ser negociados pela engenharia

1. `Scene` = criar, localizar, organizar, selecionar, excluir e manter objetos e cenas, via janela UI Manager.
2. `Control` = propriedades granulares e animáveis do **objeto selecionado**, no Inspector Fusion.
3. `Motion` = presets contextuais do objeto selecionado, no Inspector Fusion; suas curvas continuam editáveis no Spline nativo.
4. O editor controla objetos distintos independentemente; a implementação não precisa usar um nó físico para cada vértice, render pass ou feição do mapa-base.
5. Não existe timeline, playhead ou editor de curvas próprio do CartoRig.
6. Criar cena ou objeto nunca insere keyframes, rotas, destaques editoriais ou nomes de países de demonstração.
7. Câmera e objetos georreferenciados compartilham a transformação espacial da cena; um objeto ancorado não deriva durante pan/zoom.
8. Objetos não podem depender de janela, servidor ou processo temporário para renderizar.
9. A experiência instalada funciona inteiramente offline, com dados geográficos locais, sem token/conta.
10. O produto final tem instalação simples, fonte aberta, documentação e testes de host reais.

## 1. Matriz de escopo e inventário de objetos

### 1.1. Matriz de produto

| ID | Objeto/capacidade | Scene (CRUD) | Control | Motion inicial | Release proposto | Status |
|---|---|---|---|---|---|---|
| `OBJ-MAP` | Base Map (terra, oceano, fronteiras) | Inserido ao inicializar cena, não apagável isoladamente | Sim | Layer Fade | 1.0 | BASELINE-PROPOSED |
| `OBJ-REG` | Region / país e estado-província | Sim | Sim | Fade In, Fade Out, Color Transition, Instant Color Change, Border Draw, Highlight Pulse | 1.0 | BASELINE-PROPOSED |
| `OBJ-RTE` | Route / linha georreferenciada | Sim | Sim | Draw Path, Erase Path, Follow Path | 1.0 | BASELINE-PROPOSED |
| `OBJ-MRK` | Marker / cidade ou ponto escolhido | Sim | Sim | Fade In, Pop In | 1.0 | BASELINE-PROPOSED |
| `OBJ-CAM` | Camera compartilhada | Criada na cena, uma por cena | Sim | Fly To, Zoom To, Fit Transition | 1.0 | BASELINE-PROPOSED |
| `OBJ-LBL` | Label geoancorada | Sim | Sim | Fade In | 1.0 | BASELINE-PROPOSED |
| `OBJ-GRP` | Group organizacional | Criar, agrupar, reordenar | Nome/visibilidade/lock | Não | 1.0 | BASELINE-PROPOSED |
| `OBJ-DAT` | Data Layer e choropleth | Futuro | Futuro | Futuro | posterior | LATER-PROPOSED |
| `OBJ-TERRAIN` | Globe, terrain, relief 3D | Futuro | Futuro | Futuro | pesquisa | RESEARCH |

**Decisão fechada de Product Design para homologação:** Labels básicos e grupos organizacionais integram o R1.0; removê-los exige um Change Request com atualização correspondente dos testes e da interface. Não anunciar os recursos do roadmap em telas da 1.0.

### 1.2. Recursos geográficos por release

| Dataset/função | 1.0 proposto | Limite de significado |
|---|---|---|
| Natural Earth Admin 0 | Países com polígono, fronteira e metadados | Contornos generalizados, não cadastrais; registrar versão e POV |
| Natural Earth Admin 1 | Estados/províncias com geometrias presentes | Cobertura deve ser testada no bundle escolhido |
| Populated Places 10m | Cidades/pontos disponíveis | **Ponto**, não perímetro municipal |
| Coastline/land/lakes/ocean | Mapa-base | Camadas e escala dependem do pacote efetivo |
| Rivers/roads/railroads/relief raster | Extensão posterior | Não prometer detalhes ou precisão não instalados |
| Custom point | Ponto com lon/lat especificados pelo editor | Geometria de autoria, distinta de feição do catálogo |
| Import GeoJSON/CSV | Posterior | Exige contrato próprio de dados, erros e licenças |
| Endereço, CEP, municípios globais e roteamento viário | Fora do escopo | Natural Earth não os fornece integralmente |

**Identificação de fonte:** metadados por objeto incluem dataset, release, ID de feição, tipo, escala, versão, país/estado e política de fronteira. Se geometria não existir, não fabricar polígono, nem substituir City por Urban Area sem escolha explícita.

### 1.3. Composição de entrega

Instalador ou pacote GUI para Windows, código-fonte e instruções de build reprodutíveis, licença open source escolhida antes de publicar, dados offline legalmente redistribuíveis, arquivos de manifesto e versão, documentação do editor, documentação de API/esquema para engenharia, testes automatizados, testes executados no Fusion real, e pacote de cenas de regressão. Não exigir Python, Lua, CMake, contas ou terminal do **usuário final**.

## 2. Scene — navegação, criação e gerenciamento (UI Manager)

### 2.1. Superfície de entrada e layout

**Proposta principal:** a janela `CartoRig — Scene` é acionada por **uma entrada CartoRig no menu de scripts/workspace disponível no Fusion**, ou por atalho configurável se o host permitir. Uma única janela por instância Resolve, não uma janela para cada nó. Ela pode permanecer aberta enquanto se trabalha no Node Editor; alternar composição atualiza o contexto. Nenhum fluxo requer a Edit.

```text
CARTORIG  /  SCENE                     [Current Composition: <name>] [Refresh] [?]
[ Search locations, countries, states, cities...                        ] [Filter: All v]
Results  [location + category + parent + geometry] [Focus] [Add as...]  (contextual)
────────────────────────────────────────────────────────────────────────────────
SCENE OBJECTS                    [+ Add] [Collapse] [Filter objects]
◉ Base Map                        [eye] [lock]
◉ Camera                          [eye] [lock]
▸ Regions
    Brazil · Country              [eye] [lock]
    Rio de Janeiro · State        [eye] [lock]
▸ Routes
    Brasília → Amapá              [eye] [lock]
▸ Markers
    São Paulo                     [eye] [lock]
▸ Labels
    São Paulo                     [eye] [lock]
[Selected: Region — Rio de Janeiro] [Reveal node] [Fit] [Duplicate] [Delete]
[Status: Ready / Working / Error]
```

**Wireframe funcional**, não layout pixel-perfect. Proposta responsiva: largura inicial 430 px, altura 640 px, mínimo funcional 360×460 px, painel redimensionável; se o host não fornecer redimensionamento, usar janela fixa que caiba em desktop 1080p com escala Windows 125%. `Enter` aciona ação primária contextual, `Esc` cancela operação de criação/edição, `F2` renomeia objeto selecionado, `Delete` solicita exclusão de objetos autorais (sujeito à captura de foco). Nunca interceptar atalhos enquanto foco estiver fora de Scene. Bloqueios do host devem resultar em estados visíveis, não travamentos.

### 2.2. Máquina de estados de composição

| Estado | Sinal | Ação primária | Ações proibidas | Recuperação |
|---|---|---|---|---|
| `NO_COMP` | Nenhuma composição Fusion ativa | `Create Map Scene` em composição existente ou criar uma Composition conforme suporte documentado | Add object | Abrir/criar composição |
| `COMP_WITHOUT_CARTORIG` | Composição Fusion sem metadados CartoRig | `Initialize CartoRig Scene` | Alterar nós de terceiros | Inicializar sem deletar nós existentes |
| `SCENE_EMPTY` | Cena inicializada, apenas Base Map + Camera | `Find location` / `+ Add` | Presets de objeto inexistente | Criar objeto |
| `SCENE_READY` | Cena válida com objetos | Find, Add, Select, CRUD | Nenhuma operação incompatível | Normal |
| `SCENE_DIRTY` | Mudança realizada após última persistência/refresh | Autoestado na composição + indicação discreta | Inconsistência não sinalizada | Confirmação de estado persistente |
| `WRONG_CONTEXT` | Composição mudou/perdeu link | `Switch Scene` / `Refresh context` | Mutar cena anterior | Confirmar composição ativa |
| `SCENE_BROKEN` | Dados e ferramentas incompatíveis | `Inspect / Recover` | Operações destrutivas | Reparar cópia com diagnóstico |
| `LOCKED` | Objeto/cena bloqueado | `Unlock` | Delete, mudança de Control/Motion | Desbloquear explicitamente |
| `BUSY` | Indexação, pesquisa ou inserção em curso | `Cancel` quando possível | Comandos concorrentes no mesmo alvo | Retorno atômico |
| `HOST_ERROR` | Exceção de API, render, disco | `Retry` / `Copy diagnostics` | Simular sucesso | Deixar cena anterior intacta |

**Ciclo inicial recomendado:** `Open Resolve → Fusion → abrir ou criar Fusion Composition → CartoRig Scene → Initialize/Recognize → Base Map + Camera → buscar localidade → Add as...`. Se o host permitir criar a Fusion Composition pela própria ação Scene, isso é atalho, não outro modelo de cena. A janela nunca deve selecionar outra composição silenciosamente.

### 2.3. Busca, filtros e resultado

- Busca única aceita `Brasil`, `Brazil`, `São Paulo`, `Sao Paulo`, nomes em inglês e aliases indexados. Normalização insensível a caixa/acentos; sem exigir ISO3.
- `Filter: All / Continent / Country / State–Province / City` funciona antes ou depois de digitar. A seleção é filtro, não obrigação prévia de busca.
- Cada resultado apresenta `name`, `type`, `country`, `parent`, disponibilidade `Polygon / Point / Group`, origem do dataset ao expandir detalhes.
- Resultados homônimos são entradas separadas; `Rio de Janeiro — State` e `Rio de Janeiro — City` não são intercambiáveis.
- `Enter` com resultado realçado abre menu de ação, não adiciona objeto. Ações: `Add Region` só se polígono; `Add Marker` se ponto; `Focus Camera` se coordenada/alvo; `Use as Route Start/End` se endpoint válido.
- Estado `NO_MATCH` mostra `No location found in offline data`; limpar filtro ou refinar nome. Estado `NO_GEOMETRY` informa ações disponíveis; `Add Region` desabilitado com motivo.
- Busca não altera imagem até `Add`, `Focus` ou outra ação explícita. Sem internet não aparece diálogo de login/download.
- Busca selecionada não deve gerar Label, Marker, Highlight, Keyframe ou Route por conta própria.

### 2.4. Árvore de objetos e comandos CRUD

| Ação | Onde | Efeito observável e condições |
|---|---|---|
| Add | `+ Add`, resultado da busca ou ação contextual | Cria objeto único, ordenado na categoria correspondente; confirma seleção; Undo reversível |
| Select | Clique na árvore | Atualiza destaque e Inspector do objeto; sem keyframe; seleção única por padrão |
| Multi-select | Ctrl/Shift em objetos compatíveis | Permite Hide, Lock, Delete, Group; Control de seleção mista mostra `Mixed` em vez de inventar valores |
| Rename | F2 ou menu contextual | Altera rótulo visível, **não** ID do objeto, fonte geográfica ou nome de país no catálogo |
| Duplicate | Ctrl+D no foco Scene / menu contextual | Cria ID único, copia estilo e curvas; sem vínculo dinâmico involuntário com original |
| Delete | Delete/menu contextual | Remove apenas objeto do CartoRig e suas curvas gerenciadas; proteção para Base Map/Camera |
| Reorder | Drag em lista ou Move up/down | Muda **ordem de desenho** do objeto e é reproduzível no Viewer; não altera lat/lon |
| Hide/Show | Ícone eye | Suprime render, preserva estilo/keyframes; não equivale a Opacity=0 |
| Lock/Unlock | Cadeado | Impede alterações e movimento do objeto via Scene/Control/Motion; render ainda visível |
| Group/Ungroup | Menu seleção múltipla | Organiza pasta e seleção; sem transformação/opacidade animada coletiva no baseline |
| Reveal node | Barra de detalhes | Seleciona/localiza representação apropriada no Node Editor; sem alterar imagem |
| Reset property | Control | Restaura apenas uma propriedade herdada ou default; preserva outras e animações independentes |
| Undo/Redo | Comandos do Fusion | Criação/deleção/renomeação/alteração/preset em unidade lógica compatível com host; sem nós órfãos |

**Sistemática de layering:** Base Map no fundo; Regions, Routes, Markers e Labels ordenáveis em uma única ordem composta. A árvore pode agrupar por categoria, mas **reordenação global** não fica limitada à categoria. Em sobreposição, o objeto desenhado acima prevalece, respeitando alpha e blend; reorder não muda georreferência. Group na 1.0 é apenas organizacional, não cria transformações herdadas.

### 2.5. Sincronização Scene ↔ nós ↔ Inspector

1. Selecionar objeto na árvore atualiza o nó/ferramenta correspondente e mostra suas páginas Control/Motion; se o host não permitir abrir Inspector automaticamente, seleção correta e identificação clara são mandatórias.
2. Selecionar nó CartoRig no Node Editor atualiza seleção da Scene; selecionar nó não pertencente ao CartoRig não apaga estado, mas Scene mostra `Non-CartoRig selection` e impede ações direcionadas ao objeto anterior.
3. Trocar composição invalida a seleção anterior antes de habilitar controles; referência de cena é sempre `composition ID + object ID`.
4. Renomear nó manualmente não altera ID e não quebra vinculação; excluir fisicamente nó CartoRig fora de Scene produz `SCENE_BROKEN` ou recuperação coerente, nunca edição do objeto errado.
5. Fechar Scene não afeta Viewer, render, Spline, keyframes ou persistência; reabrir reconstrói árvore a partir da composição.
6. Operações no modelo e no host não devem gerar loops de evento, repetição de preset ou criação de nós duplicados.

### 2.6. Estados de erro e cópia de diagnóstico

Mensagens objetivas em inglês com entidade afetada, ação e recuperação. Exemplos: `This location has point data only. Add a Marker or Focus the Camera.`; `The current Fusion composition has changed. Select the active scene before editing.`; `CartoRig could not restore this object. No changes were made.` Erros de processamento devem distinguir `Retry`, `Cancel`, `Recover copy` e ação indisponível. Não mostrar stacktrace ao editor por padrão; `Copy diagnostics` disponibiliza código de erro e registro técnico sem exigir terminal.

## 3. Control — dicionário normativo de propriedades

**Contrato comum:** o Inspector mostra apenas propriedades aplicáveis ao objeto selecionado. Valores são avaliados no frame atual da composição. `Reset Property` restaura a propriedade ao default herdado (ou valor local default), não redefinindo outras propriedades. `Reset Style` redefine atributos de estilo do objeto selecionado e solicita confirmação se houver curvas nos canais que serão afetados. `Reset Object` não é substituto implícito de Delete. Cores têm picker gráfico com hexadecimal e alpha; não exigir digitação RGB por sliders separados. Nomes em inglês.

**Estados visuais de cada campo:** `Inherited` (valor de preset), `Overridden` (valor explícito), `Animated` (canal animável existente), `Mixed` (multiseleção), `Locked`, `Unsupported` (não editar). A cor efetiva obedece a `Scene preset → Object type default → Object override → evaluated animation at current frame`. O mapa-base não recolore objetos com override independente.

**Política de keyframes:** campos marcados `Yes` permitem keyframe manual direto no Inspector por mecanismo compatível com Fusion; `No` são parâmetros estruturais. Para campos não animáveis, ocultar/desabilitar ícone de keyframe. Variáveis `Fill Alpha` e `Object Opacity` são distintas; `Visibility` não substitui Opacity. Tamanhos gráficos indicados em `px` são pixels no output da composição e permanecem constantes com zoom por padrão; projeção geográfica afeta a **âncora**, não seu tamanho de tela.

> **Defaults abaixo são propostas visuais e de UX para aceite, não cores aprovadas pelo proprietário.** Constam aqui para eliminar escolhas arbitrárias da engenharia. Valores podem ser refinados por revisão visual mantendo a mesma semântica.

### 3.1. Tipos de edição e unidades

| Tipo | Exibição | Teclado | Reset e animação |
|---|---|---|---|
| Color | Picker + campo hex/alpha | Colar `#RRGGBB` ou `#RRGGBBAA` | Cor inteira animável com interpolação/Step quando indicado |
| Float slider | Slider + numeric input | Setas ajuste fino; número exato | Clamping nos limites apresentados |
| Percentage | 0–100% | Número em % | 100% = sem redução |
| Toggle | On/Off | Space | Só animável quando indicado |
| Enum | Dropdown | Setas e Enter | Apenas opções implementadas e disponíveis |
| Geographic point | Localidade ou lon/lat | Nome através de Scene; grau decimal como ajuste avançado | Não modificar ID do catálogo |
| Vector 2D | X/Y numéricos, unidade indicada | Numeric | Normalizado ou pixels conforme campo |
| Text | Campo Unicode | Edição integral, incluindo acentos | Suporte a nomes PT-BR; animar texto discreto somente se previsto |

### 3.2. Base Map — Control (`CT-MAP-*`)

O mapa-base é obrigatório e único por Map Scene. Ele pode ser ocultado ou configurado como transparente, mas não deletado separadamente; regiões, rotas, labels e markers permanecem presentes. Propriedades de camada afetam geometrias da base, sem alterar objetos autorais.

| ID | Campo UI | Tipo; default; limites | Anim. | Efeito/condição |
|---|---|---|---|---|
| CT-MAP-01 | Display Mode | Enum `Full Map` (default), `Transparent Overlay` | No | Full Map mostra base; overlay desliga pixels de fundo e mantém objetos selecionados; ver §6 |
| CT-MAP-02 | Ocean Fill | Color `#10283C` | Yes | Apenas pixel de oceano do mapa-base; alpha próprio |
| CT-MAP-03 | Land Fill | Color `#394C59` | Yes | Apenas terras do mapa-base |
| CT-MAP-04 | Coastline Color | Color `#B5C1CC` | Yes | Linhas de costa |
| CT-MAP-05 | Coastline Width | Float `1.0 px`; 0–12 px | Yes | Espessura em pixels, independente de zoom |
| CT-MAP-06 | Country Border Color | Color `#96AAB9` | Yes | Admin-0 boundary layer; se incluída |
| CT-MAP-07 | Country Border Width | Float `1.0 px`; 0–12 px | Yes | Bordas entre países; se houver fonte |
| CT-MAP-08 | State Border Visible | Toggle `Off` | No | Admin-1 não aparece automaticamente em todos os países |
| CT-MAP-09 | State Border Color | Color `#8295A4` | Yes | Mostrado se state borders ligado |
| CT-MAP-10 | State Border Width | Float `0.6 px`; 0–8 px | Yes | Mostrado se state borders ligado |
| CT-MAP-11 | Base Opacity | Percentage `100%` | Yes | Transparência total da base; não altera objetos autorais |
| CT-MAP-12 | Visibility | Toggle `On` | No | Oculta base sem apagar valores; não altera demais objetos |
| CT-MAP-13 | Projection | Enum `Equirectangular` baseline | No | Outras projeções só aparecem após implementação; não reinterpretar geocoordenadas silenciosamente |
| CT-MAP-14 | Style Preset | Enum `Neutral Dark` baseline | No | Seleciona tokens de estilo; não remove overrides de objetos |
| CT-MAP-15 | Reset Base Style | Action com confirmação | No | Restaura apenas estilo da base, preserva objetos, câmera e animações não relacionadas |
| CT-MAP-16 | Ocean Layer Opacity | Percentage `100%`; 0–100 | Yes | Alpha da camada Ocean; independente da base global |
| CT-MAP-17 | Land Layer Opacity | Percentage `100%`; 0–100 | Yes | Alpha da camada Land, sem afetar objetos autorais |
| CT-MAP-18 | Coastline Layer Opacity | Percentage `100%`; 0–100 | Yes | Alpha da camada Coastline |
| CT-MAP-19 | Country Border Layer Opacity | Percentage `100%`; 0–100 | Yes | Alpha das fronteiras Admin-0 |
| CT-MAP-20 | State Border Layer Opacity | Percentage `100%`; 0–100 | Yes | Alpha de fronteiras Admin-1; visível somente se a camada estiver ligada |

### 3.3. Region — Control (`CT-REG-*`)

Objeto poligonal com referência real `Polygon/MultiPolygon` a um Admin-0/Admin-1 ou conjunto de features selecionadas. Ilha, buraco e fragmentos compõem um só objeto. Um país e um estado do país podem coexistir com estilos diferentes.

| ID | Campo UI | Tipo; default; limites | Anim. | Efeito/condição |
|---|---|---|---|---|
| CT-REG-01 | Region Name | Text; nome escolhido | No | Nome exibido; não altera feature ID |
| CT-REG-02 | Geographic Source | Read-only type, ID, dataset, version | No | Propriedade auditável, não ISO obrigatório no editor |
| CT-REG-03 | Fill Color | Color `#8296A4` | Yes | Preenchimento neutro por objeto; não recolore Parent Country |
| CT-REG-04 | Fill Alpha | Percentage `100%` | Yes | Transparência só do preenchimento |
| CT-REG-05 | Stroke Visible | Toggle `On` | No | Borda independente do preenchimento |
| CT-REG-06 | Stroke Color | Color `#D7E0E7` | Yes | Linha do limite da região |
| CT-REG-07 | Stroke Width | Float `1.5 px`; 0–24 px | Yes | Constante em pixels durante zoom |
| CT-REG-08 | Stroke Alpha | Percentage `100%` | Yes | Apenas borda |
| CT-REG-09 | Object Opacity | Percentage `100%` | Yes | Multiplica Fill e Stroke após composição |
| CT-REG-10 | Visibility | Toggle `On` | No | Eye/Inspector refletem mesmo estado |
| CT-REG-11 | Blend Mode | Enum `Normal` inicialmente | No | Ampliar apenas após teste pipeline; não exibir modos mortos |
| CT-REG-12 | Draw Order | Integer / ação Scene | No | Ordem global da camada visual |
| CT-REG-13 | Fit to Region | Action | No | Enquadramento estático da câmera, não cria keyframes |
| CT-REG-14 | Reset Style | Action | No | Restaura cores/bordas/opacity do objeto, após política de curva |
| CT-REG-15 | Stroke Progress | Percentage `100%`; 0–100 | Yes | Revelação do contorno por comprimento; não altera Fill nem Stroke Width |
| CT-REG-16 | Highlight Strength | Percentage `0%`; 0–100 | Yes | Mistura de ênfase sobre o resultado visual, independente do Fill autoral |
| CT-REG-17 | Highlight Color | Color `#E6C66B`; alpha via Strength | Yes | Cor da ênfase; padrão editorial neutro sugerido; só altera esta Region |
| CT-REG-18 | Highlight Mode | Enum `Fill Tint` (default), `Stroke Tint` | No | Define qual componente recebe a ênfase; não reescreve cor-base |
| CT-REG-19 | Contour Scope | Enum `All Rings` (default), `Outer Rings` | No | Define anéis revelados pelo Stroke Progress, preservando multipolígonos e buracos |

### 3.4. Route — Control (`CT-RTE-*`)

Route representa geometria espacial independente das curvas temporais. Os endpoints sempre são coordenadas explícitas ou âncoras de pontos. Um estado/polígono não é endpoint unívoco; Scene solicita ponto de chegada antes de permitir confirmar.

| ID | Campo UI | Tipo; default; limites | Anim. | Efeito/condição |
|---|---|---|---|---|
| CT-RTE-01 | From | Geo point ou âncora | No | Origem real, editável; escolha via Scene |
| CT-RTE-02 | To | Geo point ou âncora | No | Destino real, editável; não inventar centroide |
| CT-RTE-03 | Waypoints | Lista ordered, default vazia | No | Add/Move/Delete com Undo; sem quebrar rota |
| CT-RTE-04 | Path Type | Enum `Straight` (default), `Curved`; ambos no R1.0 | No | `Straight` = segmento projetado; `Curved` = Bézier cartográfica estilizada, não navegação viária |
| CT-RTE-05 | Curvature | Float `0`; -100 a +100 | No | Em Curved, desloca alças da Bézier em norma à corda: `100`=+0,5 comprimento projetado, `-100`=-0,5; unidade visual relativa, sem alterar easing |
| CT-RTE-06 | Stroke Color | Color `#D6DFE6` | Yes | Cor da linha independente |
| CT-RTE-07 | Stroke Width | Float `3 px`; 0–32 px | Yes | Constante no espaço da tela |
| CT-RTE-08 | Stroke Alpha | Percentage `100%` | Yes | Altera só stroke |
| CT-RTE-09 | Object Opacity | Percentage `100%` | Yes | Opacidade final do objeto |
| CT-RTE-10 | Arrowhead | Toggle `Off` | No | Opcional, sem setas editoriais implícitas |
| CT-RTE-11 | Arrowhead Size | Float `12 px`; 2–64 px | Yes | Aparece só se Arrowhead On |
| CT-RTE-12 | Arrowhead Direction | Enum `Forward` default / `Reverse` | No | Não inverte endpoints sem comando explícito |
| CT-RTE-13 | Draw Progress | Percentage `100%` | Yes | Comprimento visível de 0–100%; base dos presets Draw/Erase |
| CT-RTE-14 | Trim Start | Percentage `0%` | Yes | Início do segmento visível; deve ser ≤ Trim End |
| CT-RTE-15 | Trim End | Percentage `100%` | Yes | Fim do segmento visível; deve ser ≥ Trim Start |
| CT-RTE-16 | Visibility | Toggle `On` | No | Preserva geometria e keyframes |
| CT-RTE-17 | Reverse Route | Action com preview | No | Troca From/To e ordem dos waypoints, sem alterar cor |
| CT-RTE-18 | Edit Path | Action | No | Habilita edição espacial suportada; se Viewer não aceitar handles, Scene oferece lista/valores de pontos |
| CT-RTE-19 | Follower Marker | Object reference; default `None` | No | Seleciona marcador existente; sem criação implícita; valida mesma cena |
| CT-RTE-20 | Follower Progress | Percentage `0%`; 0–100 | Yes | Posiciona marcador associado no comprimento visível/geográfico da Route, sem modificar âncora autoral original |
| CT-RTE-21 | Orient Follower | Toggle `Off` | No | Quando marcador tiver orientação, acompanha tangente; indisponível para símbolo sem rotação |
| CT-RTE-22 | Follow Route Visibility | Enum `Independent` (default), `Follow Route` | No | Define se ocultar a rota também oculta o follower; não muda keyframes |

**Semântica dos intervalos:** `Draw Progress` limita a extensão do caminho até a fração indicada; a seção efetivamente visível é a interseção entre `[0, Draw Progress]` e `[Trim Start, Trim End]`, com todos os valores normalizados em 0–100%. Se `Trim Start` superar `Trim End`, o Inspector rejeita a edição conflitante e restaura o último valor válido.

**Arrowhead ao desenhar:** quando ligada e `Draw Progress` controla a rota, fica na ponta móvel da fração visível e orientada pela tangente. Em 0% não é exibida; em 50% fica no ponto médio de comprimento da trajetória; em 100% fica no destino. `Trim Start/End` prevalece sobre segmentos fora do intervalo; detalhes de múltiplos trims ficam fora do primeiro release.

### 3.5. Marker — Control (`CT-MRK-*`)

| ID | Campo UI | Tipo; default; limites | Anim. | Efeito/condição |
|---|---|---|---|---|
| CT-MRK-01 | Anchor Location | Geographic point, localidade/coord. | No | Segue câmera; não altera catálogo de dados |
| CT-MRK-02 | Symbol | Enum `Dot` default / `Ring` | No | Outros ícones futuramente |
| CT-MRK-03 | Fill Color | Color `#E0E8ED` | Yes | Cor do símbolo |
| CT-MRK-04 | Stroke Color | Color `#142637` | Yes | Contorno do símbolo |
| CT-MRK-05 | Size | Float `14 px`; 0–128 px | Yes | Constante em pixels apesar de zoom; ponto de ancoragem fixo |
| CT-MRK-06 | Stroke Width | Float `1.5 px`; 0–16 px | Yes | Constante em pixels |
| CT-MRK-07 | Offset X / Offset Y | Float `0 px`; -500–500 | Yes | Aplica deslocamento depois da projeção, não muda lon/lat |
| CT-MRK-08 | Object Opacity | Percentage `100%` | Yes | Transparência geral |
| CT-MRK-09 | Visibility | Toggle `On` | No | Não destrutivo |
| CT-MRK-10 | Fit/Focus Marker | Action | No | Move câmera estaticamente, não altera Marker |

### 3.6. Camera — Control (`CT-CAM-*`)

A cena possui **uma única câmera cartográfica** com parâmetros autorais, não uma cópia por objeto. Zoom é um fator relativo à projeção/vista base e não representa altura física ou lente 3D. A pose inicial deve ser estável e reproduzível conforme resolução/razão de aspecto.

| ID | Campo UI | Tipo; default; limites | Anim. | Efeito/condição |
|---|---|---|---|---|
| CT-CAM-01 | Center Longitude | Float `0°`; -180–180 | Yes | Longitude centro; interpolação deve evitar saltos indevidos na mudança de 180° |
| CT-CAM-02 | Center Latitude | Float `0°`; -85–85 na projeção suportada | Yes | Latitude centro; limite mostrado, sem extrapolação inválida |
| CT-CAM-03 | Zoom | Float `1.0×`; 0.1–50.0× | Yes | Zoom relativo; escala consistente após alteração de resolução |
| CT-CAM-04 | Bearing | Float `0°`; -180–180 | Yes | Rotação plana da visualização; não pitch/3D |
| CT-CAM-05 | Fit Padding | Percentage `8%`; 0–35% | No | Margem dos limites do alvo no enquadramento |
| CT-CAM-06 | Focus Location | Action com localização selecionada | No | Centraliza sem alterar zoom/bearing, a menos que comando `Fit` |
| CT-CAM-07 | Fit Location | Action | No | Calcula centro e zoom para conter geometria no aspecto atual |
| CT-CAM-08 | Fit Selected Objects | Action | No | Calcula limites conjuntos válidos e enquadra |
| CT-CAM-09 | Save Pose | Action | No | Registra pose acessível em Motion sem criar keys por si só |
| CT-CAM-10 | Reset Pose | Action com política de curva | No | Restaura valores iniciais; não apaga outras curvas silenciosamente |

**Focus vs Fit vs Fly To:** Focus muda centro imediatamente **no estado de edição atual** e não cria keyframes automaticamente. Fit muda centro/zoom para enquadrar limites; uma City apenas ponto usa zoom padrão de foco (`4×` proposto) ajustável. Fly To é animação deliberada entre duas poses em Motion e pode animar Center+Zoom+Bearing, sem mover objetos individuais. Clique em action de pose quando Camera já animada apresenta escolha `Set keyframe at playhead` / `Change static base` / `Cancel` conforme §5, não altera outros frames silenciosamente.

### 3.7. Label — Control (`CT-LBL-*`)

| ID | Campo UI | Tipo; default; limites | Anim. | Efeito/condição |
|---|---|---|---|---|
| CT-LBL-01 | Text | Unicode string, nome sugerido | No | Conteúdo tipográfico independente da geografia |
| CT-LBL-02 | Anchor Location | Geo point | No | Segue câmera como marcador |
| CT-LBL-03 | Font Family | Enum fontes instaladas; default `Sans` via fallback | No | Fallback previsível, acentos preservados |
| CT-LBL-04 | Font Size | Float `32 px`; 6–200 px | Yes | Tamanho em tela/saída, não unidades geográficas |
| CT-LBL-05 | Text Color | Color `#F0F5F8` | Yes | Não altera outros labels |
| CT-LBL-06 | Horizontal Align | Left / Center default / Right | No | Ancora posicionamento gráfico |
| CT-LBL-07 | Offset X / Offset Y | Float `0 px`; -1000–1000 | Yes | Após projeção; acompanha movimento da câmera |
| CT-LBL-08 | Halo | Toggle `On` default | No | Contraste sobre mapa |
| CT-LBL-09 | Halo Color | Color `#0B1621` | Yes | Visível com Halo On |
| CT-LBL-10 | Halo Width | Float `2 px`; 0–20 | Yes | Visível com Halo On |
| CT-LBL-11 | Object Opacity | Percentage `100%` | Yes | Anima Fade manual ou via preset |
| CT-LBL-12 | Visibility | Toggle `On` | No | Ocultação não destrutiva |

### 3.8. Group — Control (`CT-GRP-*`)

| ID | Campo | Valor | Comportamento |
|---|---|---|---|
| CT-GRP-01 | Name | String | Somente rótulo organizacional; não modifica geometrias |
| CT-GRP-02 | Lock | On/Off | Bloqueia operações autorais nos filhos por Scene |
| CT-GRP-03 | Visibility | On/Off | Oculta filhos mantendo estados individuais; restaura ao reexibir |
| CT-GRP-04 | Reorder | Lista | Move conjunto na pilha sem alterar ordem relativa interna |

Grupos na 1.0 não têm Motion, transformações ou opacity de grupo; não exibir controles inexistentes. Remover grupo oferece `Ungroup and keep objects` (default) ou `Delete group and objects` (confirmação forte).

## 4. Motion — catálogo proposto e contratos de cada preset

### 4.1. Modelo de interação comum

Motion está no **Inspector do objeto**, separado de Control. Um objeto novo nasce no estado `No preset`. Motion mostra apenas animações compatíveis com esse objeto. Clicar no preset **seleciona e pré-configura** a ficha, mas não escreve keys até `Apply`. Ao confirmar, gera animação do objeto no sistema de tempo do Fusion e disponibiliza os canais de Control no Spline/Keyframes. Um preset não pode ser animação fechada renderizada como vídeo externo.

**Regras temporais comuns propostas para v1.0:**

- `Start Frame` = playhead **na ação Apply** (índice de quadro da composição); `Delay` = 0 f; `Duration` = 24 frames (salvo ficha específica); duração inteira ≥1 frame.
- O intervalo ativo é `[start+delay, start+delay+duration]` em frames da composição. Se o último frame exceder duração da composição, `Apply` fica indisponível até ajustar; a UI mostra intervalo efetivo.
- Easing padrão `Ease In/Out` com Bézier regular; outras opções `Linear`, `Hold` quando pertinentes; `Custom` reconhece alterações manuais. Valores entre keys são determinísticos por avaliação no tempo do Fusion.
- A variável `Target` corresponde ao valor efetivo atual de Control antes de aplicar, salvo ficha que pede escolha explícita. A animação altera **somente** canais declarados.
- Não habilitar automaticamente `Record`, alterações da câmera ou operações sobre outros objetos.
- Os frames anteriores ao Start mantêm o estado inicial especificado na ficha; os posteriores à última key mantêm o estado final. `Apply` em objeto com keys preexistentes no mesmo canal exige resolução de conflito.
- `Update` é permitido livremente apenas em `ANIMATED_PRESET` sem edição manual; no estado `PRESET_CUSTOMIZED` mostra resumo do que mudará e exige escolha `Retiming only` / `Replace affected channels` / `Cancel`.
- `Remove` oferece `Keep animation as manual` (default, retira vínculo com preset sem apagar keys) ou `Delete preset-generated keys` (com confirmação e comparação com edições manuais). Não remove objeto, outros canais nem estilos sem relação.
- `Undo` de Apply/Update/Remove restaura o estado imediatamente anterior do objeto, parâmetros e curvas. `Duplicate` cria um novo objeto com curvas independentes; duplicação não registra vínculo compartilhado entre instâncias.
- O efeito nunca depende de reprodução sequencial para calcular valor; deve funcionar em seek aleatório, renderização fora de ordem e reabertura com a janela Scene fechada.

### 4.2. Estados e conflitos por propriedade

| Estado | Definição | UI / transição |
|---|---|---|
| `STATIC` | Sem keys no canal | Control exibe valor global; editar não cria key automaticamente sem intenção |
| `ANIMATED_MANUAL` | Keys criadas ou mantidas manualmente, sem preset ativo | Key indicator + Spline; aplicar preset ao mesmo canal exige decisão |
| `ANIMATED_PRESET` | Keys vinculadas a preset aplicado sem modificação externa | Motion permite Update previsível |
| `PRESET_CUSTOMIZED` | Qualquer alteração externa em key, tangente, interpolação, expressão ou canal vinculado | Motion exibe `Customized`, preserva curva; Update com diálogo |
| `CONFLICT` | Novo preset ou comando atinge canais animados por outra origem | UI apresenta canais e intervalos: `Replace affected`, `Keep existing/Cancel`; não overwrite silencioso |
| `UNSUPPORTED` | Propriedade sem capacidade real de keyframe para a integração atual | Preset desabilitado com explicação; jamais simular curvas editáveis |

**Edição de Control em canal animado:** com keyframe explícito no playhead altera a key daquele frame; entre keys, controle deve indicar `Animated value` e oferecer `Add keyframe at current frame` ou `Edit static/base value` somente quando semanticamente suportado. Não permitir substituir animação toda silenciosamente. Se o host autokey tiver semântica diferente, apresentar estado de host e manter operações inequívocas. Mudança manual de Control em uma key de preset produz `PRESET_CUSTOMIZED`.

**Mutação de tempo:** ao mudar `Duration` de preset puro, reescalar keys ao intervalo mantendo valores e curvas relativas; depois de personalização, propor `Retiming only`, preservando formas/tangentes tanto quanto a API permitir, e não re-gerar do zero. Mudança de FPS sem mudar a duração em frames mantém a posição dos keys em quadros, alterando segundos; projeto deve avisar na alteração de FPS e não converter por conta própria. Trim/retime do clipe obedecem tempo efetivo de composição Fusion, sem criar timeline paralela.

### 4.3. Biblioteca do release inicial — proposta de aprovação

| Preset ID | Objeto | Nome UI | Canais | Release | Status |
|---|---|---|---|---|---|
| `MO-REG-01` | Region | Fade In | Object Opacity | 1.0 | BASELINE-PROPOSED |
| `MO-REG-02` | Region | Fade Out | Object Opacity | 1.0 | BASELINE-PROPOSED |
| `MO-REG-03` | Region | Color Transition | Fill Color | 1.0 | BASELINE-PROPOSED |
| `MO-REG-04` | Region | Instant Color Change | Fill Color | 1.0 | BASELINE-PROPOSED |
| `MO-RTE-01` | Route | Draw Path | Draw Progress | 1.0 | BASELINE-PROPOSED |
| `MO-RTE-02` | Route | Erase Path | Draw Progress | 1.0 | BASELINE-PROPOSED |
| `MO-MRK-01` | Marker | Fade In | Object Opacity | 1.0 | BASELINE-PROPOSED |
| `MO-MRK-02` | Marker | Pop In | Size | 1.0 | BASELINE-PROPOSED |
| `MO-CAM-01` | Camera | Fly To Location | Center longitude/latitude, Zoom, optional Bearing | 1.0 | BASELINE-PROPOSED |
| `MO-CAM-02` | Camera | Zoom To | Zoom | 1.0 | BASELINE-PROPOSED |
| `MO-LBL-01` | Label | Fade In | Object Opacity | 1.0 | BASELINE-PROPOSED |
| `MO-REG-05` | Region | Border Draw | Stroke Progress | 1.0 | BASELINE-PROPOSED |
| `MO-REG-06` | Region | Highlight Pulse | Highlight Strength | 1.0 | BASELINE-PROPOSED |
| `MO-CAM-03` | Camera | Fit Transition | Center/Zoom | 1.0 | BASELINE-PROPOSED |
| `MO-RTE-03` | Route | Follow Path | Follower Progress of linked Marker | 1.0 | BASELINE-PROPOSED |
| `MO-MAP-01` | Base Map | Layer Fade | Opacity of chosen base layer | 1.0 | BASELINE-PROPOSED |

**Não inclusos no R1.0 recomendado:** Region Mask Reveal, Route Trim Trail/Directional Reveal, Marker Pulse/Pop Out, Label Text Reveal/Slide, Camera Orbit/3D, Base Map Style Transition, Group Stagger/Cascade, data layers e choropleth. `Marker Stagger` e outras receitas multiobjeto pertencem à expansão Professional, salvo aprovação de novo escopo. Esses itens compõem inventário `LATER-PROPOSED` ou `RESEARCH`, não botões inativos do release.

### 4.4. `MO-REG-01` — Region / Fade In

| Campo do contrato | Definição proposta |
|---|---|
| **Onde** | Fusion Inspector → objeto `Region` → `Motion` → `Fade In` |
| **Estado** | `BASELINE-PROPOSED` — não aprovado automaticamente |
| **Pré-condições** | Region com geometria válida e Object Opacity alvo >0%. |
| **Canais Control afetados** | Object Opacity |
| **Inputs/defaults** | Start=playhead; Delay=0 f; Duration=24 f; Target Opacity=valor atual; Easing=Ease In/Out. |
| **Comportamento temporal e visual** | Valor 0% desde o início do intervalo; valor-alvo no frame final; depois mantém destino. Fill e Stroke inalterados. |
| **Apply/Update** | `Apply` gera somente keys dos canais especificados. `Update` segue estados §4.2 e preserva edições manuais. |
| **Conflict/Remove** | Se já existem keys em Object Opacity, `CONFLICT` antes de Apply; não altera Fill Alpha. Remover por `Keep animation as manual` (default) ou excluir só keys gerados com confirmação; mantém objeto. |
| **Persistência** | Curva e metadados sobrevivem a duplicar, fechar janela, salvar/reabrir e exportar sem depender do UI Manager. |
| **Aceitação** | Na amostra start, midpoint, end, o estado esperado é 0%, interpolação e target; segunda Region permanece constante. Verificar curvas no Spline, Undo, execução com seek aleatório e render. |

### 4.5. `MO-REG-02` — Region / Fade Out

| Campo do contrato | Definição proposta |
|---|---|
| **Onde** | Fusion Inspector → objeto `Region` → `Motion` → `Fade Out` |
| **Estado** | `BASELINE-PROPOSED` — não aprovado automaticamente |
| **Pré-condições** | Region válida, visível e Object Opacity inicial >0%. |
| **Canais Control afetados** | Object Opacity |
| **Inputs/defaults** | Start=playhead; Delay=0 f; Duration=24 f; Source=valor atual; Easing=Ease In/Out. |
| **Comportamento temporal e visual** | Da opacidade atual no início até 0% no final, mantendo 0% depois; conserva cor e borda. |
| **Apply/Update** | `Apply` gera somente keys dos canais especificados. `Update` segue estados §4.2 e preserva edições manuais. |
| **Conflict/Remove** | Keys existentes no canal geram `CONFLICT`; remover keys não desativa `Visibility`. Remover por `Keep animation as manual` (default) ou excluir só keys gerados com confirmação; mantém objeto. |
| **Persistência** | Curva e metadados sobrevivem a duplicar, fechar janela, salvar/reabrir e exportar sem depender do UI Manager. |
| **Aceitação** | Confirmar 100%→0% (ou valor inicial real) e que outro país no mapa não desaparece. Verificar curvas no Spline, Undo, execução com seek aleatório e render. |

### 4.6. `MO-REG-03` — Region / Color Transition

| Campo do contrato | Definição proposta |
|---|---|
| **Onde** | Fusion Inspector → objeto `Region` → `Motion` → `Color Transition` |
| **Estado** | `BASELINE-PROPOSED` — não aprovado automaticamente |
| **Pré-condições** | Region válida e `Target Color` escolhido explicitamente. |
| **Canais Control afetados** | Fill Color RGBA (canal lógico de cor) |
| **Inputs/defaults** | Start=playhead; Delay=0 f; Duration=24 f; From=current Fill Color; To=required Target Color; Easing=Linear default. |
| **Comportamento temporal e visual** | RGBA do preenchimento interpola continuamente sem trocar cor da borda; no frame final mantém To. |
| **Apply/Update** | `Apply` gera somente keys dos canais especificados. `Update` segue estados §4.2 e preserva edições manuais. |
| **Conflict/Remove** | Canal de cor previamente animado exige `CONFLICT`; não criar keys em Object Opacity. Remover por `Keep animation as manual` (default) ou excluir só keys gerados com confirmação; mantém objeto. |
| **Persistência** | Curva e metadados sobrevivem a duplicar, fechar janela, salvar/reabrir e exportar sem depender do UI Manager. |
| **Aceitação** | Região vermelha→verde, frames inicial/meio/final; demais regiões não mudam; RGB intermediário corresponde à interpolação escolhida. Verificar curvas no Spline, Undo, execução com seek aleatório e render. |

### 4.7. `MO-REG-04` — Region / Instant Color Change

| Campo do contrato | Definição proposta |
|---|---|
| **Onde** | Fusion Inspector → objeto `Region` → `Motion` → `Instant Color Change` |
| **Estado** | `BASELINE-PROPOSED` — não aprovado automaticamente |
| **Pré-condições** | Region válida, destino RGB(A) escolhido explicitamente. |
| **Canais Control afetados** | Fill Color com interpolação discreta |
| **Inputs/defaults** | Change Frame=playhead; Target Color=required; Interpolation=Hold/Step; Duration não aplicável. |
| **Comportamento temporal e visual** | Até o frame anterior conserva valor inicial; no Change Frame usa cor-alvo e a mantém; não existe crossfade. |
| **Apply/Update** | `Apply` gera somente keys dos canais especificados. `Update` segue estados §4.2 e preserva edições manuais. |
| **Conflict/Remove** | A transição discreta deve ser implementada por Step/Hold nativo quando disponível ou por valores adjacentes em frames inteiros que produzam o mesmo resultado exato; ausência de ambos reprova o gate, não autoriza substituir por crossfade. Remover por `Keep animation as manual` (default) ou excluir só keys gerados com confirmação; mantém objeto. |
| **Persistência** | Curva e metadados sobrevivem a duplicar, fechar janela, salvar/reabrir e exportar sem depender do UI Manager. |
| **Aceitação** | Com 30 fps: vermelho até frame 329; verde a partir de frame 330; outro país inalterado; buscar frames 328/329/330/331. Verificar curvas no Spline, Undo, execução com seek aleatório e render. |

### 4.8. `MO-RTE-01` — Route / Draw Path

| Campo do contrato | Definição proposta |
|---|---|
| **Onde** | Fusion Inspector → objeto `Route` → `Motion` → `Draw Path` |
| **Estado** | `BASELINE-PROPOSED` — não aprovado automaticamente |
| **Pré-condições** | Rota com From/To resolvidos, geometria válida e progress animável. |
| **Canais Control afetados** | Draw Progress |
| **Inputs/defaults** | Start=playhead; Delay=0 f; Duration=30 f; Progress 0→100%; Easing=Ease In/Out. |
| **Comportamento temporal e visual** | Geometria fica fixa; traçado cresce da origem ao destino; Arrowhead opcional acompanha ponta visível, oculto em 0%. |
| **Apply/Update** | `Apply` gera somente keys dos canais especificados. `Update` segue estados §4.2 e preserva edições manuais. |
| **Conflict/Remove** | Mudar waypoint/curvatura após Apply preserva curva temporal e recalcula a posição ao longo do novo caminho. Remover por `Keep animation as manual` (default) ou excluir só keys gerados com confirmação; mantém objeto. |
| **Persistência** | Curva e metadados sobrevivem a duplicar, fechar janela, salvar/reabrir e exportar sem depender do UI Manager. |
| **Aceitação** | Em 0%, 50%, 100% verificar comprimento e arrowhead; zoom de Camera não gera drift; Save/Reopen/Deliver. Verificar curvas no Spline, Undo, execução com seek aleatório e render. |

### 4.9. `MO-RTE-02` — Route / Erase Path

| Campo do contrato | Definição proposta |
|---|---|
| **Onde** | Fusion Inspector → objeto `Route` → `Motion` → `Erase Path` |
| **Estado** | `BASELINE-PROPOSED` — não aprovado automaticamente |
| **Pré-condições** | Rota existente, progresso animável. |
| **Canais Control afetados** | Draw Progress |
| **Inputs/defaults** | Start=playhead; Delay=0 f; Duration=30 f; Progress 100→0%; Easing=Ease In/Out. |
| **Comportamento temporal e visual** | Traçado desaparece progressivamente da ponta para a origem; a geometria permanece para reanimação. |
| **Apply/Update** | `Apply` gera somente keys dos canais especificados. `Update` segue estados §4.2 e preserva edições manuais. |
| **Conflict/Remove** | No canal Progress com Draw anterior, exigir `CONFLICT`; não somar valores de dois presets. Remover por `Keep animation as manual` (default) ou excluir só keys gerados com confirmação; mantém objeto. |
| **Persistência** | Curva e metadados sobrevivem a duplicar, fechar janela, salvar/reabrir e exportar sem depender do UI Manager. |
| **Aceitação** | Amostras 100%/50%/0% e teste com arrowhead ligado em transição reversa. Verificar curvas no Spline, Undo, execução com seek aleatório e render. |

### 4.10. `MO-MRK-01` — Marker / Fade In

| Campo do contrato | Definição proposta |
|---|---|
| **Onde** | Fusion Inspector → objeto `Marker` → `Motion` → `Fade In` |
| **Estado** | `BASELINE-PROPOSED` — não aprovado automaticamente |
| **Pré-condições** | Marker com geoanchor válido, opacidade-alvo >0%. |
| **Canais Control afetados** | Object Opacity |
| **Inputs/defaults** | Start=playhead; Delay=0 f; Duration=18 f; Target=valor atual; Easing=Ease In/Out. |
| **Comportamento temporal e visual** | 0→target, tamanho e posição geográfica constantes. |
| **Apply/Update** | `Apply` gera somente keys dos canais especificados. `Update` segue estados §4.2 e preserva edições manuais. |
| **Conflict/Remove** | Não altera color ou stroke; conflito em canal Opacity exige decisão. Remover por `Keep animation as manual` (default) ou excluir só keys gerados com confirmação; mantém objeto. |
| **Persistência** | Curva e metadados sobrevivem a duplicar, fechar janela, salvar/reabrir e exportar sem depender do UI Manager. |
| **Aceitação** | Verificar alpha no output, mesmo pixel de âncora em zoom de câmera e opacidade final. Verificar curvas no Spline, Undo, execução com seek aleatório e render. |

### 4.11. `MO-MRK-02` — Marker / Pop In

| Campo do contrato | Definição proposta |
|---|---|
| **Onde** | Fusion Inspector → objeto `Marker` → `Motion` → `Pop In` |
| **Estado** | `BASELINE-PROPOSED` — não aprovado automaticamente |
| **Pré-condições** | Marker com Size alvo >0 px. |
| **Canais Control afetados** | Size |
| **Inputs/defaults** | Start=playhead; Delay=0 f; Duration=18 f; Start Size=0%; Peak=115% aos 70% da duração; Final=100% de Size alvo; Easing=Bezier. |
| **Comportamento temporal e visual** | Marker cresce a partir do geoanchor, ultrapassa tamanho final e se acomoda; não altera coord. geográfica ou cor. |
| **Apply/Update** | `Apply` gera somente keys dos canais especificados. `Update` segue estados §4.2 e preserva edições manuais. |
| **Conflict/Remove** | Size com keys existentes exige conflito; se Output dimension muda, tamanho continua em px de saída. Remover por `Keep animation as manual` (default) ou excluir só keys gerados com confirmação; mantém objeto. |
| **Persistência** | Curva e metadados sobrevivem a duplicar, fechar janela, salvar/reabrir e exportar sem depender do UI Manager. |
| **Aceitação** | Amostras 0%/70%/100%; centro do marcador não desloca durante Pop; salvar/reabrir. Verificar curvas no Spline, Undo, execução com seek aleatório e render. |

### 4.12. `MO-CAM-01` — Camera / Fly To Location

| Campo do contrato | Definição proposta |
|---|---|
| **Onde** | Fusion Inspector → objeto `Camera` → `Motion` → `Fly To Location` |
| **Estado** | `BASELINE-PROPOSED` — não aprovado automaticamente |
| **Pré-condições** | Camera única, target de localidade selecionado em Scene (Point/Polygon) e pose de início válida. |
| **Canais Control afetados** | Center Longitude, Center Latitude, Zoom; Bearing somente se opt-in |
| **Inputs/defaults** | Start=playhead; Delay=0 f; Duration=45 f; Target Location=required; Fit Padding=Camera setting 8%; Ending Zoom=Fit Target ou Custom; Easing=Ease In/Out. |
| **Comportamento temporal e visual** | Em start usa pose efetiva; em end usa target pos e zoom escolhido; em todos frames os objetos seguem a transformação comum; caminho de centro evita salto ao cruzar 180°. |
| **Apply/Update** | `Apply` gera somente keys dos canais especificados. `Update` segue estados §4.2 e preserva edições manuais. |
| **Conflict/Remove** | Se canais de Camera possuem keys, solicitar resolução; `Focus` estático não é este preset. Mudança de projeção invalida fit e exige refazer alvo com aviso. Remover por `Keep animation as manual` (default) ou excluir só keys gerados com confirmação; mantém objeto. |
| **Persistência** | Curva e metadados sobrevivem a duplicar, fechar janela, salvar/reabrir e exportar sem depender do UI Manager. |
| **Aceitação** | São Paulo City: confirmar centralização e duração; testar antimeridiano, Save/Reopen/Deliver; Region/Route/Marker sem drift. Verificar curvas no Spline, Undo, execução com seek aleatório e render. |

### 4.13. `MO-CAM-02` — Camera / Zoom To

| Campo do contrato | Definição proposta |
|---|---|
| **Onde** | Fusion Inspector → objeto `Camera` → `Motion` → `Zoom To` |
| **Estado** | `BASELINE-PROPOSED` — não aprovado automaticamente |
| **Pré-condições** | Camera válida, Zoom final especificado. |
| **Canais Control afetados** | Zoom |
| **Inputs/defaults** | Start=playhead; Delay=0 f; Duration=30 f; From=Zoom atual; Target Zoom=required numeric dentro dos limites; Easing=Ease In/Out. |
| **Comportamento temporal e visual** | Aumenta/reduz zoom preservando centro e bearing; objetos georreferenciados movem-se no Viewer pelo zoom comum. |
| **Apply/Update** | `Apply` gera somente keys dos canais especificados. `Update` segue estados §4.2 e preserva edições manuais. |
| **Conflict/Remove** | Não modificar Center ao aplicar; conflito só se Zoom já animado. Remover por `Keep animation as manual` (default) ou excluir só keys gerados com confirmação; mantém objeto. |
| **Persistência** | Curva e metadados sobrevivem a duplicar, fechar janela, salvar/reabrir e exportar sem depender do UI Manager. |
| **Aceitação** | Validar Centro e Bearing iguais no início/fim; Zoom alvo exato no frame final. Verificar curvas no Spline, Undo, execução com seek aleatório e render. |

### 4.14. `MO-LBL-01` — Label / Fade In

| Campo do contrato | Definição proposta |
|---|---|
| **Onde** | Fusion Inspector → objeto `Label` → `Motion` → `Fade In` |
| **Estado** | `BASELINE-PROPOSED` — não aprovado automaticamente |
| **Pré-condições** | Label com texto válido e anchor válido. |
| **Canais Control afetados** | Object Opacity |
| **Inputs/defaults** | Start=playhead; Delay=0 f; Duration=18 f; Target=valor atual; Easing=Ease In/Out. |
| **Comportamento temporal e visual** | Texto+halo fade juntos, permanecendo geoancorados; não altera fonte/offset. |
| **Apply/Update** | `Apply` gera somente keys dos canais especificados. `Update` segue estados §4.2 e preserva edições manuais. |
| **Conflict/Remove** | No canal Opacity com keys anteriores, exigir decisão; sem texto válido, Apply indisponível. Remover por `Keep animation as manual` (default) ou excluir só keys gerados com confirmação; mantém objeto. |
| **Persistência** | Curva e metadados sobrevivem a duplicar, fechar janela, salvar/reabrir e exportar sem depender do UI Manager. |
| **Aceitação** | Renderizar "São Paulo" e "Amapá" e verificar acento/fallback, opacidade e deslocamento na câmera. Verificar curvas no Spline, Undo, execução com seek aleatório e render. |

### 4.15. `MO-REG-05` — Region / Border Draw

| Campo | Contrato de produto fechado (baseline proposto) |
|---|---|
| Acesso | Region → Inspector → Motion → `Border Draw` |
| Pré-condições | Region com Polygon/MultiPolygon válido e `Stroke Visible = On`; se não, Apply desabilitado e explicação. |
| Inputs | `Start Frame = playhead`, `Delay = 0 f`, `Duration = 36 f` (1–frames disponíveis), `From = 0%`, `To = 100%`, `Direction = Forward/Reverse`, `Contour Scope = All Rings`, `Ease = Ease In/Out`, `Keep Final = On`. |
| Control | Anima **exclusivamente** `Stroke Progress` (CT-REG-15); `Stroke Color`, `Width`, `Fill` e `Opacity` não são modificados. |
| Geometria | Progresso calculado sobre comprimento cumulativo dos contornos no sistema de desenho da cena; ordenação estável dos anéis por ID geográfico, tipo de anel e índice da fonte; ilhas e vazios preservados. `Outer Rings` exclui anéis internos somente da animação do traçado, não altera o polígono. |
| Antes / durante / depois | Antes do início: 0%; em `u=0.5` com Linear: metade do comprimento definido; ao final: 100%, mantido. Em Reverse, comprimento é percorrido da extremidade oposta; não se invertem os pontos geográficos da Region. |
| Edição posterior | Mudar contorno/fonte geográfica recalcula o desenho, preserva keys em Stroke Progress e sinaliza mudança de extensão; alterar largura não mexe em temporalidade. |
| Conflito e remoção | Outros keys em Stroke Progress geram Conflict; remoção permite manter curvas manuais ou apagar apenas keys geradas; Undo devolve exatamente o estado anterior. |
| Aceite | País com ilha + estado com buraco; frames inicial/meio/final e seek 73→12→50; nenhum anel indevidamente desaparece; Spline, Save/Reopen e MediaOut coerentes. |

### 4.16. `MO-REG-06` — Region / Highlight Pulse

| Campo | Contrato de produto fechado (baseline proposto) |
|---|---|
| Acesso | Region → Motion → `Highlight Pulse` |
| Pré-condições | Region válida, visível, não bloqueada; pode ter Fill Color ou Object Opacity já animados. |
| Inputs | `Start Frame = playhead`, `Delay = 0 f`, `Pulse Count = 2` (1–8), `Cycle = 18 f` (2–120), `Peak Strength = 35%` (0–100), `Highlight Color = #E6C66B`, `Highlight Mode = Fill Tint`, `Ease = Smooth`; duração = Count × Cycle. |
| Control | CT-REG-16 `Highlight Strength` (anima); CT-REG-17 `Highlight Color` e CT-REG-18 `Highlight Mode` (configurados quando explicitamente escolhidos). **Não** sobrescreve Fill Color, Stroke Color ou Object Opacity. |
| Tempo | Cada pulso gera valores 0 → Peak → 0 nos frames início, meio e fim de seu ciclo, sem incremento cumulativo. O último key retorna a 0; nenhum destaque residual após o último ciclo. |
| Composição | A camada de ênfase é adicionada em composição controlada sobre o resultado autoral, respeitando alpha efetivo. `Fill Tint` colore apenas os pixels cobertos pelo Fill; `Stroke Tint` apenas a borda. |
| Conflitos | Curva existente em Highlight Strength gera Conflict; outras curvas de cor/opacidade permanecem independentes. Extensão que passa do fim da composição impede Apply. |
| Aceite | Brazil destacado sem mudar Rio State; duas oscilações com Strength=0 ao final; mudar cor-base no Spline não destrói Highlight; após Remove/Undo e Save/Reopen não há mudanças em outras propriedades. |

### 4.17. `MO-CAM-03` — Camera / Fit Transition

| Campo | Contrato de produto fechado (baseline proposto) |
|---|---|
| Acesso | Camera → Motion → `Fit Transition` |
| Pré-condições | Um ou mais objetos geográficos selecionados na Scene ou um resultado válido; câmera 2D ativa e alvo com extent. |
| Inputs | `Targets = seleção explícita`, `Start Frame = playhead`, `Delay = 0 f`, `Duration = 45 f`, `Padding = 10%` (0–30), `Target Bearing = Preserve` (alternativa Reset to 0°), `Easing = Ease In/Out`; `Use Visible Objects Only = On`. |
| Control | Cria keys em `Center Longitude`, `Center Latitude`, `Zoom`, e somente quando `Reset` for solicitado em `Bearing`. `Fit Padding` recebe valor da ficha somente para cálculo da pose, não é animado. |
| Geometria | Bounding box projetado inclui todas as partes dos alvos, respeita tamanho do frame, razão de aspecto, costura do antimeridiano e clipping. Ponto isolado usa Zoom de referência `4×`, explicado no Inspector. |
| Tempo | Pose inicial = valor efetivo da câmera no Start; pose final = resultado determinado dos alvos na resolução/aspect da composição; keys iniciam no Start, terminam Start+Duration. |
| Edição posterior | Alterar os objetos-alvo após Apply **não** recalcula pose/keyframes automaticamente; `Refresh Target Fit` mostra diferença e solicita atualização. A câmera jamais muda sozinha ao renomear um objeto. |
| Conflito e remoção | Mesmo canal que Fly To ou keyframes manuais exige Conflict; a opção que preserva é Cancel; sem apagar curvas não relacionadas. |
| Aceite | Fit conjunto Brasil + outro país; 16:9 e 9:16; no fim tudo visível com padding contratado; câmera e geoanchors estáveis em todas as amostras, inclusive after reopen. |

### 4.18. `MO-RTE-03` — Route / Follow Path

| Campo | Contrato de produto fechado (baseline proposto) |
|---|---|
| Acesso | Route → Motion → `Follow Path` |
| Pré-condições | Route com geometria válida e **Marker existente** selecionado como follower; ambos na mesma Scene, não bloqueados. |
| Inputs | `Follower Marker = required`, `Start Frame = playhead`, `Delay = 0 f`, `Duration = 60 f`, `From = 0%`, `To = 100%`, `Easing = Linear`, `Reverse = Off`, `Orient to Tangent = Off`, `Follow Route Visibility = Independent`. |
| Control | Follower Progress (CT-RTE-20), Follower Marker (CT-RTE-19), orientação (CT-RTE-21) e política de visibility (CT-RTE-22). As curvas temporais são do **Route**, não da âncora-base do Marker. |
| Geometria | Percentual representa comprimento acumulado da Route no espaço de geometria contratada, não fração entre endpoints ignorando waypoints. Durante o vínculo, a posição renderizada do follower vem da Route; sua `Anchor Location` autoral é preservada para restaurar ao desvincular. |
| Tempo | No início o Marker está no From, no fim no To; em seek aleatório deve retornar ao ponto correto. Alterar waypoints recalcula posição espacial mantendo curva de Progress. |
| Visibilidade | Não cria Marker automaticamente. Em `Independent`, Marker pode permanecer visível com Route oculta; `Follow Route` o oculta quando Route escondida, sem alterar Opacity. Não alterar Size/Color/Label do Marker. |
| Conflitos | Marker já ligado como follower a outra Route exibe `Marker already follows Route X`: `Reassign / Cancel`, padrão Cancel. Não permitir ciclos de referência nem follower que seja nó apagado. |
| Remoção | Remover vínculo restaura o Marker à sua âncora original, conservando style/curvas independentes; opção explícita para manter curvas manuais de Follower Progress. |
| Aceite | Rota com waypoint; amostras 0, 25, 50, 75 e 100%; mudança de zoom, mudança de endpoint e Undo não mudam Size/Color; reabertura preserva vínculo. |

### 4.19. `MO-MAP-01` — Base Map / Layer Fade

| Campo | Contrato de produto fechado (baseline proposto) |
|---|---|
| Acesso | Base Map → Motion → `Layer Fade` |
| Pré-condições | Display Mode `Full Map`; camada selecionada existente no pacote offline, habilitada e não bloqueada. Em `Transparent Overlay`, botão disabled com motivo, sem mudança implícita de modo. |
| Inputs | `Layer = Ocean/Land/Coastline/Country Borders/State Borders`, `Start Frame = playhead`, `Delay = 0 f`, `Duration = 18 f`, `From = 0%`, `To = 100%`, `Easing = Ease Out`. |
| Control | Um único canal de camada entre CT-MAP-16 a CT-MAP-20; nunca modifica Base Opacity global, Fill Colors ou Regions independentes. |
| Tempo | Opacidade inicial antes da key; 0→100 em tempo indicado (ou outra faixa explicitamente informada). Camada mantém valor final depois. `State Borders` só está disponível quando essa camada estiver ativa e tiver geometria no bundle. |
| Composição | Opacidades se multiplicam com Base Opacity; na camada Ocean 0%, fundo pode ficar transparente onde não houver Land ou outra feição, sem inventar preenchimento. |
| Conflitos | Só canal da camada selecionada provoca Conflict. Mudança de Display Mode para Overlay preserva curva, porém o efeito não aparece até retornar a Full Map; UI informa `Hidden by display mode`. |
| Aceite | Fade de fronteiras sem fade de oceano/terra/Regions; Overlap Alpha correto; Switch Full/Overlay/Full retorna ao frame correto, Save/Reopen e Spline disponíveis. |

### 4.20. Convenções rigorosas de tempo, easing e escopo de alteração

**Notação temporal canônica:** frames inteiros indexados a partir de `0`; para uma composição com `N` frames válidos, a janela é `[0,N-1]`. `Start` e `End = Start + Duration` são amostras de quadros; `Duration` expressa distância em frames entre as keys extremas e deve obedecer `End ≤ N-1`. Esta definição evita ambiguidades entre duração em segundos, contagem de frames e intervalo inclusivo. Um preset com duas keys em `Start=100` e `Duration=24` atinge o valor final no frame 124.

**Easing:** `Linear` é interpolação linear do valor efetivo; `Ease In/Out` usa curva Bézier monótona sem overshoot nos canais escalares salvo `Pop`, que exige pico expresso; `Ease Out` privilegia desaceleração; `Hold` preserva valor anterior até a key de troca. A UI não promete handles Bézier para enums/textos cuja interpolação não seja contínua. **Cor:** em `Color Transition`, conversão para espaço linear de trabalho do renderer com interpolação linear por componentes e retorno pelo gerenciamento de cor do host; não interpolar nomes de cores nem alternar a fonte geográfica. Alpha é avaliado separadamente conforme `Fill Alpha`.

**Estado anterior:** ao aplicar efeito num canal sem keys, o preset registra `pre-apply static value` para restaurar em Undo e para oferecer remoção segura. Ao aplicar com keys anteriores, nenhum estado é destruído sem escolha. Alterações manuais feitas por ferramentas de terceiros do Fusion devem provocar ao menos comparação de assinatura da curva no próximo refresh para exibir `Customized` — não dependa exclusivamente de um evento que talvez não seja emitido.

**Retiming:** duração normalizada em `u=(frame−start)/duration`; ao ajustar duração de curva personalizada, preservar valores, ordem e posições relativas das keys por transformação afim no tempo; se frames inteiros coincidirem, apresentar erro de colisão e permitir cancelar, não esmagar keys. Tangentes devem ser reescaladas temporalmente de maneira coerente. Se a transformação não puder preservar a semântica do Fusion, desabilitar ação e informar a limitação específica — não criar um segundo editor de curvas.

**Conflito entre presets de canais diferentes:** permitido; dois presets que afetam o mesmo canal em intervalos distintos exigem `Append after existing` apenas se a integração comprovar que cria keys sem alterar o trecho existente; a baseline usa `Replace affected channels / Cancel` como decisões explícitas. Remove nunca desfaz objeto, fonte, estilo ou canal não pertencente ao preset.

### 4.21. Política de combinação e expansão do catálogo

O release 1.0 permite **um preset ativo por canal compartilhado**. Presets em canais diferentes podem coexistir no mesmo objeto (ex.: Marker Fade em Object Opacity e Pop em Size); o resultado é a composição simultânea dos canais. Uma tentativa de aplicar dois presets de opacidade no mesmo marcador produz `CONFLICT`, não combinação oculta. É possível usar keyframes manuais em outros canais sem conflito. Um futuro sequenciador com múltiplos intervalos no mesmo canal exigirá contrato próprio e não entra implicitamente no baseline.

**Roadmap fora do baseline:** `Region Mask Reveal`, `Route Trail`, `Marker Pulse`, `Label Slide/Text Reveal`, `Stagger/Sequence`, `Scenario Switch`, `Network Build`, `Location Tour`. Nenhum nome do roadmap autoriza implementação, e nenhum deve aparecer como preset utilizável até ter contrato de campos e testes equivalentes aos acima.

## 5. Camera e Route — microinterações espaciais e temporais

### 5.1. Camera: semântica definitiva proposta

| Comando | Entrada | Alterações feitas | Alterações não feitas |
|---|---|---|---|
| `Focus Camera` | Point ou centro geométrico explícito | Center Longitude/Latitude no estado estático/atual | Não altera zoom, bearing, objetos, preset ou keyframes sem confirmação |
| `Fit to Region` | Polygon/MultiPolygon | Calcula centro e zoom com `Fit Padding` no aspect ratio do Viewer/MediaOut | Não cria animação, não modifica objeto/estilo |
| `Fit to Selection` | Conjunto de pontos/paths/polígonos | Enquadra limites de todos os objetos geográficos, ignorando invisíveis se opção selecionada | Não transforma objetos individualmente |
| `Zoom` | Número em `Zoom` de Control | Escala do mapa em torno do centro escolhido | Não altera latitude/longitude do objeto |
| `Fly To Location` | Pose inicial, localidade alvo, enquadramento, intervalo | Canais da Camera em keyframes de Motion | Não cria markers, labels, highlights ou trajetórias |
| `Save Pose` | Pose atual | Registra snapshot de propriedades de Camera para reutilização no Motion | Não ativa preset, não gera keyframe |

**Fit detalhado:** para polígono, calcular caixa projetada de todos os fragmentos relevantes, encaixar margem de 8% em ambos eixos; se houver antimeridiano, escolher intervalo longitudinal envolvente mínimo que preserve a geometria. Para cidade (Point), `Fit` sem extensão poligonal oferece `Focus + Zoom` de referência proposto `4×` e mostra `Point has no area bounds`. Um estado pode conter ilhas; Fit deve considerar todas. O cálculo de escala é da projeção vigente, não de pixels desatualizados.

**Animação espacial:** interpolar centro geográfico sem saltos ao atravessar ±180°; normalizar Longitude apenas na apresentação. Latitudes inválidas são rejeitadas com aviso. Bearing interpola pelo menor arco angular quando permitido. Alteração de resolução/aspect ratio recalcula limites do Fit **se a pose depender de Fit** e preserva geoanchors; nunca deforma caminho, fronteira ou ícone com escala não uniforme. Uma `Saved Pose` armazena pose e dependência de viewport; o usuário sabe quando aplicar mesma escala versus refazer Fit.

### 5.2. Route: criação em Scene

```text
+ Add → Route
FROM       [ Search location or use Custom point ]
TO         [ Search location or use Custom point ]
           [ If polygon: Select destination point ]
WAYPOINTS  [ + Add waypoint ]
PATH TYPE  [ Straight / Curved ]
STYLE      [ Optional arrowhead ]
[ Create Route ] [ Cancel ]
```

**Destino poligonal:** `Amapá — State` identifica uma área, não uma posição única. Após selecionar essa área, Scene oferece: `Choose a city within this state` ou `Enter coordinates`. Uma ação `Pick point on map` só aparece caso o Viewer permita captura validada de posição. Não usar Macapá, centróide ou capital como escolha invisível. Se o editor escolher `Macapá — City`, o endpoint passa a ser esse ponto explicitamente.

**Geoanchoring:** From/To/Waypoints mantêm lat/lon e referências de fonte; o renderer projeta geometria a cada frame pela Camera comum. `Straight` na 1.0 = linha entre endpoints no plano da projeção selecionada, com clipping e tratamento de dateline; `Curved` na 1.0 é Bézier simétrica com controles deslocados pela norma da corda projetada, conforme CT-RTE-05, mantendo seus endpoints geográficos; não designa menor caminho esférico, rota de trânsito ou trajetória de aeronave fisicamente correta. Essas opções recebem nomes distintos em eventual expansão (`Great-circle`, `Rhumb line`, `Road route`), após dados e especificação.

**Editar rota existente:** selecionar Route em Scene ou Node Editor → Inspector Control → editar endpoint, waypoint, path type ou style. O renderer atualiza a geometria espacial (inclusive Curved) em todos os frames; `Draw Progress` permanece curva temporal existente. A posição da arrowhead é recalculada pela geometria atual. Undo restaura endpoints, forma e keys sem afetar outros objetos. `Reverse Route` solicita confirmação se existirem keys Draw e indica se a inversão afetará o sentido visual; ela não inverte automaticamente curvas temporais.

### 5.3. Edição de geometria no Viewer

A UX ideal é handles no Viewer. Entretanto, **o produto não exige que o editor utilize handles para completar um fluxo:** Scene oferece endpoints textuais e tabela ordenada de waypoints, enquanto Control oferece curvatura numérica em modo `Curved` no R1.0. Se o SDK permitir handle espacial, sua manipulação atualiza exatamente os mesmos campos; nenhuma implementação cria um segundo formato de geometria. A complexidade de POC de handles não deve bloquear Route básica.

### 5.4. Controle de direção e visibilidade

Se `Arrowhead Off`, `Draw Progress` controla somente linha. Se `Arrowhead On`, ponta aparece apenas quando há comprimento visível positivo, é orientada tangencialmente e acompanha progresso. Com `Draw Progress`=100% e `Trim Start`=0 / `Trim End`=100, a seta alcança o endpoint real. Quando rota cruza o antimeridiano, o renderer divide a representação na costura da projeção sem desenhar um traço atravessando toda a tela por engano.

## 6. Sistema visual, herança, camadas e alpha

### 6.1. Styles — aparência inicial proposta

A estética do produto **não** deve impor destaque geopolítico padrão. `Neutral Dark` é um preset inicial de trabalho e não uma paleta irrevogável. Valores estão em sRGB de UI; o renderer respeita o gerenciamento de cor do host na produção dos pixels.

| Token | Valor inicial proposto | Aplicação |
|---|---|---|
| `ocean.fill` | `#10283C` | Background oceânico de Full Map |
| `land.fill` | `#394C59` | Massa continental |
| `coast.stroke` | `#B5C1CC`, 1 px | Contorno de costa |
| `admin0.stroke` | `#96AAB9`, 1 px | Fronteiras internacionais |
| `admin1.stroke` | `#8295A4`, 0.6 px, Off | Estados/províncias |
| `region.fill` | `#8296A4` | Novo objeto Region; sem destaque vermelho/ouro |
| `region.stroke` | `#D7E0E7`, 1.5 px | Borda de objeto Region |
| `route.stroke` | `#D6DFE6`, 3 px | Trajeto novo; seta Off |
| `marker.fill` | `#E0E8ED`, 14 px | Localidade/âncora |
| `label.text` | `#F0F5F8`, 32 px | Texto autoral |

**Hierarquia:** Scene preset → default do tipo → override individual → valor animado no frame. `Reset Property` remove override de **um** token e solicita política apropriada se canal estiver animado. `Reset Object Style` exclui apenas overrides visuais daquele objeto e preserva geometria, geoanchor, ordem e presets em canais não afetados. Trocar preset da base não recolore uma Region cujo Fill tenha override. Cores de fronteiras são editáveis por propriedades que compartilham semântica (`Stroke Color/Width`) mesmo quando pertencem a objetos diferentes.

### 6.2. Sobreposição e ordem de desenho

A pilha é uma sequência global: Base Map sempre fundo; elementos de autor podem ser intercalados acima. Se Brazil e Rio State coexistirem, a cor de Rio só é visível se seu objeto estiver acima do preenchimento de Brazil e com alpha adequado; alterar ordem não muda IDs nem geometrias. Marcadores e labels não ficam presos a camadas fixas que impeçam reorder. Strokes são aplicados no objeto após seu fill, preservando ordem global. `Hide` não equivale a alpha 0: preserva curvas e não cria render opaco indesejado.

### 6.3. Modo de composição sobre vídeo

| Modo | Viewer/MediaOut | Objetos que continuam visíveis | Propriedades |
|---|---|---|---|
| `Full Map` | Fundo de mapa e camadas com alpha próprio; oceano normalmente opaco | Base + autorais visíveis | Ocean/Land/Borders + objetos; alpha permitido |
| `Transparent Overlay` | Pixels não cobertos por objetos autorais têm **alpha 0** | Region/Route/Marker/Label visíveis e Camera operante | Base oculta como background; nenhuma imagem de oceano/terra opaca por acidente |

**Alternância:** a opção Display Mode não deleta camadas nem altera suas cores; alternar de volta restaura visual. O editor pode construir um mapa full-screen ou colocar elementos cartográficos sobre um vídeo usando Merge normal do Fusion. O plugin deve fornecer saída RGBA com tratamento coerente de premultiplicação/despremultiplicação, sem halo em bordas anti-alias ou perda de alpha na exportação. `Transparent Overlay` é um modo de exibição da base, não um segundo renderer independente. A câmera continua afetando todos os objetos geoancorados.

**Acessibilidade:** feedback não depende só de cor; linhas, títulos e seleção têm rótulos legíveis; estados `Locked/Hidden/Animated/Customized` usam ícones e texto. Fonte `Sans` fallback não garante presença de uma família específica; o usuário deve poder selecionar fonte instalada, e o projeto informa fallback após reabrir em outro computador.

## 7. Persistência, dados offline e arquitetura não prescritiva

### 7.1. Contrato de cena

Toda composição CartoRig mantém identificador de cena persistente, esquema/versionamento, dados de câmera, base map, objetos autorais, estilos, ordem, source provenance, animações e vínculos aos controles Fusion. O próprio projeto/composição deve reconstituir render e controle independentemente da janela Scene. IDs de objeto são estáveis; o nome visível é mutável e **não** serve como chave de ligação. Duplicação deve criar identidade de cena/objeto coerente sem cross-edit.

**Exemplo semântico, não formato obrigatório de armazenamento:**

```json
{
  "schema": "cartorig.scene/1",
  "sceneId": "stable-id",
  "dataBundle": {"source": "Natural Earth", "version": "pinned"},
  "objects": [
    {"id":"id-01", "kind":"Region", "name":"Brazil", "featureRef":"natural-earth-admin0-id", "drawOrder": 10}
  ],
  "cameraRef": "camera-id",
  "animationRefs": ["fusion-channel-links"]
}
```

Esses identificadores são ilustrativos. A engenharia escolhe formato e persistência, mas deverá demonstrar migrations, detecção de corrupção, estado recuperável e renderização estável ao reabrir. Os canais Fusion são a fonte da avaliação temporal; Scene não mantém curva alternativa divergente.

### 7.2. Política de dados

O instalador deve incluir ou instalar de maneira automática **sem rede** os dados Natural Earth necessários ao escopo aprovado. O editor não vê ZIP, SHP, CMake, downloads manuais, tabelas ou índices técnicos. Um único catálogo offline é consultável por nomes e aliases, preservando `Country`, `State–Province`, `City` como tipos distintos. Formato e localização interna dos arquivos são escolhas de engenharia. Uma cena guarda referência a versão e identificador estável de feature; atualizações de dados não silenciam diferenças de fronteiras ou pontos.

**Limites da fonte:** 10m Admin-0 contém polígonos de países; Admin-1 contém diversas subdivisões nacionais, mas a disponibilidade real deve ser inventariada no pacote; Populated Places contém pontos de cidades, não limites municipais globais; Admin-2 do Natural Earth é restrito aos EUA. `Urban Areas` não é sinônimo jurídico de município. Fronteiras disputadas e variantes POV exigem fonte/política identificada; não há inferência silenciosa de posição política. Datas históricas de fronteiras não são cobertas genericamente.

### 7.3. Portabilidade e atualizações

- `Save → Close → Reopen` reconstrói objetos, ordem, estilos, curvas, projeção e resolução de referência.
- Projeto com dataset ausente mostra nome da fonte e versão requerida, oferece localizar pacote/instalar dados, e mantém objetos não afetados; nunca substitui fronteira por outra sem consentimento.
- Projeto de versão anterior deve abrir em modo compatível ou oferecer cópia migrada com relatório. A atualização não pode modificar silenciosamente o original.
- Ao exportar com Scene fechada, resolução ou FPS diferente, a avaliação temporal continua correta e geometrias permanecem estáveis na projeção utilizada.
- Operações de persistência não dependem de caminho absoluto do computador de origem quando os dados vêm do pacote instalado.

### 7.4. Domínios de engenharia — não tecnologia imposta

1. **Scene interface:** UI Manager + controle de eventos e contexto de composição.
2. **Scene model:** objetos autorais, IDs, fonte e relações persistentes.
3. **Geo data engine:** busca offline, geometria, projeções, clipping, antimeridiano e fonte.
4. **Fusion host adapter:** criar e relacionar ferramentas/control pages, inputs animáveis, Spline/Undo, salvar/reabrir.
5. **Render engine:** renderizar polígonos, linhas, labels, marcadores e alpha com determinismo e desempenho.
6. **Motion adapter:** aplicar presets e manter ligação declarativa a canais Fusion com estados de personalização.

As APIs de FusionScript, Fuse SDK e curvas BezierSpline oferecem caminhos documentados para essas integrações; **não** representam imposição de criar tudo com Fuse ou Lua. O engenheiro pode utilizar internamente grupos, Fuses, bibliotecas nativas/compiladas ou processamento compartilhado, desde que não exponha dependências desnecessárias nem degrade Control/Motion/seleção. A decisão final deve ser acompanhada de evidência em Resolve 20.

### 7.5. Representação em nós, nomenclatura e grafo legível

O editor reconhece um objeto no Scene e consegue localizar a sua representação autoral no Node Editor sem explorar detalhes internos de renderização. A nomeação visível proposta é `CR_<Kind>_<Slug>_<Index>`, como `CR_Region_Brazil_001`, `CR_Route_Brasilia_Amapa_001`, `CR_Marker_SaoPaulo_001` e `CR_Camera_Main`. O índice distingue duas instâncias; não é ID de banco de dados. O ID persistente é independente e armazenado separadamente. Renomear qualquer ferramenta não pode perder vínculo.

A engenharia pode manter geometria e rasterização em ferramentas auxiliares, grupo gerenciado ou biblioteca compartilhada: **controle por objeto e fluxo legível são o requisito, não um nó para cada feição geográfica da fonte**. Preservar nós Fusion criados pelo usuário que estejam fora do domínio CartoRig e permitir que ele componha acima/abaixo da saída autoral sem que Scene destrua esse trabalho.

### 7.6. Protótipos de interface que acompanham a revisão

A equipe de Product Design deverá entregar, para aprovação visual antes da implementação definitiva, protótipos dos estados de Scene `NO_COMP`, `SCENE_EMPTY`, `SCENE_READY`, `WRONG_CONTEXT`, `SCENE_BROKEN`; de cada página Control para os tipos de objeto propostos; das fichas Motion de `Fade In`, `Instant Color Change`, `Draw Path`, `Pop In` e `Fly To`; e dos estados `Customized`/`Conflict`. O wireframe textual §2.1 define posição e ordem informacional, mas não substitui uma verificação visual de tamanho, legibilidade, foco, scroll, nested tabs e DPI.

**O protótipo não precisa ser feito em software específico.** Deve permitir julgar ações primárias/secundárias, estados enabled/disabled/busy/error, seleção, feedback de keyframe e identificação da ferramenta ativa. Um protótipo visual não é prova de integração no host.

## 8. Contrato de entrega técnica para implementação nova

### 8.1. Critérios eliminatórios

1. O editor final realiza o fluxo de criação → busca → Add → Control → Motion no Fusion sem abrir terminal ou editar fontes.
2. Scene apresenta contexto de composição correto e impede mutações em composição errada.
3. Control permite manipulação individual de cada objeto e leitura no frame atual.
4. Motion gera e preserva curvas acessíveis ao Spline/Keyframes e não destrói ajustes manuais sem consentimento.
5. Region, Marker, Route e Label permanecem georreferenciados em **todos os frames** de pan/zoom/fly-to, não apenas nos extremos.
6. Todas as funções anunciadas na 1.0 operam offline e dados faltantes geram erros claros.
7. Output tem RGB e alpha corretos em Full Map e Transparent Overlay.
8. O render não exige UI Manager aberto e a composição sobrevive a Save/Reopen/Deliver.
9. Não elimina, reordena ou altera nós fora da jurisdição do CartoRig.
10. O pacote tem fonte licenciada para redistribuição e binários/instalador funcionais, não só um repositório.

### 8.2. Provas de integração de host (não reinvestigação do conceito)

| ID | Evidência exigida para release | Resultado esperado |
|---|---|---|
| `HOST-01` | Vídeo/capturas da janela Scene sobre Fusion 20 | Busca, árvore, Add e seleção sem UI travada |
| `HOST-02` | Inspector real de cada tipo | Páginas Control/Motion e propriedades contextuais corretas |
| `HOST-03` | Captura de Spline após Apply | Keyframes e tangentes editáveis alteram pixels renderizados |
| `HOST-04` | Teste Customize → Update/Remove → Undo | Curvas manuais não sobrescritas sem confirmação |
| `HOST-05` | Teste A/B de composição selecionada | Nunca editar objeto de composição anterior |
| `HOST-06` | Teste Region/Route/Marker/Label durante Fly To | Nenhum drift ou salto, inclusive antimeridiano suportado |
| `HOST-07` | Alpha renderizado sobre footage com bordas anti-alias | Sem halo, alpha 0 fora de objetos em overlay |
| `HOST-08` | Save → Close → Reopen → Deliver com UI fechada | Estado funcional e pixels equivalentes |
| `HOST-09` | Rede bloqueada | Criar, pesquisar, animar e renderizar sem internet |
| `HOST-10` | Desinstalar/reinstalar/migrar dados | Diagnóstico e recuperação sem perda silenciosa |

### 8.3. Definição operacional de pronto (DoD)

- **Funcional:** todos os testes obrigatórios do release aprovado passam e cada controle visível executa sua ação declarada; nenhum botão decorativo ou inerte.
- **Visual:** layout 1080p/1440p/4K, DPI 100/125/150%, zoom, Unicode, stroke, alpha e camadas validados com capturas de referência.
- **Temporal:** keys, Step, Bézier, seeks fora de ordem, clipes retimed, mudança de FPS e export produzem resultados previstos.
- **Persistência:** sem nós órfãos, curvas corrompidas, troca de contexto ou dependência da janela Scene.
- **Confiabilidade:** tratamento de entrada inválida, dataset incompleto, cancelamento e Undo; sem crash reproduzível nos fluxos de aceite.
- **Distribuição:** build versionada, changelog, licença selecionada, código, instalador funcional e documentação de instalação/atualização/desinstalação.

### 8.4. Não funcionais mensuráveis

A equipe fará benchmark de `Scene Open`, `Search`, `Select`, `Style update`, `Camera scrub`, `Render frame` e `Peak RAM` com três perfis: (A) 1 Region; (B) 10 Regions + 5 Markers + 3 Routes; (C) 50 Regions + 50 Markers + 20 Routes + 20 Labels, em 1920×1080, 2560×1440 e 3840×2160. Reportar mediana, p95, erros e hardware. **Não inventar metas numéricas a partir de testes realizados em outros ambientes.** O orçamento de desempenho para release será aprovado após benchmark; responsividade degradada deve mostrar `Working` e permitir Cancel, não congelar janela.

Acessibilidade: navegação teclado/foco legível, ícones com tooltip, contraste suficiente, estado de erro textual, layouts redimensionáveis. Compatibilidade com versão Windows/Resolve distribuída explicitamente; não afirmar suporte universal a macOS/Linux sem testes.

## 9. Fluxos E2E — testes de aceitação obrigatórios propostos

Todos os fluxos executam em uma composição **Fusion** dentro de Resolve Studio 20. Executar ao menos em 1440p, com verificação de render a 4K nos fluxos de alpha/geoanchor. Antes dos testes, instalar pacote offline verificado e desabilitar rede quando explicitado. Cada teste possui evidência: captura Scene, Inspector, Spline (quando usado), Viewer, log e amostras de MediaOut; em casos de reabertura, checksum ou comparação visual de pixels relevantes.

### 9.1. Definições de rastreabilidade

- **F** = aceite funcional; **V** = visual; **T** = temporal; **P** = persistência; **E** = tratamento de erro.
- **PASS** exige todas as dimensões indicadas por cenário. CI em mocks não substitui teste do host real.
- IDs de requisitos e de presets apontam para as definições integralmente presentes neste documento.

### 9.2. Cenários com entradas e resultados

| ID | Pré-condição e ações | Resultado observável | Aceite | Requisitos |
|---|---|---|---|---|
| `QA-01` | Abrir Fusion Composition sem CartoRig; abrir Scene; Initialize | Base Map + Camera neutros, sem país/rota/keyframes de exemplo | F,V,P | OBJ-MAP, OBJ-CAM, §2.2 |
| `QA-02` | Buscar `Brasil`, `Brazil`, filtrar Country | Mesma feição Country identificada, ações Region/Focus/Fit adequadas | F,E | §2.3 |
| `QA-03` | Buscar `Rio de Janeiro` | Duas entradas distintas State/City; Add Region só no State | F,E | §2.3, CT-REG |
| `QA-04` | Add Brazil Region e Rio State Region; atribuir Fill distintos | Ambas editáveis; mudar Fill de Rio não muda Brazil | F,V,P | CT-REG, §6.1 |
| `QA-05` | Inverter ordem Brazil/Rio em Scene | Região superior cobre inferior conforme alpha; Undo restaura | F,V,P | §2.4, §6.2 |
| `QA-06` | Add São Paulo City Marker e Focus Camera | Marker no ponto; Focus altera centro, não ativa animação | F,V | CT-CAM, CT-MRK |
| `QA-07` | Aplicar Camera Fly To São Paulo; scrub 0, 25%, 50%, 75%, 100% | Marker, Region e Route acompanham camera sem drift | V,T,P | MO-CAM-01 |
| `QA-08` | Criar Route Brasília → Amapá State | UI exige definir ponto no estado; não usa capital/centroide sem escolha | F,E | §5.2 |
| `QA-09` | Route com Arrowhead On; Draw Path 0→100% em 30 f | Ponta acompanha progresso; sem ponta em 0%; 50% na metade | V,T | CT-RTE, MO-RTE-01 |
| `QA-10` | Com Draw Path aplicado, alterar endpoint/waypoints | Traçado e ponta se reposicionam; keys de progress não somem | F,T,P | §5.2, MO-RTE-01 |
| `QA-11` | Region Fade In, depois editar tangente no Spline | Motion mostra Customized; Viewer avalia curva alterada | F,T,P | MO-REG-01, §4.2 |
| `QA-12` | No estado Customized, alterar Duration | Retiming explícito/Cancel; sem substituir curva sem consentimento | F,T,E | §4.2 |
| `QA-13` | Aplicar Fade e Color Transition em mesma Region | Opacity e Fill coexistem; nenhuma curva sobrescrita | F,T | MO-REG-01, MO-REG-03 |
| `QA-14` | Aplicar Fade duas vezes no mesmo canal | Conflito exibido; Cancel mantém keys exatamente iguais | F,T,E | §4.2 |
| `QA-15` | Aplicar Instant Color Change em frame 330, comp 30fps | Vermelho até frame 329, verde a partir de 330; outros objetos inalterados | V,T,P | MO-REG-04 |
| `QA-16` | Animar Fill de duas Regions manualmente em tempos diferentes | Curvas independentes no Spline, sem preset obrigatório | F,T,P | §3.3, §4.2 |
| `QA-17` | Duplicar objeto animado; alterar cor e curva na cópia | Original inalterado; IDs e canais independentes | F,T,P | §2.4, §7.1 |
| `QA-18` | Trocar composição com Scene aberta e tentar alterar objeto anterior | Estado WRONG_CONTEXT; nenhuma modificação da composição anterior | F,E | §2.2, §2.5 |
| `QA-19` | Renomear nó CartoRig no Node Editor e voltar a Scene | Objeto mantém identidade/seleção; não cria duplicata | F,P | §2.5, §7.1 |
| `QA-20` | Ocultar/mostrar Region; Lock/Unlock; Undo | Hide preserva keys; Lock impede edição; Undo restaura | F,T,P | §2.4 |
| `QA-21` | Modo Full Map → Transparent Overlay sobre footage | Alpha zero fora dos objetos autorais; contornos sem halo | V,P | §6.3 |
| `QA-22` | Desconectar internet e buscar/animar/renderizar | Fluxos funcionam sem conta, token ou tile externo | F,E,P | §7.2 |
| `QA-23` | Buscar cidade sem polígono municipal | Marker/Focus permitidos; Add Region desabilitado e explica fonte | F,E | §2.3, §7.2 |
| `QA-24` | Adicionar Label `São Paulo`, aplicar Fade e animar câmera | Unicode preservado, label segue ponto e mantém tamanho em px | V,T,P | CT-LBL, MO-LBL-01 |
| `QA-25` | Salvar, fechar UI Manager, fechar Resolve, reabrir, renderizar | Mesmos objetos, valores, keyframes e resultados visuais | F,V,T,P | §7.1, §8 |
| `QA-26` | Excluir manualmente um nó CartoRig e abrir Scene | Diagnóstico `SCENE_BROKEN`, reparo/cancel seguro, sem editar nó alheio | F,E | §2.5, §2.6 |
| `QA-27` | Duplicar composição e modificar uma cópia | Identidades de cena isoladas; original sem alterações | F,P | §7.1 |
| `QA-28` | Atualizar bundle de dados para versão diferente | Informa versão/migração; não troca fronteira ou geoanchor silenciosamente | F,E,P | §7.3 |
| `QA-29` | Buscar cidade/estado homônimo e alterar filtro | Tipos e pais legíveis; nenhuma seleção silenciosa errada | F,E | §2.3 |
| `QA-30` | Zoom da câmera com rota em antimeridiano ou multipolígono com ilhas | Sem linha cruzando tela indevidamente, sem perda de ilhas | V,T | §5, §7.2 |

### 9.3. Roteiros de prova detalhados para casos críticos

**`QA-15` — alteração instantânea manual/automática de cor:** criar cena de 900 frames a 30fps; adicionar Brazil e uma segunda Region disponível. Definir Brazil Fill `#FF0000` e segunda `#8296A4`. Colocar playhead no frame 330; escolher `Instant Color Change`, Target `#00FF00` e Apply. Consultar frames 0, 329, 330, 331, 899. Brazil precisa manter `#FF0000` nos quadros anteriores e `#00FF00` nos posteriores; não haverá interpolação intermediária. Repetir pela animação manual do mesmo canal para verificar que Motion não é obrigatório. Capturar Spline, salvar/reabrir e exportar dois frames.

**`QA-11/12` — preset personalizado:** aplicar Fade In em Region no frame 100 com duração 24f, abrir Spline, alterar alças de Bézier; Scene/Inspector identifica `Customized`. Ajustar duração para 48f. A interface apresenta opção de retiming sem reconstrução; escolher Cancel e verificar snapshots exatos dos keys anteriores. Depois aplicar retiming e comparar curvas relativas e valores nos frames de início/metade/fim. Executar Undo e verificar restauração. Nenhuma curva será apagada sem intervenção explícita.

**`QA-08/09/10` — rota Brasília–Amapá:** adicionar cidade Brasília; buscar State Amapá; escolher coordenada dentro do estado pelo campo explicitamente rotulado `Custom point` (ou cidade escolhida pelo usuário). Criar rota Straight com Stroke 3px, Arrowhead On, Apply Draw Path por 30f. Conferir a ponta em 0/15/30f; alterar endpoint; verificar mesma curva Draw Progress e mudança espacial adequada. Mover câmera e conferir âncoras. Abrir projeto novamente e conferir MediaOut.

**`QA-18` — contexto:** criar cenas A e B em diferentes composições, em A adicionar Brazil Region, em B São Paulo Marker. Com Scene mostrando A, ativar composição B no host. Antes de editar, a seleção antiga deve ser invalidada; tentativa de mudar Fill de Brazil não deve afetar A nem B; após seleção explícita de B somente Marker de B recebe a ação permitida.

**`QA-21` — overlay:** colocar Fusion Composition sobre footage com high-contrast checkerboard; adicionar Region, Route, Marker, alternar `Transparent Overlay`, renderizar RGBA e verificar alpha 0 fora de objetos e ausência de halo nas bordas. Em `Full Map`, o oceano volta conforme Ocean Fill; não houve deleção ou alteração de atributos.

**`QA-25` — persistência:** abrir projeto de prova contendo ao menos 2 Regions, 1 Route animada, 2 Markers, 1 Label e Camera Fly To. Capturar 10 quadros não sequenciais antes do fechamento (incluindo antes/depois das keys). Fechar Scene e o Resolve, reabrir e renderizar os mesmos frames. Comparar IDs, propriedades, curvas e pixels dentro da tolerância de render especificada pela engenharia para a mesma versão/hardware. Divergência de propriedades ou mudança geográfica reprova o teste.

## 10. Responsabilidade da equipe, decisões e aprovação

### 10.1. O que a engenharia pode decidir

Estrutura real dos nós (incluindo macros, Fuses e processamento compartilhado), motor vetorial/raster, algoritmos de clipping, índices geográficos, armazenamento físico, otimizações, divisão em bibliotecas, ordem de compilação, integração técnica com Undo e persistência, arquitetura de testes, plataforma CI. Essas decisões não podem alterar o comportamento observável prescrito sem proposta de alteração de produto.

### 10.2. O que a engenharia NÃO pode decidir sozinha

Visibilidade e nome dos controles; semântica de Add/Focus/Fit/Fly To; defaults visuais; catálogo Motion do release; quais canais são alterados por cada preset; comportamento diante de keyframes manuais; erro apresentado quando local não existe; escolha implícita de endpoint; alpha; ordem/ocultação de camadas; inclusão de serviço online; remover funcionalidade para contornar host. A mudança precisa de decisão do proprietário.

### 10.3. Decisões fechadas como propostas de Product Design — pacote único de homologação

A equipe de produto já escolheu uma solução preferencial para cada decisão observável. A tabela contém opções de fallback para eventual mudança solicitada pelo proprietário, **não perguntas abertas para engenharia**. O aceite do documento não declara compatibilidade do host: aceitação técnica ocorre pelo QA.

| ID | Proposta preferencial | Alternativa principal | Impacto |
|---|---|---|---|
| `DEC-A01` | Release 1.0: Base Map, Region, Route, Marker, Camera, Label, Group | Adiar Label/Group | Escopo visível |
| `DEC-A02` | Motion inicial: 16 presets definidos em §4 | Conjunto reduzido: Region Fade/Color, Route Draw, Marker Fade, Camera Fly | Biblioteca inicial |
| `DEC-A03` | Default `Neutral Dark` conforme §6 | Neutro claro ou paleta curada | Aparência inicial |
| `DEC-A04` | Scene com busca global + filtro opcional | Dropdown geográfico obrigatório | Pesquisa cotidiana |
| `DEC-A05` | Camera `Focus` estático e `Fly To` deliberado | Comportamento condicionado ao Auto Key do host | Previsibilidade temporal |
| `DEC-A06` | State endpoint: cidade ou coordenada explicitamente escolhida | Pick on Viewer, se validado | Semântica da rota |
| `DEC-A07` | Full Map / Transparent Overlay como modos distintos | Uma base sempre com alpha configurável | Composição com footage |
| `DEC-A08` | Fades: playhead como Start, 24 frames baseline, presets de câmera 45 | Defaults em segundos | Experiência Motion |
| `DEC-A09` | Preset editado manualmente entra `Customized` | Desvincular imediatamente após edição | Política de edição |
| `DEC-A10` | Marcadores/rótulos e strokes em pixels de saída | Escala em unidades geográficas por objeto | Leitura no zoom |
| `DEC-A11` | Equirectangular 2D como projeção inicial | Mercator como baseline | Geometria visual |
| `DEC-A12` | Apache-2.0 como licença recomendada para código autoral novo, após auditoria de dependências | MIT quando houver impedimento jurídico identificado | Governança open source |

**Os itens da tabela são recomendações únicas e concluídas pela equipe de Design, aguardando homologação do proprietário.** Os comportamentos preferenciais estão especificados sem deixar escolhas de produto à engenharia. O proprietário homologa o conjunto ou solicita alterações objetivas; antes da homologação, engenharia pode prototipar, mas não anunciar o escopo como aprovado.

### 10.4. Entregáveis obrigatórios do produto final

1. **Software:** instalação/reinstalação/remoção e UI CartoRig no Fusion, com assets offline.
2. **Design:** wireframes aprovados de Scene, páginas Control/Motion por objeto e estados de erro.
3. **Código:** repositório público, código-fonte completo, licença selecionada, instruções reproduzíveis de build e dependências declaradas.
4. **Dados:** manifestos de versões, fontes, atribuições quando requeridas e registro de cobertura real Natural Earth.
5. **Testes:** unitários, integração em ambiente isolado e relatórios **separados** de testes manuais no Resolve 20, com imagens/frames de referência e logs.
6. **Distribuição:** package assinado se aplicável, release notes, suporte declarado e guia sem terminal para editor final.
7. **Documentação:** instalação, uso Scene/Control/Motion, objetos, propriedades, presets, edição Spline, dados e limitações reais.

### 10.5. Critério para encerrar o trabalho de Product Design

Antes de iniciar desenvolvimento de funcionalidades observáveis, a equipe deve obter aprovação do pacote de decisões que afeta o release. O trabalho de produto está fechado quando cada controle e preset autorizado possui comportamento, default, unidade, estados, conflitos e teste descritos; qualquer escolha técnica restante não altera UI/UX. Não há obrigação de aceitar uma arquitetura interna específica antes da engenharia apresentar sua proposta.

## 11. Matriz definitiva de visão, escopo e releases — decisão de Product Design

**Definição:** o CartoRig completo é uma plataforma de **autoria cartográfica 2D cinematográfica no Fusion**, e não apenas um efeito isolado. O lançamento inicial `R1.0` precisa permitir criar, editar, animar, revisar e exportar uma cena geográfica sem depender de produtos anteriores. `R1.1 Professional` amplia linguagens de motion multiobjeto; `R2 Data & Geography` expande dados e cartografia; `Research` não tem promessa comercial. **Estas são decisões fechadas da proposta de Product Design, aguardando apenas homologação do proprietário; não são escolhas a delegar ao programador.**

### 11.1. Quadro de autorização por release

| Feature ID | Área | Comportamento entregue | R1.0 | R1.1 | R2 | Critério principal |
|---|---|---|---|---|---|---|
| SC-001 | Scene | Inicializar e reconhecer composição Fusion | **Incluído** | — | — | QA-01 |
| SC-002 | Scene | Busca offline tipada e desambiguação | **Incluído** | — | — | QA-02/03/29 |
| SC-003 | Scene | CRUD, seleção, visibilidade, lock, reorder e Undo | **Incluído** | — | — | QA-05/17/20 |
| SC-004 | Scene | Grupos organizacionais, sem transformações | **Incluído** | — | — | QA-34 |
| SC-005 | Scene | Sincronização com composição e Node Editor | **Incluído** | — | — | QA-18/19 |
| GEO-001 | Data | Admin-0 / países 10m offline | **Incluído** | — | — | QA-02/04 |
| GEO-002 | Data | Admin-1 / estados e províncias disponíveis 10m | **Incluído** | — | — | QA-03/08 |
| GEO-003 | Data | Populated Places 10m como pontos de cidades | **Incluído** | — | — | QA-06/23 |
| GEO-004 | Data | Coastline, Land, Ocean e linhas de fronteira básicas | **Incluído** | — | — | QA-33 |
| GEO-005 | Data | Rios, lagos, estradas, ferrovias e aeroportos do Natural Earth | Não | — | **Incluído** | QA-R2-GEO |
| GEO-006 | Data | Raster de relevo/batimetria Natural Earth | Não | — | **Incluído** | QA-R2-RASTER |
| GEO-007 | Data | Importar geometrias autorais GeoJSON | Não | **Incluído** | — | QA-R11-GEOJSON |
| GEO-008 | Data | CSV e cartografia temática (choropleth) | Não | — | **Incluído** | QA-R2-DATA |
| CT-001 | Control | Base Map: estilo, fronteiras, camadas e alpha | **Incluído** | — | — | QA-21/33 |
| CT-002 | Control | Region: geometria e estilo individuais | **Incluído** | — | — | QA-04/05 |
| CT-003 | Control | Route: endpoints, waypoints, stroke, trim e arrowhead | **Incluído** | — | — | QA-08/09/10 |
| CT-004 | Control | Marker: âncora, símbolo e aparência | **Incluído** | — | — | QA-06/41 |
| CT-005 | Control | Camera: centro, zoom, bearing, focus e fit | **Incluído** | — | — | QA-07/36 |
| CT-006 | Control | Label: Unicode, fontes, halo, offset e opacity | **Incluído** | — | — | QA-24 |
| CT-007 | Control | Grupo: organização/lock/visibility | **Incluído** | — | — | QA-34 |
| MO-CORE | Motion | 16 presets individuais especificados em §§4 e 14 | **Incluído** | — | — | QA-09/11/35–44 |
| MO-MANUAL | Motion | Keyframes manuais em Control + Spline | **Incluído** | — | — | QA-15/16/37 |
| MO-CONFLICT | Motion | Customized, conflitos, retiming e remoção | **Incluído** | — | — | QA-11/12/14/38 |
| RC-001 | Motion | Multi-Marker Stagger (receita) | Não | **Incluído** | — | QA-R11-STAGGER |
| RC-002 | Motion | Location Tour (receita) | Não | **Incluído** | — | QA-R11-TOUR |
| RC-003 | Motion | Strategic Corridor / Network Build | Não | **Incluído** | — | QA-R11-NETWORK |
| RC-004 | Motion | Scenario Switch / Territorial Comparison | Não | **Incluído** | — | QA-R11-SCENARIO |
| VIS-001 | Visual | Neutral Dark e Full Map / Transparent Overlay | **Incluído** | — | — | QA-21 |
| VIS-002 | Visual | Presets de mapa alternativos Light / Terrain | Não | — | **Incluído** | QA-R2-STYLES |
| VIEW-001 | Fusion | Edição de propriedades no Inspector e Spline | **Incluído** | — | — | HOST-02/03 |
| VIEW-002 | Fusion | Route Straight/Curved, endpoints, waypoints, curvatura numérica; handles no Viewer opcionais | **Incluído** | — | — | QA-10/42 |
| VIEW-003 | Fusion | Handles diretos no Viewer se viáveis e aprovados | Não | **Recurso condicionado** | — | QA-R11-HANDLES |
| EXPORT-001 | Host | MediaOut/Deliver, reabertura e uso offline | **Incluído** | — | — | QA-22/25 |
| ADV-001 | Research | Globo 3D, terreno com extrusão, fronteira dinâmica por IA | Não | Não | Não | Pesquisa separada |

**Interpretação de “Incluído”:** compromisso funcional proposto, com UI real, testes e documentação; não implica que já esteja codificado ou aprovado pelo proprietário. Toda feature visível em R1.0 deve ter controle/ação verdadeiro; não usar botões `Coming soon` para funções de R1.1/R2.

### 11.2. Matriz fechada do catálogo Motion no lançamento

| Item | Tipo | Preset ou ação | Canais animados | Padrão de duração | Dependências | R1.0 |
|---|---|---|---|---|---|---|
| MO-REG-01 | Region | Fade In | Object Opacity | 24 f | Region | Sim |
| MO-REG-02 | Region | Fade Out | Object Opacity | 24 f | Region | Sim |
| MO-REG-03 | Region | Color Transition | Fill Color | 24 f | Region | Sim |
| MO-REG-04 | Region | Instant Color Change | Fill Color/Step | instantâneo | Region | Sim |
| MO-REG-05 | Region | Border Draw | Stroke Progress | 36 f | stroke/contorno | Sim |
| MO-REG-06 | Region | Highlight Pulse | Highlight Strength | 2 × 18 f | Region | Sim |
| MO-RTE-01 | Route | Draw Path | Draw Progress | 30 f | Route válida | Sim |
| MO-RTE-02 | Route | Erase Path | Draw Progress | 30 f | Route válida | Sim |
| MO-RTE-03 | Route | Follow Path | Follower Progress | 60 f | Route + Marker existente | Sim |
| MO-MRK-01 | Marker | Fade In | Object Opacity | 18 f | Marker | Sim |
| MO-MRK-02 | Marker | Pop In | Size | 18 f | Marker | Sim |
| MO-CAM-01 | Camera | Fly To Location | Center, Zoom, Bearing opt-in | 45 f | Camera + alvo | Sim |
| MO-CAM-02 | Camera | Zoom To | Zoom | 30 f | Camera | Sim |
| MO-CAM-03 | Camera | Fit Transition | Center, Zoom, Bearing opt-in | 45 f | seleção de alvos | Sim |
| MO-LBL-01 | Label | Fade In | Object Opacity | 18 f | Label | Sim |
| MO-MAP-01 | Base Map | Layer Fade | Layer Opacity | 18 f | camada ativa | Sim |

**Nenhum preset cria um objeto geográfico implicitamente.** `Follow Path` exige Marker já existente. `Fit Transition` exige alvo. `Highlight Pulse` utiliza um canal de ênfase independente. Todo novo canal introduzido por Motion também aparece em Control e Spline. As fichas normativas individuais estão em §4; todas as convenções temporais aplicam-se cumulativamente.

### 11.3. Critérios para concluir o R1.0

A entrega só pode ser anunciada como `CartoRig 1.0` quando: (a) todas as linhas “Incluído” forem implementadas e homologadas; (b) os 16 presets tiverem provas de ajuste no Spline; (c) todos os objetos forem reproduzíveis em MediaOut com Scene fechada; (d) os cenários QA vinculados estiverem aprovados; (e) exista instalador utilizável, repositório público, licença e bundle de dados com manifesto; (f) relatórios separem testes automatizados, testes de host e testes visuais. Uma implementação parcial deve receber número pré-1.0, não ser apresentada como 1.0 completa.

## 12. Scene — especificação interacional e contratos de estado completos

### 12.1. Início e descoberta

**Entrada obrigatória:** comando visível `CartoRig Scene` acessível no contexto Fusion. Na primeira abertura, se não houver composição, mostrar título `No Fusion composition selected`, explicação, `Create Fusion Composition` (se a operação for executável no host) e `Select existing composition` como alternativa; nunca criar projeto/timeline sem consentimento. Se houver composição não inicializada, mostrar `Initialize CartoRig Scene` e explicar que os nós existentes serão preservados. Se houver Scene válida, exibir árvore e último objeto selecionado **dessa cena**, nunca da cena anterior.

**Inicialização:** criar uma unidade CartoRig reconhecível com Base Map e Camera, sem foco geográfico editorial, sem animação default e sem qualquer referência geográfica de demonstração. A composição existente mantém nós de terceiros, seu MediaOut e suas conexões; CartoRig não reescreve cadeias de autoria externa automaticamente. Quando necessitar saída combinada, apresentar `Connect CartoRig Output` e explicitar conexão a ser criada, preservando conexões anteriores.

**A janela:** largura proposta 430 px (mínimo 360), altura 640 (mínimo 460); escalável em 100/125/150% DPI, teclado e mouse. Composta por cabeçalho de composição; busca e filtros; resultados; árvore de objetos; ações contextuais; barra de status. Desabilitar duplicação da janela: reinvocar traz a mesma janela à frente e sincroniza contexto. A janela nunca precisa permanecer aberta para playback, MediaOut, reabertura ou Deliver.

### 12.2. Estado por estado: tela, ação e invariante

| Estado | Cabeçalho e corpo | Primária | Secundária / recuperação | Invariante de segurança |
|---|---|---|---|---|
| NO_COMP | `No Fusion composition selected`; sem árvore | `Create/Select Composition` | `Help` | Não escrever em projeto/timeline |
| COMP_WITHOUT_CARTORIG | Nome comp; `CartoRig has not been initialized` | `Initialize` | `Cancel` | Preservar nós autorais |
| SCENE_EMPTY | Base Map/Camera; campo busca em foco | `Find location` | `+ Add` | Sem keyframes e sem mapas exemplo |
| SCENE_READY | Árvore, selecionado e status pronto | Ação contextual | `Refresh` | Operação sempre no objectId corrente |
| SCENE_DIRTY | Indicador `Unsynced changes` | `Refresh/Retry save state` | `View details` | Não mascarar falha persistência |
| WRONG_CONTEXT | `Active composition changed` | `Use active composition` | `Return to previous composition` | Nunca editar seleção antiga |
| SCENE_BROKEN | `Some CartoRig objects need repair` | `Inspect issues` | `Recover a copy` / `Cancel` | Não reparar destrutivamente sem escolha |
| LOCKED | Cadeado e motivo | `Unlock` | `Select another object` | Nunca criar keys em bloqueado |
| BUSY | barra de progresso por tarefa cancelável | `Cancel` | `View details` | Bloquear operação concorrente no mesmo alvo |
| HOST_ERROR | code + descrição legível | `Retry` | `Copy diagnostics` / `Cancel` | Sem sucesso falso e sem objetos órfãos |
| READ_ONLY | `Composition is read-only` | `Open editable copy` | `Cancel` | Nenhuma operação mutante |

### 12.3. Busca: contrato de microinterações

1. Digitar não altera imagem, geometria, keyframes nem seleção real de ferramenta. Aplicar normalização Unicode (`NFKD` para comparação, preservando exibição), caixa, acentos e aliases presentes; resultados são determinísticos pelo mesmo bundle.
2. `All`, `Continent`, `Country`, `State–Province`, `City` são filtros; `All` padrão. Continent é **agrupamento regional derivado da classificação disponível**, não promessa de polígono continental original; ação de área deve explicitar composição de países, exceções e provenance.
3. Cada linha tem nome, tipo, país/estado, disponibilidade (`Polygon`/`Point`/`Composite`) e ações aplicáveis. Exemplos obrigatórios: `Rio de Janeiro — State, Brazil` e `Rio de Janeiro — City, RJ, Brazil` como itens separados.
4. `Enter` sobre resultado abre ação `Add as Region`, `Add as Marker`, `Focus Camera`, `Use as Route Endpoint`, `Fit`, limitadas pelo tipo e contexto. `Enter` não executa Add silenciosamente.
5. `Esc` fecha menu/detalhe antes de limpar a pesquisa; clicar `Clear` limpa texto sem remover objetos. Busca sem resultado mostra `Location not found in bundled data. Try another spelling or category.`
6. Município/cidade sem polígono: `Add Region` disabled, tooltip `Only a point is available for this city; municipal boundaries are not in the installed dataset.`; permitir Marker/Focus se ponto disponível.
7. Resultados com mesmo nome exibem sempre hierarquia e país. Ações com seleção incerta são bloqueadas. Não oferecer auto-geocoding externo nem criar objetos substitutos por heurística.
8. Enquanto indexa (primeira abertura), mostrar `Loading offline locations` e progresso; permitir cancelar; ao falhar, exibir a família de dados indisponível e abrir Scene somente em modo seguro, sem resultados falsos.

### 12.4. Árvore de objetos, foco, ordenação e multisseleção

**Modelo de árvore:** linhas de Base Map e Camera persistentes, seguidas de objetos autorais organizáveis. `Regions`, `Routes`, `Markers`, `Labels`, `Groups` funcionam como filtros/categorias, mas a ordem de desenho é uma ordem **global** independente da posição visual de categorias. A UI deve oferecer uma vista `Draw Order` plana e ordenável para eliminar o conflito entre agrupamento e Z-order.

- Clique seleciona um objeto; Shift seleciona intervalo, Ctrl alterna itens. Ação em conjunto só aparece se todos os itens forem compatíveis; em Control, propriedades mistas exibem `Mixed`, nunca um valor arbitrário.
- `Rename` é uma única operação com foco no campo, `Enter` confirma, `Esc` descarta. Texto pode conter Unicode e não altera `featureId`.
- `Duplicate` copia propriedades e curvas em **IDs novos**. Se objeto tiver vínculo a outro objeto, exibir regra: duplicação isolada conserva referência a objeto existente **da mesma cena**; duplicação de conjunto remapeia referências internas entre cópias. Não criar vínculo entre cenas.
- `Delete` de objeto selecionado avisa sobre dependências (`Route uses this Marker` / `Follower references this Marker`). Padrão Cancel se houver dependência; `Remove link and delete` requer escolha. Base Map/Camera não têm Delete no menu.
- `Hide` preserva keys e estilo; `Lock` impede alterações feitas via UI CartoRig. Reordenação afeta pixels mas não lon/lat nem priorização do catálogo. Undo reverte a ação e mantém seleção coerente.
- Grupo R1.0 é pasta organizacional; não transfere automaticamente estilo, transform, motion, source ou geoanchor. `Hide Group` aplica visibilidade visual hierárquica mantendo flags individuais; `Ungroup` preserva todos os filhos e sua ordem global.
- Seleção de nó de terceiro no Node Editor deixa Scene em `Non-CartoRig selection`, com propriedades CartoRig desabilitadas até selecionar um CartoRig. `Reveal node` e árvore mostram sempre o mesmo objectId, mesmo após renomear nós.

### 12.5. Transação, erro e recuperação

Uma criação, duplicação, exclusão, aplicação de preset, alteração de endpoint e renomeação é observada como **uma transação lógica reversível**. Antes de executar, validar pré-condições; em falha, reverter as alterações CartoRig feitas na operação, manter os nós de terceiros e informar `No changes were applied`, ou apresentar o subconjunto efetivamente aplicado quando a reversão total for tecnicamente impossível. Nunca alegar atomicidade sem teste no host.

**Mensagens canônicas:** `Location is unavailable in the offline catalogue.`; `Select a specific point inside this region.`; `This object is locked.`; `Current composition changed. Confirm the active scene.`; `The preset affects an already animated property.`; `The project uses map data version X; installed version Y differs.`; `The object could not be restored. Make a copy before attempting repair.`. Todas as mensagens incluem ação recomendada ou opção de cancelamento, sem expor stacktrace por padrão.

### 12.6. Wireframes textuais para revisão de UI

**W-01 Empty:** cabeçalho com `Scene: <composition>`; canvas de busca; Base Map/Camera presentes; botão `Add` ativo; instrução curta `Search a location or add a route.`. **W-02 Search:** linha resultado com tipo e origem, menu contextual de ações. **W-03 Object:** árvore selecionada; rodapé `Reveal node`, `Duplicate`, `Delete`, `Fit` se aplicável; Inspector real do Fusion com Control/Motion. **W-04 Conflict:** diálogo modal pequeno `Affected property: Opacity`, `Existing keys: 100–124`, `New keys: 110–140`; `Cancel` (padrão) e `Replace affected keys`. **W-05 Wrong Context:** conteúdo bloqueado até reconhecer composição atual. **W-06 Broken:** lista de objetos afetados, `Recover a copy` e `Copy diagnostics`; não reparar automaticamente.

**Contrato de acessibilidade:** tab order lógico, tooltip por elemento, focos visíveis, seleção identificada por texto e ícone além da cor, rolagem sem perda do objeto em Inspector, mensagens compatíveis com DPI; nunca capturar atalhos quando foco do teclado estiver no Viewer/Node Editor.

## 13. Control — regras transversais e dicionário de apresentação

### 13.1. Princípio de granularidade

Cada objeto tem nome, identidade e ferramentas de nível profissional contextualizadas. `Control` não é uma lista genérica de sliders RGB; a mesma propriedade usa o mesmo controle entre objetos. As tabelas `CT-*` no §3 são normativas para R1.0; os campos adicionais introduzidos pelos cinco novos presets são igualmente normativos. Nenhum controle visível pode permanecer sem ação. `Control` pode organizar propriedades em Nests `Identity`, `Geometry`, `Style`, `Animation Channels`, `Advanced`, mas **não** introduz quarto painel principal fora de Scene/Control/Motion.

### 13.2. Semântica de cores, alpha, tamanho e herança

- `Fill Color`: componente RGB do preenchimento; alpha incorporado (quando o picker oferecer) é tratado como `Fill Alpha` e exibido sem inconsistência. `Stroke Color`: RGB da borda. `Stroke Alpha`: alpha apenas da linha. `Object Opacity`: multiplicador de alpha do objeto composto. `Base Opacity`: multiplicador apenas da base. `Layer Opacity`: multiplicador da respectiva camada.
- `Visibility`: booleano não destrutivo; quando Off, objeto não renderiza, mas propriedades e keys persistem. `Lock`: impede mudança via interface CartoRig, sem afetar render; ferramenta externa host pode não respeitar Lock — documentar a limitação sem alegar proteção absoluta do Fusion.
- `Blend Mode`: apenas `Normal` na primeira entrega. Não exibir `Multiply`, `Add`, `Screen` se a implementação não suportar pipeline correto de composição premultiplicada. O modo será expansão após teste de imagem.
- `Stroke Width`, `Marker Size`, `Label Font Size`, `Halo Width` e `Arrowhead Size` usam **pixels da saída da composição** por default, sem crescimento automático no Zoom. Geoanchor acompanha câmera, tamanho de tela mantém escala perceptível. `Offset X/Y` é aplicado após projetar geoanchor para tela e antes da composição final do objeto.
- Preset de mapa fornece valores de tipo; override individual prevalece; animação no frame prevalece sobre valor estático do override para canal animado. Trocar estilo não destrói o override. `Reset Property` é por campo; `Reset Object Style` apenas estilo (sem geografia); `Reset Base Style` apenas base.
- Nenhuma mudança em `Fill` de Brazil afeta Rio State salvo se ambos forem editados explicitamente em multisseleção. Ordens z determinam cobertura; `Fill Alpha = 0%` ainda pode deixar Stroke visível; `Object Opacity = 0%` torna ambos invisíveis.

### 13.3. Estados de Control e confirmação de keyframes

| Estado | Aparência | Edição no frame atual | Reset / risco |
|---|---|---|---|
| Inherited | ícone de herança + valor do estilo | Criar override somente neste objeto | Reset remove override |
| Overridden | indicador local | Edita apenas campo selecionado | Reset restaura herança |
| Animated Manual | marca keyframe e link Spline | Se frame tem key, altera key; se intermediário, `Add key / Cancel` | Reset pergunta sobre keys |
| Animated Preset | nome do preset e estado temporal | Editar key transforma em Customized | Update sem personalização pode retiming |
| Customized | indicador `Customized` | Mantém curvas autorais | Reset/Remove não apagará keys sem escolha |
| Mixed | valor `Mixed` | Alteração é operação em lote só em objetos compatíveis | Undo da operação inteira |
| Locked | controle desabilitado + motivo | Não permitido pela UI CartoRig | Unlock explícito |
| Unsupported | desabilitado com descrição de compatibilidade | Não permitido | Não simular propriedade animável |

### 13.4. Dicionário de edição espacial versus temporal

| Operação | Local do usuário | Espaço | Altera |
|---|---|---|---|
| Mover âncora Marker | Control → Anchor | Geográfico WGS84 | Ponto-base, não camera |
| Alterar endpoint Route | Scene → Route / Control → From/To | Geográfico WGS84 | Forma espacial, keys permanecem |
| Editar waypoint | Control → Waypoints ou Viewer quando disponível | Geográfico | Forma e cálculo de comprimento |
| Alterar Curvature | Control → Curvature | Plano da projeção | Geometria, não easing |
| Mudar Draw Progress | Control / Spline | Tempo Fusion | Fração visível no caminho |
| Mudar Follow Progress | Control / Spline | Tempo Fusion | Posição renderizada do follower |
| Alterar Zoom Camera | Control / Spline | Câmera | Transformação compartilhada |
| Aplicar Motion | Motion + Spline | Tempo Fusion | Apenas canais declarados |

### 13.5. Revisão da tipografia e das unidades

Todos os nomes de controle são **inglês**. Localidades preservam o idioma original e aliases. Unidades de tempo são frames na R1.0, com timecode do host como referência; a interface pode mostrar segundos calculados, sem criar sua própria timeline. Ângulos são graus; lat/lon WGS84 em graus decimais; opacity em %; tamanho de traço em px; progress em %. Cores com picker e valores hex opcionais. Validação textual impede NaN, infinito, hex inválido, coordenadas fora dos limites e combinações impossíveis; exibir mensagem específica e preservar valor anterior.

## 14. Motion Professional — receitas compostas e expansão da biblioteca

### 14.1. Quatro níveis de Motion e princípios de composição

**Nível A — canais:** propriedades individuais de Control (`Opacity`, `Fill Color`, `Draw Progress`, `Center`, `Zoom` etc.), animáveis sem preset. **Nível B — presets por objeto:** as 16 fichas R1.0 da seção 4. **Nível C — receitas multiobjeto:** sequências que aplicam presets B a vários objetos independentes, sem substituir as curvas nativas por render fechado. **Nível D — visualização data-driven:** animação alimentada por dados temporais externos verificáveis, somente no R2. Esta divisão vem de necessidades editoriais documentadas e não implica criar quatro painéis de interface.

**Ponto de entrada das receitas R1.1:** Scene → selecionar objetos compatíveis → `Create Motion Sequence`; cria um objeto lógico `Sequence` próprio, listável em `Motion Sequences` na árvore. Seu Inspector usa `Control` para nome, participantes e ordem e `Motion` para configurar receita. Não existe Timeline CartoRig: a sequência distribui keyframes reais em objetos participantes e mantém metadados de aplicação/edição para realizar operações seguras. O objeto Sequence não substitui os objetos da cena nem cria geometrias novas. Excluir a sequência oferece `Keep all animation as manual` (padrão) ou `Remove recipe-generated keys` com confirmação e verificação de personalizações.

**Comportamento transversal:** ao reordenar participantes, mostrar `Preview changes` e somente depois `Apply changes`; reescalar keyframes com preservação de curvas personalizadas quando possível; no conflito com uma curva manual escolher `Skip object`, `Cancel whole operation` ou `Replace explicitly selected channels`. `Cancel whole operation` é o padrão. Não modificar propriedades de participantes que não estão na lista.

### 14.2. `RC-001` — Multi-Marker Stagger (R1.1)

- **Intenção:** revelar diversas localidades uma por vez, preservando independência das curvas.
- **Pré-condições:** dois ou mais Markers existentes e selecionados; cada um com geoanchor válido.
- **Parâmetros:** `Selected Markers = lista ordenada`, `Child Preset = Fade In` (ou `Pop In`), `First Start = playhead`, `Interval = 6 f` (1–120), `Child Duration = 18 f` (1–120), `Order = Scene / Alphabetical / Custom`, `Overlap Allowed = On`, `Easing = inherited from child`.
- **Algoritmo de produto:** marcador i inicia em `start+i×interval`; cada marcador recebe curvas somente em `Object Opacity` (Fade) ou `Size` (Pop). Interromper por término da composição antes de escrever qualquer curva. Ordem `Custom` é lista explícita arrastável.
- **Atualização:** adicionar novo participante não recoloca keys dos anteriores automaticamente; novo `Rebuild timings` mostra mudanças e preserva curvas personalizadas, com opção Skip ou Cancel.
- **Aceitação:** 5 Markers, início 100f e intervalo 6f produzem inícios 100/106/112/118/124; cor/tamanho dos demais não muda; cada canal existe no Spline; remover receita com Keep Manual preserva resultado.

### 14.3. `RC-002` — Location Tour (R1.1)

- **Intenção:** passar sequencialmente por localidades sem gerar camadas editoriais ou redesenhar keyframes manualmente.
- **Pré-condições:** 2 ou mais Locations tipadas e resolvidas; Camera única; nenhuma localização sem coordenadas.
- **Parâmetros:** `Ordered Stops`, `Start = playhead`, `Transition Duration = 36f` (1–300), `Hold Duration = 45f` (0–900), `Padding = 10%` (0–30%), `Zoom Strategy = Fit region / Point zoom 4×`, `Bearing = Preserve`, `Easing = Ease In/Out`; a duração total calculada é visível antes de Apply.
- **Canais:** `Center Latitude`, `Center Longitude`, `Zoom` e somente Bearing se habilitado; não cria Region, Marker, Label ou Route implicitamente.
- **Operação:** paradas são snapshots geográficos com ID de fonte e pose resultante. `Update stop` recalcula a pose daquela parada; não recalcula todas as poses sem apresentar diff. Em uma pose intermediária, não saltar da antimeridiana ao outro lado do mundo.
- **Conflito:** Camera já animada no intervalo gera preview e Cancel padrão; em Customized, atualizar um stop exige escolher quais keys afetar.
- **Aceitação:** três países e duas cidades; centro/fit precisos nas paradas, curves editáveis, mudanças em uma parada não alteram outra; Save/Reopen/Render equivalentes.

### 14.4. `RC-003` — Strategic Corridor e Network Build (R1.1)

- **Intenção:** revelar uma rede de ligações como sequência, para narrativas de comércio, infraestrutura e logística.
- **Pré-condições:** uma ou mais Routes existentes com endpoints válidos; Markers/Labels opcionais **já existentes**; nenhum caminho inventado pela ferramenta.
- **Parâmetros:** `Ordered Routes = lista`, `Start = playhead`, `Draw Duration per Route = 30 f` (1–300), `Gap = 5 f` (0–120), `Overlap = 0%` (0–90), `Easing = Ease In/Out`, `Reveal Existing Endpoint Markers = Off`, `Camera Fit Before = Off` (quando On, target e duração explícitos).
- **Canais:** cada Route recebe seu próprio `Draw Progress`; Markers só recebem `Opacity/Size` se a opção de inclusão for habilitada e o usuário confirmar. Camera só recebe keys quando solicitada explicitamente.
- **Categorias:** a interface permite `Physical Route / Relationship / Proposed / Hypothetical`; essas classificações controlam rótulo de provenance e recomendação de estilo, mas não mudam a geometria automaticamente. Caminho de projeto de ferrovia não pode parecer rede comprovadamente construída sem o estado `Proposed`.
- **Aceitação:** três rotas recebem canais distintos; mudar cor, curvatura, rota ou endpoint de uma não muda as demais; retiming conjunto não destrói personalizações; Preview/MediaOut correspondem.

### 14.5. `RC-004` — Scenario Switch e Territorial Comparison (R1.1)

- **Intenção:** alternar hipóteses ou duas versões declaradas de um mapa sem misturar sua veracidade.
- **Pré-condições:** dois ou mais grupos lógicos de objetos existentes, cada grupo com `Scenario Name`, `Source`, `Status = Observed / Historical / Proposed / Hypothetical`, e quando aplicável data (`as-of`). A ferramenta não cria por si só uma área disputada, fronteira histórica ou rota militar.
- **Parâmetros:** `Scenario Set`, `Start = playhead`, `Mode = Step` (default) ou `Crossfade`, `Crossfade Duration = 12 f` (1–120), `Keep Legend = On`, `Show status tag = On` (obrigatório para Proposed/Hypothetical), `Order = Custom`.
- **Canais:** em Step, alternar visibilidade por propriedades compatíveis de composição mantendo estados originais do objeto; em Crossfade, animar opacidade dos objetos designados, sem alterar o Fill ou as curvas existentes de terceiros. Se uma instância tiver Opacity manual, o estado é Conflict; não mesclar escondido.
- **Resultado:** uma hipótese não se torna o estado do mapa-base; legenda visível diferencia cenário e fonte. Escolher `Observed` exige metadados de fonte, mas não constitui validação científica automática.
- **Aceitação:** 3 rotas hipotéticas distintas; somente cenário selecionado aparece em Step, Crossfade sem alpha acumulado >100%; status sempre legível; dados e keys persistem após reabertura.

### 14.6. Expansões especificadas, mas não presentes no R1.0

| ID futuro | Objeto | Comportamento previsto | Condições para autorizar release |
|---|---|---|---|
| MO-RTE-04 | Route / Trail | Animar Trim Start e Trim End com segmento viajante | Definir direção, comprimento e overlap; curva nativa |
| MO-LBL-02 | Label / Text Reveal | Revelação por caracteres ou máscara, Unicode | Teste shaping PT/EN, grapheme cluster, Spline e clipping |
| MO-MRK-03 | Marker / Pulse | Escala em pulso sem deslocar âncora | Contrato peak/cycle, conflito com Pop |
| MO-MAP-02 | Base Map / Style Transition | Interpolar tokens explícitos entre estilos | Estilos versionados, alpha e overrides preservados |
| MO-REG-07 | Region / Mask Reveal | Revelar Fill por direção/máscara mantendo fronteira | Sem confundir com expansão territorial histórica |
| MO-DATA-01 | Data Layer / Values | Mapear série temporal para cores e rótulos | Import validado, fonte e data para cada valor |
| MO-ADV-01 | Histórico / Territorial Change | Alternância de geometrias datadas fornecidas | Sem inventar limites ou interpolar polígonos incompatíveis |
| MO-ADV-02 | Globe / Orbit | Câmera globo tridimensional | Motor 3D e política de dados própria, fora do 2D |

**Não utilizar** o nome da função futura em UI ativa até a respectiva ficha conter defaults, limites, canais, conflitos, Undo e aceites equivalentes aos de R1.0. `LATER` identifica compromisso de visão, não funcionalidade entregue.

## 15. Contrato de engenharia para rewrite íntegro

### 15.1. Responsabilidades dos módulos — liberdade de tecnologia, comportamento fixo

```text
Fusion Host (Composition / Node Editor / Inspector / Keyframes / Spline / MediaOut)
   ├── CartoRig Scene Window (UI Manager: CRUD, find, selected context)
   ├── CartoRig Object Controls (Control + Motion via páginas de Inspector)
   ├── CartoRig Scene State (stable identities, layer order, provenance)
   ├── Geographic Engine (offline search, WGS84, projections, geometry)
   ├── Cartographic Renderer (RGBA determinístico; output do Fusion)
   └── Motion Adapter (parâmetros animáveis + keys/tangentes host + provenance)
```

**Interface como contrato, não código a ser copiado.** A engenharia determina se deve usar Fuses, Lua, C++ nativo, macros, grupos, bibliotecas de projeção ou componentes compartilhados. As APIs oficiais documentam páginas de controle no Inspector e BezierSpline; isso sustenta a abordagem, mas o contrato é verificado por comportamento no Resolve Studio 20. Não prescrever uma ferramenta por feature se isso prejudicar desempenho ou estabilidade.

### 15.2. Modelo de domínio persistente

Campos mínimos canônicos independentemente do formato em disco:

| Entidade | Campos mandatórios | Regras |
|---|---|---|
| Scene | `sceneId`, `schemaVersion`, `hostCompositionId`, `createdAt`, `dataManifestId`, `projection`, `displayMode`, `drawStack`, `cameraId` | ID estável; duplicação remapeia vínculos |
| Object | `objectId`, `type`, `displayName`, `hostToolRef`, `sourceRef`, `geometryRef`, `styleOverrides`, `visibility`, `lock`, `drawOrder` | Nome não é ID; objeto pertence a uma Scene |
| SourceRef | `provider=Natural Earth`, `dataset`, `datasetVersion`, `featureId`, `scale`, `worldview`, `featureType` | Garante provenance e desambiguação |
| GeoAnchor | `lat`, `lon`, `referenceType`, `sourceFeatureId?`, `offsetPx` | WGS84; display em pixels após projetar |
| Route | `from`, `to`, `waypointsOrdered`, `pathType`, `curvature`, `arrowhead`, `followerRef?` | Endpoint de Polygon requer escolha de ponto |
| Camera | `centerLat`, `centerLon`, `zoom`, `bearing`, `fitPadding`, `savedPoses[]` | Uma por cena; estado geográfico único |
| MotionBinding | `motionId`, `presetId`, `objectId`, `affectedChannels[]`, `originalStateFingerprint`, `createdKeys`, `currentKeyFingerprint`, `status`, `parameters` | Curvas host são a verdade temporal |
| Data manifest | `dataset`, `sourceURL`, `release`, `sha256`, `license`, `coverage`, `conversionVersion` | Conteúdo instalável offline e auditável |

**Persistência:** nenhuma curva é avaliada pelo UI Manager. Curvas/valores ficam sob controle do Fusion em parâmetros animáveis, e metadados CartoRig armazenam os vínculos e a proveniência das operações. Se metadados divergirem do estado real do Fusion, prevalece a curva host, e o vínculo passa a `Customized/Needs repair`; nunca corrigir keyframes silenciosamente a partir do cache da Scene.

### 15.3. Integridade do motor geográfico

- **Sistema de referência:** armazenar coordenadas WGS84 (`lon`, `lat`) e aplicar projeção configurada em um ponto comum da composição. Projeção baseline `Equirectangular` 2D; geometrias fonte são vetores, não PNG pré-posicionado por zoom.
- **Topologia:** preservar outer/inner rings, ilha, fragmentos, multipolígonos, linhas multipartes; orientar e validar anéis; não preencher buracos nem unir países por acidente. Pipeline pode generalizar linhas conforme escala desde que preservando semântica e resultados determinísticos.
- **Antimeridiano:** dividir e recompor segmentos na costura da projeção, preservar orientação de route e minimizar arco de câmera longitudinal; nunca desenhar linha longa atravessando o mapa por erro de wrap.
- **Câmera:** todos os objetos recebem transformação geográfica compatível no **mesmo frame**. Marker e Label podem conservar tamanho de tela; não deslocar posições por alterações na área de bounding box de outro objeto.
- **Importância editorial:** Natural Earth contém diferentes políticas e perspectivas de limites; registrar a escolha e não substituir camada histórica/disputada. `Urban Areas` não é município legal; `Populated Places` são pontos.
- **Resolução de dependências:** dados administrativos não precisam ser transformados em milhares de nós Fusion visíveis; o objetivo é edição independente de cada objeto criado pelo usuário.

### 15.4. Integração com Node Editor, Inspector, Spline e eventos

1. Cena ativa identificada por composição + sceneId; seleção por objectId; eventos da janela e Node Editor não se propagam recursivamente.
2. Seleção em Scene abre/expõe controles do objeto correspondente no Inspector, ou em caso de limitação comprovada, seleciona a ferramenta e informa claramente o caminho para o Inspector já existente — sem inventar um Inspector paralelo.
3. Parâmetros animáveis são verdadeiros canais Fusion. Motion deve criar keys efetivos, não exibir apenas valores de animação calculados em outra interface.
4. Toda aplicação de preset guarda fingerprint dos canais, compara com o estado host e apresenta `Customized` se keys/tangentes/interpolações foram modificados por fora.
5. Início/fim de operação com Undo/Redo do host quando suportado; se a operação não for atomicamente reversível, UI bloqueia sequência e informa limite antes de aplicar.
6. Dados pessoais, login, rede e serviços externos não fazem parte do sistema de renderização. Instalação offline precisa de todos os componentes essenciais.
7. Reabertura com UI Manager fechada restaura pixels e keys. Não usar caminhos absolutos de usuário para dados instalados. Erro de arquivo não pode derrubar o Resolve.

### 15.5. Contratos de tempo e colisão de curvas

A engenharia deve tratar a identidade de keyframe por `objectId + channel + localFrame` e não por nome visível; usar tempo de composição e sua representação nativa para evitar drift de amostra. Se um preset gerou keys 100/124 e o usuário edita tangentes no Spline, a próxima atualização não pode sobrescrever a geometria da curva. Reescalonamento de tempo reescala posições das keys e tangentes; em colisão de dois frames no mesmo índice, mostrar erro e reverter a operação. Em troca de FPS, preservar posição dos keyframes em frames conforme política do documento (e informar mudança de duração em segundos); não reinterpretar por conta própria.

### 15.6. Qualidade não funcional com metas propostas (não medições)

| Cenário de produto | Meta de aceite proposta em hardware de referência | Observação |
|---|---|---|
| Abrir Scene em cena R1.0 com 20 objetos | p95 ≤2 s | Sem recriar cache pesado ao reabrir |
| Busca offline por cidade/país já indexado | p95 ≤500 ms | Inclui render de resultados, não apenas consulta SQL |
| Selecionar objeto e atualizar Inspector | p95 ≤400 ms | Em estado Ready |
| Alterar Fill simples em 1440p | p95 ≤800 ms até resposta visual | Preview qualidade padrão |
| Scrub de 100 quadros arbitrários | Sem inconsistências ou frames de outro tempo | Precisão prevalece sobre FPS constante |
| Render 3840×2160 de cena moderada | Completar sem crash/erro de alpha | Latência medida e relatada, sem FPS inventado |
| Memória com 50 Regions, 50 Markers, 20 Routes, 20 Labels | Sem crescimento contínuo após 20 ciclos de abrir/fechar | Medir RAM/VRAM e reportar |
| Instalação limpa offline | Sem terminal/IDE e sem dependência de conta | Usuário final |

**Hardware de referência a declarar no relatório:** Windows, versão exata Resolve Studio 20, CPU/GPU/RAM/driver, resolução, preset de preview, versões do bundle, quantidade de objetos e FPS. Metas numéricas acima são **propostas de Product Design**, não resultados experimentais. É proibido substituir medição de host por benchmark C++ isolado ou runner Linux e declarar atendimento.

### 15.7. Segurança, robustez e manutenção

Arquivos de geometrias e metadados devem validar limites, tamanho, tipos, NaN, polígonos inválidos e strings potencialmente malformadas antes de construir ferramentas. Não executar código embutido em arquivos geográficos ou textos de Label; SVG ou formatos avançados só entram após sanitização própria. Manter versões de esquema e compatibilidade; migrar em cópia; integridade por hash do bundle; logs de erro sem dados pessoais por padrão. Erros inesperados retornam mensagem segura e deixam composição recuperável. Fonte aberta inclui licença para código de terceiros e SBOM simples de dependências; recomenda-se **Apache-2.0 para o código novo**, condicionado à análise de compatibilidade antes da publicação.

## 16. Plano de QA completo, rastreável e executável

### 16.1. Base de testes obrigatória

**Ambiente:** DaVinci Resolve Studio 20 no Windows, Fusion aberto. Criar uma composição de 900 quadros a 30 fps, 1920×1080 e 2560×1440, com reexecução dos testes de rendering e alpha em 3840×2160. A fonte Natural Earth instalada deve ser registrada em manifesto SHA-256. O projeto de teste contém: Base Map, Camera, Brazil Country, Rio de Janeiro State, São Paulo City Marker, Brasília City Marker, uma Route Brasília→ponto explícito no Amapá e Labels Unicode.

**Formato de prova:** cada caso registra `test_id`, build hash, host version, source bundle, `preconditions`, ações exatas, frame(s), valores esperados, resultados F/V/T/P/E, evidências Viewer + Inspector + Spline + MediaOut, status PASS/FAIL/BLOCKED e issue. `BLOCKED` não conta como PASS. Captura sem frame/timecode ou sem input identificado não constitui evidência completa.

**Gate QA-01–QA-30:** os trinta testes detalhados na §9.2 fazem parte obrigatória do release R1.0. O catálogo ampliado impõe ainda os seguintes testes. A enumeração não autoriza ignorar cenários negativos ou as provas HOST-01 a HOST-10.

### 16.2. Casos adicionais R1.0 — visual, temporal, integração e erros

| Teste | Preparação e ação | Resultado obrigatório | Evidências |
|---|---|---|---|
| QA-31 | Rota em 100f; aplicar Erase 30f | Draw Progress 100% no 100 e 0% no 130; geometry preservada | Inspector, Spline, MediaOut |
| QA-32 | Marker com Pop 18f e Fade 18f no mesmo start | Size overshoot e Opacity animados sem conflito, anchor imóvel | 0/9/13/18, Spline |
| QA-33 | Alterar Ocean/Land/Border layers e frame base | Camadas independentes e estilo de Regions preservado | RGBA, pixels, Inspector |
| QA-34 | Group 3 Regions, Hide Group, Ungroup | Hierarquia não muda geoIDs, keys e draw order global | Scene, Viewer, Undo |
| QA-35 | Region multipolígono, Border Draw 36f | Stroke Progress 0/50/100 e desenho correto das ilhas/anéis | frames 100/118/136, spline |
| QA-36 | Highlight Pulse 2×18f, Peak 35% | Strength 0→35→0 duas vezes; cor-base imutável | key list, screenshots, pixels |
| QA-37 | Camera Fit Transition Brasil + Chile | Ambos objetos dentro do frame final e padding de 10% quando geometricamente possível | 16:9, 9:16, MediaOut |
| QA-38 | Route com waypoint e Follower Marker | Marker percorre Route 0/25/50/75/100%; seu Anchor autoral não muda | Spline, Viewer, IDs |
| QA-39 | Marker já vinculado a rota A; tentar rota B | Dialog `Reassign / Cancel`; Cancel não altera vínculo | estados, Undo |
| QA-40 | Base Map Layer Fade somente Admin-0 | Borders entram; Ocean/Land/Regions não mudam de opacity | canais + RGBA |
| QA-41 | No Transparent Overlay tentar Layer Fade | Apply disabled com motivo; retornar Full Map restaura curva anterior | Scene, Inspector |
| QA-42 | Route Curved Draw + mudança de Curvature/waypoint | Curvas não reescritas, arrowhead recalcula trajeto espacial | Spline, 0/50/100, Undo |
| QA-43 | Dois presets diferentes em canais não coincidentes | Fade+Border Draw e Fade+Highlight coexistem | Curve state, pixels |
| QA-44 | Dois presets no mesmo canal | Conflict explícito; Cancel mantém keys e pixel hash | diff antes/depois |
| QA-45 | Inserir valor inválido `NaN`, lon 210, hex errado | Mensagem contextual e valor anterior restaurado | Inspector, error |
| QA-46 | Remover preset customized com Keep Manual | vínculo removido, keys e pixels idênticos | curve snapshots, reopened |
| QA-47 | Remover preset com Delete Keys | Somente keys pertencentes ao preset, após confirmação; Undo restaura | estado por canal |
| QA-48 | Duplicar Region com 2 presets e overrides | novo objectId, mesmas curvas iniciais, edições isoladas | Scene, Spline, original/cópia |
| QA-49 | Export com Scene UI fechada e rede indisponível | frames equivalentes às amostras com janela aberta | per-frame SHA/checksum tolerância |
| QA-50 | Importação de projeto em outra máquina com bundle ausente | diagnóstico de dataset, sem render de fronteira substituta | logs, UI, MediaOut |
| QA-51 | Seleção Node Editor → Scene; Scene → Inspector | objeto correto em toda sequência sem atraso enganoso | captura dupla, IDs |
| QA-52 | Renomear nó livre + excluir nó CartoRig manualmente | detectar corrupção parcial e oferecer recover copy | context/error, output preservado |
| QA-53 | Alterar FPS de 30 para 24 em projeto de teste | keys preservam índices de frame conforme política; UI informa impacto em segundos | timecode, keys antes/depois |
| QA-54 | Seek fora de ordem 450, 0, 899, 330, 100 | resultado em cada frame igual a render sequencial da mesma cena | checksum frame |
| QA-55 | Câmera de 179° para -179° | interpolação percorre arco curto; não atravessa mundo indevidamente | path/viewport amostras |
| QA-56 | Sobrepor mapa transparente ao footage com borda antialias | zero alpha fora dos objetos, sem halo sob imagem contrastante | RGBA linear/visual |
| QA-57 | Label `São Paulo — Amapá` com troca de fonte | Unicode e layout persistem; fallback explícito em fonte ausente | Viewer, reopen |
| QA-58 | Changing Neutral Dark tokens após overrides region | Rio override preservado; reset de Stroke não apaga Fill/curva | Inspector, diff colors |
| QA-59 | Scene em `WRONG_CONTEXT`, clique Delete | nenhuma alteração em comp anterior/atual; foco seguro | state + IDs |
| QA-60 | 20 ciclos abrir/fechar Scene e alternar comp | sem vazamento crescente, travamento ou geração duplicada de ferramentas | RAM/VRAM, logs |

### 16.3. Exemplos de contratos com valores exatos

**QA-15 / QA-16 — Mudança categórica de cor.** Comp 900f/30fps, Brazil `#FF0000` até frame 329 e `#00FF00` a partir de frame 330. Editar manualmente o canal Fill Color sem Motion e repetir com `Instant Color Change`. Em 0, 329, 330, 331 e 899, capturar valor avaliado da cor e frame renderizado. A mudança não pode ocorrer no 329, nem ser interpolada durante o 330; Rio State mantém seu próprio Fill. Registrar o modo de curva (`Hold` ou equivalente exato), reabertura e output MediaOut.

**QA-11/12/46 — Preset personalizado.** Region com Fade In nas keys 100→124, alterar uma tangente no Spline. `PRESET_CUSTOMIZED` deve ser exibido após Refresh. Tentar mudar Duration para 48: diálogo `Retiming Only / Replace affected channels / Cancel`, default Cancel; após Cancel, fingerprints de keys e pixels invariáveis. Após Retiming Only, curvas mantêm forma relativa se não houver colisão; Remove→Keep Manual elimina vínculo mas não muda visual.

**QA-35/36 — Contorno e destaque.** Em Region com multipolígono, Stroke Progress 0/50/100 sobre comprimento esperado; `Fill` constante. Em Highlight Pulse, dois ciclos distintos com pico aos frames 109 e 127 se Start=100, Cycle=18, Count=2, e retorno ao zero em 118 e 136. O controle `Highlight Strength` é visível no Spline e a cor-base de Brazil não deve sofrer alterações.

**QA-38/42 — Desenho e follower.** Route Brasília→Amapá tem destino escolhido explicitamente em coordenada ou cidade. Criar um waypoint e Marker follower existente; comparar posição do Marker em 0/25/50/75/100% de Follower Progress, animando câmera simultaneamente. Alterar waypoint e verificar que curva Follower Progress não foi regravada. Remover vínculo: Marker retorna à sua âncora-base, sem mudar símbolo/Fill/Size.

**QA-37 — Fit geográfico.** Selecionar Brazil e Chile; no frame final calcular bounding boxes de saída de cada polígono e verificar que o conjunto está dentro do viewport e padding definido, exceto distorções de projeção documentadas. Repetir no aspect ratio vertical; nunca distorcer latitude/longitude dos objetos para caber no frame.

**QA-56 — Alpha correto.** Em Transparent Overlay, amostrar pontos fora da silhueta dos elementos: alpha deve ser zero até tolerância de quantização do formato. Contorno anti-aliased sobre checkerboard não pode apresentar halo opaco. Full Map mantém base configurada. Comparar com Merge sobre vídeo e export, não somente Viewer com fundo preto.

### 16.4. Gates e critérios de reporte

Um teste `PASS` deve registrar input, estado inicial, estado intermediário observável, resultado, evidência visual quando aplicável e persistência quando pertinente. `HOST-02` verifica existência/funcionamento real de abas; `HOST-03` verifica controles presentes no Spline; `HOST-08` verifica render sem janela. Testes de mock, unitários, CI Linux e screenshots não substituem provas no host Windows/Resolve 20. Resultado bloqueado, experiência degradada ou falha de QA eliminatório impede fechar o release.

## 17. Evidência editorial — estudo comparativo de 20 produções

### 17.1. Método e alcance da evidência

Foram examinadas **10 produções de Johnny Harris e 10 de CaspianReport**, selecionadas por necessidades geográficas distintas: redes estratégicas, mudança de escala, localização de atores, disputas territoriais, infraestrutura, rotas e cenários alternativos. A documentação consultada inclui títulos e descrições públicas, capítulos, transcrições textuais acessíveis e materiais de bastidores. **Não houve auditoria audiovisual contínua, registro quadro a quadro ou medição de frequência, duração e easing dos movimentos nos 20 vídeos.** Portanto os termos da tabela abaixo são **problemas editoriais apoiados por fontes textuais e soluções recomendadas para o CartoRig**, não prova de que os autores usaram um efeito específico em um timecode determinado.

**Distinção normativa:** `PROVENANCE-VIDEO` indica a produção consultada; `NEED` descreve informação cartográfica necessária à narrativa; `MOTION-SOLUTION` representa uma solução de design e não observação direta de técnica. O CartoRig não deve reproduzir imagens, marcas, composições ou arquivos proprietários desses canais. Seus presets são operações cartográficas genéricas e originais.

### 17.2. Amostra de Johnny Harris: demanda → capacidade

| Referência | Produção consultada | Problema cartográfico | Capacidade CartoRig pertinente |
|---|---|---|---|
| JH-01 | [The most important country you’ve never heard about, Mapped](https://www.youtube.com/watch?v=yczYThn4nDI) | País pequeno, estreito marítimo, bases e escala mundial/local | Camera Fly To, Fit Transition, Marker Fade |
| JH-02 | [The War in Yemen, Mapped](https://www.youtube.com/watch?v=qsO-rULEfrk) | Atores e fases de conflito em contexto regional | Region Color, Highlight Pulse, cenários datados futuros |
| JH-03 | [The Iran-Iraq War, Mapped](https://www.youtube.com/watch?v=7PNCdOQvrRM) | Fases militares e corredores marítimos | Route Draw, Network Build, Border Draw |
| JH-04 | [The Rise of Hezbollah, Mapped](https://www.youtube.com/watch?v=ETFTg1Za28U) | Foco em fronteira pequena com contexto regional | Fit, Highlight, Border Draw |
| JH-05 | [Why everyone’s mad about China’s new map](https://www.youtube.com/watch?v=WpQQOQ__1ok) | Várias reivindicações em escalas diferentes | Location Tour, Scenario Switch, fonte geográfica |
| JH-06 | [How Europe Stole Africa so Quickly, Mapped](https://www.youtube.com/watch?v=LjieOlWXwTw) | Mudança territorial histórica no continente | Region Step e camadas históricas fornecidas |
| JH-07 | [Why Sudan is on the Verge of Civil War, Mapped](https://www.youtube.com/watch?v=bl9HEcfq1Oc) | Localização de atores e regiões em disputa | Region Highlight, Camera Fit, Markers |
| JH-08 | [Why the US is Militarizing the Pacific](https://www.youtube.com/watch?v=plHRRFHZ_f0) | Rede de instalações em áreas marítimas extensas | Marker Stagger, Location Tour, Route Network |
| JH-09 | [How the US Stole Puerto Rico, Mapped](https://www.youtube.com/watch?v=xb9E8fvMPOA) | Relação entre território insular e país distante | Fly To, Region Border, Marker |
| JH-10 | Every secret CIA prison, mapped | Múltiplos locais e geografia de rede | Marker Stagger, Label Fade, Camera Fit |

### 17.3. Amostra de CaspianReport: demanda → capacidade

| Referência | Produção consultada | Problema cartográfico | Capacidade CartoRig pertinente |
|---|---|---|---|
| CR-01 | [How Russia plans to rule Eurasia by river](https://www.youtube.com/watch?v=VtE5sTpkn7k) | Rede de rios, ferrovias e nós | Route Draw/Follow, Network Build |
| CR-02 | [How this silent war is rewiring the Black Sea](https://www.youtube.com/watch?v=CWoYVlMuUNQ) | Corredores alternativos e infraestrutura | Layer Fade, Fit Transition, Network Build |
| CR-03 | [How China is preparing for conflict with India](https://rosetta.to/u/caspianreport/how-china-is-preparing-for-conflict-with-india) | Limites, altitude, estradas e pontos de interesse | Border Draw, Markers, dados R2 |
| CR-04 | [Why Thailand and Cambodia are fighting](https://www.youtube.com/watch?v=1Hp-W2bpPrw) | Fronteiras formais e reivindicações | Border Draw, Scenario Switch |
| CR-05 | [How Iran’s water crisis could spark collapse](https://www.youtube.com/watch?v=CtcTG8-qzbA) | Lagos, rios e mudança ao longo do tempo | Layer Fade, dados geográficos datados R2 |
| CR-06 | [Inside Turkey and the UAE’s secret war](https://www.youtube.com/watch?v=PHhc-48JT3U) | Relação entre atores e possíveis vias de apoio | Route Draw, Network Build, provenance |
| CR-07 | [How the Gulf states plan to checkmate Iran](https://www.youtube.com/watch?v=T5W2LWLYpms) | Rotas alternativas e chokepoints | Route Follow, Fit Transition, Network Build |
| CR-08 | [Why Greenland is only the beginning](https://rosetta.to/u/caspianreport/why-greenland-is-only-the-beginning) | Reivindicações árticas e geometria jurídica | Highlight, futuros dados especiais, fonte |
| CR-09 | [Three ways Trump could strike Iran](https://rosetta.to/u/caspianreport/three-ways-trump-could-strike-iran) | Hipóteses mutuamente alternativas | Scenario Switch, estilos de hipótese |
| CR-10 | [How China could conquer Taiwan without firing a shot](https://rosetta.to/u/caspianreport/topic/geopolitics) | Interdição hipotética de rotas marítimas | Route Draw, Scenario Switch, rotulagem |

**A auditoria documental não justifica números como “30% dos vídeos fazem Fly To”**. A escolha de presets foi realizada por cobertura de tarefas cartográficas recorrentes na amostra e custo de edição manual, combinada com a taxonomia acadêmica de movimentos. A amostra é exploratória, não representativa de toda a produção dos canais.

### 17.4. Referências de processo e benchmark profissional

- Johnny Harris, [How I Make My Maps](https://www.youtube.com/watch?v=GsojLuJpe_0): referência de fluxo editorial e composição cartográfica em camadas, não um catálogo licenciado de presets.
- GEOlayers 3, [Help / API](https://github.com/GEOlayers/Help): Mapcomp, objetos geográficos, âncoras, `setViewAtTime`, `fitViewAtTime`, desenho com `addTrimPaths` e relação entre mapas/feições/estilos. É uma referência conceitual de After Effects, **não** fonte de código compatível com Fusion.
- MapStory, [UIST 2025](https://keiichiihara.github.io/paper/uist2025-mapstory.pdf): estudo de 200 vídeos e categorias de câmera, destaque e elementos animados; auxilia na taxonomia, não certifica frequência dos efeitos dos dois canais escolhidos.
- Natural Earth, [vetores culturais 10m](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/) e [Populated Places](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-populated-places/): delimita cobertura real. Não permitir que a UX trate ponto de cidade como polígono municipal.

**Critério de uso das fontes:** a equipe pode consultar materiais externos para contextualização, mas todos os contratos funcionais obrigatórios e regras de UX encontram-se neste único arquivo. Os links acima não são dependência documental da especificação.

## 18. Entrega final de engenharia, publicação e governança

### 18.1. O usuário final deve receber

**Software instalável** para Windows compatível com Resolve Studio 20, com CartoRig Scene visível no fluxo Fusion, páginas Control/Motion nos objetos, saída conectável ao MediaOut, catálogo offline Natural Earth, presets de Motion reais e exemplos autorais de teste neutros. Instalação, primeira execução, atualização e desinstalação são realizadas por UI, sem pedir terminal, Python, Lua, compilador, CMake, contas, tokens ou download manual de banco geográfico. A página Edit é somente host de timeline/saída quando for usada; não é superfície de autoria CartoRig.

**Código e distribuição:** repositório público completo do CartoRig rewrite, histórico de commits, licença OSS definida e compatível (recomendação Apache-2.0), licenças de dependências e fontes, manifesto de dados e hashes, builds versionadas, release notes, changelog, tag assinada quando possível, instruções de build e diagnóstico de ambiente. Uma dependência proprietária do host não faz o código do plugin automaticamente proprietário, mas os termos do SDK/instalação devem ser respeitados e descritos.

**Documentação:** Quick Start `Create → Search → Add → Control → Motion → Spline → Render`, referência de todos os campos `CT-*`, presets `MO-*`, resolução de conflitos, uso de `Transparent Overlay`, diferença entre cidade e município, limites do Natural Earth, atalhos, solução de erros, backup/migração, desinstalação, API/schema interno e políticas de licença e dados. Nenhuma funcionalidade anunciada como pronta sem tutorial correspondente.

### 18.2. Artefatos obrigatórios para aceite de Product Design e QA

| Entregável | Conteúdo mínimo | Validação |
|---|---|---|
| `cartorig-windows-installer` | arquivos de plugin, UI, dados offline, manifesto | instalar/rodar com rede bloqueada |
| `cartorig-source` | todos os componentes autorais e dependências declaradas | build reproduzível conforme docs |
| `cartorig-ui-review` | capturas de Scene estados, Inspector por tipo e Motion Conflict | revisão visual + DPI |
| `cartorig-host-tests` | evidência HOST-01…HOST-10 no Resolve real | PASS por teste ou blocker explícito |
| `cartorig-qa-report` | QA-01…QA-60 com inputs, frames, evidência F/V/T/P/E | resultados verificáveis e issues |
| `cartorig-data-manifest` | versões, geometrias incluídas, SHA-256, licença, cobertura | teste de integridade e provenance |
| `cartorig-regression-comps` | composições neutras com casos de rota, border, câmera, alpha e labels | Save/Reopen/Render |
| `cartorig-docs` | manual de usuário + referência de parâmetros + erros | todo controle documentado |
| `cartorig-release-notes` | mudanças, requisitos e limites conhecidos | publicação pública honesta |

### 18.3. Quality gates de publicação

`Gate 0 — Product`: escopo R1.0 e decisões visuais homologados pelo proprietário; nenhum comportamento observável fica a critério arbitrário da engenharia. `Gate 1 — Code`: build limpa, licença e dependências auditadas, testes unitários e integração automatizada sem falhas críticas. `Gate 2 — Host`: Inspector, UI Manager, Spline, MediaOut, Undo e persistência demonstrados em Resolve Studio 20. `Gate 3 — UX`: fluxos essenciais executados por editor de vídeo familiarizado com Fusion e por pessoa sem conhecimento de GIS; registrar cliques, erros e confusão. `Gate 4 — Visual/Temporal`: amostras 1080p/1440p/4K, alpha, Unicode, animadores independentes e antimeridiano sem regressões. `Gate 5 — Release`: instalador limpo offline, bundle correto, documentação e código público. Gate falho é impeditivo para `1.0`.

### 18.4. Governança das decisões sem perguntas recorrentes

Esta especificação contém **uma recomendação fechada para cada comportamento do release**, inclusive valores padrão, catálogo, política de keyframes, conflitos, overlay, prioridade de dados e composição de pacote. O proprietário não precisa inventar soluções técnicas. Cabe-lhe apenas homologar ou solicitar alteração da proposta de produto em revisão consolidada. A engenharia pode escolher implementação interna, mas alterações que mudem resultados observáveis precisam ser registradas como `Change Request` com comportamento anterior, novo comportamento, motivo, efeito em testes e aceite. Uma limitação comprovada do Fusion deve vir acompanhada de pelo menos uma alternativa de experiência tecnicamente viável, **sem cortar recursos unilateralmente**.

### 18.5. Declaração de encerramento de Product Design

**O contrato de produto está definido, não implementado.** O estado `CR-PS-2.0 / PRODUCT DESIGN COMPLETE` significa que há escopo recomendado, inputs, comportamentos, propriedades, fluxo, casos de erro, catálogo Motion, critérios de render e entregáveis. Isso **não** significa que o proprietário tenha homologado o release, que a engenharia tenha concluído o software ou que os testes HOST/QA já tenham passado. Um documento “final” não substitui prova de funcionamento e não inventa aprovações.

---


## 19. Referências técnicas, delimitação de evidências e glossário

**Fontes de capacidade e benchmark (não documentos funcionais adicionais necessários para entender esta especificação):**

1. Blackmagic Design — **Fusion Fuse SDK**: https://documents.blackmagicdesign.com/UserManuals/Fusion_Fuse_SDK.pdf — ferramentas, páginas de controle do Inspector, widgets e manipulação de parâmetros. A existência de uma API não comprova desempenho ou todos os detalhes de integração no host-alvo.
2. Blackmagic Design — **Fusion Scripting Guide**: https://documents.blackmagicdesign.com/UserManuals/Fusion8_Scripting_Guide.pdf — `Composition`/`Tool`/`BezierSpline`, operações de Undo e automação. Confirmar comportamento no Studio 20 durante implementação.
3. GEOlayers 3 Help/API: https://github.com/GEOlayers/Help — Mapcomp, busca de features, desenho, styles, `addTrimPaths`, `setViewAtTime` e `fitViewAtTime`; é benchmark de produto **After Effects**, não SDK compatível com Fusion.
4. Natural Earth — 10m Cultural Vectors: https://www.naturalearthdata.com/downloads/10m-cultural-vectors/ — países, admin1, pontos de cidades, áreas urbanas e limites do dataset.
5. Natural Earth — downloads: https://www.naturalearthdata.com/downloads/ — versões e escalas geográficas, sujeitos a atualização no tempo.
6. Pesquisa acadêmica **MapStory: Prototyping Editable Map Animations with LLM Agents**, UIST 2025: https://keiichiihara.github.io/paper/uist2025-mapstory.pdf — taxonomia de movimentos de câmera, destaque de feições e trajetórias.
7. Johnny Harris — *How I Make My Maps*: https://www.youtube.com/watch?v=GsojLuJpe_0 — referência do processo editorial, **não** biblioteca de presets oficialmente definida.
8. CaspianReport — https://www.youtube.com/@CaspianReport — referência temática de geopolítica, **não** prova de frequência ou duração de um efeito sem auditoria audiovisual específica.

**Declaração metodológica:** os controles, defaults e fichas de Motion de §3–6 são **propostas explícitas da equipe de produto**, derivadas de capacidades reconhecíveis do Fusion e padrões de animação cartográfica. Não são copiados de preset do GEOlayers e **não** são apresentados como aprovados pelo proprietário. A avaliação editorial de canais de YouTube não substitui contagem frame a frame. Os testes `HOST-*` e `QA-*` não foram executados por este documento.

---

**Estado documental:** `CR-PS-2.0 — PRODUCT DESIGN COMPLETE / OWNER SIGN-OFF REQUIRED`. Documento funcional independente, sem dependência de especificações anteriores. A aprovação da proposta de produto e a validação técnica da implementação são etapas diferentes. O projeto é implementado inteiramente do zero, com contrato funcional fechado e rastreabilidade sem depender de implementações herdadas.

