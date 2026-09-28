# Play Console — textos para copiar

Rascunhos para preencher a ficha da loja e as declarações de **Conteúdo do app**.
Enquadram o Monitoramento como parental e consentido — o que evita a reprovação
por política de vigilância. Ajuste o que quiser antes de colar.

---

## 1. Ficha da loja principal

**Nome do app**

```
OmniTool
```

**Descrição breve** (máx. 80 caracteres)

```
Utilitários pessoais: bloqueio de chamadas, notas rápidas e monitoramento familiar.
```

**Descrição completa** (máx. 4000 caracteres)

```
O OmniTool reúne utilitários pessoais para o dia a dia, num app só:

BLOQUEIO DE CHAMADAS
Rejeita automaticamente chamadas de números que você escolher, de contatos
selecionados e de desconhecidos. As regras ficam apenas no seu aparelho.

NOTAS RÁPIDAS
Guarde textos que você usa com frequência (chave Pix, endereço, dados) e copie
com um toque. Notas sensíveis podem ficar ocultas, protegidas por biometria.

MONITORAMENTO FAMILIAR
Permite que um aparelho da família transmita câmera, microfone e tela para outro
aparelho, para que responsáveis acompanhem os próprios filhos.

Transparente por princípio: enquanto está transmitindo, o aparelho monitorado
mostra um aviso permanente na tela e na barra de notificações. Não há modo oculto.
Use apenas em aparelhos seus e com o conhecimento e o consentimento de quem usa o
aparelho monitorado. O app não se destina a monitorar pessoas sem o conhecimento
delas.

Os dados de vídeo e áudio vão diretamente entre os dois aparelhos e não são
gravados nem armazenados em servidores.
```

> **Não use** palavras como "espião", "oculto", "secreto", "sem que saibam". É o
> que dispara a reprovação por política de apps de vigilância (stalkerware).

---

## 2. Permissões de serviço em primeiro plano

Aparece na página **Conteúdo do app** só depois de subir uma build que declare
essas permissões (a build 1000, anterior ao Monitoramento, não conta). Para cada
tipo, cole a justificativa e grave um vídeo curto (30–60 s) mostrando o uso.

**Câmera** (`FOREGROUND_SERVICE_CAMERA`)

```
No utilitário de Monitoramento, o aparelho transmite a câmera para outro aparelho
da família, para acompanhamento parental consentido. O serviço em primeiro plano
mantém a transmissão ativa e exibe um aviso permanente enquanto ela dura.
```

**Microfone** (`FOREGROUND_SERVICE_MICROPHONE`)

```
No utilitário de Monitoramento, o aparelho transmite o áudio do microfone para
outro aparelho da família. O serviço em primeiro plano mantém a transmissão ativa
e exibe um aviso permanente enquanto ela dura.
```

**Projeção de mídia / captura de tela** (`FOREGROUND_SERVICE_MEDIA_PROJECTION`)

```
No utilitário de Monitoramento, o aparelho transmite a própria tela para outro
aparelho da família, com confirmação do sistema a cada sessão. O serviço em
primeiro plano mantém a transmissão ativa e exibe um aviso permanente enquanto
ela dura.
```

> **Vídeo de demonstração**: grave a tela mostrando iniciar a transmissão, o aviso
> permanente aparecendo e o outro aparelho recebendo a imagem. Suba no YouTube
> (não listado) e cole o link no formulário.

---

## 3. Segurança dos dados (Data safety)

Guia de como responder o formulário:

- **O app coleta ou compartilha dados do usuário?**
  Câmera, microfone e tela são **acessados**, mas transmitidos ponto a ponto e
  **não coletados** por você (não passam pelos seus servidores nem são gravados).
  Contatos e notas ficam só no aparelho. Se responder que coleta, o formulário
  passa a exigir detalhamento; a resposta honesta aqui é que os dados **não são
  coletados** por você — são processados no aparelho / entre aparelhos.
- **Os dados são criptografados em trânsito?** Sim — o WebRTC criptografa a
  transmissão (DTLS/SRTP) entre os aparelhos.
- **O usuário pode pedir a exclusão dos dados?** Os dados locais são apagados ao
  desinstalar; a sinalização é apagada ao encerrar a sessão. Não há conta nem
  dado no servidor para excluir.

---

## 4. Outras declarações da página

- **Política de Privacidade**: hospede `docs/privacy-policy.html` e cole a URL.
  Pelo GitHub Pages (Settings › Pages › branch `main`, pasta `/docs`), a URL fica
  `https://<seu-usuario>.github.io/<repo>/privacy-policy.html`.
- **Anúncios**: não contém anúncios.
- **Acesso ao app**: todas as funcionalidades disponíveis sem acesso especial (não há login).
- **Público-alvo**: faixa **adulta (18+)**. Não inclua público infantil — um app de
  monitoramento no público Famílias é barrado.
- **Classificação de conteúdo**: questionário padrão, sem violência/conteúdo adulto.
