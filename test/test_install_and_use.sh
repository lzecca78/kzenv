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

test_install_and_use() {
  # Takes a static version and the optional keyword to install it with
  local k="${2-""}";
  local v="${1}";
  kzenv install "${k}" || return 1;
  check_version "${v}" || return 1;
  return 0;
};

declare -a errors=();

log 'info' '### Test Suite: Install and Use'

declare -A string_tests=();

string_tests['latest version']="$(kzenv list-remote | grep -e "^[0-9]\+\.[0-9]\+\.[0-9]\+$" | head -n 1),latest";
string_tests['latest possibly-unstable version']="$(kzenv list-remote | head -n 1),latest:";
string_tests['latest alpha']="$(kzenv list-remote | grep 'alpha' | head -n 1),latest:alpha";
string_tests['latest beta']="$(kzenv list-remote | grep 'beta' | head -n 1),latest:beta";
string_tests['latest rc']="$(kzenv list-remote | grep 'rc' | head -n 1),latest:rc";
string_tests['latest possibly-unstable version from 0.11']="$(kzenv list-remote | grep '^0\.11\.' | head -n 1),latest:^0.11.";
string_tests['0.11.15-oci']='0.11.15-oci,0.11.15-oci';
string_tests['latest version matching regex']='0.8.8,latest:^0.8';
string_tests['specific version']="0.7.13,0.7.13";

declare kv k v;
declare -i test_num=1;

for desc in "${!string_tests[@]}"; do
  cleanup || log 'error' 'Cleanup failed?!';
  kv="${string_tests[${desc}]}";
  v="${kv%,*}";
  k="${kv##*,}";
  log 'info' "## Param Test ${test_num}/${#string_tests[*]}: ${desc} ( ${k} / ${v} )";
  test_install_and_use "${v}" "${k}" \
    && log info "## Param Test ${test_num}/${#string_tests[*]}: ${desc} ( ${k} / ${v} ) succeeded" \
    || error_and_proceed "## Param Test ${test_num}/${#string_tests[*]}: ${desc} ( ${k} / ${v} ) failed";
  test_num+=1;
done;

test_num=1;
for desc in "${!string_tests[@]}"; do
  cleanup || log 'error' 'Cleanup failed?!';
  kv="${string_tests[${desc}]}";
  v="${kv%,*}";
  k="${kv##*,}";
  log 'info' "## ./.kustomize-version Test ${test_num}/${#string_tests[*]}: ${desc} ( ${k} / ${v} )";
  log 'info' "Writing ${k} to ./.kustomize-version";
  echo "${k}" > ./.kustomize-version;
  test_install_and_use "${v}" \
    && log info "## ./.kustomize-version Test ${test_num}/${#string_tests[*]}: ${desc} ( ${k} / ${v} ) succeeded" \
    || error_and_proceed "## ./.kustomize-version Test ${test_num}/${#string_tests[*]}: ${desc} ( ${k} / ${v} ) failed";
  test_num+=1;
done;

cleanup || log 'error' 'Cleanup failed?!';
log 'info' '## ${HOME}/.kustomize-version Test Preparation';
declare v1="$(kzenv list-remote | grep -e "^[0-9]\+\.[0-9]\+\.[0-9]\+$" | head -n 2 | tail -n 1)";
declare v2="$(kzenv list-remote | grep -e "^[0-9]\+\.[0-9]\+\.[0-9]\+$" | head -n 1)";
if [ -f "${HOME}/.kustomize-version" ]; then
  log 'info' "Backing up ${HOME}/.kustomize-version to ${HOME}/.kustomize-version.bup";
  mv "${HOME}/.kustomize-version" "${HOME}/.kustomize-version.bup";
fi;
log 'info' "Writing ${v1} to ${HOME}/.kustomize-version";
echo "${v1}" > "${HOME}/.kustomize-version";

log 'info' "## \${HOME}/.kustomize-version Test 1/3: Install and Use ( ${v1} )";
test_install_and_use "${v1}" \
  && log info "## \${HOME}/.kustomize-version Test 1/1: ( ${v1} ) succeeded" \
  || error_and_proceed "## \${HOME}/.kustomize-version Test 1/1: ( ${v1} ) failed";

log 'info' "## \${HOME}/.kustomize-version Test 2/3: Override Install with Parameter ( ${v2} )";
test_install_and_use "${v2}" "${v2}" \
  && log info "## \${HOME}/.kustomize-version Test 2/3: ( ${v2} ) succeeded" \
  || error_and_proceed "## \${HOME}/.kustomize-version Test 2/3: ( ${v2} ) failed";

log 'info' "## \${HOME}/.kustomize-version Test 3/3: Override Use with Parameter ( ${v2} )";
(
  kzenv use "${v2}" || exit 1;
  check_version "${v2}" || exit 1;
) && log info "## \${HOME}/.kustomize-version Test 3/3: ( ${v2} ) succeeded" \
  || error_and_proceed "## \${HOME}/.kustomize-version Test 3/3: ( ${v2} ) failed";

log 'info' '## \${HOME}/.kustomize-version Test Cleanup';
log 'info' "Deleting ${HOME}/.kustomize-version";
rm "${HOME}/.kustomize-version";
if [ -f "${HOME}/.kustomize-version.bup" ]; then
  log 'info' "Restoring backup from ${HOME}/.kustomize-version.bup to ${HOME}/.kustomize-version";
  mv "${HOME}/.kustomize-version.bup" "${HOME}/.kustomize-version";
fi;

log 'info' 'Install invalid specific version';
cleanup || log 'error' 'Cleanup failed?!';


declare -A neg_tests=();
neg_tests['specific version']="9.9.9";
neg_tests['latest:word']="latest:word";

test_num=1;

for desc in "${!neg_tests[@]}"; do
  cleanup || log 'error' 'Cleanup failed?!';
  k="${neg_tests[${desc}]}";
  expected_error_message="No versions matching '${k}' found in remote";
  log 'info' "##  Invalid Version Test ${test_num}/${#neg_tests[*]}: ${desc} ( ${k} )";
  [ -z "$(kzenv install "${k}" 2>&1 | grep "${expected_error_message}")" ] \
    && error_and_proceed "Installing invalid version ${k}";
  test_num+=1;
done;

if [ "${#errors[@]}" -gt 0 ]; then
  log 'warn' '===== The following install_and_use tests failed =====';
  for error in "${errors[@]}"; do
    log 'warn' "\t${error}";
  done
  log 'error' 'Test failure(s): install_and_use';
else
  log 'info' 'All install_and_use tests passed';
fi;

exit 0;
