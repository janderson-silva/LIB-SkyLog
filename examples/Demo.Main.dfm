object frmPrincipal: TfrmPrincipal
  Left = 0
  Top = 0
  Caption = 'SkyLog - demonstracao'
  ClientHeight = 260
  ClientWidth = 650
  Position = poScreenCenter
  OnCreate = FormCreate
  object lblInfo: TLabel
    Left = 24
    Top = 24
    Width = 595
    Height = 60
    AutoSize = False
    WordWrap = True
    Caption = 'Inicializando SkyLog...'
  end
  object btnErro: TButton
    Left = 24
    Top = 100
    Width = 270
    Height = 38
    Caption = 'Gerar erro no OnClick'
    TabOrder = 0
    OnClick = ErroClick
  end
  object btnBanco: TButton
    Left = 320
    Top = 100
    Width = 300
    Height = 38
    Caption = 'Gerar chave duplicada no FireDAC'
    TabOrder = 1
    OnClick = BancoClick
  end
  object btnOutro: TButton
    Left = 24
    Top = 156
    Width = 596
    Height = 38
    Caption = 'Abrir outro formulario com SkyLog desativado'
    TabOrder = 2
    OnClick = OutroClick
  end
  object SkyLog1: TSkyLog
    LogDirectory = 'logs'
    Left = 584
    Top = 216
  end
end
