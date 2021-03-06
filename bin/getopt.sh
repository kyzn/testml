#! bash

set -e

getopt() {
  local opt_spec
  opt_spec="$(
    echo "$GETOPT_SPEC" |
      grep -A999999 '^--$' |
      grep -v '^\s*$' |
      tail -n+2
  )"

  if ${GETOPT_DEFAULT_HELP:-true}; then
    if [[ $# -eq 0 ]];then
      set -- --help
    fi
  fi

  local parsed
  parsed="$(
    echo "$GETOPT_SPEC" |
    git rev-parse --parseopt -- "$@"
  )" || true

  if [[ $parsed =~ ^cat ]]; then
    eval "$parsed" | pager
    exit 0
  else
    eval "$parsed"
  fi

  while IFS= read -r line; do
    if [[ $line =~ ^([a-zA-Z]+)(,([a-z]+))?(=?)\  ]]; then
      opt_var="option_${BASH_REMATCH[1]}"
      if [[ -n ${BASH_REMATCH[3]} ]]; then
        opt_var="option_${BASH_REMATCH[3]}"
      fi
      if [[ -z ${BASH_REMATCH[4]} ]]; then
        printf -v "$opt_var" false
      else
        lines_var="${opt_var}_lines"
        if [[ -n ${!lines_var} ]]; then
          eval "$opt_var+=()"
        fi
      fi
    fi
  done <<<"$opt_spec"

  while [ $# -gt 0 ]; do
    local option="$1"; shift

    [[ $option != -- ]] || break

    local found=false line=
    while IFS= read -r line; do
      local wants_value=false match opt_var
      if [[ $line =~ ^([-a-zA-Z]+)(,([-a-z]+))?(=?)\  ]]; then
        if [[ "${#BASH_REMATCH[1]}" -gt 1 ]]; then
          match="--${BASH_REMATCH[1]}"
        else
          match="-${BASH_REMATCH[1]}"
        fi
        opt_var="option_${BASH_REMATCH[1]}"
        if [[ -n "${BASH_REMATCH[3]}" ]]; then
          opt_var="option_${BASH_REMATCH[3]}"
        fi
        opt_var=${opt_var//-/_}
        if [[ -n "${BASH_REMATCH[4]}" ]]; then
          wants_value=true
        fi
      else
        die "Invalid GETOPT_SPEC option line: '$line'"
      fi

      if [[ $option == "$match" ]]; then
        if $wants_value; then
          lines_var="${opt_var}_lines"
          if [[ -n ${!lines_var} ]]; then
            eval "$opt_var+=('$1')"
          else
            printf -v "$opt_var" "%s" "$1"
          fi
          shift
        else
          printf -v "$opt_var" true
        fi
        found=true
        break
      fi
    done <<<"$opt_spec"

    $found || die "Unexpected option: '$option'"
  done

  local arg_name arg_var required=false array=false re1='^\+'
  for arg_name in $GETOPT_ARGS; do
    arg_var="${arg_name//-/_}"
    if [[ $arg_var =~ ^@ ]]; then
      array=true
      arg_var="${arg_var#@}"
    fi
    if [[ "$arg_var" =~ $re1 ]]; then
      required=true
      arg_var="${arg_var#+}"
    fi

    if [[ $# -gt 0 ]]; then
      if $array; then
        # XXX do this without eval:
        set -f
        eval "$arg_var=($*)"
        set +f
        set --
      else
        printf -v "$arg_var" "%s" "$1"
        shift
      fi
    fi
    if $required && [[ -z ${!arg_var} ]]; then
      die "'$arg_name' is required"
    fi
  done
  [ $# -eq 0 ] || die "Unexpected arguments: '$*'"
}

pager() {
  less -FRX
}

# vim: set ft=sh lisp:
