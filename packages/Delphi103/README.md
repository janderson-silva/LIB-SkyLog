# Instalação no Delphi 10.3 Rio

Estes projetos são exclusivos do Delphi 10.3 e da instalação Win32. Usam o mesmo
`source\SkyLog.pas` do restante da biblioteca. Os pacotes do Delphi 13 permanecem
em `packages\SkyLogRuntime.dpk` e `packages\SkyLogDesign.dpk`.

1. Feche a IDE após uma violação de acesso e abra novamente o Delphi 10.3.
2. Se houver um **SkyLog** antigo instalado nessa IDE, remova somente sua entrada
   em **Component > Install Packages** antes de instalar os novos pacotes.
3. Abra **SkyLogRuntime103.dproj**, selecione **Release / Win32** e use **Build**.
4. Abra **SkyLogDesign103.dproj**, selecione **Release / Win32**, use **Build**
   e depois **Install**.
5. Adicione a pasta `source` desta cópia da biblioteca ao Library Path do 10.3.
   Evite manter outra cópia de `SkyLog.pas` no mesmo caminho de pesquisa.

Abra os `.dproj` desta pasta. Abrir o `.dpk` antigo ao lado de um `.dproj` criado
pelo Delphi 13 pode reutilizar as configurações desse projeto mais novo.
Não copie os `.dproj`/`.dproj.local` da instalação do Delphi 13 para esta pasta.

As BPLs e os DCPs ficam em `build\Delphi103IDE\Win32\Release`, na raiz da
biblioteca. Mantenha `SkyLogRuntime103.bpl` acessível à IDE junto do pacote de
design. Os nomes com `103` impedem a seleção de uma BPL homônima do Delphi 13.
Não instale simultaneamente os pacotes antigo e novo: ambos contêm `SkyLog`.

O MSBuild gera os recursos `.res` automaticamente a partir dos `.dproj`.
Para compilar fora da IDE, em um **RAD Studio 10.3 Command Prompt**, na raiz:

```bat
msbuild packages\Delphi103\SkyLogRuntime103.dproj /t:Build /p:Config=Release /p:Platform=Win32
msbuild packages\Delphi103\SkyLogDesign103.dproj /t:Build /p:Config=Release /p:Platform=Win32
```

Esses comandos compilam, mas não instalam o componente na IDE. O script geral
`scripts\build.ps1` continua disponível para os testes de execução Win32/Win64.

Teste adicional de carregamento/registro, no mesmo prompt e na raiz da biblioteca:

```bat
dcc32 -B -Q "-LUrtl;vcl;FireDAC" -Ebuild\Delphi103IDE\Win32\Release -N0build\Delphi103IDE\Win32\Release tests\SkyLog.PackageTests.dpr
build\Delphi103IDE\Win32\Release\SkyLog.PackageTests.exe build\Delphi103IDE\Win32\Release\SkyLogRuntime103.bpl build\Delphi103IDE\Win32\Release\SkyLogDesign103.bpl
```

Esse teste chama o registro em um processo separado e não substitui a confirmação
do comando Install dentro da IDE.
