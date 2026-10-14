# SkyLog

Componente **Delphi VCL** para registrar exceções de formulários, DataModules e seus componentes, incluindo erros FireDAC. Gera logs em JSON ou texto, com níveis de severidade, mascaramento de dados sensíveis, rotação e limpeza de arquivos antigos.

Funciona em **Windows, Win32 e Win64, na thread principal**. Registra a exceção sem substituir o tratamento normal da aplicação.

## Versões e pacotes

Escolha os projetos da sua versão do Delphi. Os números das pastas seguem o **Package version** da Embarcadero, não o número do compilador.

| Delphi | Pasta / Package version | Runtime | Design — instalar na IDE |
| --- | --- | --- | --- |
| 10.3 Rio | `packages/Delphi260` — **260** | [SkyLogRuntime260.dproj](packages/Delphi260/SkyLogRuntime260.dproj) | [SkyLogDesign260.dproj](packages/Delphi260/SkyLogDesign260.dproj) |
| 12 Athens | `packages/Delphi290` — **290** | [SkyLogRuntime290.dproj](packages/Delphi290/SkyLogRuntime290.dproj) | [SkyLogDesign290.dproj](packages/Delphi290/SkyLogDesign290.dproj) |
| 13 Florence | `packages/Delphi370` — **370** | [SkyLogRuntime370.dproj](packages/Delphi370/SkyLogRuntime370.dproj) | [SkyLogDesign370.dproj](packages/Delphi370/SkyLogDesign370.dproj) |

São os pacotes disponíveis neste repositório. Não use o pacote de uma versão em outra.

## Instalação

Mantenha as pastas `source`, `packages` e `resources` na estrutura original. É necessário ter VCL e FireDAC instalados.

1. Em **Tools > Options > Language > Delphi > Library**, adicione o **caminho completo da pasta `source`** ao **Library path** de Win32 e, se usar, de Win64. Preserve os caminhos existentes.
2. Abra o projeto **Runtime** da tabela e execute **Build**, em **Release**.
3. Abra o projeto **Design** correspondente e execute **Build** e depois **Install**, na mesma configuração e plataforma.
4. Na paleta **SkyLog**, coloque um `TSkyLog` no formulário ou DataModule.

Para instalar na IDE, use **Win32 no Delphi 10.3 e 12**. No Delphi 13, use Win32 ou Win64 conforme a arquitetura da IDE. Ao atualizar, remova a entrada do pacote antigo antes de instalar o novo.

**A BPL disponibiliza o componente na paleta; o Library path permite compilá-lo.** Com ambos configurados, basta `uses SkyLog`: não é necessário alterar o DPR ou o Search Path de cada projeto. Se aparecer `Unit 'SkyLog' not found`, confira o Library path da plataforma selecionada.

## Configurações

Configure pelo Object Inspector ou em código:

| Propriedade | Para que serve / padrão |
| --- | --- |
| `Enabled` | Ativa o registro automático e manual. **True**. |
| `LogDirectory` | Pasta dos logs. Vazia: pasta `logs` ao lado do executável, com uma subpasta por aplicação. Precisa permitir escrita. |
| `LogFormat` | **slfJSON**: um registro por linha em `.jsonl`. `slfText`: texto em `.log`. |
| `MinimumLevel` | Menor nível gravado. **sllDebug**, que inclui todos. |
| `MaxFileSizeMB` | Tamanho por arquivo. **10 MB**; `0` desativa a rotação por tamanho. |
| `RetentionDays` | Dias de logs preservados. **30**; `0` desativa a limpeza. |
| `MaskSensitiveData` | Substitui dados sensíveis por `[REDACTED]`. **True**. |
| `SensitiveFields` | Nomes de campos a mascarar; já inclui senha, token, CPF, cartão e outros. Ignora maiúsculas/minúsculas. |
| `SensitiveValues` | Valores literais a mascarar, com comparação exata. Adicione segredos em execução, sem salvá-los no DFM. |
| `LogAbort` | Registra exceções `EAbort`. **False**. |
| `ApplicationName` | Nome da aplicação no log. Vazio: nome do executável. |
| `ApplicationVersion` | Versão no log. Vazia: versão do executável, quando disponível. |
| `ApplicationBuild` | Identificador da entrega. Vazio: quarto número da versão do executável, quando disponível. |

Níveis: **Debug < Info < Warning < Error < Fatal**. Por exemplo, `sllWarning` grava Warning, Error e Fatal. Exceções usam **Error**; `sllFatal` as filtra. O método `Fatal` apenas registra, sem encerrar a aplicação.

Eventos opcionais: `OnWriteError` avisa sobre falha de gravação; `OnCleanupError`, sobre falha na limpeza; `OnDiagnostics`, sobre eventos não monitorados; `OnGetStackTrace` permite integrar um provedor de pilha. Consulte também `LastWriteError`, `LastCleanupError` e `Diagnostics` em código.

## Uso rápido

Use **um TSkyLog ativo por formulário ou DataModule**, com esse formulário/DataModule como `Owner`. Mantenha `Enabled = True`; a captura começa ao carregar o formulário. No designer de DataModules, use `ClassGroup = Vcl.Controls.TControl`.

```pascal
SkyLog1.Info('Cadastro salvo');
SkyLog1.Warning('Consulta demorada');
SkyLog1.Error('Falha na operacao');
SkyLog1.SensitiveFields.Add('chave_integracao');
```

- Para erros tratados dentro de um `except`, chame `SkyLog1.LogException(E)`.
- Para monitorar uma rotina chamada diretamente, use `Execute(Component, EventName, Action)`; a exceção continua sendo propagada.
- Após criar componentes ou trocar eventos em execução, chame `SkyLog1.Refresh`.

A captura automática depende dos eventos monitorados; não cobre todo erro do processo. No Delphi 10.3 e 12, handlers personalizados precisam de RTTI estendida. Arquivo e linha exatos exigem símbolos e um provedor de pilha. O mascaramento depende dos campos/valores reconhecidos e configurados.

Exemplo de uso: [demo/DemoSkyLog.dproj](demo/DemoSkyLog.dproj).
