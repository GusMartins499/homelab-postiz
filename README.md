# homelab-postiz

[Postiz](https://github.com/gitroomhq/postiz-app) (agendador de posts open source, AGPL-3.0) rodando como pod **rootless** via **Podman Quadlet** no homelab. O foco é agendar posts no LinkedIn, mas ele aceita outras redes também.

## Estrutura

```
quadlet/postiz.pod                   # pod que agrupa os 4 containers (rede compartilhada em localhost)
quadlet/postiz-postgres.container    # PostgreSQL 17 — banco do Postiz e do Temporal
quadlet/postiz-redis.container       # Redis 7.2
quadlet/postiz-temporal.container    # Temporal 1.28 (fila de workflows que o Postiz usa para publicar)
quadlet/postiz-app.container         # o Postiz (frontend + backend + workers)
temporal/dynamicconfig/              # config dinâmica do Temporal
env/*.env.example                    # templates — versionados
env/*.env                            # config real com segredos — NUNCA versionado
scripts/setup-env.sh                 # gera os env/*.env com senha do banco e JWT aleatórios
scripts/deploy.sh                    # instala/atualiza as units, reinicia e publica no Tailscale
scripts/backup-postiz.sh             # pg_dump + uploads, guarda os 7 mais recentes
```

## Como funciona

- **Imagens:** versões fixadas (`postiz-app:v2.26.0`, `postgres:17-alpine`, `redis:7.2`, `temporalio/auto-setup:1.28.1`). Atualizar trocando a tag.
- **Diferenças do compose oficial:** um único Postgres serve o Postiz e o Temporal (bancos `postiz`, `temporal` e `temporal_visibility`). O Temporal usa visibilidade em SQL **sem Elasticsearch**, e o `temporal-ui` e o `admin-tools` ficam de fora. Assim o stack cabe nos ~4 GB de RAM do homelab.
- **Porta:** só o pod publica, em `127.0.0.1:4007`. Postgres, Redis e Temporal escutam só dentro do pod.
- **HTTPS:** `tailscale serve` publica em `https://home-lab.tailb8c929.ts.net:4443`, **só para a tailnet**.
- **Dados:** volumes do Podman `postiz-pgdata`, `postiz-redis`, `postiz-config` e `postiz-uploads`.
- **Limites de RAM:** app 1.5G, Temporal 512M, Postgres 384M, Redis 128M.

As portas HTTPS do `tailscale serve` no homelab:

| Porta | Serviço |
|---|---|
| `443` | n8n |
| `4443` | Postiz |
| `8443` | Syncthing |
| `10000` | Vaultwarden |

O `serve` aceita qualquer porta. A restrição a 443/8443/10000 vale só para o **Funnel**.

## Setup inicial

```bash
./scripts/setup-env.sh
./scripts/deploy.sh
```

O primeiro boot demora: o Temporal cria os schemas e o Postiz roda as migrations. Acompanhe com `podman logs -f postiz-app`.

Depois:

1. Abrir `https://home-lab.tailb8c929.ts.net:4443` e criar a conta.
2. Fechar o cadastro: `DISABLE_REGISTRATION=true` no `env/postiz.env` e `systemctl --user restart postiz-app`.

## Conectar o LinkedIn

O Postiz publica usando um app **seu** do LinkedIn.

1. Em <https://www.linkedin.com/developers/apps>, criar um app. O LinkedIn exige associar uma **Página** (pode ser uma página sua, criada só para isso).
2. Na aba **Products**, adicionar **Share on LinkedIn** e **Sign In with LinkedIn using OpenID Connect**. Para postar em Página de empresa, pedir também **Advertising API** (tem aprovação).
3. Na aba **Auth**, em *Authorized redirect URLs*, adicionar:
   ```
   https://home-lab.tailb8c929.ts.net:4443/integrations/social/linkedin
   https://home-lab.tailb8c929.ts.net:4443/integrations/social/linkedin-page
   ```
   A URL só funciona dentro da tailnet, mas isso basta: quem segue o redirect é o seu navegador, não o LinkedIn.
4. Copiar *Client ID* e *Client Secret* para `LINKEDIN_CLIENT_ID` / `LINKEDIN_CLIENT_SECRET` em `env/postiz.env` e rodar `systemctl --user restart postiz-app`.
5. No Postiz: **Add Channel → LinkedIn**.

> ⚠️ O token do LinkedIn **expira em 60 dias** e não tem refresh fora do programa de parceiros. Quando expirar, o canal aparece desconectado no Postiz e é só reconectar. Posts agendados para depois da expiração falham até você reconectar.

## API pública e MCP

Em **Settings → Public API** o Postiz gera uma API key. Com ela dá para criar e agendar posts por HTTP (`/api/public/v1/...`) ou ligar o servidor MCP do Postiz a um cliente como o Claude Code.

## Operação

```bash
systemctl --user status postiz-pod postiz-app postiz-temporal postiz-postgres postiz-redis
podman logs postiz-app --tail 50 -f
podman stats --no-stream
tailscale serve status
```

## Backup

```bash
./scripts/backup-postiz.sh
```

Gera `~/backups/postiz/postiz-AAAAMMDD-HHMMSS.tar.gz` com o dump do banco do Postiz (`pg_dump -Fc`) e os uploads. Os bancos do Temporal ficam de fora porque só guardam estado de fila. Para restaurar: `pg_restore --clean` no `postiz.dump` e `podman volume import postiz-uploads uploads.tar`.

> ⚠️ **Backup na mesma máquina não é backup.** Copiar os `.tar.gz` para fora do homelab.
