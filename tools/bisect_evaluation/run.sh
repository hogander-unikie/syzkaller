#!/bin/bash
# Copyright 2020 syzkaller project authors. All rights reserved.
# Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.
#
# NOTE: Syz-bisect is using sudo. Before running this script ensure "sudo" is not asking for
# password. I.e. add "timestamp_timeout=-1" using "sudo visudo"
#

BASELINE_CONFIGS="`realpath ~/go/src/github.com/google/syzkaller/dashboard/config/upstream-kasan.config.baseline`"
REPRODUCER_CONFIG="`realpath ~/go/src/github.com/google/syzkaller/dashboard/config/upstream-kasan.config`"
GO_VERSION=1.14.6
SYZKALLER_REPOSITORY=https://github.com/hogander-unikie/syzkaller
SYZKALLER_BRANCH=reuse_testresults_evaluation
SYZKALLER_REPROS_REPOSITORY=https://github.com/hogander-unikie/syzkaller-repros.git
SYZKALLER_REPROS_BRANCH=bisect
KERNEL_REPOSITORY=git://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
KERNEL_BRANCH=next-20200909
KERNEL_SRC=$PWD/linux
WITHOUT_CONFIG_BISECT_ONLY=false
WITH_CONFIG_BISECT_ONLY=true
WITH_CCACHE_ONLY=true
WITHOUT_CCACHE_ONLY=false
REPRODUCER_LIST="53c79be6b6f985867ecf07544b1b962c401cdffe 679c09d7d8ae7850343c817c27bde5d9bd20d981 1db8f1bd66c36cee9e3dae942beca3671ef5f424 2820deb61d92a8d7ab17a56ced58e963e65d76d0 04566a88dc3d58bba90b721bdc23255fca4738ea 53599a7fc4882bf655e43ac53edfe43e7740baab 671808ee0357bad4ecc810b476cb414d3ab001ac 6320028c28d699cfc0c5131ee86b23b07cee118e 16d70bfe5eec749472fff1e66c78dacee7efa27c 29de44bf206913f5aea3cf4dec938ee8e8d8d838 2c26acc6cb82fa28a2cacf8e07e693564022699a 03ee30ae11dfd0ddd062af26566c34a8c853698d 04e95388a1b71c0e15b667b54b34ad3a60a9d933 0881c535c265ca965edc49c0ac3d0a9850d26eb1 4f66f3287ba3341410ff35b736339628173a5aaa 4f9d538745b5c309ed92a48a40bd62b3a80bfe31 50cb7f7656c6922b446bd3165b7a49e7aed235fb 53f3f4e8264a2986ccaf87f7ff145a425dead166 232223b1e1dc405ba8ca60125d643ea8bbeb65ac"

sudo apt-get install golang-go
go get golang.org/dl/go$GO_VERSION
~/go/bin/go$GO_VERSION download
export PATH=~/sdk/go$GO_VERSION/bin:$PATH
go get -u -d github.com/google/syzkaller/...

git -C ~/go/src/github.com/google/syzkaller remote add bisect-remote $SYZKALLER_REPOSITORY
git -C ~/go/src/github.com/google/syzkaller fetch bisect-remote
git -C ~/go/src/github.com/google/syzkaller checkout bisect-remote/$SYZKALLER_BRANCH

pushd ~/go/src/github.com/google/syzkaller
make clean
make
GOOS=linux GOARCH=amd64 go build "-ldflags=-s -w -X github.com/google/syzkaller/prog.GitRevision=`git -C ~/go/src/github.com/google/syzkaller rev-parse HEAD` -X 'github.com/google/syzkaller/prog.gitRevisionDate=`git -C ~/go/src/github.com/google/syzkaller log -n 1 --format="%ad"`'" -o ./bin/syz-bisect github.com/google/syzkaller/tools/syz-bisect
popd

export PATH=~/go/src/github.com/google/syzkaller/bin:$PATH

git clone $SYZKALLER_REPROS_REPOSITORY
git -C syzkaller-repros fetch origin
git -C syzkaller-repros checkout origin/$SYZKALLER_REPROS_BRANCH

if [ ! -d chroot ]
then
    ~/go/src/github.com/google/syzkaller/tools/create-image.sh
fi

if [ ! -d bisect_bin ]
then
    wget https://storage.googleapis.com/syzkaller/bisect_bin.tar.gz
    tar -xvf bisect_bin.tar.gz
fi

sudo apt-get install libmpfr6
sudo apt-get install grub-efi
sudo apt-get install ccache

if [ ! -f /usr/lib/x86_64-linux-gnu/libmpfr.so.4 ]
then
    ln -s /usr/lib/x86_64-linux-gnu/libmpfr.so.6 /usr/lib/x86_64-linux-gnu/libmpfr.so.4
fi

for reproducer in $REPRODUCER_LIST
do
    BISECT_COMMON="./syzkaller-repros/bisect.py --reproducer ./syzkaller-repros/linux/$reproducer.c  --kernel_repository $KERNEL_REPOSITORY --kernel_branch $KERNEL_BRANCH --chroot ./chroot --reproducer_config $REPRODUCER_CONFIG --bisect_bin ./bisect_bin --syzkaller_repository $SYZKALLER_REPOSITORY --syzkaller_branch $SYZKALLER_BRANCH --kernel_src $KERNEL_SRC"
    if [ $WITHOUT_CONFIG_BISECT_ONLY != "true" ]
    then
	for baseline in $BASELINE_CONFIGS
	do
	    if [ $WITHOUT_CCACHE_ONLY != "true" ]
	    then
		$BISECT_COMMON --baseline_config $baseline --ccache /usr/bin/ccache --output ./out_with_config_bisect_with_ccache/`basename $baseline`
	    fi
	    if [ $WITH_CCACHE_ONLY != "true" ]
	    then
		$BISECT_COMMON --baseline_config $baseline --output ./out_with_config_bisect_without_ccache/`basename $baseline`
	    fi
	done
    fi
    if [ $WITH_CONFIG_BISECT_ONLY != true ]
    then
	if [ $WITHOUT_CCACHE_ONLY != "true" ]
	then
	    $BISECT_COMMON --ccache /usr/bin/ccache --output ./out_without_config_bisect_with_ccache
	fi
	if [ $WITH_CCACHE_ONLY != "true" ]
	then
	    $BISECT_COMMON --output ./out_without_config_bisect_without_ccache
	fi
    fi
done
