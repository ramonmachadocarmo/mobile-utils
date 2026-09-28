# OmniTool

[![Sponsor](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/ramonmachadocarmo)

**All-In-One Mobile Utilities**: app Flutter (Android e iOS) com utilitários pessoais. Cada utilitário fica em `lib/features/<nome>/` e é listado na tela inicial em `lib/main.dart` (`_utilities`).

## Utilitários

### Bloqueio de chamadas

Rejeita automaticamente chamadas recebidas conforme regras configuráveis:

- **Números digitados**: qualquer número, com descrição opcional.
- **Números dos contatos**: escolhidos da agenda (busca e seleção múltipla).
- **Desconhecidos**: números fora da agenda e números ocultos/privados (**só Android**).
- **Histórico** das chamadas rejeitadas nos últimos 7 dias; as mais antigas são apagadas automaticamente (**só Android**).

Os números batem por sufixo (mínimo de 8 dígitos), então `+55 11 91234-5678`, `(11) 91234-5678` e `011 91234-5678` são tratados como o mesmo número.

| | Android | iOS |
|---|---|---|
| Bloquear números da lista | ✅ `CallScreeningService` | ✅ Call Directory Extension |
| Bloquear desconhecidos | ✅ | ❌ a Apple não permite; use Ajustes › Apps › Telefone › Silenciar Desconhecidos |
| Histórico (7 dias) | ✅ | ❌ o iOS não informa a extensão |
| Versão mínima | Android 10 (API 29) | iOS 14 |

#### Android

Na primeira vez, toque em **Ativar** na tela de bloqueio e escolha o OmniTool como *app de identificação de chamadas e spam*. Para bloquear desconhecidos, o app precisa da permissão de contatos (pedida ao ligar a opção). Sem ela, não dá para saber quem é desconhecido e as chamadas passam; se a permissão for retirada depois (ex.: reinstalação), a tela mostra um aviso com o botão **Permitir**.

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
3. Publique as regras de `firestore.rules`. Elas liberam só a coleção `monitor_sessions` (ofertas WebRTC efêmeras, sem dados pessoais). Sem login, quem souber o código pode entrar na sessão; para endurecer, adicione Firebase Auth.
4. No CI, o build funciona sem o `google-services.json` (o plugin do Firebase só é aplicado quando o arquivo existe), mas o monitoramento só conecta com ele presente. Para o app do CI funcionar, comite o arquivo ou injete-o de um secret.

#### iOS: captura de tela (pendente)

Câmera e microfone já funcionam no iOS. A captura de **tela** no iOS exige uma *Broadcast Upload Extension* (outro target, como a do bloqueio de chamadas) seguindo o guia de screen sharing do `flutter_webrtc`. Até ela existir, escolher "Tela" num iPhone transmissor não funciona.

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

`.github/workflows/android.yml` roda analyze e testes em todo PR. Com uma tag `v*` (ou manualmente pela aba Actions, escolhendo o track), gera o AAB assinado e envia para a Play Store (track `internal` por padrão). O `versionName` vem da tag e o `versionCode` é o número da execução.

```bash
git tag v1.0.1 && git push origin v1.0.1
```

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
