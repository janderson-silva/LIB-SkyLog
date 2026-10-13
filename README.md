# SkyLog — componente Delphi VCL

`TSkyLog` registra exceções do **formulário que é seu Owner**, dos controles e dos componentes pertencentes a esse formulário. Coloque uma instância em cada formulário que deseja monitorar e configure `LogDirectory`.

Arquivos diários: `yyyy-mm-dd.log`, texto UTF-8, data/hora local com milissegundos. A pasta é criada automaticamente. O componente mantém o tratamento normal da aplicação: registra e propaga a exceção original.

## Compatibilidade

- Windows, VCL, Win32 e Win64.
- Componente validado para **Delphi 10.3 Rio (compilador 33.0)** e **Delphi 13 Florence (compilador 37.0)**, em Win32 e Win64. A renomeação dos pacotes para os sufixos `260`/`370` não foi recompilada; consulte o [histórico de validação](VALIDATION.md). Outras versões serão adicionadas e validadas separadamente.
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
| `LogDirectory` | Pasta dos arquivos. Vazia: `logs` junto ao executável. Caminhos relativos também são resolvidos a partir do executável. |
| `LogAbort` | Inclui `EAbort` no log. Padrão: `False`, pois `Abort` é frequentemente usado para cancelar uma operação. |
| `OnWriteError` | Avisa quando não foi possível gravar; recebe arquivo e mensagem. |
| `LastWriteError` | Última falha de gravação, disponível em código. Esvazia após gravação bem-sucedida. |
| `Diagnostics` | Lista de eventos cuja assinatura não pôde ser interceptada. Consulte após `Refresh`. |

Instâncias carregadas pelo DFM são ativadas em `Loaded`, antes do `OnCreate` no ciclo normal da VCL (`OldCreateOrder=False`). Nenhuma alteração no DPR ou em `Application.OnException` é necessária.

## Exemplo de log

```text
[2026-10-06 14:57:33.768] Origem: frmPrincipal.frmClinicaVet.frmPelagem.frmCadPelagem.qrAux | Formulario: frmCadPelagem | Componente: qrAux (TFDQuery) | Evento: OnError | Metodo:  | EIBNativeException | Codigo: 335544665 | Fase: FireDAC | PID: 1234 | Thread: 5678 | Ocorrencia: {IDENTIFICADOR} | Erro: [FireDAC][Phys][FB]violation of PRIMARY or UNIQUE KEY constraint "INTEG_365" on table "PELAGEM"\r\nProblematic key value is ("CODIGO" = 2)
  Contexto: frmPrincipal.frmClinicaVet.frmPelagem.frmCadPelagem.btnSalvar.OnClick [TfrmCadPelagem.btnSalvarClick] -> frmPrincipal.frmClinicaVet.frmPelagem.frmCadPelagem.qrAux.OnError []
  Banco[0]: Codigo=335544665 | Objeto=PELAGEM | Erro=violation of PRIMARY or UNIQUE KEY constraint ...
```

Exemplo ilustrativo de Firebird. O teste de integração executado usa SQLite e sua chave duplicada real tem código `1555`.

O caminho `Origem` segue a cadeia real de **Owner**, não a sequência em que as telas foram abertas nem o `Parent` visual. Para ter o caminho aninhado do exemplo, os formulários precisam ser criados com os respectivos Owners. Se forem todos criados com `Application`, a origem será, por exemplo, `frmCadPelagem.qrAux`.

O evento `OnError` identifica a query; a linha `Contexto` também mostra o botão/evento que chamou a operação. `Metodo` fica vazio quando o evento não tinha um handler do desenvolvedor. Quando o nome do método não está na RTTI, o log usa classe e endereço.

As quebras de linha da mensagem são preservadas como `\r\n`, evitando que uma mensagem multilinha se confunda com uma nova entrada. Barras e delimitadores também são escapados. O log inclui os erros nativos da coleção `Errors` do FireDAC e os erros internos de Array DML. SQL e parâmetros não são acrescentados automaticamente.

Uma falha de banco pode produzir registros nas fases `FireDAC` e `Evento`, com o **mesmo identificador de ocorrência**: o primeiro observa a notificação do banco, o segundo registra a exceção saindo do handler. O FireDAC também pode notificar um erro de Array DML. Isso preserva o erro mesmo quando o handler o trata; não significa necessariamente novas falhas. A propagação da mesma exceção entre eventos aninhados é registrada uma vez.

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

Linhas exatas do fonte e uma pilha completa exigem símbolos e um provedor de stack trace. O SkyLog grava `ExceptAddr` e aproveita `Exception.StackTrace` quando já disponível. Ele não inventa uma linha do código nem identifica uma query arbitrária dentro de um handler sem evidência.

Os eventos e `WindowProc` são restaurados ao desativar/destruir. Não mantenha cópias dos handlers interceptados para chamar depois de `Refresh`/desativação. Se outro framework também encadear `WindowProc`, desfaça esse encadeamento antes de desativar o logger. Use `Release` para fechar formulários dentro dos próprios eventos, seguindo o ciclo usual da VCL.

## Gravação

A gravação é síncrona, abre/acrescenta/fecha o arquivo por entrada e serializa os loggers dentro do mesmo processo. A pasta precisa permitir escrita. Se outra instância do programa bloquear o mesmo arquivo, a falha aparece em `LastWriteError`, `OnWriteError` e na saída de depuração; não substitui a exceção original. Para várias instâncias simultâneas, configure subpastas por instância. Não destrua o logger dentro de `OnWriteError`.

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
