# Projetos por versão do Delphi

Cada versão tem seus próprios projetos `.dproj`/`.dpk`, nomes de pacotes e pasta
de saída. Não existem mais projetos de compilação diretamente em `packages`.
O componente é compartilhado em `source\SkyLog.pas`; diferenças de RTL são
tratadas por compilação condicional nesse fonte, sem duplicar a implementação.

| Delphi | Pasta | Runtime | Design | Saída padrão |
| --- | --- | --- | --- | --- |
| 10.3 Rio | [Delphi103](Delphi103/README.md) | SkyLogRuntime103 | SkyLogDesign103 | `build\Delphi103\<plataforma>\Release` |
| 13 Florence | [Delphi13](Delphi13/README.md) | SkyLogRuntime13 | SkyLogDesign13 | `build\Delphi13\<plataforma>\Release` |

O runtime suporta Win32/Win64 nas duas versões. O design deve corresponder à
arquitetura da IDE: Win32 no 10.3; Win32 ou Win64 no 13. Compile primeiro o runtime
e depois o design, sempre na mesma versão, arquitetura e configuração.

Para instalar, use **Component > Install Packages > Add** e selecione a BPL de
design da pasta de saída correspondente. Mantenha a BPL do runtime junto dela.
Essa foi a forma de instalação confirmada pelo usuário no Delphi 10.3.

## Migração da organização anterior

- Delphi 13: os projetos antes localizados na raiz de `packages` foram substituídos
  por `Delphi13\SkyLogRuntime13.dproj` e `Delphi13\SkyLogDesign13.dproj`.
  Atualize também a lista de runtime packages da aplicação se ela usava
  explicitamente `SkyLogRuntime`; o novo nome é `SkyLogRuntime13`.
- Delphi 10.3: os nomes `SkyLogRuntime103`/`SkyLogDesign103` foram mantidos.
  A saída passou de `build\Delphi103IDE` para `build\Delphi103`.
- Se houver um pacote antigo instalado, remova apenas sua entrada no gerenciador
  de pacotes da IDE antes de adicionar o novo caminho. Não carregue dois pacotes
  que contenham a mesma unit `SkyLog` na mesma IDE/aplicação.
- Binários antigos não são apagados automaticamente, pois uma IDE pode estar
  usando esses arquivos. As próximas compilações usam somente os caminhos novos.

## Novas versões

Ao adicionar suporte, crie `packages\Delphi<versão>` com projetos de GUIDs próprios,
nomes de pacotes exclusivos, proteção contra o compilador incorreto e saídas em
`build\Delphi<versão>\<plataforma>\<configuração>`. Aponte para o mesmo `source`.
Cadastre o compilador em `scripts\build.ps1`, valide os testes e documente a
instalação. Não acrescente uma versão à lista de suporte sem compilá-la e testá-la.
