#compdef git-issue

# zsh completion for `git issue` (and the `git-issue` binary)
#
# Source this file (or place it on your $fpath as _git-issue) to enable
# tab-completion of subcommands and issue ids.

_git-issue() {
    local -a subcommands
    subcommands=(
        'help:Show help'
        'new:Create a new issue'
        'reply:Add a message to an issue'
        'show:Show an issue'
        'ls:List issues'
        'edit-title:Edit an issue title'
        'edit-msg:Edit a message'
        'status:Set an arbitrary status'
        'priority:Set an issue priority'
        'tag:Add tags to an issue'
        'untag:Remove tags from an issue'
        'config:List, get, or set configuration'
        'import:Import GitHub issues into refs/issues'
        'close:Close an issue'
        'reopen:Reopen an issue'
        'pull:Pull issue refs'
        'push:Push issue refs'
        'fetch:Fetch issue refs'
        'sync:Sync issue refs'
    )

    if (( CURRENT == 2 )); then
        _describe 'command' subcommands
        return
    fi

    case "${words[2]}" in
        show)
            local -a ids
            ids=(${(f)"$(git for-each-ref --format='%(refname)' refs/issues/ 2>/dev/null | sed 's#^refs/issues/##')"})
            _values 'flag' '--all' '--open' '--closed'
            _describe 'issue id' ids
            ;;
        reply|edit-title|edit-msg|close|reopen|status|priority|tag|untag)
            local -a ids
            ids=(${(f)"$(git for-each-ref --format='%(refname)' refs/issues/ 2>/dev/null | sed 's#^refs/issues/##')"})
            _describe 'issue id' ids
            ;;
        ls)
            _values 'flag' '--all' '--open' '--closed' '--porcelain' '--sort' '--priority-gt' '--priority-lt' '--priority' '--tag'
            ;;
        new)
            _values 'flag' '-m' '--message'
            ;;
        import)
            _values 'flag' '--state' '--comments'
            ;;
        close|reopen)
            _values 'flag' '-f' '--force'
            ;;
    esac
}

_git-issue "$@"
