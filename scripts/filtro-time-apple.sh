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

TIME_OFICIAL="PPWW79FQJ9"   # time da conta dona de https://github.com/vivicarteri/AdaLovelace

trocar_time() {
    # project.xcproj  (formato novo, JSON): "DEVELOPMENT_TEAM": "ABC123XYZ9",
    # project.pbxproj (formato antigo):     DEVELOPMENT_TEAM = ABC123XYZ9;
    # Também pega as versões por plataforma, tipo DEVELOPMENT_TEAM[sdk=iphoneos*].
    sed -E \
        -e "s/(\"DEVELOPMENT_TEAM(\[[^]\"]*\])?\"[[:space:]]*:[[:space:]]*\")[^\"]*\"/\1$1\"/g" \
        -e "s/(DEVELOPMENT_TEAM(\[[^]\"]*\])?\"?[[:space:]]*=[[:space:]]*)\"?[A-Za-z0-9]*\"?;/\1$1;/g"
}

case "$1" in
    clean)
        trocar_time "$TIME_OFICIAL"
        ;;
    smudge)
        meu_time=$(git config --get time-apple.meuTime)
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
