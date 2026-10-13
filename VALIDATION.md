# Histórico de validação — 2026-10-13

## Alterações posteriores sem execução

As alterações de gravação do formato 2 (identificação de aplicação/build,
execução/correlação/registro, fuso horário, rotação, retenção e novos eventos de
pilha/diagnósticos/limpeza) receberam somente revisão estática do código e da
documentação. Por solicitação do usuário, não foram feitos build, compilação,
execução de testes nem criação de exemplos. Os resultados históricos abaixo
não validam essas alterações.

## Validação histórica

Este registro descreve a validação anterior à adoção dos sufixos de Package version
`260`/`370`. Os nomes e comandos abaixo são históricos; scripts, exemplos e testes
não fazem parte da estrutura atual. A renomeação para `Delphi260`/`Delphi370` e
`SkyLogRuntime260`/`SkyLogDesign260`/`SkyLogRuntime370`/`SkyLogDesign370` não inclui
nova compilação, execução de testes ou instalação na IDE.

Ambiente: Windows, Delphi 10.3 Rio (dcc32/dcc64 33.0) e Delphi 13 Florence
(dcc32/dcc64 37.0). Validação após a organização dos projetos por versão.

## Compilação e execução

```powershell
.\scripts\build.ps1 -DelphiBin 'C:\Program Files (x86)\Embarcadero\Studio\20.0\bin' -Platform All
.\scripts\build.ps1 -Platform All
```

No segundo comando, o PATH apontava para o Delphi 13. O script identificou os
compiladores 33.0/37.0 e selecionou os projetos de `packages\Delphi103` e
`packages\Delphi13`, respectivamente. Os pacotes foram compilados via MSBuild,
com os mesmos `.dproj` disponibilizados para a IDE.

| Verificação | 10.3 Win32 | 10.3 Win64 | 13 Win32 | 13 Win64 |
| --- | --- | --- | --- | --- |
| Runtime por versão | Compilado | Compilado | Compilado | Compilado |
| Design por versão | Compilado | Não aplicável: IDE Win32 | Compilado | Compilado |
| Testes do componente | 40 aprovados, 0 falhas | 40 aprovados, 0 falhas | 40 aprovados, 0 falhas | 40 aprovados, 0 falhas |
| Carregamento/registro das BPLs | Aprovado | Não aplicável | Aprovado | Aprovado |
| Demo VCL com DFM | Smoke aprovado | Smoke aprovado | Smoke aprovado | Smoke aprovado |
| Exceção real SQLite/FireDAC | Código 1555 | Código 1555 | Código 1555 | Código 1555 |

Saídas padronizadas: `build\Delphi103\<plataforma>\Release` e
`build\Delphi13\<plataforma>\Release`. O componente em `source\SkyLog.pas` não foi
alterado durante esta reorganização. Os nomes do Rio foram mantidos; os nomes
novos do Florence são `SkyLogRuntime13`/`SkyLogDesign13`.

## Cobertura

Origem/evento/método, UTF-8, exceção original, parâmetros `var`/`out`, retorno de
função, evento FireDAC pré-existente e vazio, código nativo simulado 335544665,
código real SQLite, isolamento entre formulários, conexão compartilhada,
eventos aninhados, propagação sem duplicação entre wrappers, desativação/reativação,
registro manual, `Execute`, `EAbort`, erro de gravação, `WindowProc`, `Refresh`
dentro de evento e destruição do logger durante callback.

Handlers públicos com RTTI são interceptados em ambas as versões. Um handler
privado sem RTTI permanece intacto e é informado em `Diagnostics` no Rio; no
Florence continua sendo interceptado. O FireDAC usa uma assinatura interna no Rio.

O teste dos pacotes usa RTL/VCL/FireDAC compartilhados, carrega runtime/design,
localiza e chama o export `Register`, verifica a classe e a página da paleta,
cria/destrói uma instância em modo de design, consulta propriedades por RTTI,
altera Enabled e descarrega as BPLs. Também verifica que o carregamento do runtime
Rio não cria janela. A identificação do export contempla os nomes decorados de
Win32 e Win64.

O smoke test carrega o DFM do demo e verifica os registros de `btnErro`, `qrAux`
e do código de banco, sem abrir janela para interação.

## Instalação na IDE e limites

O usuário confirmou que a instalação direta de `SkyLogDesign103.bpl` por
**Component > Install Packages > Add** funcionou no Delphi 10.3. O comando Install
do projeto havia apresentado uma AV em `bds.exe`; a causa exata não foi comprovada.
Por isso a documentação orienta a instalação direta da BPL compilada.

O teste automatizado de registro executa em processo separado, não dentro da IDE.
Não foi executada automaticamente uma nova instalação nos caminhos reorganizados,
nem a instalação dos novos nomes do Delphi 13. As entradas antigas devem ser
atualizadas conforme `packages\README.md`.

Não realizados: teste interativo de todas as telas do demo, conexão a servidor
Firebird real, outras versões do Delphi, FMX ou execução concorrente em threads.
