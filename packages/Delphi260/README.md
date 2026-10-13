# Delphi 10.3 Rio

Projetos exclusivos do compilador 33.0, compartilhando `source\SkyLog.pas`.
O sufixo `260` corresponde ao **Package version** do Delphi 10.3 Rio.
O runtime suporta Win32/Win64; o pacote de design é somente Win32.

1. Abra `SkyLogRuntime260.dproj` e execute **Build** em **Release / Win32**.
2. Abra `SkyLogDesign260.dproj` e execute **Build** em **Release / Win32**.
3. Em **Component > Install Packages > Add**, selecione `SkyLogDesign260.bpl` de
   `build\Delphi260\Win32\Release`. A instalação direta da BPL foi confirmada
   pelo usuário antes desta renomeação; o comando Install do projeto apresentou AV nessa IDE.
4. Mantenha `SkyLogRuntime260.bpl` junto da BPL de design e adicione `source` ao
   Library Path da plataforma usada pela aplicação.

Abra os `.dproj` desta pasta, sem copiar configurações do Delphi 13 para ela.
Após uma AV, reinicie a IDE antes de uma nova tentativa.

Os recursos `.res` são gerados pelo MSBuild ao compilar os `.dproj`.
As saídas ficam em `build\Delphi260\<plataforma>\Release`.
Consulte a [migração](../README.md#migração-da-organização-anterior) para atualizar
instalações e aplicações que usem os nomes antigos dos pacotes.
