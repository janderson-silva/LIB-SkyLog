# Projetos por versão do Delphi

Cada versão tem seus próprios projetos `.dproj`/`.dpk`, nomes de pacotes e pasta
de saída. Não existem mais projetos de compilação diretamente em `packages`.
O componente é compartilhado em `source\SkyLog.pas`; diferenças de RTL são
tratadas por compilação condicional nesse fonte, sem duplicar a implementação.
O registro na paleta também é compartilhado: ambos os pacotes de design usam
`source\SkyLog.Register.pas`.

As pastas e os projetos usam o **Package version** do Delphi: `260` para o
Delphi 10.3 Rio e `370` para o Delphi 13 Florence. Esse número não é o
`CompilerVersion`: o Rio continua usando o compilador 33.0 e a diretiva `VER330`;
o Florence usa 37.0 e `VER370`.

| Delphi | Pasta | Runtime | Design | Saída padrão |
| --- | --- | --- | --- | --- |
| 10.3 Rio | [Delphi260](Delphi260/README.md) | SkyLogRuntime260 | SkyLogDesign260 | `build\Delphi260\<plataforma>\Release` |
| 13 Florence | [Delphi370](Delphi370/README.md) | SkyLogRuntime370 | SkyLogDesign370 | `build\Delphi370\<plataforma>\Release` |

O runtime suporta Win32/Win64 nas duas versões. O design deve corresponder à
arquitetura da IDE: Win32 no 10.3; Win32 ou Win64 no 13. Compile primeiro o runtime
e depois o design, sempre na mesma versão, arquitetura e configuração.

Para instalar, use **Component > Install Packages > Add** e selecione a BPL de
design da pasta de saída correspondente. Mantenha a BPL do runtime junto dela.
Essa foi a forma de instalação confirmada pelo usuário no Delphi 10.3.

## Migração da organização anterior

- Delphi 10.3: a pasta `Delphi103` passa a ser `Delphi260`; os pacotes
  `SkyLogRuntime103`/`SkyLogDesign103` passam a `SkyLogRuntime260`/`SkyLogDesign260`.
- Delphi 13: a pasta `Delphi13` passa a ser `Delphi370`; os pacotes
  `SkyLogRuntime13`/`SkyLogDesign13` passam a `SkyLogRuntime370`/`SkyLogDesign370`.
- As saídas passam a `build\Delphi260` e `build\Delphi370`, respectivamente.
  Atualize a lista de runtime packages das aplicações que usem os nomes antigos
  explicitamente, incluindo `SkyLogRuntime` sem sufixo, e recompile suas dependências.
- Se houver um pacote antigo instalado, remova apenas sua entrada no gerenciador
  de pacotes da IDE antes de adicionar o novo caminho. Não carregue dois pacotes
  que contenham a mesma unit `SkyLog` na mesma IDE/aplicação.
- Binários antigos não são apagados automaticamente, pois uma IDE pode estar
  usando esses arquivos. As próximas compilações usam somente os caminhos novos.

## Novas versões

Ao adicionar suporte, crie `packages\Delphi<PackageVersion>` com projetos de GUIDs próprios,
nomes de pacotes exclusivos, proteção contra o compilador incorreto e saídas em
`build\Delphi<PackageVersion>\<plataforma>\<configuração>`. Use o mesmo sufixo
`<PackageVersion>` nos nomes dos pacotes e aponte para o mesmo `source`.
Valide a compatibilidade e documente a instalação antes de anunciar suporte.
