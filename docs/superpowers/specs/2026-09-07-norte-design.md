# Norte — Design Spec

**Data:** 2026-09-07
**Status:** Aprovado pelo usuário (chat)

## Problema

Dev trabalhando em 3 frentes (IA Solutions, Chai School, projeto Nath Pereira) + faculdade,
alternando entre MacBook e iPhone o dia todo. Precisa de:

- **Mac:** Kanban de tarefas (status, urgência, prazo) + agenda do Google Calendar, num app
  nativo — sem guia de navegador.
- **iPhone:** agenda (dia/semana) e widgets de tela de bloqueio, no estilo da referência
  visual (faixa semanal com blocos coloridos + lista do dia).
- **Custo zero.** Sem backend, sem assinatura, sem conta Apple paga.

## Decisões tomadas (com o usuário)

1. **iPhone:** app próprio instalado via Xcode com conta Apple gratuita (expira a cada 7 dias;
   reinstalação via script). Não usar conta paga por ora.
2. **Sync Mac ↔ iPhone:** espelhamento via Google Calendar (opção A). Sem Firebase/backend.
3. **Kanban:** board único com etiquetas coloridas por contexto. Colunas:
   Backlog → A Fazer → Fazendo → Feito.
4. **Calendários:** conta Google única do usuário; o app cria calendários por contexto
   (IA Solutions, Chai School, Nath Pereira, Faculdade, Pessoal) + calendário oculto
   "📋 Tarefas" para o espelho.
5. **Ambiente:** MacBook Air M4, macOS Tahoe 26, Xcode 26.6; iPhone 15, iOS 26.

## Arquitetura

Um projeto Xcode (gerado por XcodeGen a partir de `project.yml`) com:

| Target | Plataforma | Papel |
|---|---|---|
| `Norte` (macOS) | macOS 26 | Kanban + Agenda — centro de comando |
| `Norte` (iOS) | iOS 26 | Agenda dia/semana, read-only |
| `NorteWidgets` | iOS 26 | Widgets de lock screen e home screen |
| `NorteKit` | SwiftPM local | Modelos, serviços EventKit, design system compartilhados |

- **Sem rede própria.** Todo dado externo entra/sai via EventKit (calendário do sistema).
  A conta Google é sincronizada pelo próprio macOS/iOS (Ajustes → Contas de Internet).
- **Persistência de tarefas:** SwiftData, local no Mac. iPhone não tem banco de tarefas.

## Modelo de dados (SwiftData, só no Mac)

`Task`:
- `id: UUID`
- `title: String`
- `context: Context` (enum: iaSolutions, chaiSchool, nathPereira, faculdade, pessoal — cada
  um com cor e nome de exibição)
- `status: Status` (backlog, todo, doing, done)
- `urgency: Urgency` (alta 🔴, média 🟡, baixa 🟢)
- `deadline: Date?`
- `notes: String`
- `createdAt`, `completedAt: Date?`
- `mirrorEventID: String?` — identificador do evento espelhado no calendário "📋 Tarefas"

## Espelhamento (Mac → Google Calendar)

- Tarefa **com prazo** e status ≠ Feito ⇒ existe um evento no calendário "📋 Tarefas"
  no dia/hora do prazo (1h de duração; se o prazo for só data, evento de dia inteiro).
- Título do evento: `{emoji urgência} {título da tarefa}`.
- Notas do evento carregam `norte-task-id: <UUID>` para reconciliação idempotente.
- Mudou prazo/título/urgência ⇒ atualiza o evento. Concluiu ou removeu prazo ⇒ apaga o evento.
- Reconciliação roda: ao abrir o app, ao salvar qualquer tarefa e via
  `EKEventStoreChanged` (mudanças externas).
- Falha de gravação (sem permissão, calendário sumiu) ⇒ banner não-bloqueante no app com ação
  de correção; nunca perde a tarefa local.

## Primeira execução (onboarding)

1. Pede permissão de calendário (Full Access).
2. Detecta a conta Google (source CalDAV no EventKit). Se ausente, tela explicando como
   adicionar em Ajustes → Contas de Internet.
3. Cria (se não existirem) os 5 calendários de contexto + "📋 Tarefas" na conta Google,
   com as cores do design system. Idempotente por nome.

## App do Mac

- Janela única, tema escuro, materiais translúcidos (Liquid Glass nativo do Tahoe).
- **Centro:** Kanban de 4 colunas. Card mostra: barra de cor do contexto, título, bolinha de
  urgência, prazo relativo ("faltam 2d"; atrasado em vermelho). Drag & drop entre colunas
  muda status. Clique abre edição.
- **Lateral direita:** agenda do dia como linha do tempo (eventos coloridos pela cor do
  calendário) + resumo dos próximos 3 dias.
- **Topo:** chips de filtro por contexto (multi-seleção) + busca.
- **⌘N:** quick-add de tarefa (título, contexto, urgência, prazo) de qualquer tela.
- Tarefas em "Feito" há mais de 14 dias são ocultadas (não apagadas).

## App do iPhone

- **Topo:** faixa da semana — 7 colunas com mini-blocos coloridos por evento (referência
  visual do usuário). Tap num dia seleciona.
- **Corpo:** lista do dia selecionado — eventos em ordem cronológica; seção separada
  "Tarefas" com os itens do calendário "📋 Tarefas" (cor por urgência, derivada do emoji).
- Read-only. Pull-to-refresh força reload do EventKit.

## Widgets (iOS)

- **Lock screen inline:** próximo evento (hora + título).
- **Lock screen retangular:** próximos 3 itens do dia (eventos + tarefas).
- **Home screen (systemMedium):** dia atual — timeline compacta.
- Widgets leem EventKit diretamente (sem App Group, que é instável em conta gratuita).
  Timeline recarrega a cada 15 min e via `EKEventStoreChanged` no app.

## Distribuição / rotina

- **Mac:** build local, assinatura "Sign to Run Locally" — não expira.
- **iPhone:** `./scripts/install-iphone.sh` — compila e instala via `xcodebuild`/
  `devicectl` no aparelho conectado (cabo ou Wi-Fi). Necessário a cada 7 dias
  (limite da conta Apple gratuita). README documenta o ritual.

## Testes

- Unit (NorteKit): reconciliação do espelho (criar/atualizar/apagar; idempotência;
  eventos órfãos), formatação de prazo relativo, mapeamento urgência↔emoji.
  EventKit abstraído por protocolo para testes com fake em memória.
- Smoke manual documentado no README (checklist de onboarding + fluxo básico).

## Fora do escopo (v1)

Notificações, Kanban no iPhone, app de menu bar, temas, subtarefas, recorrência,
múltiplas contas Google, iPad.
