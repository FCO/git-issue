# bash completion for `git issue` (and the `git-issue` binary)
#
# Source this file from your ~/.bashrc (or drop it in
# /etc/bash_completion.d) to enable tab-completion of subcommands and
# issue ids.

_git_issue_complete() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    local subcommands="help new reply show ls edit-title edit-msg status close reopen pull push fetch sync"

    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$subcommands" -- "$cur") )
        return 0
    fi

    case "${COMP_WORDS[1]}" in
        show)
            local ids
            ids=$(git for-each-ref --format='%(refname)' refs/issues/ 2>/dev/null | sed 's#^refs/issues/##')
            COMPREPLY=( $(compgen -W "--all --open --closed $ids" -- "$cur") )
            ;;
        reply|edit-title|edit-msg|status)
            local ids
            ids=$(git for-each-ref --format='%(refname)' refs/issues/ 2>/dev/null | sed 's#^refs/issues/##')
            COMPREPLY=( $(compgen -W "$ids" -- "$cur") )
            ;;
        close|reopen)
            local ids
            ids=$(git for-each-ref --format='%(refname)' refs/issues/ 2>/dev/null | sed 's#^refs/issues/##')
            COMPREPLY=( $(compgen -W "-f --force $ids" -- "$cur") )
            ;;
        ls)
            COMPREPLY=( $(compgen -W "--all --open --closed --porcelain" -- "$cur") )
            ;;
        new)
            COMPREPLY=( $(compgen -W "-m --message" -- "$cur") )
            ;;
    esac
    return 0
}

complete -F _git_issue_complete git-issue

# Integrate with git's own completion so `git issue <TAB>` works too.
if declare -F __git_complete >/dev/null 2>&1; then
    __git_complete issue _git_issue_complete
fi
