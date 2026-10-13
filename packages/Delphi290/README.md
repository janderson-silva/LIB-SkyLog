# Delphi 12 Athens

Projetos exclusivos do compilador 36.0 (`VER360`), compartilhando os fontes de
`source`. O sufixo `290` corresponde ao **Package version** do Delphi 12 Athens,
seguindo o padrão de nomenclatura das demais versões do repositório.

O runtime está configurado para Win32/Win64. O pacote de design está configurado
para instalação na IDE de 32 bits (Win32), inclusive ao desenvolver aplicações Win64.

## Instalação pelo usuário

1. Abra `SkyLogRuntime290.dproj` no Delphi 12 e compile em **Release / Win32**.
2. Abra `SkyLogDesign290.dproj` e compile em **Release / Win32**.
3. Em **Component > Install Packages > Add**, selecione `SkyLogDesign290.bpl`
   em `build\Delphi290\Win32\Release`, a partir da raiz do repositório.
4. Mantenha `SkyLogRuntime290.bpl` junto da BPL de design e adicione `source`
   ao **Library path** das plataformas usadas pela aplicação.
5. Na paleta **SkyLog**, coloque `TSkyLog` no formulário e configure `LogDirectory`.

Para aplicações Win64 que utilizem runtime packages, compile também
`SkyLogRuntime290.dproj` em **Release / Win64** e use sua saída correspondente.
Não misture os binários Win32 e Win64.

Os caminhos de saída seguem o padrão
`build\Delphi290\<plataforma>\<configuração>`. São apenas configurações dos
projetos; essas pastas serão geradas quando você compilar no Delphi.
Os recursos `.res` são gerados pelo MSBuild ao compilar os `.dproj`.

O fonte compartilhado já seleciona, para compiladores anteriores ao Delphi 13,
o caminho com `TRttiMethod.CreateImplementation`. Nesse caminho, handlers de
eventos precisam de RTTI estendida; handlers sem essa informação permanecem
intactos e são informados em `Diagnostics`. O `OnError` do FireDAC usa uma
assinatura interna, sem depender de RTTI no handler original.

Foram criados somente os projetos e estas instruções. Nenhum build, compilação,
teste ou instalação foi executado para o Delphi 12.

Referência: [versões de compilador e packages da Embarcadero](https://docwiki.embarcadero.com/RADStudio/Athens/en/Compiler_Versions_Table).
