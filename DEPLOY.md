# 🚀 Guia de Deploy: WaCalls no Dokploy

## Domínio: `wacallsclick.clickmixhub.com`

---

## Pré-requisitos

- Dokploy instalado e funcionando
- Acesso ao painel do Dokploy
- DNS do domínio `wacallsclick.clickmixhub.com` apontando para o servidor

---

## Passo 1 — Criar a Aplicação no Dokploy

1. Acesse o painel do Dokploy
2. Clique em **New Application** → **Docker Compose**
3. Preencha:
   - **Name:** `wacalls`
   - **Description:** WaCalls — Chamadas WhatsApp by Clickmixhub

---

## Passo 2 — Configurar o Repositório GitHub

1. Em **Source** → **GitHub**
2. Selecione o repositório: `andrewscyber/wacalls`
3. Branch: `main`
4. **Auto Deploy on Push:** ✅ Habilitar

---

## Passo 3 — Variáveis de Ambiente

No painel do Dokploy, em **Environment Variables**, adicione:

```env
WACALLS_TOKEN=<seu-token-seguro-aqui>
```

> Para gerar um token seguro: `openssl rand -hex 32`

---

## Passo 4 — Volume Persistente (CRÍTICO)

O banco SQLite armazena as credenciais das sessões WhatsApp. **Sem volume, as sessões são perdidas a cada restart.**

No Dokploy → **Volumes**:

| Host Path | Container Path | Descrição |
|-----------|---------------|-----------|
| `/data/wacalls` | `/app/data` | Banco SQLite + dados de sessão |

Ou via Docker Compose (já configurado no repositório):
```yaml
volumes:
  - wacalls_data:/app/data
```

---

## Passo 5 — Configurar o Domínio

No Dokploy → **Domains**:

| Campo | Valor |
|-------|-------|
| **Domain** | `wacallsclick.clickmixhub.com` |
| **HTTPS** | ✅ (Let's Encrypt automático) |
| **Port** | `8080` |
| **Path** | `/` |

---

## Passo 6 — Configurar o Traefik (se necessário)

Se o Dokploy usa Traefik, adicione as labels no `docker-compose.yml`:

```yaml
services:
  wacalls:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wacalls.rule=Host(`wacallsclick.clickmixhub.com`)"
      - "traefik.http.routers.wacalls.entrypoints=websecure"
      - "traefik.http.routers.wacalls.tls.certresolver=letsencrypt"
      - "traefik.http.services.wacalls.loadbalancer.server.port=8080"
```

---

## Passo 7 — Deploy

1. Clique em **Deploy** no Dokploy
2. O Dokploy irá:
   - Clonar o repositório `andrewscyber/wacalls`
   - Executar o `docker-compose.yml`
   - Buildar a imagem Docker (multi-stage: Node → Go → Alpine)
   - Iniciar o container
3. Aguarde ~3-5 minutos para o build completo (primeira vez)

---

## Passo 8 — Verificar o Deploy

Após o deploy:

```bash
# Testar a API (sem token — se WACALLS_TOKEN estiver vazio):
curl https://wacallsclick.clickmixhub.com/api/sessions

# Testar com token:
curl -H "Authorization: Bearer <seu-token>" https://wacallsclick.clickmixhub.com/api/sessions
```

Resposta esperada:
```json
{"sessions": []}
```

---

## Passo 9 — Parear a Primeira Conta WhatsApp

1. Acesse: `https://wacallsclick.clickmixhub.com`
2. Clique em **Nova sessão**
3. Escaneie o QR Code com **WhatsApp → Dispositivos conectados**
4. A sessão ficará como `open` / `paired: true`
5. Pronto para fazer chamadas!

---

## 🔄 Atualização Automática

Cada push na branch `main` do repositório `andrewscyber/wacalls` irá:
1. Executar o CI (testes Go + build React)
2. Buildar e fazer push da imagem para `ghcr.io/andrewscyber/wacalls:latest`
3. O Dokploy detecta o novo push e faz o re-deploy automaticamente

---

## ⚠️ Importante — Segurança

- O banco `wacalls.db` contém credenciais de sessão WhatsApp. **Sempre use volume persistente.**
- Configure `WACALLS_TOKEN` em produção. Sem ele, qualquer pessoa com acesso ao domínio pode criar sessões.
- O HTTPS é obrigatório em produção (WebRTC exige contexto seguro para acessar o microfone).

---

## 🔧 Configuração de Portas

| Porta | Uso |
|-------|-----|
| `8080` | HTTP do servidor Go (interno) |
| `443` | HTTPS público (Traefik/Dokploy) |

> **Não é necessário abrir a porta 8080 publicamente** — o Traefik faz o proxy.

---

## 📋 Checklist Final

- [ ] DNS configurado: `wacallsclick.clickmixhub.com` → IP do servidor
- [ ] `WACALLS_TOKEN` definido no Dokploy
- [ ] Volume persistente mapeado para `/app/data`
- [ ] HTTPS habilitado
- [ ] Primeiro deploy concluído
- [ ] QR Code escaneado e sessão pareada
