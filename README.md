# git-issue

git-issue é um conjunto de scripts que usa o próprio object store do Git para gerenciar “issues” como referências (`refs/issues/*`) e árvores/commits, sem depender de um servidor externo. Ele também inclui uma página web (React) que lê essas refs via API do GitHub e exibe as issues e mensagens.

## Conceito

- Cada issue é um ref: `refs/issues/ISS-<ID>` apontando para um commit cujo tree contém:
  - `title`: blob com o título da issue
  - `status`: blob com o estado (ex.: `open`)
  - `msgs/`: diretório com blobs, cada um representando uma mensagem/resposta (`ISS-<id>-<id_msg>`) 
- Operações (new/reply/edit) constroem árvores com `git mktree` e criam commits com `git commit-tree`, atualizando o ref via `git update-ref`.

## Requisitos

- Git instalado e configurado (`user.name` e `user.email`).
- `$EDITOR` (ou `$VISUAL`) definido; se não estiver, os scripts usam `vi` por padrão.

## Scripts disponíveis

- `./git-issue new "Título da issue"`
  - Cria uma nova issue. Abre o editor para a primeira mensagem. 
  - Atualiza `refs/issues/ISS-<ID>` com um commit raiz (sem parent), contendo `title`, `status` e `msgs/<msg_id>`.
- `./git-issue show ISS-<ID>`
  - Mostra o título e lista todas as mensagens (`msgs/*`), indicando o autor do commit que inclui cada mensagem.
- `./git-issue reply ISS-<ID>`
  - Adiciona uma mensagem na issue. Abre o editor para o conteúdo. 
  - Cria um commit com parent no tip atual de `refs/issues/ISS-<ID>` e atualiza o ref.
- `./git-issue edit-title ISS-<ID>`
  - Edita o título da issue, criando um novo commit (com parent) e atualizando o ref.
- `./git-issue edit-msg <MSG_ID>`
  - Edita o conteúdo de uma mensagem específica, preservando o id e criando novo commit.
- `./git-issue ls`
  - Lista todas as issues (`refs/issues/*`) com seus títulos.
- `./git-issue pull` / `./git-issue push` / `./git-issue sync`
  - Sincronizam os refs de issues com o remoto: fetch/push de `refs/issues/*`.

## Fluxo recomendado

1. Antes de responder/editar em um clone novo, traga os refs de issues:
   - `git fetch origin 'refs/issues/*:refs/issues/*'` ou `./git-issue pull`
2. Crie respostas/edições normalmente (`reply`, `edit-*`).
3. Faça push:
   - `git push origin 'refs/issues/*:refs/issues/*'` ou `./git-issue push`

Se o push for rejeitado (non-fast-forward), traga as atualizações (`pull`) e re‑aplique sua alteração na ponta atual (os scripts já usam o parent do tip local). Evite criar respostas com ref inexistente localmente, pois isso gera commits raiz.

## Web (GitHub Pages)

Há um app em `web/` (React + Vite) que consome a API do GitHub para:
- Listar issues lendo `matching-refs` em `refs/issues/*`.
- Exibir uma issue (título e mensagens). Para cada mensagem, mostra o autor do primeiro commit que adicionou aquele arquivo.

Link (GitHub Pages):
- https://FCO.github.io/git-issue/

### Rodando localmente

- `cd web`
- `npm install`
- `npm run dev`

### Publicando no GitHub Pages

O repositório já está configurado para publicar a partir da pasta `docs/` ou via branch `gh-pages`.

- Deploy via `docs/` (branch main):
  - `cd web && npm run deploy`
  - Isso faz build e copia `web/dist` → `docs/`. Faça commit/push da pasta `docs/`.
  - Em Settings → Pages, selecione Source: Deploy from a branch, Branch: `main`, Folder: `/docs`.

- Deploy via `gh-pages`:
  - Crie a branch `gh-pages` se ainda não existir: `git branch gh-pages && git push -u origin gh-pages`
  - `cd web && npm run deploy:ghpages`
  - Em Settings → Pages, selecione Branch: `gh-pages`, Folder: `/root`.

### Limites de API / Cache

- Requests sem autenticação: ~60 por hora por IP; com token: ~5.000/h.
- O app usa `ETag` e `If-None-Match` (localStorage) para reduzir chamadas e respeitar rate limits.
- Para aumentar limites, defina um token e adicione `Authorization: Bearer <TOKEN>` (pode ser parametrizado via `.env` no app).

## Dicas e troubleshooting

- “Failed to fetch” / rate limit: autentique e/ou aguarde o `X-RateLimit-Reset`; verifique headers: `X-RateLimit-*`.
- “non-fast-forward” ao dar push: faça `./git-issue pull` e refaça sua resposta/edição; verifique o parent do commit:
  - `git log --pretty='%H %P' -n 1 $(git rev-parse refs/issues/ISS-<ID>)`
- Editor vazio: defina `$EDITOR` ou `$VISUAL`; por padrão será `vi`.

## Licença

Este projeto é experimental e usa Git como backend para issues. Use com cuidado e faça backup dos seus refs/objetos conforme necessário.
