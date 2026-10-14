object frmPrincipal: TfrmPrincipal
  Left = 0
  Top = 0
  BorderStyle = bsSingle
  BorderIcons = [biSystemMenu, biMinimize]
  Caption = 'DemoSkyLog | Laboratorio de logs'
  ClientHeight = 530
  ClientWidth = 760
  Color = 16448250
  Font.Charset = DEFAULT_CHARSET
  Font.Color = 3421236
  Font.Height = -14
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 19
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 760
    Height = 100
    Align = alTop
    BevelOuter = bvNone
    Color = 5979424
    ParentBackground = False
    TabOrder = 0
    object lblTitle: TLabel
      Left = 24
      Top = 16
      Width = 300
      Height = 32
      Caption = 'DemoSkyLog'
      Font.Color = clWhite
      Font.Height = -27
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblSubtitle: TLabel
      Left = 26
      Top = 59
      Width = 690
      Height = 19
      Caption = 'Laboratorio de excecoes | Teste a captura e consulte os registros gerados.'
      Font.Color = clWhite
      Font.Height = -14
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
  end
  object grpErrors: TGroupBox
    Left = 24
    Top = 120
    Width = 712
    Height = 250
    Caption = '  1. Escolha um cenario  '
    TabOrder = 1
    object lblInstructions: TLabel
      Left = 20
      Top = 29
      Width = 672
      Height = 38
      AutoSize = False
      WordWrap = True
      Caption = 'Cada botao provoca uma falha intencional. Feche a mensagem de erro para continuar testando. O ultimo cenario demonstra o registro manual.'
    end
    object btnConversao: TButton
      Left = 20
      Top = 82
      Width = 326
      Height = 42
      Caption = '01  |  Conversao de texto'
      TabOrder = 0
      OnClick = btnConversaoClick
    end
    object btnDivisao: TButton
      Left = 366
      Top = 82
      Width = 326
      Height = 42
      Caption = '02  |  Divisao por zero'
      TabOrder = 1
      OnClick = btnDivisaoClick
    end
    object btnLista: TButton
      Left = 20
      Top = 134
      Width = 326
      Height = 42
      Caption = '03  |  Indice fora da lista'
      TabOrder = 2
      OnClick = btnListaClick
    end
    object btnData: TButton
      Left = 366
      Top = 134
      Width = 326
      Height = 42
      Caption = '04  |  Data invalida'
      TabOrder = 3
      OnClick = btnDataClick
    end
    object btnNegocio: TButton
      Left = 20
      Top = 186
      Width = 326
      Height = 42
      Caption = '05  |  Regra de negocio'
      TabOrder = 4
      OnClick = btnNegocioClick
    end
    object btnTratado: TButton
      Left = 366
      Top = 186
      Width = 326
      Height = 42
      Caption = '06  |  Excecao tratada'
      TabOrder = 5
      OnClick = btnTratadoClick
    end
  end
  object grpLogs: TGroupBox
    Left = 24
    Top = 386
    Width = 712
    Height = 86
    Caption = '  2. Consulte os logs  '
    TabOrder = 2
    object lblLogs: TLabel
      Left = 20
      Top = 29
      Width = 466
      Height = 40
      AutoSize = False
      WordWrap = True
      Caption = 'Formato JSON. Os registros ficam na pasta logs, ao lado do executavel, dentro da subpasta da aplicacao.'
    end
    object btnAbrirLogs: TButton
      Left = 506
      Top = 28
      Width = 186
      Height = 38
      Caption = 'Abrir pasta de logs'
      TabOrder = 0
      OnClick = btnAbrirLogsClick
    end
  end
  object lblDebugger: TLabel
    Left = 24
    Top = 488
    Width = 712
    Height = 34
    AutoSize = False
    WordWrap = True
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    Caption = 'No Delphi, o depurador pode pausar na excecao: pressione F9 para continuar. Para testar o fluxo completo, execute a demo fora da IDE.'
  end
  object SkyLog1: TSkyLog
    SensitiveFields.Strings = (
      'password'
      'passwd'
      'pwd'
      'senha'
      'token'
      'access_token'
      'refresh_token'
      'authorization'
      'api_key'
      'apikey'
      'secret'
      'client_secret'
      'cpf'
      'cnpj'
      'card'
      'card_number'
      'cvv'
      'conta'
      'agencia'
      'account'
      'iban')
    Left = 32
    Top = 24
  end
end
