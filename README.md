<div align="center">
  <img src="assets/logo.png" width="128" alt="Norte" />
  <h1>Norte 🧭</h1>
  <p><b>Kanban + agenda nativos no seu Mac, pra organizar o dia a dia de quem programa.</b></p>
  <p>
    <img alt="Plataforma" src="https://img.shields.io/badge/macOS-26%2B-8b6bff?style=flat-square" />
    <img alt="Swift" src="https://img.shields.io/badge/Swift-6-f05138?style=flat-square" />
    <img alt="Licença" src="https://img.shields.io/badge/licença-MIT-36b37e?style=flat-square" />
    <img alt="iPhone" src="https://img.shields.io/badge/iPhone-em%20breve-ffb020?style=flat-square" />
  </p>
</div>

Norte é um app **nativo de macOS** (SwiftUI) que junta num lugar só o que um dev
precisa pra não se perder entre várias frentes: um **Kanban de tarefas** (com
contexto por empresa/projeto, urgência e prazo) e a sua **agenda da semana** —
tudo com **widgets de desktop** pra bater o olho sem abrir nada.

Sem nuvem, sem login, sem servidor e **sem custo**: os dados ficam no seu Mac e a
agenda vem do calendário do próprio sistema (que já sincroniza seu Google
Calendar).

> **Feito pra vida real de dev:** trabalhar em 2 empresas + projeto próprio +
> faculdade sem virar refém de 10 abas de navegador.

## ✨ O que tem

- **Kanban** com colunas Backlog → A Fazer → Fazendo → Feito, arrastar e soltar,
  cor por **contexto** (empresa/projeto), **urgência** (🔴🟡🟢) e prazo com
  contagem regressiva.
- **Tarefas recorrentes** (diária/semanal/quinzenal/mensal) — ao concluir, a
  próxima ocorrência é criada sozinha.
- **Agenda da semana** em grade, colorida, com os eventos do seu Google Calendar.
- **Criar eventos** direto do app, no calendário do contexto.
- **Widgets de desktop**: semana em grade, dia, e um mini-kanban de tarefas a
  vencer. Clicar num widget abre o app; clicar numa tarefa abre ela pra editar.
- **Espelho inteligente**: tarefas com prazo viram eventos num calendário oculto
  "📋 Tarefas", então elas aparecem na agenda (e nos widgets) automaticamente.

## 🚀 Instalar no Mac (bizu)

Pré-requisitos: **Xcode** e **[XcodeGen](https://github.com/yonyz/XcodeGen)**
(`brew install xcodegen`).

```sh
git clone https://github.com/phmucelin/norte.git
cd norte
./scripts/install-mac.sh
```

Esse script gera o projeto, compila em **Release** (importante: os widgets do
macOS só registram em Release), instala o **Norte.app** em `/Applications` e
recarrega os widgets. Na primeira abertura, autorize o acesso ao calendário.

Depois: botão direito na Mesa → **Editar Widgets** → **Norte** → arraste
"Minha semana", "Meu dia" ou "Tarefas a vencer".

> 💡 Se os widgets aparecerem em cinza, é uma config do macOS, não do app:
> **Ajustes do Sistema → Mesa e Dock → Widgets → Estilo do widget → Colorido**.

## 📱 iPhone — em breve

A versão de **iPhone** (agenda + widgets de tela de bloqueio) **está a caminho**,
mas **ainda não está pronta pra uso**. O código do app iOS já está no repo, porém
falta acabamento e a distribuição (conta Apple). Fica ligado nas próximas
versões. 🙏

## 🛠️ Desenvolvimento

```sh
cd NorteKit && swift test     # testes de unidade da lógica (modelos, sync, agenda)
xcodegen generate             # (re)gerar o Norte.xcodeproj
open Norte.xcodeproj          # abrir no Xcode
```

**Arquitetura:** um pacote local `NorteKit` (modelos, motor de espelhamento,
helpers de agenda, serviço EventKit — tudo testável) + apps SwiftUI finos para
macOS/iOS e a extensão de widgets. Detalhes em
[`docs/superpowers/specs`](docs/superpowers/specs).

## 🤝 Contribuindo

Issues e PRs são bem-vindos! É um projeto pessoal que virou open source pra
ajudar outros devs a se organizarem. Ideias de widget, temas e integrações são
especialmente legais.

## 📄 Licença

MIT — veja [LICENSE](LICENSE). Use, modifique e compartilhe à vontade.
