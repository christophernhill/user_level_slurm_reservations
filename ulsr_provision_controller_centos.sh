#!/usr/bin/env bash
#
# ulsr_provision_controller_centos.sh - MOC HIL ULSR Slurm Controller Provisioning Script
#
# Run on the Slurm controller node
# Installs MOC HIL User Level Slurm Reservations code
#
# Notes
#   Assumes Slurm has been previously installed or is installed separately
#   Assumes CentOS
#   Run as root on controller node, NOT on server nodes
#   NFS kernel server must be provisioned on the controller
#      /shared the shared directory, exported via NFS

set -x

SLURM_USER=slurm
SLURM_USER_DIR=/home/$SLURM_USER

INSTALL_USER=centos
INSTALL_USER_DIR=/home/$INSTALL_USER

SLURM_CONF_FILE_PATH=/etc/slurm
SLURM_CONF_FILE_NAME=slurm.conf
SLURM_CONF_FILE=$SLURM_CONF_FILE_PATH/$SLURM_CONF_FILE_NAME

PYTHON_VER=python2.7

DATE_TIME=`date +%Y%m%d_%H%M%S`

# Select proper release or Git repo

USE_ULSR_RELEASE=0

if [ $USE_ULSR_RELEASE = 1 ]; then
    ULSR_RELEASE_VERSION=0.0.3
    ULSR_RELEASE_GZIP_FILE=v$ULSR_RELEASE_VERSION.tar.gz
    ULSR_RELEASE_PATH=https://github.com/mghpcc-projects/user_level_slurm_reservations/archive
    ULSR_RELEASE=$ULSR_RELEASE_PATH/$ULSR_RELEASE_GZIP_FILE
else
    ULSR_REPO_NAME=user_level_slurm_reservations
    ULSR_REPO_URL=https://github.com/mghpcc-projects/$ULSR_REPO_NAME.git
    ULSR_BRANCH=development
fi

NFS_SHARED_DIR=/shared
HIL_SHARED_DIR=$NFS_SHARED_DIR/hil

LOCAL_BIN=/usr/local/bin

yum makecache -y fast
yum install -y emacs
yum install -y nfs-utils
yum install -y virtualenv

echo "export SYSTEMD_EDITOR=emacs" >> ~/.bashrc

cd $INSTALL_USER_DIR

if [ $USE_ULSR_RELEASE = 1 ]; then
    ULSR_DIR=$INSTALL_USER_DIR/ulsr-$ULSR_RELEASE_VERSION
    if [ -d $ULSR_DIR ]; then
	mv $ULSR_DIR $ULSR_DIR.$DATE_TIME
    fi
    wget $ULSR_RELEASE
    tar xvf $ULSR_RELEASE_GZIP_FILE
    mv user_level_slurm_reservations-$ULSR_RELEASE_VERSION ulsr-$ULSR_RELEASE_VERSION
else
    ULSR_DIR=$INSTALL_USER_DIR/ulsr-$ULSR_BRANCH
    if [ -d $ULSR_DIR ]; then
	mv $ULSR_DIR $ULSR_DIR.$DATE_TIME
    fi
    git clone --branch $ULSR_BRANCH $ULSR_REPO_URL $ULSR_DIR
fi

# Create log file directory

LOGFILE_DIR=/var/log/moc_hil_ulsr
mkdir -p $LOGFILE_DIR
chmod 775 $LOGFILE_DIR
chown $SLURM_USER:$SLURM_USER $LOGFILE_DIR

# Set up Python virtual environment, install Python hostlist

virtualenv -p $PYTHON_VER $SLURM_USER_DIR/scripts/ve
source $SLURM_USER_DIR/scripts/ve/bin/activate
pip install python-hostlist
pip install requests
deactivate

PYTHON_LIB_DIR=$SLURM_USER_DIR/scripts/ve/lib/python2.7/site-packages

# Set up NFS server and shared FS, export to compute nodes

mkdir -p $NFS_SHARED_DIR
chmod 777 $NFS_SHARED_DIR
chown nobody:nobody $NFS_SHARED_DIR
sudo chkconfig nfs on
sudo service rpcbind start
sudo service nfs start

cat >> /etc/exports <<EOF
$NFS_SHARED_DIR *(rw,sync,no_root_squash)
EOF

exportfs -a

mkdir -p $HIL_SHARED_DIR/bin
chmod -R 700 $HIL_SHARED_DIR/bin
chown -R $INSTALL_USER:$INSTALL_USER $HIL_SHARED_DIR/bin

# Create Slurm user script directory

mkdir -p $SLURM_USER_DIR/scripts
chown -R $SLURM_USER:$SLURM_USER $SLURM_USER_DIR/scripts

# Copy files to final resting places
#
# Install HIL user-level commands and HIL periodic wrappers

HIL_COMMAND_FILES="hil_reserve \
                   hil_release \
                   hil_slurm_monitor.sh"

for file in $HIL_COMMAND_FILES; do
    cp $ULSR_DIR/commands/$file $HIL_SHARED_DIR/bin
    cp $ULSR_DIR/commands/$file $LOCAL_BIN
    chmod 755 $LOCAL_BIN/$file
done

# Install ULSR periodic monitor files

HIL_MONITOR_FILES="hil_slurm_monitor.py"

for file in $HIL_MONITOR_FILES; do
    cp $ULSR_DIR/commands/$file $SLURM_USER_DIR/scripts/
    chown $SLURM_USER:$SLURM_USER $SLURM_USER_DIR/scripts/$file
    echo ""
done

chmod 755 $LOCAL_BIN/hil_*.sh

# Install ULSR common files

ULSR_COMMON_FILES="hil_slurm_client.py \
                   hil_slurm_constants.py \
                   hil_slurm_helpers.py \
                   hil_slurm_logging.py
                   hil_slurm_settings.py"

for file in $HIL_COMMON_FILES; do
    cp $ULSR_DIR/common/$file $PYTHON_LIB_DIR/$file
    chown $SLURM_USER:$SLURM_USER $PYTHON_LIB_DIR/$file
done

# Install HIL client package files

HIL_PKG_FILES="__init__.py"

HIL_CLIENT_FILES="__init__.py \
                  base.py \
                  client.py \
                  extensions.py \
                  network.py \
                  node.py \
                  project.py \
                  switch.py \
                  user.py"

mkdir -p $PYTHON_LIB_DIR/hil/client

for file in $HIL_PKG_FILES; do
    cp $ULSR_DIR/hil/$file $PYTHON_LIB_DIR/hil/$file
done
chown -R $SLURM_USER:$SLURM_USER $PYTHON_LIB_DIR/hil/client

for file in $HIL_CLIENT_FILES; do
    cp $ULSR_DIR/hil/client/$file $PYTHON_LIB_DIR/hil/client/$file
done

chown -R $SLURM_USER:$SLURM_USER $PYTHON_LIB_DIR/hil/


# Install ULSR Prolog and Epilog files

ULSR_PROLOG_FILES="hil_slurmctld_epilog.sh \
                   hil_slurmctld_prolog.py \
                   hil_slurmctld_prolog.sh"

for file in $HIL_PROLOG_FILES; do
    cp $ULSR_DIR/prolog/$file $SLURM_USER_DIR/scripts/
    chown $SLURM_USER:$SLURM_USER $SLURM_USER_DIR/scripts/$file
    echo ""
done


chmod 755 $SLURM_USER_DIR/scripts/hil_*.sh

# Install HIL Network Audit files

HIL_NETAUDIT_FILES=""

for file in $HIL_NETAUDIT_FILES; do
    echo ""
done

# Update the Slurm config file 
#
# Write prolog & epilog locations to slurm.conf

cat >> $SLURM_CONF_FILE <<EOF
#
# Slurmctld Prolog and Epilog
PrologSlurmctld=$SLURM_USER_DIR/scripts/hil_slurmctld_prolog.sh
EpilogSlurmctld=$SLURM_USER_DIR/scripts/hil_slurmctld_epilog.sh
EOF

chown $SLURM_USER:$SLURM_USER $SLURM_CONF_FILE
cp -p $SLURM_CONF_FILE $HIL_SHARED_DIR

echo 'Provision compute nodes, then restart Slurm control daemon.'
set +x
