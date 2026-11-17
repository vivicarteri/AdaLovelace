#!/bin/sh
# Filtro do git para o time da Apple (DEVELOPMENT_TEAM) do projeto do Xcode.
#
# Cada pessoa do grupo usa a PRÓPRIA conta Apple Developer no computador dela,
# mas o que vai para o GitHub é sempre o time oficial do repositório.
#
#   clean  → roda no commit (git add): troca o time de quem está commitando pelo time oficial.
#   smudge → roda no checkout/pull:    troca o time oficial pelo time de quem está nesta máquina.
#
# Não precisa rodar este arquivo na mão: o git chama ele sozinho.
# Para ligar, cada pessoa roda UMA vez: sh scripts/configurar-time.sh SEU_TEAM_ID

set -eu

TIME_OFICIAL="PPWW79FQJ9"   # time da conta dona de https://github.com/vivicarteri/AdaLovelace

trocar_time() {
    # Se o Team ID não tiver o formato de 10 caracteres alfanuméricos, repassa o arquivo intacto
    # para nunca corromper o projeto com erro do sed.
    if ! printf '%s\n' "$1" | grep -Eq '^[A-Z0-9]{10}$'; then
        cat
        return
    fi
    # project.xcproj  (formato novo, JSON): "DEVELOPMENT_TEAM": "ABC123XYZ9",
    # project.pbxproj (formato antigo):     DEVELOPMENT_TEAM = ABC123XYZ9;
    # Também pega as versões por plataforma, tipo "DEVELOPMENT_TEAM[sdk=iphoneos*]" = ABC123XYZ9;
    sed -E \
        -e "s/(\"DEVELOPMENT_TEAM(\[[^]\"]*\])?\"[[:space:]]*:[[:space:]]*\")[^\"]*\"/\1$1\"/g" \
        -e "s/(\"?DEVELOPMENT_TEAM(\[[^]\"]*\])?\"?[[:space:]]*=[[:space:]]*)\"?[A-Za-z0-9_]*\"?;/\1$1;/g"
}

case "${1:-}" in
    clean)
        trocar_time "$TIME_OFICIAL"
        ;;
    smudge)
        meu_time=$(git config --get time-apple.meuTime || true)
        if [ -n "$meu_time" ]; then
            trocar_time "$meu_time"
        else
            cat
        fi
        ;;
    *)
        cat
        ;;
esac
