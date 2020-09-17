#!/bin/bash

###
### NOTE: Syz-bisect is using sudo. Before running this script ensure "sudo" is not asking for
###       password. I.e. add "timestamp_timeout=-1" using "sudo visudo"
###

BASELINE_CONFIG="`realpath $PWD/baseline.config`"
REPRODUCER_CONFIG="`realpath $PWD/config`"
GO_VERSION=1.14.6
SYZKALLER_REPOSITORY=https://github.com/hogander-unikie/syzkaller
SYZKALLER_BRANCH=flaky_flag
SYZKALLER_REPROS_REPOSITORY=https://github.com/hogander-unikie/syzkaller-repros.git
SYZKALLER_REPROS_BRANCH=bisect
KERNEL_REPOSITORY=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
KERNEL_BRANCH=v4.19.59
WITHOUT_CONFIG_BISECT_ONLY=false
WITH_CONFIG_BISECT_ONLY=true
#REPRODUCER_LIST=76868b4c83962eefbf8015f01aeb9da4189fc25e 703f732a1f1f5e1d8314bb1a98eca20309420116 68fe3119847862315e52aa14961144b5a909bc23 9b519f4f0bcaeb000ba93389eda00310a6020abe be39d3abb5842e873d15d019b19f5ebef17c604a 55fc56e39caaf4f597fdbf388108892196d55f3f 68958b9d3651e09f0651b08f039f40c415fd02e6 ee7cf202a47281cda2e5a76bd1ba0683a10c2a65 4b61862ab93380cf84d66e09596ff3cbc3bc5341 ae0125a57674f57b675fad8f1440eb2be4790fba fb7ed6c3b2a69045e6b84a4ef30816f0f48791a9
REPRODUCER_LIST="68958b9d3651e09f0651b08f039f40c415fd02e6 703f732a1f1f5e1d8314bb1a98eca20309420116 ce692a3aa13e00e335e090be7846c6eb60ddff7a 61318630f216fec89e9be95e621470084000d7bc 9b519f4f0bcaeb000ba93389eda00310a6020abe be39d3abb5842e873d15d019b19f5ebef17c604a 76868b4c83962eefbf8015f01aeb9da4189fc25e 55fc56e39caaf4f597fdbf388108892196d55f3f ee7cf202a47281cda2e5a76bd1ba0683a10c2a65 4b61862ab93380cf84d66e09596ff3cbc3bc5341 fb7ed6c3b2a69045e6b84a4ef30816f0f48791a9"

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

ln -s /usr/lib/x86_64-linux-gnu/libmpfr.so.6 /usr/lib/x86_64-linux-gnu/libmpfr.so.4

for reproducer in $REPRODUCER_LIST
do
    if [ $WITHOUT_CONFIG_BISECT_ONLY != "true" ]
    then
	for baseline in $BASELINE_CONFIGS
	do
	    ./syzkaller-repros/bisect.py --reproducer ./syzkaller-repros/linux/$reproducer.c  --kernel_repository $KERNEL_REPOSITORY --kernel_branch $KERNEL_BRANCH --chroot ./chroot  --baseline_config $baseline --reproducer_config $REPRODUCER_CONFIG --bisect_bin ./bisect_bin --syzkaller_repository $SYZKALLER_REPOSITORY --syzkaller_branch $SYZKALLER_BRANCH --output ./out_with_config_bisect ; mv ./out_with_config_bisect/syz-bisect.log ./out_with_config_bisect/$reproducer.`basename $baseline`.log
	done
    fi
    if [ $WITH_CONFIG_BISECT_ONLY != true ]
    then
	./syzkaller-repros/bisect.py --reproducer ./syzkaller-repros/linux/$reproducer.c  --kernel_repository $KERNEL_REPOSITORY --kernel_branch $KERNEL_BRANCH --chroot ./chroot --reproducer_config $REPRODUCER_CONFIG --bisect_bin ./bisect_bin --syzkaller_repository  $SYZKALLER_REPOSITORY --syzkaller_branch $SYZKALLER_BRANCH --output ./out_without_config_bisect ; mv ./out_without_config_bisect/syz-bisect.log ./out_without_config_bisect/$reproducer.log
    fi
done
