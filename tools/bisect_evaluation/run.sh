#!/bin/bash

###
### NOTE: Syz-bisect is using sudo. Before running this script ensure "sudo" is not asking for
###       password. I.e. add "timestamp_timeout=-1" using "sudo visudo"
###

BASELINE_CONFIG=$PWD/barebones.config
REPRODUCER_CONFIG=$PWD/config
GO_VERSION=1.14.6
SYZKALLER_REPOSITORY=https://github.com/hogander-unikie/syzkaller
SYZKALLER_BRANCH=syzbot_baseline
SYZKALLER_REPROS_REPOSITORY=https://github.com/hogander-unikie/syzkaller-repros.git
SYZKALLER_REPROS_BRANCH=bisect_ccache
KERNEL_BRANCH=next-20200909
WITHOUT_CONFIG_BISECT_ONLY=false
WITH_CONFIG_BISECT_ONLY=false
WITH_CCACHE_ONLY=true
WITHOUT_CCACHE_ONLY=false
REPRODUCER_LIST="03ee30ae11dfd0ddd062af26566c34a8c853698d 04566a88dc3d58bba90b721bdc23255fca4738ea 04e95388a1b71c0e15b667b54b34ad3a60a9d933 0770dac266a734e3fda1520f6043777eda49452c 0881c535c265ca965edc49c0ac3d0a9850d26eb1 08e23caab6df4fcf8d6e276eeb4e76b2593478f4 0bc9e858900bb1cbbf0c45d8d7c3e8f82223d5d0 0c160f657ea1d4f0c929ad3a38bfb2015287c068 0c963236471bc9561fd3b38da03cd09482e90c72 0cce013ad4d05a277cf6b226fbec5670121cb0cc 0e82d2b61b41835147751850840d2f7ff8c10e23 0ecd52ecc7c81632f075709c2ba04477f4facf46 0ed735159b5caa20a0459a421b3668285313693e 0f2f82c0d4d0713abbe4da0cfd86c4f04bb80e1c 0f432ce7d3823ec269013f756ddf10f5423d8ba7 10a5b82e70465a6edacfdcdcef9a58c28819dc51 130cae4a4387fae6614fccf5eed180400ea30948 16d70bfe5eec749472fff1e66c78dacee7efa27c 18fd68c40a8208c2cd7060c19ca1180350db763b 1db8f1bd66c36cee9e3dae942beca3671ef5f424 232223b1e1dc405ba8ca60125d643ea8bbeb65ac 2820deb61d92a8d7ab17a56ced58e963e65d76d0 29de44bf206913f5aea3cf4dec938ee8e8d8d838 2c26acc6cb82fa28a2cacf8e07e693564022699a 2ccb2784ac25def3b08e246ef3a10e1b6e4eb3e3 2d6d1853e26eb3b70cd558298ebf0c98157fcccf 2f9df25e4d56c2dad0d84b7d7b1425c8ce5f609c 317ef02b0d5cbd19d445294fed91453c7f970fc3 3412d306afcb68c2a2fa64bd31e9d3a2cb002b18 3742e99590e09f89d6f92929fafc9cdad91139f4 39ea6caa479af471183997376dc7e90bc7d64a6a 3c51126024b6157a3f7ac2a11317f4a056d33f24 3d6afd8470840e9145db28cc425fea4238c34d14 3edda08c51e262e7751654c03af50b947c58fe40 416a58dce9f16ea8e68f9f58cb06bc0f4869ada8 41ef72eead121f7189d1cbd590622f386a40e2b3 4c9043f20d7397012c9bc1652ab381104a706004 4d7de0e6a195b6a5ffef01d2776e737a52c7de60 4dff835a61baa190ad74b2b2bc8ce96e35ff171e 4f66f3287ba3341410ff35b736339628173a5aaa 4f9d538745b5c309ed92a48a40bd62b3a80bfe31 50cb7f7656c6922b446bd3165b7a49e7aed235fb 52f970e1e55bb56098ab0ff6d574e2e967af9b09 53599a7fc4882bf655e43ac53edfe43e7740baab 53c79be6b6f985867ecf07544b1b962c401cdffe 53f3f4e8264a2986ccaf87f7ff145a425dead166 5880f0fd11dc5a2d9165121a85d8cf9f0fc19b81 5bf475dc85383fbbca8b288631d0393ab30dfdde 5e57e5f0dc65684681141a35c4f202efe41b2578 5ed56f4caf5b58ccf3c013d5798b2fb61b40eba8 6320028c28d699cfc0c5131ee86b23b07cee118e 671808ee0357bad4ecc810b476cb414d3ab001ac 679c09d7d8ae7850343c817c27bde5d9bd20d981 6a6553c3d34bb00172b5cbd32f4912151b6133dc"

sudo apt-get install golang-go
go get golang.org/dl/go1.14.6
~/go/bin/go$GO_VERSION download
export PATH=~/sdk/go$GO_VERSION/bin:$PATH
go get -u -d github.com/google/syzkaller/...

git -C ~/go/src/github.com/google/syzkaller remote add bisect-remote $SYZKALLER_REPOSITORY
git -C ~/go/src/github.com/google/syzkaller fetch bisect-remote
git -C ~/go/src/github.com/google/syzkaller checkout bisect-remote/$SYZKALLER_BRANCH

pushd ~/go/src/github.com/google/syzkaller
make
GOOS=linux GOARCH=amd64 go build "-ldflags=-s -w -X github.com/google/syzkaller/prog.GitRevision=`git -C ~/go/src/github.com/google/syzkaller rev-parse HEAD` -X 'github.com/google/syzkaller/prog.gitRevisionDate=`git -C ~/go/src/github.com/google/syzkaller log -n 1 --format="%ad"`'" -o ./bin/syz-bisect github.com/google/syzkaller/tools/syz-bisect
popd

export PATH=~/go/src/github.com/google/syzkaller/bin:$PATH

git clone $SYZKALLER_REPROS_REPOSITORY
pushd syzkaller-repros
git checkout $SYZKALLER_REPROS_BRANCH
popd
~/go/src/github.com/google/syzkaller/tools/create-image.sh
wget https://storage.googleapis.com/syzkaller/bisect_bin.tar.gz
tar -xvf bisect_bin.tar.gz

sudo apt-get install libmpfr6
sudo apt-get install grub-efi
sudo apt-get install ccache

ln -s /usr/lib/x86_64-linux-gnu/libmpfr.so.6 hogander@hogander-HP-ZBook-15-G5:/usr/lib$ ln -s /usr/lib/x86_64-linux-gnu/libmpfr.so.4

for reproducer in $REPRODUCER_LIST
do
    if [ $WITHOUT_CONFIG_BISECT_ONLY != "true" ]
    then
	if [ $WITHOUT_CCACHE_ONLY != "true" ]
	then
	    ./syzkaller-repros/bisect.py --reproducer ./syzkaller-repros/linux/$reproducer.c  --kernel_repository  git://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git --kernel_branch $KERNEL_BRANCH --chroot ./chroot  --baseline_config $BASELINE_CONFIG --reproducer_config $REPRODUCER_CONFIG --bisect_bin ./bisect_bin --ccache /usr/bin/ccache --syzkaller_repository $SYZKALLER_REPOSITORY --syzkaller_branch $SYZKALLER_BRANCH --output ./out_with_config_bisect_with_ccache ; mv ./out_with_config_bisect_with_ccache/syz-bisect.log ./out_with_config_bisect_with_ccache/$reproducer.log
	fi
	if [ $WITH_CCACHE_ONLY != "true" ]
	then
	    ./syzkaller-repros/bisect.py --reproducer ./syzkaller-repros/linux/$reproducer.c  --kernel_repository git://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git --kernel_branch $KERNEL_BRANCH --chroot ./chroot  --baseline_config $BASELINE_CONFIG --reproducer_config $REPRODUCER_CONFIG --bisect_bin ./bisect_bin --syzkaller_repository $SYZKALLER_REPOSITORY --syzkaller_branch $SYZKALLER_BRANCH --output ./out_with_config_bisect_without_ccache ; mv ./out_with_config_bisect_without_ccache/syz-bisect.log ./out_with_config_bisect__without_ccache/$reproducer.log
	fi
    fi
    if [ $WITH_CONFIG_BISECT_ONLY != true ]
    then
	if [ $WITHOUT_CCACHE_ONLY != "true" ]
	then
	    ./syzkaller-repros/bisect.py --reproducer ./syzkaller-repros/linux/$reproducer.c  --kernel_repository git://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git --kernel_branch $KERNEL_BRANCH --chroot ./chroot --reproducer_config $REPRODUCER_CONFIG --bisect_bin ./bisect_bin --ccache /usr/bin/ccache --syzkaller_repository  $SYZKALLER_REPOSITORY --syzkaller_branch $SYZKALLER_BRANCH --output ./out_without_config_bisect_with_ccache ; mv ./out_without_config_bisect_with_ccache/syz-bisect.log ./out_without_config_bisect_with_ccache/$reproducer.log
	fi
	if [ $WITH_CCACHE_ONLY != "true" ]
	then
	    ./syzkaller-repros/bisect.py --reproducer ./syzkaller-repros/linux/$reproducer.c  --kernel_repository git://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git --kernel_branch $KERNEL_BRANCH --chroot ./chroot --reproducer_config $REPRODUCER_CONFIG --bisect_bin ./bisect_bin --ccache /usr/bin/ccache --syzkaller_repository  $SYZKALLER_REPOSITORY --syzkaller_branch $SYZKALLER_BRANCH --output ./out_without_config_bisect_without_ccache ; mv ./out_without_config_bisect_without_ccache/syz-bisect.log ./out_without_config_bisect_without_ccache/$reproducer.log
	fi
    fi
done
