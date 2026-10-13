# SkyLog — componente Delphi VCL

`TSkyLog` registra exceções do **formulário que é seu Owner**, dos controles e dos componentes pertencentes a esse formulário. Coloque uma instância em cada formulário que deseja monitorar e configure `LogDirectory`.

Arquivos em UTF-8 separados por dia e execução, com rotação por tamanho, retenção configurável e data/hora local com milissegundos e fuso. A pasta é criada automaticamente. O componente mantém o tratamento normal da aplicação: registra e propaga a exceção original.

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

Propriedades principais:

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
| `OnWriteError` | Avisa quando não foi possível gravar; recebe arquivo e mensagem. |
| `LastWriteError` | Última falha de gravação, disponível em código. Esvazia após gravação bem-sucedida. |
| `OnCleanupError` | Avisa sobre falha de retenção, separadamente da gravação; recebe caminho e mensagem. O registro atual já foi gravado. |
| `LastCleanupError` | Falha da última limpeza executada por esta instância. Esvazia após uma limpeza bem-sucedida; gravações sem limpeza não apagam esse diagnóstico. |
| `OnGetStackTrace` | Integra um provedor de pilha. Recebe a exceção, o endereço disponível e o texto da pilha por referência. |
| `Diagnostics` | Lista de eventos cuja assinatura não pôde ser interceptada e de falhas em `OnDiagnostics`. É renovada por `Refresh`. |
| `OnDiagnostics` | Notificação ao final de `Refresh` quando há diagnósticos. Eles também são enviados à saída de depuração. |

Instâncias carregadas pelo DFM são ativadas em `Loaded`, antes do `OnCreate` no ciclo normal da VCL (`OldCreateOrder=False`). Nenhuma alteração no DPR ou em `Application.OnException` é necessária.

## Formato do registro

Cada registro mantém uma linha principal e linhas complementares indentadas. A linha principal começa com data/hora em `yyyy-mm-ddThh:mm:ss.zzz±hh:mm`, usando o fuso local da máquina no instante da captura, e contém `Formato: 2`. O horário e o deslocamento são derivados do mesmo instante UTC, inclusive durante a transição do horário de verão.

Os campos são `Aplicacao`, `Versao`, `Build`, `Execucao`, `Origem`, `Formulario`, `Componente`, `Evento`, `Metodo`, `Excecao`, `Codigo`, `Fase`, `PID`, `Thread`, `Correlacao`, `Registro`, `Endereco` e `Erro`. Valores textuais ausentes e endereços indisponíveis aparecem como `n/a`. A versão automática vem do executável da aplicação, não da BPL do SkyLog.

`Execucao` identifica a sessão da biblioteca no processo e é compartilhado pelos componentes. `Correlacao` agrupa a cadeia de eventos/operações monitorados; pode reunir mais de uma exceção na mesma ação. `Registro` é exclusivo de cada entrada. Uma chamada manual fora de uma cadeia monitorada recebe sua própria correlação, além do identificador de registro.

O caminho `Origem` segue a cadeia real de **Owner**, não a sequência em que as telas foram abertas nem o `Parent` visual. Formulários criados com `Application` como Owner não produzem automaticamente uma hierarquia de telas.

O evento `OnError` identifica a query; a linha `Contexto` também mostra o botão/evento que chamou a operação. `Metodo` aparece como `n/a` quando o evento não tinha um handler do desenvolvedor. Quando o nome do método não está na RTTI, o log usa classe e endereço.

As quebras de linha da mensagem são preservadas como `\r\n`, evitando que uma mensagem multilinha se confunda com uma nova entrada. Barras e delimitadores também são escapados. O log inclui os erros nativos da coleção `Errors` do FireDAC e os erros internos de Array DML. SQL e parâmetros não são acrescentados automaticamente.

Uma falha de banco pode produzir registros nas fases `FireDAC` e `Evento`, com a **mesma correlação e identificadores de registro diferentes**: o primeiro observa a notificação do banco, o segundo registra a exceção saindo do handler. O FireDAC também pode notificar um erro de Array DML. Isso preserva o erro mesmo quando o handler o trata; não significa necessariamente novas falhas. A propagação da mesma exceção entre eventos aninhados é registrada uma vez.

`Contexto` e `Banco[n]` são incluídos quando existem informações correspondentes. A linha `StackTrace` contém a pilha disponível ou `n/a`. Falhas na obtenção da pilha acrescentam `StackTraceErro` e não impedem a gravação do restante da entrada.

Leitores do formato anterior precisam aceitar `Formato: 2`, o horário com fuso e os novos campos. `Ocorrencia` foi substituído por `Correlacao`; a classe da exceção agora tem o rótulo `Excecao`. Os arquivos antigos permanecem intactos.

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
