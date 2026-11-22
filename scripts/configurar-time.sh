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

if ! printf '%s\n' "$meu_time" | grep -Eq '^[A-Z0-9]{10}$'; then
    echo "Erro: Team ID inválido ('$meu_time'). O Team ID da Apple deve ter 10 caracteres (letras maiúsculas A-Z e números 0-9)." >&2
    echo "Exemplo: sh scripts/configurar-time.sh ABC123XYZ9" >&2
    exit 1
fi

# Guardado só neste computador (.git/config), nunca vai para o GitHub
git config time-apple.meuTime "$meu_time"
git config filter.time-apple.clean "sh scripts/filtro-time-apple.sh clean"
git config filter.time-apple.smudge "sh scripts/filtro-time-apple.sh smudge"
git config filter.time-apple.required true

# O smudge normalmente ajusta arquivos durante checkout. Em um pull integrado
# por merge, reaplica o Team ID local após o merge para manter o projeto pronto
# para abrir no Xcode.
hooks_dir=$(git rev-parse --git-path hooks)
post_merge="$hooks_dir/post-merge"
marcador="# configurado por scripts/configurar-time.sh"
if [ -e "$post_merge" ] && ! grep -Fq "$marcador" "$post_merge"; then
    echo "Aviso: já existe um hook post-merge em $post_merge; ele não foi sobrescrito."
else
    cat > "$post_merge" <<'HOOK'
#!/bin/sh
# configurado por scripts/configurar-time.sh
set -e
cd "$(git rev-parse --show-toplevel)"

git ls-files '*.xcproj' '*.pbxproj' | while IFS= read -r arquivo; do
    temporario="$arquivo.time-apple-tmp"
    if sh scripts/filtro-time-apple.sh smudge < "$arquivo" > "$temporario"; then
        mv "$temporario" "$arquivo"
    else
        rm -f "$temporario"
        exit 1
    fi
done
HOOK
    chmod +x "$post_merge"
fi

# Coloca o seu time no projeto que já está aqui, sem perder nenhuma outra mudança sua
git ls-files '*.xcproj' '*.pbxproj' | while IFS= read -r arquivo; do
    temporario="$arquivo.time-apple-tmp"
    if sh scripts/filtro-time-apple.sh smudge < "$arquivo" > "$temporario"; then
        mv "$temporario" "$arquivo"
    else
        rm -f "$temporario"
        exit 1
    fi
done

echo "Pronto! Neste computador o projeto usa o time $meu_time."
echo "Nos commits, o time vai sempre como o oficial do repositório."
echo "Se o Xcode estiver aberto, feche e abra o projeto de novo."
