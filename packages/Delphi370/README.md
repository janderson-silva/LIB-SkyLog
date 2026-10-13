# Delphi 13 Florence

Projetos exclusivos do compilador 37.0, compartilhando `source\SkyLog.pas`.
O sufixo `370` corresponde ao **Package version** do Delphi 13 Florence.
A implementação do componente usada pelo Delphi 13 permanece a mesma.

1. Abra `SkyLogRuntime370.dproj` e execute **Build** em **Release**.
2. Abra `SkyLogDesign370.dproj` e execute **Build** na mesma plataforma.
3. Em **Component > Install Packages > Add**, selecione `SkyLogDesign370.bpl` da
   pasta `build\Delphi370\<plataforma>\Release`.
4. Mantenha `SkyLogRuntime370.bpl` junto da BPL de design e adicione `source` ao
   Library Path da plataforma usada pela aplicação.

Use Win32 para a IDE de 32 bits ou Win64 para a IDE de 64 bits. O runtime pode ser
compilado em ambas as plataformas independentemente da arquitetura da IDE.

Os recursos `.res` são gerados pelo MSBuild ao compilar os `.dproj`.

Os pacotes antigos sem sufixo ou com sufixo `13` foram substituídos. Consulte a
[migração](../README.md#migração-da-organização-anterior) antes de atualizar uma
instalação existente ou uma aplicação que utilize runtime packages.
