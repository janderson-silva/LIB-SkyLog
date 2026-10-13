# Delphi 13 Florence

Projetos exclusivos do compilador 37.0, compartilhando `source\SkyLog.pas`.
A implementação do componente usada pelo Delphi 13 permanece a mesma.

1. Abra `SkyLogRuntime13.dproj` e execute **Build** em **Release**.
2. Abra `SkyLogDesign13.dproj` e execute **Build** na mesma plataforma.
3. Em **Component > Install Packages > Add**, selecione `SkyLogDesign13.bpl` da
   pasta `build\Delphi13\<plataforma>\Release`.
4. Mantenha `SkyLogRuntime13.bpl` junto da BPL de design e adicione `source` ao
   Library Path da plataforma usada pela aplicação.

Use Win32 para a IDE de 32 bits ou Win64 para a IDE de 64 bits. O runtime pode ser
compilado em ambas as plataformas independentemente da arquitetura da IDE.

Os recursos `.res` são gerados pelo MSBuild ao compilar os `.dproj`. Na raiz:

```powershell
.\scripts\build.ps1 -DelphiBin 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin'
```

O script compila os mesmos projetos usados pela IDE, executa os testes e o demo,
mas não instala BPLs. Ele identifica a versão do compilador automaticamente.

Os pacotes antigos sem sufixo foram substituídos. Consulte a
[migração](../README.md#migração-da-organização-anterior) antes de atualizar uma
instalação existente ou uma aplicação que utilize runtime packages.
