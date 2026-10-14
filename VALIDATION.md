# Validação — 2026-10-14

## Resultado atual

Foram compilados os pacotes atuais e executadas as suítes recuperadas/ampliadas
usando `scripts/build.ps1`, nas instalações locais do Delphi 10.3 Rio (20.0),
12 Athens (23.0) e 13 Florence (37.0). Os testes exercitam o componente real e
inspecionam os arquivos gravados; não usam uma reimplementação do mascaramento.

| Verificação | 10.3 Win32 | 10.3 Win64 | 12 Win32 | 12 Win64 | 13 Win32 | 13 Win64 |
| --- | --- | --- | --- | --- | --- | --- |
| Pacote runtime, Release | OK | OK | OK | OK | OK | OK |
| Pacote design, Release | OK | N/A | OK | N/A | OK | OK |
| Suíte recuperada | 40/40 | 40/40 | 40/40 | 40/40 | 40/40 | 40/40 |
| Novas regressões | 67/67 | 67/67 | 67/67 | 67/67 | 67/67 | 67/67 |
| Carregamento/registro/descarregamento das BPLs | OK | N/A | OK | N/A | OK | OK |

Total funcional: **642 verificações, zero falhas**, mais as verificações dos
pacotes. N/A: estas instalações do Rio/Athens não oferecem pacote de design Win64.
O teste de registro usa um processo separado; não instala nem altera a IDE.

Antes da correção, os 36 casos de mascaramento foram executados no Delphi 13
Win32: **18 falharam**. Após a correção, os mesmos 36 passam em toda a matriz.
Na execução em Rio/Athens, a suíte também detectou que `TJSONNumber` herda de
`TJSONString` nessas versões: números comuns estavam sendo convertidos em
strings. O tratamento agora preserva os tipos de escalares sem correspondência
e substitui integralmente escalares que contenham um literal sensível.

### Cobertura adicionada

- Literais numéricos em JSON, arrays e objetos aninhados; correspondência parcial;
  proteção de chaves; booleanos/null; preservação dos demais tipos.
- Segredos sobrepostos, ordens distintas, sobreposição consigo mesmo, valores
  repetidos/vazios, comparação sensível a maiúsculas, marcador sem reprocessamento.
- Campos sensíveis recursivos, texto entre aspas, CPF/CNPJ e desativação da
  proteção, tanto em JSON Lines quanto em texto.
- UTF-8, escape de quebras/aspas, uma linha física por registro, tipos do esquema,
  padrões do construtor e carregamento de DFM antigo sem as novas propriedades.
- Matriz de filtros de nível e `Enabled=False` para registro manual.
- DataModules: eventos reais interceptados, origem manual, limites de propriedade,
  contexto ordenado entre escopos e ausência de duplicação na propagação.
- Identidade da exceção original preservada com filtro ativo e falha de gravação;
  mascaramento de metadados/pilha/diagnósticos e recuperação após falha de escrita.
- Rotação por tamanho, registro maior que o limite, limite desativado e troca de
  formato sem misturar arquivos.
- Retenção de `.jsonl`/`.log`, dia de fronteira, modificação recente, arquivos
  alheios/subpastas preservados, arquivo bloqueado, callback com erro e frequência
  máxima diária por política.
- Propriedades novas e seus padrões acessíveis via RTTI no pacote de design.

### Reprodução e evidências

Os comandos estão no README e em `tests/README.md`. Cada execução preserva
artefatos e evidências em `build/Delphi260`, `build/Delphi290` ou `build/Delphi370`,
subpastas `<Win32|Win64>/Release`:

- `build-Runtime.log`, `build-Design.log`: compilação dos `.dproj` com MSBuild.
- `compile-SkyLog.Tests.log`, `run-SkyLog.Tests.log`: suíte recuperada.
- `compile-SkyLog.Features.log`, `run-SkyLog.Features.log`: novas regressões.
- `compile-packages.log`, `run-packages.log`: teste de carregamento e registro,
  quando houver pacote de design disponível para a arquitetura.
- `tests/test-output-*` e `tests/features-*`: arquivos gerados pelos testes.

Essas saídas são ignoradas pelo Git. O compilador ainda emite o aviso já existente
W1002 referente a `TSearchRec.FindData`, API específica de Windows usada na retenção.

### Limites desta execução

Não foram testados instalação interativa na IDE, todas as telas da demo,
Firebird em servidor real, FMX, concorrência em workers nem falhas de energia.
Não há promessa de cobertura exaustiva para todos os formatos de dados sensíveis.
A captura continua restrita à thread principal, conforme o README.

## Validação histórica — 2026-10-13

Este registro descreve a validação anterior à adoção dos sufixos de Package version
`260`/`370`. Os nomes e comandos abaixo são históricos; os scripts e testes atuais
foram recuperados e adaptados na execução de 2026-10-14. A renomeação original para `Delphi260`/`Delphi370` e
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
