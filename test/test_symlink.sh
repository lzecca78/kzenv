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

declare -a errors=();

log 'info' '### Testing symlink functionality';

KZENV_BIN_DIR='/tmp/tfenv-test';
log 'info' "## Creating/clearing ${KZENV_BIN_DIR}"
rm -rf "${KZENV_BIN_DIR}" && mkdir "${KZENV_BIN_DIR}";
log 'info' "## Symlinking ${PWD}/bin/* into ${KZENV_BIN_DIR}";
ln -s "${PWD}"/bin/* "${KZENV_BIN_DIR}";

cleanup || log 'error' 'Cleanup failed?!';

log 'info' '## Installing 1.0.11';
${KZENV_BIN_DIR}/tfenv install 1.0.11 || error_and_proceed 'Install failed';

log 'info' '## Using 1.0.11';
${KZENV_BIN_DIR}/tfenv use 0.8.2 || error_and_proceed 'Use failed';

log 'info' '## Check-Version for 1.0.10';
check_version 1.0.10 || error_and_proceed 'Version check failed';

if [ "${#errors[@]}" -gt 0 ]; then
  log 'warn' '===== The following symlink tests failed =====';
  for error in "${errors[@]}"; do
    log 'warn' "\t${error}";
  done;
  log 'error' 'Symlink test failure(s)';
  exit 1;
else
  log 'info' 'All symlink tests passed.';
fi;

exit 0;
