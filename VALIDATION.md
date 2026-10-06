# Validação — 2026-10-06

Ambiente: Windows, Delphi 13 Florence, compiladores dcc32/dcc64 versão 37.0.

Comando: `scripts\build.ps1 -Platform All`.

| Verificação | Win32 | Win64 |
| --- | --- | --- |
| Pacote SkyLogRuntime | Compilado | Compilado |
| Pacote SkyLogDesign | Compilado | Compilado |
| Testes automatizados | 35 aprovados, 0 falhas | 35 aprovados, 0 falhas |
| Demo VCL com DFM | Compilado e executado em modo smoke | Compilado e executado em modo smoke |
| Exceção real SQLite/FireDAC | Chave duplicada, código 1555 | Chave duplicada, código 1555 |

Cobertura principal: origem/evento/método, UTF-8, exceção original, parâmetros `var` e `out`, retorno de função, evento FireDAC pré-existente e vazio, código nativo simulado 335544665, código real SQLite, isolamento de formulários e formulários filhos, conexão compartilhada com query externa, eventos aninhados, propagação sem duplicação entre wrappers, desativação/reativação, registro manual, `Execute`, `EAbort`, erro de gravação, `WindowProc`, `Refresh` dentro de um evento e destruição do logger durante callback.

O smoke test cria o formulário pelo DFM, executa os botões e verifica os registros novos de `btnErro`, `qrAux` e do código de banco. Não abre a janela para interação.

Não realizados: instalação do componente na IDE, teste interativo de todas as telas do demo, conexão a servidor Firebird real, versões anteriores do Delphi, FMX ou execução concorrente em threads. A mensagem Firebird do README é ilustrativa; o teste real usa SQLite em memória.
