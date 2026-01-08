#!/bin/false
# SPDX-License-Identifier: Apache-2.0 OR MIT
# shellcheck shell=bash # not executable
# shellcheck disable=SC2034

modes=(binutils objdump)

# https://ftp.gnu.org/gnu/binutils
binutils_version=2.45.1
# https://apt.llvm.org
llvm_version=21
version="binutils-${binutils_version}-llvm-${llvm_version}"
latest=binutils-2.45.1-llvm-21
