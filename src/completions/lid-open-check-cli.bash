_pam_lid_open_check()
{
    local cur prev

    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "${COMP_CWORD}" in
        1)
            COMPREPLY=( $(compgen -W "status enable disable help debug state" -- "$cur") )
            ;;
        2)
            case "$prev" in
                debug)
                    COMPREPLY=( $(compgen -W "enable disable" -- "$cur") )
                    ;;
                state)
                    COMPREPLY=( $(compgen -W "open closed" -- "$cur") )
                    ;;
            esac
            ;;
    esac
}

complete -F _pam_lid_open_check lid-open-check-cli