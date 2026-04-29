ryoku_limine_ensure_cmdline_flags() {
  local limine_config="$1"
  shift

  local temp_file line updated_line indent cmdline padded_cmdline flag

  temp_file=$(mktemp)

  while IFS= read -r line; do
    if [[ $line =~ ^([[:space:]]*)cmdline:[[:space:]]*(.*)$ ]]; then
      indent="${BASH_REMATCH[1]}"
      cmdline="${BASH_REMATCH[2]}"

      for flag in "$@"; do
        padded_cmdline=" $cmdline "
        [[ $padded_cmdline == *" $flag "* ]] || cmdline+=" $flag"
      done

      updated_line="${indent}cmdline: $cmdline"
      printf '%s\n' "$updated_line" >>"$temp_file"
    else
      printf '%s\n' "$line" >>"$temp_file"
    fi
  done <"$limine_config"

  mv "$temp_file" "$limine_config"
}
