object frmPrincipal: TfrmPrincipal
  Left = 0
  Top = 0
  Caption = 'frmPrincipal'
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object btnConversao: TButton
    Left = 24
    Top = 376
    Width = 113
    Height = 49
    Caption = 'btnConversao'
    TabOrder = 0
    OnClick = btnConversaoClick
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
