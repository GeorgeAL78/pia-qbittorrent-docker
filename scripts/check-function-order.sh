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
# DEFINITION FORMS RECOGNISED. All four of these are legal POSIX and all four fail
# identically at runtime when called early, so all four are matched:
#
#   f() {          f(){          f () {          f()
#                                                {
#
# An earlier version of this script matched only the first, which meant a
# reformat could reintroduce the bug with a green build. If you add a form this
# does not recognise, the gate silently stops protecting that function - so
# widen the matcher rather than working around it.
#
# What this does NOT do: detect calls to functions that are never defined at all.
# That is a different class, and `not found` in the container startup log is the
# standing assertion for it.
#
# Usage: check-function-order.sh <file> [file...]
status=0

for f in "$@"; do
  [ -f "$f" ] || continue
  out=$(awk '
    { line[NR] = $0 }
    # Candidate definition: optional indent, name, optional space, (), then either
    # "{" on this line or nothing more (with "{" expected on the next line).
    /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\([[:space:]]*\)[[:space:]]*\{?[[:space:]]*$/ {
      cand = $0
      sub(/^[[:space:]]*/, "", cand)
      sub(/[[:space:]]*\(.*$/, "", cand)
      # Brace on this line, or on the next one by itself.
      if ($0 ~ /\{[[:space:]]*$/) { if (!(cand in def)) def[cand] = NR }
      else { pend = cand; pendline = NR; next }
    }
    # Resolve the two-line form: "{" alone on the line after "name()".
    pend != "" {
      if ($0 ~ /^[[:space:]]*\{[[:space:]]*$/ && NR == pendline + 1) {
        if (!(pend in def)) def[pend] = pendline
      }
      pend = ""
    }
    END {
      for (n in def) {
        for (i = 1; i < def[n]; i++) {
          if (line[i] ~ /^[[:space:]]*#/) continue
          # Skip the definition line itself in any of its forms.
          if (line[i] ~ ("^[[:space:]]*" n "[[:space:]]*\\([[:space:]]*\\)")) continue
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
