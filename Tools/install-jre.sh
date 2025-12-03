#!/bin/sh

amroot=`id | grep root`
if [ "$amroot" = "" ];then
   echo "Must be root to install JRE. Exit."
   exit 1
fi

wget https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.deb

dpkg -i jdk-17_linux-x64_bin.deb

echo $JAVA_HOME

java -version
