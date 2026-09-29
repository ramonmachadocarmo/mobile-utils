# OmniTool

[![Sponsor](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/ramonmachadocarmo)

**All-In-One Mobile Utilities**: app Flutter (Android e iOS) com utilitários pessoais. Cada utilitário fica em `lib/features/<nome>/` e é listado na tela inicial em `lib/main.dart` (`_utilities`).

## Utilitários

### Bloqueio de chamadas

Rejeita automaticamente chamadas recebidas conforme regras configuráveis:

- **Números digitados**: qualquer número, com descrição opcional.
- **Números dos contatos**: escolhidos da agenda (busca e seleção múltipla).
- **Desconhecidos**: números fora da agenda e números ocultos/privados (**só Android**).
- **Prefixos**: todos os números que começam com um prefixo, ex.: `0303` (telemarketing), um DDD, ou `+1` para outro país (**só Android**). Prefixos sem `+` comparam com o número nacional (sem DDI e sem zeros) e precisam de pelo menos 2 dígitos.
- **Horário de silêncio**: um "não perturbe" com início, fim e dias da semana; pode atravessar a meia-noite (os dias marcados são os do início). Opções para deixar passar os contatos e quem ligar de novo em até 3 minutos, para urgências (**só Android**).
- **Resposta por SMS**: manda uma mensagem configurável a quem foi rejeitado, no máximo uma vez a cada 12 h por número e nunca para números ocultos. Por padrão só responde as chamadas do horário de silêncio (**só Android**).
- **Histórico** das chamadas rejeitadas nos últimos 7 dias, indicando as respondidas por SMS; as mais antigas são apagadas automaticamente (**só Android**).

Os números batem por sufixo (mínimo de 8 dígitos), então `+55 11 91234-5678`, `(11) 91234-5678` e `011 91234-5678` são tratados como o mesmo número.

| | Android | iOS |
|---|---|---|
| Bloquear números da lista | ✅ `CallScreeningService` | ✅ Call Directory Extension |
| Bloquear desconhecidos | ✅ | ❌ a Apple não permite; use Ajustes › Apps › Telefone › Silenciar Desconhecidos |
| Prefixos, horário de silêncio, SMS | ✅ | ❌ a Call Directory Extension só aceita uma lista fixa de números; use o Foco do iOS |
| Histórico (7 dias) | ✅ | ❌ o iOS não informa a extensão |
| Versão mínima | Android 10 (API 29) | iOS 14 |

#### Android

Na primeira vez, toque em **Ativar** na tela de bloqueio e escolha o OmniTool como *app de identificação de chamadas e spam*. Para bloquear desconhecidos, o app precisa da permissão de contatos (pedida ao ligar a opção). Sem ela, não dá para saber quem é desconhecido e as chamadas passam; se a permissão for retirada depois (ex.: reinstalação), a tela mostra um aviso com o botão **Permitir**.

O horário de silêncio com "permitir contatos" também depende da permissão de contatos: sem ela, as chamadas passam (para não barrar a família) e a tela mostra um aviso. A resposta por SMS pede a permissão de SMS ao ser ligada e pode ter custo da operadora.

> **Play Store:** `SEND_SMS` é uma permissão restrita. Publicar com ela exige preencher a *Declaração de permissões* na Play Console, e o Google pode recusar o uso. Se for recusado, remova a linha `SEND_SMS` do `AndroidManifest.xml`: o resto do bloqueio continua funcionando e a opção de SMS só mostra o aviso de permissão.

As regras em Kotlin espelham as de Dart (`phone_utils.dart` e `QuietHours` em `call_blocker_config.dart`), que têm os testes; mudou uma, mude a outra.

Código nativo: `android/app/src/main/kotlin/.../callblocker/`.

#### iOS

A extensão fica em `ios/CallBlockerExtension/` e o widget das notas rápidas em `ios/QuickNotesWidget/`. Os dois targets são criados no `Runner.xcodeproj` por `ios/scripts/add_extension_targets.rb` (veja [Release iOS](#release-ios-testflight)), sem precisar abrir o Xcode. App, extensão e widget compartilham dados pelo App Group `group.com.ramonmachadocarmo.mobileUtils`.

O app registra o esquema `mobileutils://` (usado pelos toques no widget) e pede Face ID com a mensagem de `NSFaceIDUsageDescription`, ambos já no `Runner/Info.plist`.

No iPhone, ative em **Ajustes › Apps › Telefone › Bloqueio e Identificação de Chamadas › OmniTool** (o app mostra um botão para abrir os Ajustes).

No iOS, números sem DDI recebem o código do país configurado no app (padrão +55) e precisam incluir o DDD.

### Notas rápidas

Guarda textos que você cola com frequência (chave Pix, endereço, dados bancários...). Funciona igual no Android e no iOS.

- **Toque numa nota para copiar** o conteúdo para a área de transferência.
- **Nova nota com o que está copiado**: botão na barra do topo.
- **Fixar** notas no topo; as demais ficam ordenadas pelo uso mais recente.
- **Ocultar** o conteúdo na lista para dados sensíveis. Mostrar, copiar, editar ou desocultar uma nota oculta pede **digital, rosto ou PIN do aparelho** (uma vez por visita à tela; trava de novo quando o app vai para segundo plano).
- Busca por título e conteúdo (o conteúdo de notas ocultas não entra na busca).
- Excluir com opção de desfazer.
- **Widget na tela inicial** com as notas fixadas. Notas ocultas nunca aparecem no widget.
  - Android: por padrão ocupa **1×1** — um botão "Notas" que abre uma janelinha com as notas fixadas; tocar numa copia e fecha, sem abrir o app. Redimensionado para 2×2 ou mais, mostra a lista direto (tocar numa nota copia; tocar no título abre as notas).
  - iOS: tamanhos pequeno, médio e grande (o menor do iOS equivale a 2×2 ícones). No médio e grande, tocar numa nota abre o app e copia (a Apple não deixa widgets escreverem na área de transferência); no pequeno, o toque abre as notas.

As notas ficam só no aparelho (`shared_preferences`), sem sincronização nem criptografia. A digital protege a visualização no app, não os dados gravados.

### Monitoramento

Dois celulares com o app: um **transmite** câmera, microfone e tela; o outro **assiste**. Feito para acompanhar os próprios filhos, com o aparelho em mãos e o consentimento deles.

- **Transparente por princípio**: enquanto transmite, o aparelho monitorado mostra um aviso permanente na tela e uma notificação fixa ("Monitoramento ativo"). Não há modo oculto.
- **Pareamento**: o transmissor gera um código de 6 dígitos; quem vai assistir digita esse código. A conexão de vídeo/áudio é ponto a ponto (WebRTC); o Firebase só serve para os dois se acharem.
- **Fontes**: o microfone vai sempre; o receptor alterna a imagem entre câmera frontal, traseira e tela.

| | Android | iOS |
| --- | --- | --- |
| Câmera + microfone | ✅ | ✅ |
| Tela | ✅ | ⏳ falta a Broadcast Extension (veja abaixo) |

Código: `lib/features/remote_monitor/`.

#### Configuração do Firebase (uma vez só)

Passo a passo completo em [docs/firebase-setup.md](docs/firebase-setup.md). Em resumo:

1. Crie um projeto no [Firebase Console](https://console.firebase.google.com) e ative o **Cloud Firestore**.
2. Registre os apps e baixe os arquivos de configuração (ambos ignorados pelo git):
   - Android (pacote `com.ramonmachadocarmo.mobileUtils`) → `android/app/google-services.json`.
   - iOS (bundle `com.ramonmachadocarmo.mobileUtils`) → `ios/Runner/GoogleService-Info.plist`.
   O jeito rápido é `dart pub global activate flutterfire_cli && flutterfire configure`.
3. Publique as regras de `firestore.rules`. Elas liberam só as coleções `monitor_sessions` e `walkie_sessions` (ofertas WebRTC efêmeras, sem dados pessoais). Sem login, quem souber o código pode entrar na sessão; para endurecer, adicione Firebase Auth.
4. No CI, o build funciona sem o `google-services.json` (o plugin do Firebase só é aplicado quando o arquivo existe), mas o monitoramento só conecta com ele presente. Para o app do CI funcionar, comite o arquivo ou injete-o de um secret.

#### iOS: captura de tela (pendente)

Câmera e microfone já funcionam no iOS. A captura de **tela** no iOS exige uma *Broadcast Upload Extension* (outro target, como a do bloqueio de chamadas) seguindo o guia de screen sharing do `flutter_webrtc`. Até ela existir, escolher "Tela" num iPhone transmissor não funciona.

### Walkie-talkie

Chamada de **duas vias** com câmera e microfone entre dois aparelhos — o monitoramento em versão simétrica, sem captura de tela. Funciona no Android e no iOS.

- **Pareamento**: um aparelho **cria a sala** e mostra um código de 6 dígitos; o outro **entra** com o código. A conexão é ponto a ponto (WebRTC), com a mesma sinalização do monitoramento (coleção `walkie_sessions`).
- **Modo walkie-talkie (push-to-talk)**: por padrão o microfone fica mudo e só transmite enquanto você segura o botão **Segure para falar**. Dá para desligar o modo e deixar o microfone sempre aberto, como uma chamada comum.
- **Câmera**: preview da própria câmera no canto e botão para virar entre frontal e traseira.

Usa o mesmo Firebase do monitoramento (veja a configuração acima). Código: `lib/features/walkie_talkie/`.

### Medidor de ruído

Mostra o nível de barulho em decibéis pelo microfone, com mínimo, média e máximo, gráfico dos últimos 30 s e uma tabela de referência (conversa, trânsito, limite de 85 dB para 8 h de exposição). Funciona no Android e no iOS.

- O áudio é lido em PCM e descartado na hora; nada é gravado nem enviado.
- A média é a energética (Leq), como nos decibelímetros, e não a média simples dos dB.
- O valor é o nível do microfone em dBFS + 90 dB, uma aproximação de dB SPL para celulares comuns. Não é um aparelho certificado: em **Calibrar** dá para ajustar ±20 dB comparando com um decibelímetro de referência.
- No Android usa a fonte de áudio de reconhecimento de voz, que desliga o ganho automático.

Código: `lib/features/noise_meter/`.

### WhatsApp rápido

Abre uma conversa no WhatsApp com qualquer número, sem salvar o contato. Funciona no Android e no iOS.

- Digite ou cole o número; sem `+`, recebe o DDI configurado (padrão +55). Números brasileiros precisam do DDD.
- Mensagem inicial opcional.
- Guarda os 10 últimos números para abrir de novo com um toque.

Usa o link oficial `https://wa.me/<número>?text=<mensagem>`. Código: `lib/features/quick_whatsapp/`.

## Identidade visual

Paleta: azul-marinho `#243C86`, azul `#047BFB`, laranja `#FD9704`, cinza `#4C4C4C` e branco (em `lib/theme.dart`). Títulos em Poppins e texto em Inter (via `google_fonts`, baixadas no primeiro uso e guardadas em cache).

As imagens ficam em `assets/branding/`. Depois de trocá-las, gere de novo:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

A splash nativa mostra só o logo. Em seguida, `lib/splash_overlay.dart` mostra o logo na mesma posição com o nome e a tagline por ~1,4 s (não aparece quando o app abre pelo widget).

## Rodando

```bash
flutter pub get
flutter run
```

## CI

`.github/workflows/ci.yml` roda `flutter analyze` e `flutter test` em todo push na `main`. Os PRs são testados pelo workflow do Android.

## Release Android (Play Store)

`.github/workflows/android.yml` roda analyze e testes em todo PR. **Um push de tag `v*`** gera o AAB assinado e envia para o teste interno da Play Store (`internal`, `completed`) — publicar um Release no GitHub também funciona, pois cria a tag. O disparo manual pela aba Actions permite escolher track e status (padrão `draft`), útil para validar o pipeline sem mexer no teste interno.

O `versionName` (`N.N.N`) e o `versionCode` (`+N`) vêm do `pubspec.yaml`. Para lançar, suba a versão e publique o release:

```bash
scripts/bump_version.sh patch   # ou minor / major — incrementa também o build number
scripts/release.sh              # commita, faz push e cria/sobe a tag vN.N.N (dispara o deploy)
```

O build number sempre cresce, então o deploy não é recusado por `versionCode` repetido.

### Configuração (uma vez só)

1. **Keystore de upload** (guarde fora do repositório e faça backup):

   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Para builds locais assinados, crie `android/key.properties` (ignorado pelo git) com `storeFile`, `storePassword`, `keyAlias` e `keyPassword`. Sem ele, o release usa a chave de debug.

2. **Play Console**: crie o app com o pacote `com.ramonmachadocarmo.mobileUtils`, ative o Play App Signing e envie o **primeiro AAB manualmente** (a API só publica em apps que já têm um upload).

3. **Service account**: no Google Cloud, ative a *Google Play Android Developer API*, crie uma service account e gere uma chave JSON. Na Play Console, em *Usuários e permissões*, convide o e-mail dela com permissão de gerenciar releases do app.

4. **Secrets** (*Settings › Secrets and variables › Actions*, no environment `play-store`):

   | Secret | Valor |
   | --- | --- |
   | `ANDROID_KEYSTORE_BASE64` | keystore em base64 |
   | `ANDROID_KEYSTORE_PASSWORD` | senha do keystore |
   | `ANDROID_KEY_ALIAS` | `upload` |
   | `ANDROID_KEY_PASSWORD` | senha da chave |
   | `PLAY_SERVICE_ACCOUNT_JSON` | conteúdo do JSON da service account |

   No PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))`.

## Release iOS (TestFlight)

> **Desativado por enquanto:** em `ios-release.yml`, o gatilho por tag e os passos de assinatura e upload estão comentados; o workflow só compila sem assinatura, manualmente. Para reativar, descomente esses trechos.

Tudo roda em runners macOS do GitHub Actions, sem precisar de Mac:

- **`.github/workflows/ios-setup.yml`** (manual): `targets` cria os targets das extensions e commita o projeto; `certificates` cria o certificado de distribuição e os profiles com o [fastlane match](https://docs.fastlane.tools/actions/match/).
- **`.github/workflows/ios-release.yml`**: com uma tag `vX.Y.Z` (ou manualmente), gera o `.ipa` assinado e envia para o TestFlight. A versão vem da tag e o build number é o número da execução.

```bash
git tag v1.0.1 && git push origin v1.0.1
```

### Configuração (uma vez só)

1. **Targets**: rode o workflow *iOS setup* com `targets`. Ele commita o `Runner.xcodeproj` com as extensions, o `Podfile` e o `Gemfile.lock`.
2. **Portal da Apple** ([developer.apple.com](https://developer.apple.com/account/resources/identifiers/list), em *Identifiers*):
   - Crie o App Group `group.com.ramonmachadocarmo.mobileUtils`.
   - Registre os App IDs `com.ramonmachadocarmo.mobileUtils`, `com.ramonmachadocarmo.mobileUtils.CallBlockerExtension` e `com.ramonmachadocarmo.mobileUtils.QuickNotesWidget`, todos com a capability **App Groups** apontando para esse grupo.
3. **App Store Connect**: crie o app com o bundle ID `com.ramonmachadocarmo.mobileUtils`. Em *Usuários e acesso › Integrações › Chaves da API do App Store Connect*, gere uma chave com acesso **Admin** e baixe o `.p8` (só dá para baixar uma vez).
4. **Repositório do match**: crie um repositório **privado** vazio no GitHub (ex.: `ios-certificates`) e um token (PAT) com acesso de escrita a ele.
5. **Secrets** (*Settings › Secrets and variables › Actions*, no environment `production`):

   | Secret | Valor |
   | --- | --- |
   | `APPLE_TEAM_ID` | Team ID (em *Membership details* no portal da Apple) |
   | `ASC_KEY_ID` | Key ID da chave de API |
   | `ASC_ISSUER_ID` | Issuer ID (topo da página de chaves) |
   | `ASC_KEY_P8_BASE64` | conteúdo do `.p8` em base64 |
   | `MATCH_GIT_URL` | `https://github.com/<usuario>/ios-certificates.git` |
   | `MATCH_GIT_BASIC_AUTHORIZATION` | base64 de `<usuario>:<PAT>` |
   | `MATCH_PASSWORD` | senha que você escolher para criptografar os certificados |

   No PowerShell, o base64 sai com `[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXX.p8"))` e `[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("usuario:PAT"))`.
6. **Certificados**: rode o workflow *iOS setup* com `certificates`. Repita quando o certificado (1 ano) ou os profiles expirarem.
