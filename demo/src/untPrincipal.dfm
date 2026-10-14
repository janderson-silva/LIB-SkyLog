object frmPrincipal: TfrmPrincipal
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'DemoSkyLog | Laboratorio de logs'
  ClientHeight = 580
  ClientWidth = 760
  Color = 16448250
  Font.Charset = DEFAULT_CHARSET
  Font.Color = 3421236
  Font.Height = -14
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 19
  object lblDebugger: TLabel
    Left = 24
    Top = 538
    Width = 712
    Height = 34
    AutoSize = False
    Caption = 
      'No Delphi, o depurador pode pausar na excecao: pressione F9 para' +
      ' continuar. Para testar o fluxo completo, execute a demo fora da' +
      ' IDE.'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    WordWrap = True
  end
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
    ExplicitWidth = 758
    object lblTitle: TLabel
      Left = 24
      Top = 16
      Width = 170
      Height = 37
      Caption = 'DemoSkyLog'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -27
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblSubtitle: TLabel
      Left = 26
      Top = 59
      Width = 447
      Height = 19
      Caption = 
        'Laboratorio de excecoes | Teste a captura e consulte os registro' +
        's gerados.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -14
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
  end
  object pagCenarios: TPageControl
    Left = 24
    Top = 120
    Width = 712
    Height = 300
    ActivePage = tabGerais
    TabOrder = 1
    object tabGerais: TTabSheet
      Caption = 'Erros gerais'
      object grpErrors: TGroupBox
        Left = 0
        Top = 0
        Width = 704
        Height = 266
        Align = alClient
        Caption = '  1. Escolha um cenario  '
        TabOrder = 0
        object lblInstructions: TLabel
          Left = 20
          Top = 29
          Width = 672
          Height = 38
          AutoSize = False
          Caption = 
            'Cada botao provoca uma falha intencional. Feche a mensagem de er' +
            'ro para continuar testando. O ultimo cenario demonstra o registr' +
            'o manual.'
          WordWrap = True
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
    end
    object tabBanco: TTabSheet
      Caption = 'Banco de dados'
      object lblBanco: TLabel
        Left = 20
        Top = 16
        Width = 664
        Height = 44
        AutoSize = False
        Caption = 
          'SQLite em memoria: erros reais de SQL e restricoes. Cada clique ' +
          'cria um banco novo.'
        WordWrap = True
      end
      object btnSQL: TButton
        Left = 20
        Top = 76
        Width = 318
        Height = 42
        Caption = '07 | SQL invalido'
        TabOrder = 0
        OnClick = btnSQLClick
      end
      object btnTabela: TButton
        Left = 366
        Top = 76
        Width = 318
        Height = 42
        Caption = '08 | Tabela inexistente'
        TabOrder = 1
        OnClick = btnTabelaClick
      end
      object btnDuplicado: TButton
        Left = 20
        Top = 128
        Width = 318
        Height = 42
        Caption = '09 | Chave duplicada'
        TabOrder = 2
        OnClick = btnDuplicadoClick
      end
      object btnObrigatorio: TButton
        Left = 366
        Top = 128
        Width = 318
        Height = 42
        Caption = '10 | Campo obrigatorio'
        TabOrder = 3
        OnClick = btnObrigatorioClick
      end
      object btnBancoSensivel: TButton
        Left = 20
        Top = 180
        Width = 318
        Height = 42
        Caption = '11 | Banco com senha e token'
        TabOrder = 4
        OnClick = btnBancoSensivelClick
      end
    end
    object tabSensivel: TTabSheet
      Caption = 'Dados sensiveis'
      object lblSensivel: TLabel
        Left = 20
        Top = 16
        Width = 664
        Height = 44
        AutoSize = False
        Caption = 
          'Dados ficticios. Confira [REDACTED] nos logs. A mensagem na tela' +
          ' pode mostrar o valor original.'
        WordWrap = True
      end
      object btnSensivelTexto: TButton
        Left = 20
        Top = 76
        Width = 318
        Height = 42
        Caption = '12 | Senha, token, CPF e cartao'
        TabOrder = 0
        OnClick = btnSensivelTextoClick
      end
      object btnSensivelJSON: TButton
        Left = 366
        Top = 76
        Width = 318
        Height = 42
        Caption = '13 | JSON com dados sensiveis'
        TabOrder = 1
        OnClick = btnSensivelJSONClick
      end
      object btnSensivelLiteral: TButton
        Left = 20
        Top = 128
        Width = 318
        Height = 42
        Caption = '14 | Segredo sem nome de campo'
        TabOrder = 2
        OnClick = btnSensivelLiteralClick
      end
    end
  end
  object grpLogs: TGroupBox
    Left = 24
    Top = 436
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
      Caption = 
        'Formato JSON. Os registros ficam na pasta logs, ao lado do execu' +
        'tavel, dentro da subpasta da aplicacao.'
      WordWrap = True
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
  object FDGUIxWaitCursor1: TFDGUIxWaitCursor
    Provider = 'Forms'
    Left = 144
    Top = 24
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
    SensitiveValues.Strings = (
      'segredo-literal-demo-2026')
    Left = 32
    Top = 24
  end
end
