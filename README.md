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

#### iOS: configuração no Xcode (uma vez só)

A extensão precisa ser adicionada como target no Xcode. Os arquivos já estão em `ios/CallBlockerExtension/`.

1. Abra `ios/Runner.xcworkspace` no Xcode.
2. **File › New › Target… › Call Directory Extension**, com nome `CallBlockerExtension` e bundle id `com.ramonmachadocarmo.mobile_utils.CallBlockerExtension`. Recuse "Activate scheme".
3. Apague os arquivos que o Xcode gerou para o target e adicione os de `ios/CallBlockerExtension/` (`CallDirectoryHandler.swift`, `Info.plist`, `CallBlockerExtension.entitlements`), marcando só o target da extensão.
4. Em **Build Settings** do target da extensão, aponte `INFOPLIST_FILE` para `CallBlockerExtension/Info.plist` e `CODE_SIGN_ENTITLEMENTS` para `CallBlockerExtension/CallBlockerExtension.entitlements`. Iguale o *iOS Deployment Target* ao do Runner.
5. No target **Runner**, defina `CODE_SIGN_ENTITLEMENTS` como `Runner/Runner.entitlements`.
6. Em **Signing & Capabilities**, adicione a capability **App Groups** com `group.com.ramonmachadocarmo.mobile_utils` nos dois targets.
7. No Runner, em **Build Phases**, confira se *Embed Foundation Extensions* inclui o `CallBlockerExtension.appex` e fica **antes** de *Thin Binary*.

#### iOS: widget das notas rápidas (uma vez só)

Os arquivos estão em `ios/QuickNotesWidget/`.

1. **File › New › Target… › Widget Extension**, nome `QuickNotesWidget`, bundle id `com.ramonmachadocarmo.mobile_utils.QuickNotesWidget`, **sem** "Include Configuration App Intent"/Live Activity. Recuse "Activate scheme".
2. Apague os arquivos gerados e adicione os de `ios/QuickNotesWidget/` (`QuickNotesWidget.swift`, `Info.plist`, `QuickNotesWidget.entitlements`) só no target do widget.
3. Em **Build Settings** do widget: `INFOPLIST_FILE` = `QuickNotesWidget/Info.plist`, `CODE_SIGN_ENTITLEMENTS` = `QuickNotesWidget/QuickNotesWidget.entitlements`, *iOS Deployment Target* 14.0.
4. Adicione a capability **App Groups** (`group.com.ramonmachadocarmo.mobile_utils`) no target do widget.
5. Confira em *Embed Foundation Extensions* do Runner que o `QuickNotesWidget.appex` está incluído e antes de *Thin Binary*.

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

`.github/workflows/ci.yml` roda `flutter analyze` e `flutter test` em todo PR e push na `main`.
