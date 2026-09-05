#!/bin/sh
# Fail if a shell function is called before the line that defines it.
#
# POSIX sh and busybox ash create a function when its definition is EXECUTED, not
# when the file is parsed. A call above the definition is therefore "not found",
# $? is 127, and execution continues down whatever error path follows.
#
# This shipped once: in v5.2.3-16, pf_bind was called at line 1191 and defined at
# 1374, so the startup bind failed, PORT_FORWARDING was switched off for the life
# of the container, and the refresh loop could never recover it. Neither `sh -n`
# nor `shellcheck` flags this - it is valid shell, just wrong at runtime.
#
# Usage: check-function-order.sh <file> [file...]
status=0

for f in "$@"; do
  [ -f "$f" ] || continue
  out=$(awk '
    # Definition: a top-level "name() {" at the start of a line.
    /^[a-z_][a-z0-9_]*\(\) \{/ {
      name = $1
      sub(/\(\).*/, "", name)
      if (!(name in def)) def[name] = NR
    }
    { line[NR] = $0 }
    END {
      for (n in def) {
        for (i = 1; i < def[n]; i++) {
          # Skip comments and the definition line itself.
          if (line[i] ~ /^[[:space:]]*#/) continue
          if (line[i] ~ ("^[[:space:]]*" n "\\(\\)")) continue
          # A call: the name bounded by non-identifier characters, not followed
          # by "(" (which would be another definition or a subshell construct).
          if (line[i] ~ ("(^|[^a-zA-Z0-9_])" n "([^a-zA-Z0-9_(]|$)")) {
            printf "  %s called at line %d but defined at line %d\n", n, i, def[n]
            bad = 1
          }
        }
      }
      exit bad ? 1 : 0
    }' "$f")
  if [ -n "$out" ]; then
    printf '%s: functions used before definition\n%s\n' "$f" "$out"
    status=1
  else
    printf '  %s: all functions defined before first call\n' "$f"
  fi
done

exit $status
