# Delphi 10.3 Rio

Projetos exclusivos do compilador 33.0, compartilhando `source\SkyLog.pas`.
O runtime suporta Win32/Win64; o pacote de design é somente Win32.

1. Abra `SkyLogRuntime103.dproj` e execute **Build** em **Release / Win32**.
2. Abra `SkyLogDesign103.dproj` e execute **Build** em **Release / Win32**.
3. Em **Component > Install Packages > Add**, selecione `SkyLogDesign103.bpl` de
   `build\Delphi103\Win32\Release`. A instalação direta da BPL foi confirmada
   pelo usuário; o comando Install do projeto apresentou AV nessa IDE.
4. Mantenha `SkyLogRuntime103.bpl` junto da BPL de design e adicione `source` ao
   Library Path da plataforma usada pela aplicação.

Abra os `.dproj` desta pasta, sem copiar configurações do Delphi 13 para ela.
Após uma AV, reinicie a IDE antes de uma nova tentativa.

Na raiz da biblioteca:

```powershell
.\scripts\build.ps1 -DelphiBin 'C:\Program Files (x86)\Embarcadero\Studio\20.0\bin'
```

O script compila os mesmos projetos da IDE, gera os recursos `.res`, executa os
40 testes em Win32/Win64 e o teste de carregamento/registro em Win32. Não instala
BPLs. As saídas são separadas automaticamente das do Delphi 13.

Os nomes `SkyLogRuntime103`/`SkyLogDesign103` foram mantidos. A pasta de saída mudou
para `build\Delphi103\<plataforma>\Release`. Atualize a entrada de instalação se
ela ainda aponta para `build\Delphi103IDE`, seguindo a [migração](../README.md#migração-da-organização-anterior).