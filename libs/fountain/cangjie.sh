#!/bin/bash
# 并在home目录的.bashrc末尾添加source /path/of/cangjie.sh
# Please copy this file to the location you need,
# and add 'source /path/of/cangjie.sh' to the end of ~/.bashrc

export FOUNTAIN_HOME=$( cd -- "$( dirname -- "${BASH_SOURCE}" )" &> /dev/null && pwd -P )

cangjie_version(){
  echo '### 系统环境'
  echo '```bash'
  echo "$ lsb_release -a"
  lsb_release -a
  echo
  echo "$ uname -a"
  uname -a
  echo
  echo "$ cjc -v"
  cjc -v
  echo
  echo '$ echo $CANGJIE_STDX_DYNAMIC_PATH'
  echo $CANGJIE_STDX_DYNAMIC_PATH
  echo '```'
  STDX_VERSION=`echo $CANGJIE_STDX_DYNAMIC_PATH|awk -F'/' '{print $8}'`
  echo '
### 问题描述
```bash
git clone https://gitcode.com/Cangjie-SIG/fountain.git
cd fountain'
echo "git checkout -t origin/$1"
echo 'cd fboot'
echo "export CANGJIE_STDX_DYNAMIC_PATH=/path/of/stdx/$STDX_VERSION/linux_x86_64_llvm/dynamic/stdx"
echo '
cjpm install --root ../installed
cd ../installed
CJPM_INSTALL=`pwd`
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CJPM_INSTALL/libs/fboot
export PATH=$PATH:$CJPM_INSTALL/bin
cd ../fdemo
export POSTGRES=<URL_OF_POSTGRES>
./boot.sh build
```
'
#  echo '$ echo $CANGJIE_HOME'
#  echo $CANGJIE_HOME
#  echo
#  echo '$ echo $CANGJIE_STDX_DYNAMIC_PATH'
##  echo $CANGJIE_STDX_DYNAMIC_PATH
#  echo
#  echo '$ ls $CANGJIE_STDX_DYNAMIC_PATH'
#  ls $CANGJIE_STDX_DYNAMIC_PATH
#  echo '$ ls $CANGJIE_FOUNTAIN_LIBS'
#  ls $CANGJIE_FOUNTAIN_LIBS
  echo
}
cangjie_env(){
  export CJPM_CONFIG=/mnt/d/docs/work/cangjie/repository
  export CJPM_INSTALL=/mnt/d/docs/work/cangjie/installed
  export CANGJIE_STDX_PATH=/mnt/d/docs/work/cangjie/stdx/$2/linux_x86_64_llvm
  export CANGJIE_STDX_DYNAMIC_PATH=$CANGJIE_STDX_PATH/dynamic/stdx
  export CANGJIE_STDX_STATIC_PATH=$CANGJIE_STDX_PATH/static/stdx
  export CANGJIE_FOUNTAIN_LIBS=$CJPM_INSTALL/libs/fboot
  export CANGJIE_HOME=/mnt/d/docs/work/cangjie/cangjie-linux-bin/$1
  export LD_LIBRARY_PATH=/usr/local/openssl-3.3.2/lib:$CANGJIE_FOUNTAIN_LIBS:$LD_LIBRARY_PATH
  export PATH=$PATH:$CJPM_INSTALL/bin
  source $CANGJIE_HOME/envsetup.sh
}
cj(){
  echo "cj $1 $2 $3 $4 $5"
  case "$1" in
  env)
    cangjie_env $2 $3
    ;;
  version)
    cangjie_version $2
    ;;
  cleanUpdate)
    fboot cleanUpdate
    ;;
  install)
    fboot version $2 $3 $4 $5
    cd fboot
    cjpm install --root $CJPM_INSTALL
    echo -e "\a"
    cd ..
    ;;
  installed)
    cd $CJPM_INSTALL
    ;;
  study)
    cd /mnt/d/docs/work/cangjie/study
    ;;
  fountain)
    cd $FOUNTAIN_HOME
    if [[ "$2" == "install" ]]; then                                                                                 
        cj install
    elif [ -n "$2" ]; then                                                                                           
        echo 'only "install" can be followed command "cj fountain"'
    fi
    ;;
  fboot)
    cd $FOUNTAIN_HOME/fboot
    ;;
  fdemo)
    cd $FOUNTAIN_HOME/fdemo
    ;;
  '-c')
    f=$2
    cf=${f%.cj*}
    cjc $f -o $cf && ./$cf
    ;;
  esac
}

cj env 1.0.3 1.0.3.1
