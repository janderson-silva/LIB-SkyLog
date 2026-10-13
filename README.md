# SkyLog — componente Delphi VCL

`TSkyLog` registra exceções do **formulário que é seu Owner**, dos controles e dos componentes pertencentes a esse formulário. Coloque uma instância em cada formulário que deseja monitorar e configure `LogDirectory`.

Arquivos em UTF-8 separados por dia e execução, com rotação por tamanho, retenção configurável e data/hora local com milissegundos e fuso. A pasta é criada automaticamente. O componente mantém o tratamento normal da aplicação: registra e propaga a exceção original.

## Guia rápido

1. [Instale o pacote](#instalação-na-paleta) da sua versão do Delphi.
2. Coloque um `TSkyLog` em cada formulário que deseja monitorar. O formulário deve ser o `Owner` (proprietário) do logger; os componentes monitorados devem pertencer à sua árvore de proprietários.
3. Configure `LogDirectory` para uma pasta com permissão de escrita. Se ficar vazio, será usada a pasta `logs` junto ao executável.
4. Mantenha `Enabled = True`. Instâncias colocadas pela IDE são ativadas automaticamente ao carregar o formulário.
5. Quando uma exceção escapar de um evento monitorado, consulte o arquivo na subpasta `skylog-v2-...` do destino. O registro identifica a origem e o motivo; arquivo e linha do fonte dependem de uma pilha com símbolos.

Não é necessário alterar o DPR nem `Application.OnException`. Se você tratar e consumir o erro com `try/except`, use `LogException` dentro do `except`. Para componentes criados em código ou eventos trocados durante a execução, chame `Refresh` depois da configuração.

**Consulta:** [Compatibilidade](#compatibilidade) · [Configuração](#configuração) · [Como ler o log](#como-ler-o-log) · [Métodos públicos](#métodos-públicos) · [Componentes criados em código](#componentes-criados-em-código) · [Registro manual](#erros-tratados-e-operações-explícitas) · [Cobertura e limites](#cobertura-e-limites) · [Gravação e retenção](#gravação)

## Compatibilidade

- Windows, VCL, Win32 e Win64.
- Há validação histórica para **Delphi 10.3 Rio (compilador 33.0)** e **Delphi 13 Florence (compilador 37.0)**, em Win32 e Win64. A renomeação dos pacotes e as alterações de gravação/formato descritas aqui **não foram compiladas nem testadas**; consulte o [histórico de validação](VALIDATION.md). Os projetos de Delphi 12 também permanecem sem validação por compilação.
- No Delphi 13, permanece a implementação original com `TRttiInvokableType.CreateImplementation`. Antes do Delphi 13, a criação do interceptador usa `TRttiMethod.CreateImplementation`, disponível no Rio.
- **No Delphi 10.3, o método atribuído ao evento precisa de RTTI estendida**. Os handlers publicados dos formulários (como os criados pela IDE) e métodos públicos com RTTI padrão são atendidos. Para handlers privados/protegidos personalizados, publique o método ou habilite a geração de RTTI para sua visibilidade. Sem essa informação, o evento fica intacto e aparece em `Diagnostics`; `Execute` e `LogException` continuam disponíveis. O `OnError` do FireDAC usa uma assinatura interna e funciona mesmo sem handler anterior ou sem RTTI no handler. O Delphi 13 mantém a captura baseada apenas na RTTI do tipo do evento.
- FireDAC é uma dependência do pacote. A aplicação continua escolhendo seu driver: Firebird, InterBase, SQLite etc.
- Não é um componente FMX nem compatível com Delphi 7/XE nesta implementação.

## Instalação na paleta

Os projetos são separados por versão e compartilham o código em `source`:

Pastas e projetos usam o **Package version**: `260` para Delphi 10.3 Rio e `370`
para Delphi 13 Florence.

| Delphi | Projeto de runtime | Projeto de design |
| --- | --- | --- |
| 10.3 Rio | `packages\Delphi260\SkyLogRuntime260.dproj` | `packages\Delphi260\SkyLogDesign260.dproj` |
| 13 Florence | `packages\Delphi370\SkyLogRuntime370.dproj` | `packages\Delphi370\SkyLogDesign370.dproj` |

1. Abra o projeto de runtime da sua versão e execute **Build**, em **Release**.
2. Abra o projeto de design correspondente e execute **Build** na mesma plataforma.
3. Em **Component > Install Packages > Add**, selecione a BPL de design gerada em
   `build\Delphi260\<plataforma>\Release` ou `build\Delphi370\<plataforma>\Release`.
   Mantenha a BPL de runtime junto dela. A instalação direta da BPL foi confirmada
   pelo usuário no Delphi 10.3 antes da renomeação, após uma AV no comando Install do projeto.
4. Adicione `source` ao **Library path** das plataformas usadas pela aplicação.
5. Na paleta **SkyLog**, coloque `TSkyLog` no formulário e configure `LogDirectory`.

Use Win32 para o design do Delphi 10.3. No Delphi 13, use a arquitetura da IDE
(Win32 ou Win64). O runtime pode ser compilado nas duas plataformas em ambas as versões.

Não misture DCUs, DCPs ou BPLs de versões/arquiteturas diferentes. Ao atualizar uma
instalação antiga, remova sua entrada antes de adicionar a nova BPL, evitando carregar
simultaneamente dois pacotes que contenham `SkyLog`. Consulte as
[instruções de migração e organização](packages/README.md), incluindo os novos
nomes e caminhos de saída das duas versões.

No Rio, o timer interno só é criado
ao iniciar o monitoramento em execução; o comportamento do Delphi 13 é preservado.

## Configuração

Propriedades de configuração:

| Propriedade | Função |
| --- | --- |
| `Enabled` | Ativa/desativa a captura. Padrão: `True`. |
| `LogDirectory` | Pasta-base. Vazia: `logs` junto ao executável. Caminhos relativos também são resolvidos a partir do executável. Os arquivos ficam em uma subpasta exclusiva da aplicação. |
| `LogAbort` | Inclui `EAbort` no log. Padrão: `False`, pois `Abort` é frequentemente usado para cancelar uma operação. |
| `ApplicationName` | Nome registrado da aplicação. Vazio: nome do executável. |
| `ApplicationVersion` | Versão registrada. Vazia: `FileVersion` numérica do executável; sem esse recurso, `n/a`. |
| `ApplicationBuild` | Identificador de build, que pode receber a identificação da entrega. Vazio: quarto número de `FileVersion`; sem esse recurso, `n/a`. |
| `MaxFileSizeMB` | Limite por segmento, em unidades de 1.048.576 bytes. Padrão: `10`. Zero desativa a rotação por tamanho. Negativos são recusados. |
| `RetentionDays` | Número de dias de calendário preservados, incluindo hoje. Padrão: `30`. Zero desativa a limpeza. Negativos são recusados. |

Eventos e informações de diagnóstico (as propriedades `LastWriteError`, `LastCleanupError`, `Diagnostics` e `MonitoredForm` são consultadas em código):

| Membro | Função |
| --- | --- |
| `OnWriteError` | Avisa quando não foi possível gravar; recebe arquivo e mensagem. |
| `LastWriteError` | Última falha de gravação, disponível em código. Esvazia após gravação bem-sucedida. |
| `OnCleanupError` | Avisa sobre falha de retenção, separadamente da gravação; recebe caminho e mensagem. O registro atual já foi gravado. |
| `LastCleanupError` | Falha da última limpeza executada por esta instância. Esvazia após uma limpeza bem-sucedida; gravações sem limpeza não apagam esse diagnóstico. |
| `OnGetStackTrace` | Integra um provedor de pilha. Recebe a exceção, o endereço disponível e o texto da pilha por referência. |
| `Diagnostics` | Lista de eventos cuja assinatura não pôde ser interceptada e de falhas em `OnDiagnostics`. É renovada por `Refresh`. |
| `OnDiagnostics` | Notificação ao final de `Refresh` quando há diagnósticos. Eles também são enviados à saída de depuração. |
| `MonitoredForm` | Formulário que é o `Owner` do logger; retorna `nil` se o proprietário não for um formulário. |

Instâncias carregadas pelo DFM são ativadas em `Loaded`, antes do `OnCreate` no ciclo normal da VCL (`OldCreateOrder=False`). Nenhuma alteração no DPR ou em `Application.OnException` é necessária.

## Como ler o log

### Exemplo de erro de conversão

```text
[2026-10-13T16:16:41.291-04:00] Formato: 2 | Aplicacao: Project1.exe | Versao: 1.0.0.0 | Build: 0 | Execucao: 717ABCA893F046BF96E0D266B24F0E60 | Origem: Form1.Button1 | Formulario: Form1 | Componente: Button1 (TButton) | Evento: OnClick | Metodo: TForm1.Button1Click | Excecao: EConvertError | Codigo: n/a | Fase: Evento | PID: 12784 | Thread: 11012 | Correlacao: {2F7D5BD3-6EEF-477E-AC1B-D862D1C1D659} | Registro: {C580F9A0-6321-4CC9-B296-F293CA53224A} | Endereco: 0x00424A56 | Erro: 'a' is not a valid integer value
  Contexto: Form1.Button1.WindowProc(0x0202) [n/a] -> Form1.WindowProc(0x0111) [n/a] -> Form1.Button1.WindowProc(0xBD11) [n/a] -> Form1.Button1.OnClick [TForm1.Button1Click]
  StackTrace: n/a
```

**Leitura do exemplo:** durante o clique em `Button1`, uma conversão do texto `'a'` para inteiro falhou. A exceção escapou de `TForm1.Button1Click`, possivelmente vinda de uma rotina chamada por ele. O log identifica o evento e o motivo, mas não informa a linha exata nem qual função fez a conversão.

### Campos da linha principal

| Campo | Significado e utilidade |
| --- | --- |
| Data/hora entre `[]` | Momento da captura no fuso local da máquina. No exemplo: 13/10/2026 às 16:16:41 e 291 milissegundos; `T` separa data e hora, e `-04:00` indica quatro horas atrás de UTC. Permite ordenar e comparar ocorrências entre fusos. |
| `Formato` | Versão da estrutura do registro, atualmente `2`. Orienta ferramentas que leem o arquivo; é independente da versão da aplicação. |
| `Aplicacao` | Nome do executável, como `Project1.exe`, ou o valor de `ApplicationName`. Identifica qual programa gerou o erro. |
| `Versao` | `FileVersion` numérica do executável ou `ApplicationVersion`. Ajuda a localizar as versões afetadas. A versão automática vem da aplicação, não da BPL do SkyLog. |
| `Build` | Identificação da compilação/entrega. Usa `ApplicationBuild` ou, por padrão, o quarto número de `FileVersion`. Em `1.0.0.0`, o build automático é `0`. |
| `Execucao` | Identificador da sessão da biblioteca no processo, compartilhado pelos componentes. Agrupa logs da mesma execução e separa execuções diferentes. |
| `Origem` | Caminho do componente pela cadeia de `Owner`, como `Form1.Button1`. Distingue componentes com nomes iguais em formulários diferentes. |
| `Formulario` | Nome do formulário monitorado. Pode ser diferente do título exibido na janela (`Caption`). |
| `Componente` | Nome e classe do componente: `Button1 (TButton)` identifica a instância e seu tipo. |
| `Evento` | Evento ou operação em andamento, como `OnClick`, `OnError`, `ExecSQL` ou `WindowProc(0x0202)`. |
| `Metodo` | Handler (método ligado ao evento), como `TForm1.Button1Click`. É o ponto inicial da investigação; a falha pode vir de uma rotina chamada por ele. Pode ser informado manualmente em `LogException`. |
| `Excecao` | Classe da exceção. `EConvertError` indica erro de conversão; a mensagem explica qual conversão falhou. |
| `Codigo` | Código numérico extraído de erros FireDAC ou `EOSError`. Para o `EConvertError` do exemplo, aparece `n/a`, pois a biblioteca não extrai um código desse tipo de exceção. |
| `Fase` | Ponto em que o SkyLog observou a exceção. Os valores estão na tabela abaixo. Não representa o nível de gravidade. |
| `PID` | Identificador do processo no Windows. Ajuda a relacionar o log à instância em ferramentas de diagnóstico. Pode ser reutilizado pelo Windows após o processo terminar. |
| `Thread` | Identificador da thread (linha de execução) que gravou o registro. No uso suportado pelo componente, a captura ocorre na thread principal da VCL. |
| `Correlacao` | Identificador da cadeia de eventos/operações monitorados. Reúne registros relacionados à mesma ação, que pode produzir mais de uma exceção. |
| `Registro` | Identificador exclusivo desta entrada. Permite apontar uma ocorrência específica, mesmo quando várias têm a mesma correlação. |
| `Endereco` | Endereço de memória associado à exceção; `0x` indica hexadecimal. Na captura de evento, vem de `ExceptAddr`. Com símbolos da mesma compilação, ajuda a localizar o código; sozinho não informa a linha do fonte. |
| `Erro` | Mensagem da exceção. No exemplo, significa: “`'a'` não é um valor inteiro válido”. |

`n/a` significa informação ausente, indisponível ou não aplicável ao campo. Não indica, por si só, falha na gravação.

| `Fase` | Quando é usada |
| --- | --- |
| `Evento` | A exceção escapou de um handler monitorado, como `OnClick`. |
| `Mensagem` | A exceção escapou do processamento de uma mensagem em `WindowProc`. |
| `FireDAC` | O banco notificou um erro por um evento `TFDErrorEvent`, como `OnError`. |
| `Manual` | A aplicação chamou `LogException`. |
| `Operacao` | A exceção escapou de uma ação passada a `Execute`. |

Para distinguir os identificadores: **`Execucao` = sessão do programa; `Correlacao` = cadeia monitorada; `Registro` = entrada no arquivo**. Uma chamada manual fora de uma cadeia monitorada recebe sua própria correlação, além do identificador de registro.

### Contexto: como a execução chegou ao erro

A linha `Contexto` mostra os eventos e operações monitorados ainda encadeados no momento da captura. Leia da esquerda para a direita, do mais externo até o mais interno. Cada etapa usa `origem.evento [método]`.

No exemplo, `WindowProc` é a rotina que processa mensagens de um controle ou formulário:

| Etapa | O que aconteceu |
| --- | --- |
| `Form1.Button1.WindowProc(0x0202)` | O botão processou `WM_LBUTTONUP`, a liberação do botão esquerdo do mouse. |
| `Form1.WindowProc(0x0111)` | O formulário processou `WM_COMMAND`, mensagem usada para receber notificações de controles, entre outras finalidades. |
| `Form1.Button1.WindowProc(0xBD11)` | O botão processou `CN_COMMAND`, mensagem interna da VCL ligada ao encaminhamento do comando ao controle. |
| `Form1.Button1.OnClick [TForm1.Button1Click]` | O processamento chegou ao evento de clique e ao método da aplicação do qual escapou a exceção. |

Os `[n/a]` das etapas `WindowProc` são esperados: o SkyLog não atribui um nome de handler a esses níveis. As quatro etapas descrevem o processamento do mesmo clique, não quatro erros. O contexto não é um histórico de cliques anteriores nem uma pilha completa de todas as funções chamadas.

Os códigos das mensagens podem ser consultados em [WM_LBUTTONUP](https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-lbuttonup), [WM_COMMAND](https://learn.microsoft.com/en-us/windows/win32/menurc/wm-command) e [constantes de Vcl.Controls](https://docwiki.embarcadero.com/Libraries/Sydney/en/Vcl.Controls).

### StackTrace e detalhes de banco

`StackTrace` é a pilha de chamadas da exceção: pode revelar as rotinas envolvidas e, com os símbolos adequados, arquivos e linhas. `StackTrace: n/a` significa que nenhuma pilha foi obtida. O SkyLog consulta `Exception.StackTrace` e oferece `OnGetStackTrace` para integrar um provedor; ele não inclui um provedor externo. Veja os [requisitos e limites da pilha](#cobertura-e-limites).

Falhas ao obter a pilha acrescentam `StackTraceErro`, preservando o restante do registro. Isso é diferente de uma pilha simplesmente indisponível.

Em erros de banco, linhas `Banco[n]` trazem o código, objeto e mensagem de cada erro nativo da coleção `Errors` do FireDAC, incluindo os erros internos de Array DML. O índice `n` começa em zero. SQL e parâmetros não são acrescentados automaticamente. O evento `OnError` identifica a query quando essa é a origem reconhecida; `Contexto` pode mostrar o botão/evento que chamou a operação.

Uma falha de banco pode produzir registros nas fases `FireDAC` e `Evento`, com a **mesma correlação e identificadores de registro diferentes**: o primeiro observa a notificação do banco, o segundo registra a exceção saindo do handler. O FireDAC também pode notificar um erro de Array DML. Isso preserva o erro mesmo quando o handler o trata; não significa necessariamente novas falhas. A propagação da mesma exceção entre eventos aninhados é registrada uma vez.

### Regras do formato

Cada entrada contém uma linha principal e linhas complementares indentadas. `Contexto` e `Banco[n]` só aparecem quando há informações correspondentes; `StackTrace` aparece mesmo quando vale `n/a`.

- A data/hora usa `yyyy-mm-ddThh:mm:ss.zzz±hh:mm`. Horário local e deslocamento são derivados do mesmo instante UTC, inclusive nas transições de horário de verão.
- `Origem` segue a cadeia real de **Owner**, não a sequência de abertura das telas nem o `Parent` visual. Formulários cujo Owner é `Application` não formam automaticamente uma hierarquia de telas.
- `Metodo` pode ser `n/a` quando não há handler identificado. Quando existe handler, mas seu nome não está na RTTI (informações de tipos disponíveis em execução), o log usa classe e endereço.
- Quebras de linha da mensagem são escritas como `\r` e `\n`; uma sequência CRLF aparece como `\r\n`. Barras invertidas e delimitadores `|` também são escapados, evitando confundir o conteúdo com novos campos ou entradas.

Leitores do formato anterior precisam aceitar `Formato: 2`, o horário com fuso e os novos campos. `Ocorrencia` foi substituído por `Correlacao`; a classe da exceção agora tem o rótulo `Excecao`. Os arquivos antigos permanecem intactos.

## Métodos públicos

| Método | Quando usar |
| --- | --- |
| `Refresh` | Após criar/configurar componentes ou trocar handlers em execução. Atualiza as interceptações da árvore pertencente ao formulário. |
| `OwnsComponent(Component)` | Consulta se um componente pertence ao escopo deste logger, respeitando a cadeia de `Owner` e os limites entre formulários. |
| `LogException(E, Component, EventName, HandlerName)` | Registra uma exceção explicitamente, por exemplo dentro de um `except` que a consome. Só `E` é obrigatório; componente omitido ou `nil` usa o formulário. Os textos de evento e método são opcionais. |
| `Execute(Component, EventName, Action)` | Executa uma rotina anônima com um nome de operação e registra a exceção que escapar dela. Componente `nil` usa o formulário. A exceção original continua sendo propagada. |

## Componentes criados em código

Depois de criar/configurar componentes ou trocar handlers em tempo de execução, chame `Refresh`:

```pascal
uses SkyLog;

procedure TfrmCadastro.FormCreate(Sender: TObject);
begin
  qrAux := TFDQuery.Create(Self);
  qrAux.Name := 'qrAux';
  qrAux.Connection := dmBanco.Conexao;
  SkyLog1.Refresh;
end;
```

Para criar também o logger em código:

```pascal
SkyLog1 := TSkyLog.Create(Self); // Self deve ser o formulario
SkyLog1.LogDirectory := 'C:\MeuSistema\Logs';
SkyLog1.Refresh;                // depois de atribuir os eventos
```

`Refresh` restaura as interceptações anteriores e lê novamente a árvore de componentes. Apenas um SkyLog ativo é permitido por formulário. Componentes em frames e outros componentes pertencentes ao formulário entram na captura. Ao encontrar outro formulário na árvore, a varredura para: ele precisa de seu próprio SkyLog.

## Erros tratados e operações explícitas

Se seu código captura e consome uma exceção internamente, registre dentro do `except`:

```pascal
try
  MinhaOperacao;
except
  on E: Exception do
  begin
    SkyLog1.LogException(E, qrAux, 'ExecSQL', 'TfrmCadastro.Salvar');
    // seu tratamento existente
  end;
end;
```

Para informar a operação exata que deseja observar:

```pascal
SkyLog1.Execute(qrAux, 'ExecSQL',
  procedure
  begin
    qrAux.ExecSQL;
  end);
```

`Execute` também propaga a exceção original. `LogException` ignora componentes fora do formulário; `Execute` recusa uma origem fora do escopo. Query em DataModule não pertence ao formulário: use como contexto o próprio formulário ou um componente dele, e informe a operação/método explicitamente. Não associe uma query compartilhada a um formulário por adivinhação.

## Cobertura e limites

O componente usa três pontos de captura:

1. Eventos publicados e atribuídos dos componentes: `OnClick`, `OnChange`, `OnCreate`, eventos de datasets etc. Preserva parâmetros `var`/`out`, retorno de função e handlers originais.
2. `WindowProc` dos controles do formulário: captura também exceções que escapam do processamento interno de mensagens, mesmo fora de um handler publicado. Nesse caso o evento registrado é a mensagem, por exemplo `WindowProc(0x0421)`.
3. Eventos `TFDErrorEvent`, inclusive `OnError` antes vazio, para observar erros nativos do banco. Uma conexão compartilhada só é atribuída ao formulário quando o iniciador comprova essa origem; uma query própria é observada diretamente.

Não há promessa de capturar literalmente todo erro de um processo. Ficam fora da captura automática:

- Exceções consumidas por um `try/except` antes de chegar a esses pontos, exceto a notificação FireDAC observada previamente.
- Métodos comuns chamados diretamente fora de evento/mensagem monitorada; use `Execute` ou `LogException`.
- Erros antes da ativação, durante carregamento anterior a `Loaded`, depois da destruição do logger, encerramento forçado, corrupção fatal e falhas que impedem o processo de executar o logger.
- Workers/`TTask`, FireDAC assíncrono e chamadas concorrentes: esta versão é voltada ao ciclo VCL na **thread principal**. Capture na thread de origem e encaminhe os detalhes à UI com o formulário ainda vivo; não reutilize um objeto `Exception` já destruído.
- Eventos com RTTI incompleta, parâmetros sem tipo, open arrays ou convenção diferente de `register`. Eles são mantidos intactos e informados em `Diagnostics`.
- Objetos compartilhados em DataModules e controles cujo Owner é outro formulário, mesmo que o Parent visual esteja na tela monitorada.

Linhas exatas do fonte e uma pilha completa exigem símbolos da mesma compilação e um provedor de stack trace configurado pela aplicação. O SkyLog aproveita `Exception.StackTrace` e oferece `OnGetStackTrace` para integrar o provedor escolhido. Nenhum provedor externo foi instalado ou incluído nos pacotes.

`OnGetStackTrace` recebe o texto já disponível em `Exception.StackTrace` e pode complementá-lo ou substituí-lo. Deve usar a pilha capturada para a exceção original, não a pilha atual do callback. O objeto `E` só pode ser utilizado durante a chamada; o endereço pode ser `nil`, como nas notificações FireDAC anteriores ao lançamento da exceção. Se o callback falhar, o texto anterior é preservado e o erro do provedor é registrado separadamente. Sem provedor/símbolos, não há promessa de arquivo e linha exatos.

No registro manual, `ExceptAddr` só é usado quando `E` é a exceção atualmente tratada; caso contrário, `Endereco` aparece como `n/a`, evitando atribuir o endereço de outra exceção.

Os eventos e `WindowProc` são restaurados ao desativar/destruir. Não mantenha cópias dos handlers interceptados para chamar depois de `Refresh`/desativação. Se outro framework também encadear `WindowProc`, desfaça esse encadeamento antes de desativar o logger. Use `Release` para fechar formulários dentro dos próprios eventos, seguindo o ciclo usual da VCL.

## Gravação

A gravação é síncrona, abre/acrescenta/fecha o arquivo por entrada e serializa os loggers dentro do mesmo processo. A pasta precisa permitir escrita. Erros de gravação aparecem em `LastWriteError`, `OnWriteError` e na saída de depuração; não substituem a exceção original. O fechamento do arquivo não representa garantia de persistência física diante de falha de energia.

Dentro de `LogDirectory`, o componente administra exclusivamente a subpasta `skylog-v2-<SHA256 do caminho absoluto do executável em minúsculas>`. Alterar o nome/versão exibidos no registro não altera essa subpasta. Mover ou renomear o executável cria outra área; a anterior fica preservada para gestão manual. A subpasta exclusiva não pode ser um link/junção.

Os nomes seguem `skylog-<yyyy-mm-dd>_<identificador da execução>_<segmento com seis dígitos>.log`. Uma nova execução usa outro identificador, mesmo que o Windows reutilize o PID. Componentes da mesma execução e destino compartilham os segmentos; processos diferentes gravam arquivos diferentes.

A rotação acontece antes de acrescentar uma entrada que ultrapassaria `MaxFileSizeMB`. O registro completo, incluindo seus detalhes, fica no mesmo segmento. Se uma única entrada ultrapassar o limite, ela é preservada inteira em um segmento próprio, que pode ficar maior que o tamanho configurado. Zero desativa apenas o limite por tamanho; a separação por dia e execução continua. O tamanho por segmento não é uma quota total de disco.

A retenção é verificada após uma gravação bem-sucedida, no máximo uma vez por dia, destino e valor de `RetentionDays` em cada processo. Preserva os últimos dias de calendário configurados, incluindo o dia atual. Só exclui arquivos diretamente na subpasta exclusiva, com nome completo reconhecido pelo SkyLog e com data do nome **e** última modificação anteriores ao período preservado. Não percorre subpastas, não remove links e não limpa arquivos antigos no padrão `yyyy-mm-dd.log`. Não há limpeza enquanto a aplicação está fechada ou sem gravar registros.

Falhas na limpeza não descartam a entrada recém-gravada. São informadas por `LastCleanupError`, `OnCleanupError` e saída de depuração; nova tentativa ocorre na próxima varredura diária. O evento é disparado no componente que executou a varredura. Configure os componentes de um mesmo destino com a mesma política: qualquer instância pode aplicar sua retenção aos arquivos antigos daquele executável.

Na integração com a aplicação, atribua `OnWriteError` para perceber perda de registros, `OnCleanupError` para perceber retenção incompleta e `OnDiagnostics` para consultar os eventos não monitorados. Os diagnósticos de `Refresh` também são emitidos na saída de depuração mesmo sem handler. Esses avisos não criam janelas nem registram automaticamente outra exceção no mesmo destino. Não destrua o logger ou o formulário dentro desses callbacks ou de `OnGetStackTrace`.

## Arquivos de instalação

Mantenha `source` e `packages`, preservando sua posição relativa. Abra os `.dproj`
da versão desejada conforme as instruções de instalação acima.
A pasta `build` contém saídas geradas e não precisa acompanhar os fontes:
ao compilar os projetos, as saídas configuradas são criadas novamente.
As pastas `examples`, `tests` e `scripts` não fazem parte da estrutura atual.
Os resultados dos testes anteriores estão documentados em [VALIDATION.md](VALIDATION.md).

## Organização

```text
source/SkyLog.pas             Componente e implementação
source/SkyLog.Register.pas    Registro na paleta
packages/Delphi260/          Projetos do Delphi 10.3 Rio (Package version 260)
packages/Delphi370/          Projetos do Delphi 13 Florence (Package version 370)
```

Referências da Embarcadero: [callback de RTTI](https://docwiki.embarcadero.com/Libraries/Athens/en/System.Rtti.TMethodImplementationCallback), [OnError de datasets FireDAC](https://docwiki.embarcadero.com/Libraries/Athens/en/FireDAC.Comp.Client.TFDRdbmsDataSet.OnError), [OnError da conexão](https://docwiki.embarcadero.com/Libraries/Athens/en/FireDAC.Comp.Client.TFDCustomConnection.OnError).
