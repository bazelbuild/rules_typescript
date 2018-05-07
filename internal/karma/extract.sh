#!/bin/bash
# Copyright 2018 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################
#

ARCHIVE=$1
OUT_DIR=$2
STRIP_PREFIX=$3

mkdir -p "${OUT_DIR}"

BASENAME=$(basename "${ARCHIVE}")

if [[ "${BASENAME}" == *.deb ]]; then
  dpkg -x "${ARCHIVE}" "${OUT_DIR}"
elif [[ "${BASENAME}" == *.tar ]]; then
  tar xf "${ARCHIVE}" -C "${OUT_DIR}"
elif [[ "${BASENAME}" == *.tar.bz2 || "${BASENAME}" == *.tbz2 ]]; then
  tar xjf "${ARCHIVE}" -C "${OUT_DIR}"
elif [[ "${BASENAME}" == *.tar.gz || "${BASENAME}" == *.tgz ]]; then
  tar xzf "${ARCHIVE}" -C "${OUT_DIR}"
elif [[ "${BASENAME}" == *.tar.Z ]]; then
  tar xZf "${ARCHIVE}" -C "${OUT_DIR}"
elif [[ "${BASENAME}" == *.zip ]]; then
  unzip "${ARCHIVE}" -d "${OUT_DIR}"
else
  exit -1
fi

if [[ ! -z "${STRIP_PREFIX}" ]]; then
  pushd "${OUT_DIR}"
  # Intentionally not quoted so that globbing in STRIP_PREFIX works.
  mv ${STRIP_PREFIX}/* .
  popd
fi
