# Configuração do Firebase — Monitoramento

Passo a passo para ligar o util de **Monitoramento**. O Firebase é usado só para
sinalização (os dois celulares trocam ofertas WebRTC e depois conversam direto);
nenhum vídeo ou áudio passa pela nuvem.

Identificadores deste app:

| | Valor |
| --- | --- |
| Pacote Android | `com.ramonmachadocarmo.mobileUtils` |
| Bundle iOS | `com.ramonmachadocarmo.mobileUtils` |
| Coleção Firestore | `monitor_sessions` |

---

## 1. Criar o projeto

1. Abra o [Firebase Console](https://console.firebase.google.com) e **Adicionar projeto**.
2. Nome à escolha (ex.: `omnitool`). Google Analytics é opcional — pode desativar.

## 2. Ativar o Cloud Firestore

1. No menu lateral: **Criar** › **Firestore Database** › **Criar banco de dados**.
2. Local: escolha `southamerica-east1` (São Paulo) para menor latência no Brasil.
3. Comece em **modo de produção** (as regras deste repositório vão substituir as padrão).

## 3. Registrar os apps e baixar as configurações

Você pode fazer manualmente (3a) ou pelo `flutterfire` (3b). O resultado é o mesmo:
dois arquivos de configuração no lugar certo. Os dois já estão no `.gitignore`.

### 3a. Manual

**Android**

1. No Console: ⚙️ **Configurações do projeto** › aba **Geral** › **Seus apps** › ícone Android.
2. Nome do pacote: `com.ramonmachadocarmo.mobileUtils`. Apelido e SHA-1 são opcionais.
3. Baixe o `google-services.json` e coloque em:

   ```
   android/app/google-services.json
   ```

**iOS**

1. Ainda em **Seus apps**, clique no ícone Apple.
2. ID do pacote: `com.ramonmachadocarmo.mobileUtils`.
3. Baixe o `GoogleService-Info.plist` e coloque em:

   ```
   ios/Runner/GoogleService-Info.plist
   ```

   No iOS, esse arquivo também precisa estar incluído no target **Runner** do Xcode.
   O script `ios/scripts/add_extension_targets.rb` não faz isso; se você usa o
   fluxo sem Mac, adicione-o à lista de recursos do Runner (ou rode uma vez o
   `flutterfire configure`, que já o inclui).

### 3b. flutterfire (mais rápido)

Precisa do [Firebase CLI](https://firebase.google.com/docs/cli) logado (`firebase login`):

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<id-do-projeto>
```

Selecione Android e iOS. Ele baixa os dois arquivos, coloca nos lugares certos e
gera o `lib/firebase_options.dart`. Este app inicializa o Firebase pela
configuração nativa, então o `firebase_options.dart` é opcional — pode manter.

## 4. Publicar as regras de segurança

As regras estão em [`firestore.rules`](../firestore.rules): liberam apenas a
coleção `monitor_sessions`, que guarda ofertas efêmeras (SDP e ICE), sem dados
pessoais, apagadas ao encerrar a sessão.

**Pelo Console** (mais simples): Firestore Database › aba **Regras** › cole o
conteúdo de `firestore.rules` › **Publicar**.

**Pela CLI** (se preferir versionar):

```bash
npm install -g firebase-tools
firebase login
firebase init firestore   # aponte para firestore.rules quando perguntar
firebase deploy --only firestore:rules
```

## 5. Testar

Com os arquivos no lugar:

```bash
flutter pub get
flutter run   # em dois aparelhos
```

1. Aparelho A: **Monitoramento** › _Este aparelho será transmitido_ › aceite o
   consentimento › **Iniciar transmissão**. Anote o código de 6 dígitos.
2. Aparelho B: **Monitoramento** › _Assistir a outro aparelho_ › digite o código
   › **Conectar**.

Se aparecer "Firebase não configurado" ao abrir o Monitoramento, os arquivos de
configuração não foram encontrados — confira os caminhos do passo 3.

## 6. CI (opcional)

O build do CI funciona **sem** o `google-services.json` — o plugin do Firebase só
é aplicado quando o arquivo existe. Mas o app gerado pelo CI só conecta o
monitoramento com o arquivo presente. Duas opções:

- **Comitar** `android/app/google-services.json` (ele não contém segredo
  sensível — é embarcado no app de qualquer forma). Para isso, remova a linha
  correspondente do `.gitignore`.
- **Injetar de um secret**: guarde o conteúdo em `GOOGLE_SERVICES_JSON` e
  adicione um passo antes do build no `.github/workflows/android.yml`:

  ```yaml
  - name: google-services.json
    run: echo '${{ secrets.GOOGLE_SERVICES_JSON }}' > android/app/google-services.json
  ```

## Segurança e custo

- **Sem login**: quem descobrir o código de 6 dígitos pode entrar na sessão. A
  proteção é o código aleatório e a vida curta do documento. Para endurecer,
  adicione Firebase Auth e valide o dono da sessão nas regras.
- **Custo**: a sinalização são poucas leituras/escritas por sessão. O vídeo é
  ponto a ponto e **não** passa pelo Firebase, então o tier gratuito (Spark)
  cobre folgado o uso pessoal.
- **NAT**: em redes muito fechadas, os STUN públicos podem não bastar e a
  conexão não fecha. Nesse caso é preciso somar um servidor TURN em
  `lib/features/remote_monitor/monitor_session.dart` (`_iceServers`).
