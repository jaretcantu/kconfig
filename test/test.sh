#!/bin/sh

WD=$(dirname `readlink -f $0`)
BUILDDIR=$WD/..

export KBUILD_KCONFIG=$WD/Kconfig

# Generate test configuration
$WD/gen_kconfig < $WD/testlist > $KBUILD_KCONFIG
make -C $BUILDDIR oldconfig || exit $?

$WD/check_kconfig < $BUILDDIR/.config
