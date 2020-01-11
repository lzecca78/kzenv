#!/usr/bin/env bash

set -uo pipefail;

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

if [ "${KZENV_DEBUG:-0}" -gt 0 ]; then
  [ "${DEBUG:-0}" -gt "${KZENV_DEBUG:-0}" ] || export DEBUG="${KZENV_DEBUG:-0}";
  if [[ "${KZENV_DEBUG}" -gt 2 ]]; then
    export PS4='+ [${BASH_SOURCE##*/}:${LINENO}] ';
    set -x;
  fi;
fi;

source "${KZENV_ROOT}/lib/bashlog.sh";

# Curl wrapper to switch TLS option for each OS
function curlw () {
  local TLS_OPT="--tlsv1.2";

  # Check if curl is 10.12.6 or above
  if [[ -n "$(command -v sw_vers 2>/dev/null)" && ("$(sw_vers)" =~ 10\.12\.([6-9]|[0-9]{2}) || "$(sw_vers)" =~ 10\.1[3-9]) ]]; then
    TLS_OPT="";
  fi;

  curl ${TLS_OPT} "$@";
}
export -f curlw;

check_version() {
  v="${1}";
  [ -n "$(${KZENV_ROOT}/bin/kustomize version kustomize version| grep -oE KustomizeVersion:${v} |cut -d':' -f2)" ];
}
export -f check_version;

cleanup() {
  log 'info' 'Performing cleanup';
  local pwd="$(pwd)";
  log 'debug' "Deleting ${pwd}/versions";
  rm -rf ./versions;
  log 'debug' "Deleting ${pwd}/.kustomize-version";
  rm -rf ./.kustomize-version;
  log 'debug' "Deleting ${pwd}/min_required.tf";
  rm -rf ./min_required.tf;
};
export -f cleanup;

function error_and_proceed() {
  errors+=("${1}");
  log 'warn' "Test Failed: ${1}";
};
export -f error_and_proceed;

export KZENV_HELPERS=1;
