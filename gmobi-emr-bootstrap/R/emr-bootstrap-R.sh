#/bin/bash

# AWS EMR bootstrap script
# for installing open-source R (www.r-project.org) with sparkR and RStudio on AWS EMR
#
# Original work Copyright (c) 2014 schmidbe@amazon.de
# Modified work Copyright (c) 2016 Gmobi Inc.
##############################

# Usage:
# --rstudio - installs rstudio-server default false
# --updateR - installs latest R version, default false
# --user - sets user for rstudio, default "rstudio"
# --user-pw - sets user-pw for user USER, default "rstudio"
# --rstudio-port - sets rstudio port, default 80

# error message
error_msg ()
{
	echo 1>&2 "Error: $1"
}

# get input parameters
RSTUDIO=true
USER="rstudio"
USERPW="rstudio"
UPDATER=false
RSTUDIOPORT=8787
while [ $# -gt 0 ]; do
	case "$1" in
		--rstudio)
			RSTUDIO=true
			;;
		--rexamples)
			REXAMPLES=true
			;;
		--plyrmr)
			PLYRMR=true
			;;
		--rhdfs)
			RHDFS=true
			;;
		--updateR)
			UPDATER=true
			;;
        --rstudio-port)
            shift
            RSTUDIOPORT=$1
            ;;
		--user)
		   shift
		   USER=$1
		   ;;
   		--user-pw)
   		   shift
   		   USERPW=$1
   		   ;;
		-*)
			# do not exit out, just note failure
			error_msg "unrecognized option: $1"
			;;
		*)
			break;
			;;
	esac
	shift
done

# install latest R version from AWS Repo
sudo yum update R-base -y

# create rstudio user on all machines
# we need a unix user with home directory and password and hadoop permission
sudo adduser $USER
sudo sh -c "echo '$USERPW' | passwd $USER --stdin"


# install rstudio
# only run if master node
if [ "$RSTUDIO" = true ]; then
  # install Rstudio server
  # please check and update for latest RStudio version
  sudo yum install --nogpgcheck -y /home/hadoop/R/rstudio-server-rhel-0.99.893-x86_64.rpm

  # change port - 8787 will not work for many companies
  sudo sh -c "echo 'www-port=$RSTUDIOPORT' >> /etc/rstudio/rserver.conf"
  sudo rstudio-server restart
fi

# update to latest R version
if [ "$UPDATER" = true ]; then
	mkdir R-latest
	cd R-latest
	wget http://mirror.bjtu.edu.cn/cran/src/base/R-latest.tar.gz
	tar -xzf R-latest.tar.gz
	sudo yum install -y gcc
	sudo yum install -y gcc-c++
	sudo yum install -y gcc-gfortran
	sudo yum install -y readline-devel
	cd R-3*
	./configure --with-x=no --with-readline=no --enable-R-profiling=no --enable-memory-profiling=no
	make
	sudo make install
    sudo su << EOF1
echo '
export PATH=$PATH:~/R-latest/bin/
' >> /etc/profile
EOF1
fi


# set unix environment variables
sudo su << EOF1
echo '
export HADOOP_HOME=/usr/lib/hadoop
export SPARK_HOME=/usr/lib/spark
' >> /etc/profile
EOF1

# set R environment variables
sudo su << EOF1
echo '
HADOOP_HOME=/usr/lib/hadoop
SPARK_HOME=/usr/lib/spark
HADOOP_USER_NAME=hadoop
' >> /usr/lib64/R/etc/Renviron
EOF1

sudo sh -c "source /etc/profile"

# RCurl package needs curl-config unix package
sudo yum install -y curl-devel

# install required packages
sudo R --no-save << EOF
install.packages(c('RJSONIO', 'itertools', 'digest', 'Rcpp', 'functional', 'httr', 'plyr', 'stringr', 'reshape2', 'caTools', 'rJava'),
repos="http://mirror.bjtu.edu.cn/cran", INSTALL_opts=c('--byte-compile') )
# here you can add your required packages which should be installed on ALL nodes
# install.packages(c(''), repos="http://mirror.bjtu.edu.cn/cran", INSTALL_opts=c('--byte-compile') )
EOF

# put sparkR into .libPaths
sudo su << EOF1
echo '
.libPaths(new = c(file.path(Sys.getenv("SPARK_HOME"), "R", "lib"), .libPaths()))
' >> /usr/lib64/R/etc/Rprofile.site
EOF1
