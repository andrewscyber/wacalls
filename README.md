<div align="center">

# 📞 WaCalls — Clickmixhub

**Chamadas de voz nativas do WhatsApp direto do navegador.**  
Construído em Go puro, com suporte a múltiplas contas, WebRTC, codec MLow e autenticação por token.

[![Go](https://img.shields.io/badge/Go-1.26+-00ADD8?logo=go&logoColor=white)](https://go.dev)
[![React](https://img.shields.io/badge/React-19-61DAFB?logo=react&logoColor=black)](https://react.dev)
[![WhatsApp](https://img.shields.io/badge/whatsmeow-VoIP-25D366?logo=whatsapp&logoColor=white)](https://github.com/tulir/whatsmeow)
[![Docker](https://img.shields.io/badge/Docker-Multi--stage-2496ED?logo=docker&logoColor=white)](https://hub.docker.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](#licença)

[Visão Geral](#visão-geral) · [Arquitetura](#arquitetura) · [Quick Start](#quick-start) · [Deploy Dokploy](#deploy-dokploy) · [API](#api)

</div>

---

## Visão Geral

O WaCalls conecta uma ou mais contas do WhatsApp via **QR Code** e permite **realizar e receber chamadas de voz 1:1** de qualquer navegador. O áudio do microfone é enviado como **PCM bruto a 16 kHz por um DataChannel WebRTC** ao servidor Go, que o codifica com o codec **MLow** da Meta e injeta no relay **SRTP** do WhatsApp — e o caminho reverso traz o áudio do destinatário de volta ao navegador.

> **Tipo de API:** Este projeto usa a **API não-oficial do WhatsApp** (via whatsmeow/WhatsApp Web + QR Code).  
> Para a API Oficial da Meta (Cloud API), consulte o sistema Asterisk/SIP do Clickmixhub.

### Por que usar o WaCalls?

| Cenário | Solução |
|---------|---------|
| Clientes sem API Oficial Meta | ✅ WaCalls (QR Code + whatsmeow) |
| Clientes com API Oficial Meta | ✅ Asterisk + SIP Trunk (ver `MANUAL_VOIP_CLICKMIXHUB.md`) |

---

## Arquitetura

```
┌──────────────────────────────────────────────────────────────┐
│                     BROWSER (React + WebRTC)                 │
│   mic + speaker · DataChannel 16kHz PCM · HTTP + SSE         │
└───────────────────────────┬──────────────────────────────────┘
                             │ POST /api/sessions/{sid}/calls/{id}/webrtc
                             ▼
┌────────────────────── GO SERVER ─────────────────────────────┐
│  SessionManager  ·  Broker SSE  ·  WebRTC Bridge (pion)      │
│  internal/wa     ·  internal/voip (call · media · transport)  │
└───────────────┬─────────────────────────────┬────────────────┘
                │ <call> signaling             │ SRTP media
                ▼                             ▼
         WhatsApp WS                  WhatsApp Relay
         (whatsmeow)                  (SRTP/SCTP)
```

---

## Quick Start

### Pré-requisitos

- **Go 1.26+**
- **Node.js 22+** e **npm** (apenas para build do cliente)
- Nenhum CGO, sem DLLs — o codec MLow é Go puro

```bash
# Clonar e entrar no projeto
git clone https://github.com/andrewscyber/wacalls.git
cd wacalls

# Dependências Go
go mod download

# Dependências do cliente React
cd client && npm install && cd ..

# Rodar (modo dev)
go run ./cmd/server -addr :8080
```

Abra `http://localhost:8080`, clique em **Nova sessão** e escaneie o QR Code com  
**WhatsApp → Dispositivos conectados**.

### Cliente React em modo dev

```bash
cd client
npm run dev   # Vite em :5173 — proxy /api → http://localhost:8080
```

### Build de produção

```bash
cd client && npm run build && cd ..
go run ./cmd/server -static client/dist -addr :8080
```

---

## Deploy Dokploy

### 1. Variáveis de Ambiente

| Variável | Obrigatória | Descrição |
|----------|-------------|-----------|
| `WACALLS_TOKEN` | Recomendado | Token Bearer para autenticar a API. Vazio = sem auth. |

Gere um token seguro:
```bash
openssl rand -hex 32
```

### 2. No Dokploy

1. Crie uma aplicação do tipo **Docker Compose**
2. Aponte para o repositório `andrewscyber/wacalls`
3. Adicione a variável `WACALLS_TOKEN` nas configurações
4. Configure o domínio: `wacallsclick.clickmixhub.com`
5. Habilite HTTPS (Traefik automático)
6. Adicione um **volume persistente** mapeando `/app/data` para guardar o banco SQLite

### 3. Docker Compose (produção)

```yaml
version: "3.8"
services:
  wacalls:
    image: ghcr.io/andrewscyber/wacalls:latest
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - wacalls_data:/app/data
    environment:
      WACALLS_TOKEN: ${WACALLS_TOKEN}
volumes:
  wacalls_data:
```

---

## Autenticação

Se `WACALLS_TOKEN` estiver definido, todas as rotas `/api/*` exigem:

```
Authorization: Bearer <seu-token>
```

Se a variável estiver vazia, a autenticação é desativada (apenas para LAN/dev).

---

## Flags do Servidor

| Flag | Padrão | Descrição |
|------|--------|-----------|
| `-addr` | `:8080` | Endereço de escuta HTTP |
| `-db` | `wacalls.db` | Caminho do banco SQLite |
| `-static` | `client/dist` | Diretório dos assets do cliente |
| `-debug` | `false` | Logging verbose |
| `-max-calls-per-session` | `8` | Máx. chamadas simultâneas por sessão |

---

## API

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/api/sessions` | Listar contas |
| `POST` | `/api/sessions` | Criar conta e iniciar pareamento QR |
| `DELETE` | `/api/sessions/{sid}` | Remover conta |
| `POST` | `/api/sessions/{sid}/calls` | Iniciar chamada (`{ phone }`) |
| `POST` | `/api/sessions/{sid}/calls/{id}/webrtc` | Trocar SDP WebRTC |
| `POST` | `/api/sessions/{sid}/calls/{id}/accept` | Aceitar chamada recebida |
| `POST` | `/api/sessions/{sid}/calls/{id}/reject` | Rejeitar chamada |
| `DELETE` | `/api/sessions/{sid}/calls/{id}` | Encerrar chamada |
| `GET` | `/api/sessions/{sid}/history` | Histórico de chamadas |
| `GET` | `/api/events` | Server-Sent Events (SSE) |

---

## Testes

```bash
go test ./...                 # Testes Go (codec, SRTP, STUN, RTP, etc.)
cd client && npm run build    # Type-check + build do cliente
```

---

## Segurança

> ⚠️ O banco `wacalls.db` contém credenciais de sessão do WhatsApp. **Nunca o commite** e mantenha-o protegido com permissões corretas.

- Use sempre `WACALLS_TOKEN` em ambientes expostos à internet
- O container roda como usuário não-root (`node`, uid 1001)
- O `.dockerignore` exclui `.env` e `*.db` do contexto de build

---

## Créditos

Este projeto é baseado no excelente trabalho de:

- [**@jotadev66**](https://github.com/jotadev66) — criador do WaCalls original
- [**whatsmeow**](https://github.com/tulir/whatsmeow) — biblioteca Go para o protocolo WhatsApp Web
- [**pion/webrtc**](https://github.com/pion/webrtc) — stack WebRTC em Go puro

---

## Licença

[MIT](./LICENSE)

---

<div align="center">
<strong>Mantido pelo time Clickmixhub</strong><br/>
<a href="https://clickmixhub.com">clickmixhub.com</a>
</div>
