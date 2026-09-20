-- ============================================================================
-- COMPACT FOLDERS para o snacks.explorer (estilo IntelliJ/VSCode)
-- ============================================================================
--
-- CONTEXTO / POR QUE ESSE ARQUIVO EXISTE
-- ----------------------------------------------------------------------------
-- snacks.nvim NÃO tem suporte oficial a compactar cadeias de pasta única
-- (ex: java/com/nicolai/ecommerce virar uma linha só). Foi pedido oficialmente
-- na issue https://github.com/folke/snacks.nvim/issues/916 e o mantenedor
-- (folke) respondeu explicitamente "Not interested in adding this". Ou seja:
-- tudo abaixo é feito por cima de API INTERNA e NÃO DOCUMENTADA do plugin.
-- Não existe garantia de estabilidade entre versões.
--
-- SE ALGO PARAR DE FUNCIONAR APÓS UM UPDATE DO snacks.nvim, o primeiro passo
-- é comparar as funções originais em:
--   lua/snacks/picker/format.lua      -> M.tree(item, picker), M.filename(item, picker)
--   lua/snacks/explorer/tree.lua      -> Tree:node(path), estrutura do Node
--   lua/snacks/picker/source/explorer.lua -> como os "items" do finder são
--                                             montados (campos: parent, last,
--                                             open, internal, file, dir)
-- com o que está sobrescrito aqui, e ajustar.
--
-- ARQUITETURA DA SOLUÇÃO (3 pontos de intervenção independentes)
-- ----------------------------------------------------------------------------
-- 1. `transform` (config do source "explorer"): remove da LISTAGEM os nós que
--    fazem parte do "meio"/"fim" de uma cadeia de pasta única (eles não têm
--    linha própria, viram parte do texto da linha "cabeça").
-- 2. `Format.tree` (monkeypatch): recalcula o RECUO (indent) ignorando os
--    ancestrais que foram absorvidos, senão os filhos do fim da cadeia
--    ficariam recuados como se estivessem N níveis abaixo (quando visualmente
--    deveriam estar só 1 nível abaixo da linha compactada).
-- 3. `Format.filename` (monkeypatch): troca o TEXTO da linha "cabeça" pelo
--    caminho compactado ("java" -> "java/com/nicolai/ecommerce"), mas só
--    quando a pasta está aberta (node.open == true) — fechada, mostra só o
--    nome próprio.
--
-- Os pontos 2 e 3 usam monkeypatch de `require("snacks.picker.format")`.
-- Esse padrão (sobrescrever Format.tree / Format.filename) foi confirmado
-- funcionando por outros usuários em discussões públicas do repositório
-- (ex: discussion #829 sobrescrevendo Format.tree, issue #708 sobrescrevendo
-- Snacks.picker.format.filename) — mas nenhum desses casos fazia exatamente
-- o que fazemos aqui, então é extrapolação, não cópia de solução pronta.
--
-- DEFINIÇÃO CENTRAL: O QUE É UM NÓ "ABSORVIDO"
-- ----------------------------------------------------------------------------
-- Um nó-diretório é "absorvido" (não ganha linha própria) quando:
--   - é diretório (node.dir == true)
--   - tem pai (node.parent ~= nil)
--   - o PAI não é a raiz do explorer (node.parent.parent ~= nil) -- a raiz
--     nunca vira uma linha renderizada, então o primeiro nível de pastas
--     dentro do cwd SEMPRE fica visível, mesmo se só tiver uma pasta.
--   - o pai tem exatamente 1 filho (esse próprio nó)
-- Essa checagem é local (só olha o pai imediato) e propaga corretamente
-- porque quem monta o LABEL da linha cabeça (compact_label) desce
-- recursivamente pela cadeia inteira de qualquer forma.
--
-- PONTOS FRÁGEIS / PREMISSAS NÃO GARANTIDAS PELA DOCUMENTAÇÃO OFICIAL
-- ----------------------------------------------------------------------------
-- (a) `item.file` é o path usado como chave em `Tree:node(item.file)`.
--     Confirmado pelo próprio código-fonte do usuário (recursive_toggle já
--     usava esse padrão antes desta mudança), mas não é campo documentado.
-- (b) `node.children` é uma tabela indexada por chave arbitrária (iteramos
--     com `pairs`, não `ipairs`) — não é uma lista sequencial. Se a
--     implementação mudar para lista, `pairs` ainda funciona, mas vale checar.
-- (c) `node.path`, `node.parent`, `node.dir`, `node.last`, `node.open` são
--     campos observados em uso real (scripts de comunidade + DeepWiki gerado
--     a partir do código-fonte), não em documentação oficial do snacks.nvim.
-- (d) Em `Format.filename`, a técnica pra achar QUAL segmento do retorno
--     representa o nome da pasta é comparar o TEXTO (ignorando "/" final)
--     com o basename do nó — não comparamos por highlight group (ex:
--     "SnacksPickerDir"/"SnacksPickerFile") porque não temos certeza de qual
--     grupo é usado para diretórios no modo tree com filename_only=true.
--     Se o snacks mudar o texto retornado (ex: adicionar sufixo, prefixo,
--     emoji condicional etc.), essa comparação para de casar e o rename
--     silenciosamente não acontece (fallback seguro: mostra o nome original).
-- (e) `Format.tree` é uma função COMPARTILHADA entre todos os sources que
--     usam `tree = true` (ex: lsp_symbols também usa). Por isso o guard
--     `if picker.opts.source ~= "explorer" then return tree_orig(...) end`
--     é essencial — sem ele, o outline de símbolos LSP também seria afetado.
-- (f) Este monkeypatch é aplicado uma vez, dentro de `config()`, sobre o
--     módulo `snacks.picker.format` (singleton via `require`). Se outro
--     plugin/config também sobrescrever `Format.tree` ou `Format.filename`
--     DEPOIS deste arquivo carregar, o patch daqui pode ser perdido
--     (dependendo de quem sobrescreve por último) ou vice-versa.
-- (g) `is_absorbed` e `compact_label` fazem I/O leve (`vim.fn.fnamemodify`)
--     em CADA chamada de formatação de linha. Para árvores muito grandes
--     isso pode ter custo perceptível — não otimizado/cacheado.
--
-- COMO TESTAR SE ALGO QUEBROU
-- ----------------------------------------------------------------------------
-- 1. Abrir um projeto Java/Kotlin com pacotes aninhados (ex: com/foo/bar/baz
--    onde cada pasta intermediária só tem 1 filho).
-- 2. Pasta FECHADA deve mostrar só o nome da própria pasta (ex: "java").
-- 3. Pasta ABERTA (<CR>, que dispara recursive_toggle) deve mostrar o
--    caminho completo compactado (ex: "java/com/foo/bar/baz") E os filhos
--    de "baz" devem aparecer recuados 1 nível abaixo dessa linha, não N.
-- 4. Pastas com 2+ filhos, ou com um único filho que é ARQUIVO (não pasta),
--    nunca devem ser compactadas — devem se comportar como antes.
-- ============================================================================

local function child_count(node)
  local n = 0
  for _ in pairs(node.children or {}) do
    n = n + 1
    if n > 1 then
      break
    end
  end
  return n
end

-- Ver seção "DEFINIÇÃO CENTRAL" acima para a regra completa.
local function is_absorbed(node)
  local parent = node and node.parent
  if not (node and node.dir and parent and parent.parent) then
    return false
  end
  return child_count(parent) == 1
end

local function get_dir_children(node)
  local children = {}
  for _, c in pairs(node.children or {}) do
    children[#children + 1] = c
  end
  return children
end

-- Monta "java/com/nicolai/ecommerce" a partir do nó "cabeça" da cadeia,
-- descendo enquanto cada nó tiver EXATAMENTE 1 filho que também é diretório.
-- Se `node` não inicia cadeia nenhuma, retorna só o próprio basename
-- (chamador deve comparar `label == basename` para saber se houve compactação).
local function compact_label(node)
  local parts = { vim.fn.fnamemodify(node.path, ":t") }
  local current = node
  while true do
    local children = get_dir_children(current)
    if #children == 1 and children[1].dir then
      current = children[1]
      parts[#parts + 1] = vim.fn.fnamemodify(current.path, ":t")
    else
      break
    end
  end
  return table.concat(parts, "/")
end

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    picker = {
      hidden = true,
      ignored = true,
      sources = {
        files = {
          hidden = true,
          ignored = true,
        },
        explorer = {
          -- PONTO DE INTERVENÇÃO 1: esconde da listagem os nós absorvidos.
          -- `transform` roda por item; retornar `false` remove o item da
          -- lista renderizada, retornar nada (nil) mantém o comportamento
          -- padrão. Isso é feito ANTES da formatação (pontos 2 e 3 abaixo),
          -- então a lista que chega em Format.tree/Format.filename já não
          -- contém esses nós.
          --
          -- FRÁGIL: `transform` para o source "explorer" foi confirmado em
          -- uso real numa discussão da comunidade (folke/snacks.nvim
          -- discussions #2595), mas não é 100% documentado no picker.md
          -- principal. Assinatura observada: function(item, ctx).
          transform = function(item)
            if not item.dir then
              return
            end
            local Tree = require("snacks.explorer.tree")
            local node = Tree:node(item.file)
            if node and is_absorbed(node) then
              return false
            end
          end,
          actions = {
            -- Script original do usuário, sem mudanças de lógica.
            -- Continua funcionando como antes: abre a cadeia inteira de
            -- pastas-de-filho-único de uma vez só ao dar <CR>. Isso é o que
            -- faz a compactação (pontos 2 e 3) e o toggle trabalharem juntos:
            -- ao abrir a linha "cabeça", TODOS os nós absorvidos da cadeia
            -- também são abertos internamente (Tree:toggle em cada um), só
            -- que sem gerar linha própria pra cada um (por causa do
            -- `transform` acima).
            recursive_toggle = function(picker, item)
              local Actions = require("snacks.explorer.actions")
              local Tree = require("snacks.explorer.tree")
              local get_children = function(node)
                local children = {}
                for _, child in pairs(node.children) do
                  table.insert(children, child)
                end
                return children
              end
              local refresh = function()
                Actions.update(picker, { refresh = true })
              end
              ---@param node snacks.picker.explorer.Node
              local function toggle_recursive(node)
                Tree:toggle(node.path)
                refresh()
                vim.schedule(function()
                  local children = get_children(node)
                  if #children ~= 1 then
                    return
                  end
                  local child = children[1]
                  if not child.dir then
                    return
                  end
                  toggle_recursive(child)
                end)
              end
              --
              local node = Tree:node(item.file)
              if not node then
                return
              end
              if node.dir then
                toggle_recursive(node)
              else
                picker:action("confirm")
              end
            end,

            -- PONTO DE INTERVENÇÃO 4: "a" (adicionar arquivo/pasta) dentro de
            -- uma linha compactada.
            --
            -- POR QUE ISSO EXISTE: a ação nativa "explorer_add" (tecla "a"
            -- padrão do snacks) abre um prompt vazio e cria o arquivo dentro
            -- do diretório do NÓ selecionado. Só que, numa linha compactada
            -- (ex: "java" mostrando "java/com/nicolai/ecommerce"), o nó
            -- selecionado (item) é sempre a CABEÇA da cadeia ("java"), não o
            -- diretório real onde os arquivos moram ("ecommerce"). Ou seja,
            -- sem essa ação customizada, apertar "a" ali criaria o arquivo
            -- dentro de "java", não de "ecommerce" — e o prompt não dá
            -- nenhuma pista visual disso.
            --
            -- O QUE ESTA AÇÃO FAZ, PASSO A PASSO:
            --   1. acha o nó sob o cursor (ou o pai, se for um arquivo);
            --   2. desce pela cadeia de pasta única até achar o diretório
            --      REAL onde o arquivo deve ser criado (mesmo algoritmo de
            --      `compact_label`, mas guardando o nó final, não só o nome);
            --   3. abre um prompt (via `Snacks.input`) PRÉ-PREENCHIDO com o
            --      caminho compactado + "/" (ex: "user/domain/"), só pra
            --      contexto visual — o usuário digita o resto depois;
            --   4. ao confirmar, remove esse prefixo visual do valor (se o
            --      usuário manteve ele intacto, que é o uso esperado) e cria
            --      o arquivo/pasta relativo ao diretório REAL (passo 2), não
            --      relativo à cabeça da cadeia.
            --
            -- FRÁGIL / NÃO TESTADO CONTRA O NEOVIM REAL — ATENÇÃO:
            -- Diferente dos pontos 1-3 (que reaproveitam/decoram código
            -- nativo confirmado), esta ação REIMPLEMENTA na mão a criação de
            -- arquivo/pasta (mkdir/io.open), porque não consegui localizar o
            -- código-fonte exato de "explorer_add" pra decorar em cima dele
            -- com segurança. Isso significa:
            --   - `Snacks.input({ prompt, default }, callback)` foi
            --     confirmado em uso real (discussion #1748 do repositório,
            --     ação `explorer_paste_rename`), então o campo `default`
            --     pra pré-preencher o texto é confiável.
            --   - `Tree:open(path)` e `Actions.update(picker, {target=...,
            --     refresh=true})` já eram usados no `recursive_toggle` e em
            --     `M.reveal` (lua/snacks/explorer/init.lua), então também
            --     são confiáveis.
            --   - JÁ a criação de arquivo em si (`vim.fn.mkdir` + `io.open`
            --     em modo "a") é uma reimplementação MINHA, não uma cópia do
            --     que o snacks faz internamente. Funciona pro caso comum
            --     (criar 1 arquivo ou 1 pasta), mas NÃO replica possíveis
            --     detalhes do "explorer_add" original, como: aviso ao tentar
            --     sobrescrever um arquivo já existente, criação de múltiplos
            --     arquivos de uma vez, ou qualquer tratamento especial de
            --     erro que a implementação nativa faça.
            --   - Se o arquivo já existir, `io.open(path, "a")` não
            --     sobrescreve (é modo append), mas também não avisa o
            --     usuário — abre silenciosamente. Se isso for um problema,
            --     vale adicionar uma checagem de `vim.fn.filereadable(path)`
            --     antes e usar `vim.notify` pra avisar.
            --   - Se o usuário apagar/alterar o prefixo pré-preenchido antes
            --     de confirmar, o valor inteiro (sem prefixo nenhum pra
            --     remover) ainda é tratado como caminho relativo ao
            --     diretório REAL (passo 2) — ou seja, nunca volta a criar
            --     relativo à cabeça da cadeia.
            --
            -- COMO TESTAR: abrir uma linha compactada (ex: "java/com/..."),
            -- apertar "a", conferir que o prompt já vem com
            -- "java/com/.../" preenchido, digitar um nome de arquivo, dar
            -- <CR>, e conferir no sistema de arquivos que o arquivo foi
            -- criado dentro do último diretório da cadeia (não em "java").
            add_compact = function(picker, item)
              local Tree = require("snacks.explorer.tree")
              local Actions = require("snacks.explorer.actions")

              local node = item and Tree:node(item.file)
              if not node then
                return
              end
              -- se o cursor está num arquivo, usa o diretório-pai dele
              -- (mesmo comportamento esperado do "explorer_add" nativo)
              local dir_node = node.dir and node or node.parent
              if not dir_node then
                return
              end

              -- desce a cadeia de pasta única (mesma regra de compact_label)
              -- pra achar o diretório REAL onde o arquivo vai ser criado
              local tail = dir_node
              local label_parts = { vim.fn.fnamemodify(dir_node.path, ":t") }
              while true do
                local children = get_dir_children(tail)
                if #children == 1 and children[1].dir then
                  tail = children[1]
                  label_parts[#label_parts + 1] = vim.fn.fnamemodify(tail.path, ":t")
                else
                  break
                end
              end

              -- só usa prefixo visual se realmente houve compactação
              -- (cadeia com mais de 1 segmento); senão, prompt vazio como
              -- o comportamento nativo
              local prefix = ""
              if #label_parts > 1 then
                prefix = table.concat(label_parts, "/") .. "/"
              end

              Snacks.input({
                prompt = 'Add a new file or directory (directories end with "/")',
                default = prefix,
              }, function(value)
                if not value or value == "" then
                  return
                end
                -- remove o prefixo visual se o usuário manteve ele intacto
                if prefix ~= "" and value:sub(1, #prefix) == prefix then
                  value = value:sub(#prefix + 1)
                end
                if value == "" then
                  return
                end

                local is_dir = value:sub(-1) == "/"
                local target = vim.fs.normalize(tail.path .. "/" .. value)

                if is_dir then
                  vim.fn.mkdir(target, "p")
                else
                  vim.fn.mkdir(vim.fs.dirname(target), "p")
                  local fd = io.open(target, "a")
                  if fd then
                    fd:close()
                  end
                end

                Tree:open(tail.path)
                Actions.update(picker, { target = target, refresh = true })

                if not is_dir then
                  vim.schedule(function()
                    vim.cmd.edit(target)
                  end)
                end
              end)
            end,
          },
          win = {
            list = {
              keys = {
                ["<CR>"] = "recursive_toggle",
                ["a"] = "add_compact",
              },
            },
          },
        },
      },
    },
  },
  config = function(_, opts)
    -- IMPORTANTE: os monkeypatches abaixo só devem rodar DEPOIS do
    -- `require("snacks").setup(opts)`, pra garantir que o módulo
    -- "snacks.picker.format" já esteja carregado/estável antes de mexermos
    -- nele. Por isso usamos `config = function(_, opts)` em vez de deixar
    -- o lazy.nvim chamar setup() implicitamente a partir de `opts` (tabela).
    require("snacks").setup(opts)

    local Format = require("snacks.picker.format")

    -- PONTO DE INTERVENÇÃO 2: recuo (indent) da árvore.
    -- Cópia da função original `M.tree` (lua/snacks/picker/format.lua),
    -- com UMA mudança: ao subir pelos ancestrais (node.parent), pula
    -- (não insere ícone/recuo para) qualquer ancestral que seja "absorvido"
    -- — já que esse ancestral não tem linha própria, ele não deve "gastar"
    -- um nível de indentação visual.
    --
    -- FRÁGIL: se a função original `M.tree` mudar de assinatura, de nome
    -- do highlight group ("SnacksPickerTree"), ou de como monta os ícones
    -- (picker.opts.icons.tree.{vertical,middle,last}), esta cópia manual
    -- vai dessincronizar da versão real do plugin. Não há como "herdar"
    -- automaticamente mudanças da função original aqui, porque precisamos
    -- reescrever a lógica de percurso (não dá pra só "decorar" a função
    -- original chamando-a por cima, como fizemos com Format.filename).
    local tree_orig = Format.tree
    Format.tree = function(item, picker)
      if picker.opts.source ~= "explorer" then
        -- não mexe em outros pickers com tree=true (ex: lsp_symbols)
        return tree_orig(item, picker)
      end
      local ret = {}
      local icons = picker.opts.icons.tree
      local indent = {}
      local node = item
      while node and node.parent do
        if node == item or not is_absorbed(node) then
          local is_last, icon = node.last, ""
          if node ~= item then
            icon = is_last and " " or icons.vertical
          else
            icon = is_last and icons.last or icons.middle
          end
          table.insert(indent, 1, icon)
        end
        -- nota: mesmo quando o ancestral é absorvido (pulamos o ícone dele),
        -- continuamos subindo por node.parent normalmente — só não geramos
        -- segmento visual pra ele.
        node = node.parent
      end
      ret[#ret + 1] = { table.concat(indent), "SnacksPickerTree" }
      return ret
    end

    -- PONTO DE INTERVENÇÃO 3: nome exibido na linha "cabeça" da cadeia.
    -- Ao contrário do patch de Format.tree (que reescreve a função inteira),
    -- aqui DECORAMOS a função original: chamamos `filename_orig` primeiro
    -- pra obter os segmentos de texto/highlight já formatados (ícone, cor
    -- de git status, etc. continuam intactos), e só then trocamos o TEXTO
    -- do segmento que corresponde ao nome da pasta.
    --
    -- Comportamento: só compacta quando `node.open == true` (pasta aberta).
    -- Fechada, mostra só o nome próprio — ver conversa que motivou essa
    -- regra: ao fechar a pasta, mostrar o caminho inteiro era confuso/
    -- redundante já que os filhos não estão visíveis mesmo.
    --
    -- FRÁGIL (ver item "(d)" no cabeçalho do arquivo): a forma de achar o
    -- segmento certo pra substituir é comparar TEXTO (basename, ignorando
    -- "/" final), não highlight group. Se isso parar de casar, o pior caso
    -- é só não compactar (silencioso, não quebra nada).
    local filename_orig = Format.filename
    Format.filename = function(item, picker)
      local ret = filename_orig(item, picker)
      if picker.opts.source == "explorer" and item.dir then
        local Tree = require("snacks.explorer.tree")
        local node = Tree:node(item.file)
        if node and node.open then
          local basename = vim.fn.fnamemodify(node.path, ":t")
          local label = compact_label(node)
          if label ~= basename then
            for _, seg in ipairs(ret) do
              local trimmed = seg[1]:gsub("/$", "")
              if trimmed == basename then
                seg[1] = seg[1]:match("/$") and (label .. "/") or label
                break
              end
            end
          end
        end
      end
      return ret
    end
  end,
}
