#!/bin/sh
# Liga a troca automática do time da Apple neste computador.
#
# Rode UMA vez, na pasta do repositório, com o Team ID da SUA conta Apple Developer:
#
#     sh scripts/configurar-time.sh ABC123XYZ9
#
# Onde achar o Team ID: developer.apple.com/account → Membership details → Team ID
# (ou no Xcode: Settings → Accounts → sua conta).
#
# Depois disso:
#   - no seu computador o projeto usa o SEU time (pode escolher ele no Xcode normalmente);
#   - quando você faz commit, o que vai para o GitHub é sempre o time oficial (PPWW79FQJ9);
#   - quando você faz pull, o projeto volta para o SEU time sozinho.
#
# Para trocar de time depois, é só rodar de novo com o novo Team ID.

set -e
cd "$(git rev-parse --show-toplevel)"

meu_time="$1"
if [ -z "$meu_time" ]; then
    echo "Uso: sh scripts/configurar-time.sh SEU_TEAM_ID"
    echo "Exemplo: sh scripts/configurar-time.sh ABC123XYZ9"
    exit 1
fi

# Guardado só neste computador (.git/config), nunca vai para o GitHub
git config time-apple.meuTime "$meu_time"
git config filter.time-apple.clean "sh scripts/filtro-time-apple.sh clean"
git config filter.time-apple.smudge "sh scripts/filtro-time-apple.sh smudge"

# Coloca o seu time no projeto que já está aqui, sem perder nenhuma outra mudança sua
git ls-files '*.xcproj' '*.pbxproj' | while IFS= read -r arquivo; do
    sh scripts/filtro-time-apple.sh smudge < "$arquivo" > "$arquivo.tmp"
    mv "$arquivo.tmp" "$arquivo"
done

echo "Pronto! Neste computador o projeto usa o time $meu_time."
echo "Nos commits, o time vai sempre como o oficial do repositório."
echo "Se o Xcode estiver aberto, feche e abra o projeto de novo."
