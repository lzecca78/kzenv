#!/usr/bin/env bash

set -uo pipefail;

####################################
# Ensure we can execute standalone #
####################################

function early_death() {
  echo "[FATAL] ${0}: ${1}" >&2;
  exit 1;
};

if [ -z "${KZENV_ROOT:-""}" ]; then
  # http://stackoverflow.com/questions/1055671/how-can-i-get-the-behavior-of-gnus-readlink-f-on-a-mac
  readlink_f() {
    local target_file="${1}";
    local file_name;

    while [ "${target_file}" != "" ]; do
      cd "$(dirname ${target_file})" || early_death "Failed to 'cd \$(dirname ${target_file})' while trying to determine KZENV_ROOT";
      file_name="$(basename "${target_file}")" || early_death "Failed to 'basename \"${target_file}\"' while trying to determine KZENV_ROOT";
      target_file="$(readlink "${file_name}")";
    done;

    echo "$(pwd -P)/${file_name}";
  };

  KZENV_ROOT="$(cd "$(dirname "$(readlink_f "${0}")")/.." && pwd)";
  [ -n ${KZENV_ROOT} ] || early_death "Failed to 'cd \"\$(dirname \"\$(readlink_f \"${0}\")\")/..\" && pwd' while trying to determine KZENV_ROOT";
else
  KZENV_ROOT="${KZENV_ROOT%/}";
fi;
export KZENV_ROOT;

if [ -n "${KZENV_HELPERS:-""}" ]; then
  log 'debug' 'KZENV_HELPERS is set, not sourcing helpers again';
else
  [ "${KZENV_DEBUG:-0}" -gt 0 ] && echo "[DEBUG] Sourcing helpers from ${KZENV_ROOT}/lib/helpers.sh";
  if source "${KZENV_ROOT}/lib/helpers.sh"; then
    log 'debug' 'Helpers sourced successfully';
  else
    early_death "Failed to source helpers from ${KZENV_ROOT}/lib/helpers.sh";
  fi;
fi;

#####################
# Begin Script Body #
#####################

export PATH="${KZENV_ROOT}/bin:${PATH}";

errors=();
if [ "${#}" -ne 0 ]; then
  targets="${@}";
else
  targets="$(\ls "$(dirname "${0}")" | grep 'test_')";
fi;

for t in ${targets}; do
  bash "$(dirname "${0}")/${t}" \
    || errors+=( "${t}" );
done;

if [ "${#errors[@]}" -ne 0 ]; then
  log 'warn' '===== The following test suites failed =====';
  for error in "${errors[@]}"; do
    log 'warn' "\t${error}";
  done;
  log 'error' 'Test suite failure(s)';
else
  log 'info' 'All test suites passed.';
fi;

exit 0;
