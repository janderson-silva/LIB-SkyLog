# Validação — 2026-10-13

Ambiente: Windows, Delphi 10.3 Rio (dcc32/dcc64 33.0) e Delphi 13 Florence (dcc32/dcc64 37.0).

Comandos executados:

```powershell
.\scripts\build.ps1 -DelphiBin 'C:\Program Files (x86)\Embarcadero\Studio\20.0\bin' -OutputRoot 'build\Delphi10.3' -Platform All
.\scripts\build.ps1 -DelphiBin 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin' -Platform All
```

| Verificação | 10.3 Win32 | 10.3 Win64 | 13 Win32 | 13 Win64 |
| --- | --- | --- | --- | --- |
| Pacote SkyLogRuntime | Compilado | Compilado | Compilado | Compilado |
| Pacote SkyLogDesign | Compilado | Não aplicável: IDE Win32 | Compilado | Compilado |
| Testes automatizados | 40 aprovados, 0 falhas | 40 aprovados, 0 falhas | 40 aprovados, 0 falhas | 40 aprovados, 0 falhas |
| Demo VCL com DFM | Smoke aprovado | Smoke aprovado | Smoke aprovado | Smoke aprovado |
| Exceção real SQLite/FireDAC | Código 1555 | Código 1555 | Código 1555 | Código 1555 |

Os binários de cada versão foram gerados em pastas separadas. A implementação original de `CreateImplementation` continua selecionada no Delphi 13. No Delphi 10.3, o interceptador usa a RTTI do método original; para FireDAC, usa uma assinatura interna, inclusive com `OnError` vazio.

Os cinco testes adicionais verificam handlers públicos com RTTI e handlers privados sem RTTI. No Delphi 10.3, um handler sem RTTI é preservado e informado em `Diagnostics`; no Delphi 13, continua sendo interceptado. A exceção original é preservada nos dois casos. No Rio, publique o handler personalizado ou habilite RTTI para sua visibilidade para obter a captura automática desse evento.

## Verificação adicional dos pacotes de instalação Rio

Após o relato de AV em `bds.exe` ao usar Install, foram criados projetos exclusivos
para Rio em `packages\Delphi103`, compilados com o MSBuild do Delphi 10.3. O
carregamento do runtime deixou de criar o timer/janela no ramo anterior ao Delphi 13.
Os testes de execução acima foram repetidos: 40 aprovados nas quatro combinações.

`tests\SkyLog.PackageTests.dpr`, compilado em Win32 com os pacotes compartilhados
`rtl;vcl;FireDAC`, passou em: carregamento de `SkyLogRuntime103.bpl` sem criar janela,
carregamento de `SkyLogDesign103.bpl`, localização e chamada do export `Register`,
registro de `TSkyLog` na página SkyLog, criação/destruição em modo de design,
RTTI de propriedades/eventos, alteração de Enabled em design e descarregamento.

O teste usa um callback de registro em um processo separado; não executa o comando
Install dentro de `bds.exe`. A AV original ainda não foi reproduzida nem sua causa
exata comprovada. Na cópia externa configurada no Library Path do Rio, foi encontrado
um `.dproj` com `ProjectVersion=20.4` e plataformas do Delphi 13. Os novos projetos
evitam reutilizar esses metadados e as BPLs de mesmo nome entre versões.

Cobertura principal: origem/evento/método, UTF-8, exceção original, parâmetros `var` e `out`, retorno de função, evento FireDAC pré-existente e vazio, código nativo simulado 335544665, código real SQLite, isolamento de formulários e formulários filhos, conexão compartilhada com query externa, eventos aninhados, propagação sem duplicação entre wrappers, desativação/reativação, registro manual, `Execute`, `EAbort`, erro de gravação, `WindowProc`, `Refresh` dentro de um evento e destruição do logger durante callback.

O smoke test cria o formulário pelo DFM, executa os botões e verifica os registros novos de `btnErro`, `qrAux` e do código de banco. Não abre a janela para interação.

Não realizados: instalação do componente na IDE, teste interativo de todas as telas do demo, conexão a servidor Firebird real, outras versões do Delphi, FMX ou execução concorrente em threads. A mensagem Firebird do README é ilustrativa; o teste real usa SQLite em memória.
