# Bash completion ports for aichat and ftdv.

_aichat_completion() {
  local cur prev
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]:-}

  case $prev in
    -m|--model)
      COMPREPLY=( $(compgen -W "$(command aichat --list-models 2>/dev/null)" -- "$cur") )
      return
      ;;
    -r|--role)
      COMPREPLY=( $(compgen -W "$(command aichat --list-roles 2>/dev/null)" -- "$cur") )
      return
      ;;
    -s|--session)
      COMPREPLY=( $(compgen -W "$(command aichat --list-sessions 2>/dev/null)" -- "$cur") )
      return
      ;;
    -a|--agent)
      COMPREPLY=( $(compgen -W "$(command aichat --list-agents 2>/dev/null)" -- "$cur") )
      return
      ;;
    --rag)
      COMPREPLY=( $(compgen -W "$(command aichat --list-rags 2>/dev/null)" -- "$cur") )
      return
      ;;
    --macro)
      COMPREPLY=( $(compgen -W "$(command aichat --list-macros 2>/dev/null)" -- "$cur") )
      return
      ;;
    -f|--file)
      COMPREPLY=( $(compgen -f -- "$cur") )
      compopt -o filenames
      return
      ;;
  esac

  local options='-m --model --prompt -r --role -s --session --empty-session --save-session -a --agent --agent-variable --rag --rebuild-rag --macro --serve -e --execute -c --code -f --file -S --no-stream --dry-run --info --sync-models --list-models --list-roles --list-sessions --list-agents --list-rags --list-macros -h --help -V --version'
  COMPREPLY=( $(compgen -W "$options" -- "$cur") )
}

_ftdv_completion() {
  local cur prev word command= i
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]:-}

  if [[ $prev == --config ]]; then
    COMPREPLY=( $(compgen -f -- "$cur") )
    compopt -o filenames
    return
  fi

  for ((i = 1; i < COMP_CWORD; i++)); do
    word=${COMP_WORDS[i]}
    case $word in
      --config) ((i++)) ;;
      diff|status|completions|help) command=$word; break ;;
    esac
  done

  case $command in
    diff)
      COMPREPLY=( $(compgen -W '--cached -h --help' -- "$cur") )
      ;;
    status|completions)
      COMPREPLY=( $(compgen -W '-h --help' -- "$cur") )
      ;;
    help)
      COMPREPLY=( $(compgen -W 'diff status completions help' -- "$cur") )
      ;;
    *)
      COMPREPLY=( $(compgen -W '-c --cached -w --worktree --config -v --verbose -h --help -V --version diff status completions help' -- "$cur") )
      ;;
  esac
}

complete -F _aichat_completion aichat
complete -F _ftdv_completion ftdv
