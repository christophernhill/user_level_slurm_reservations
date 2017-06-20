#!/bin/bash
#
# HIL Slurmctrld Prolog shell script
#
# Runs hil_slurmctld_prolog.py with --hil_prolog, e.g. as the prolog
#
PATH=/bin:/usr/bin
LOGFILE=/var/log/slurm-llnl/hil_prolog.log
HOME=/vagrant/user_level_slurm_reservations

source ${HOME}/../ve/bin/activate
python $HOME/prolog/hil_slurmctld_prolog.py --hil_prolog >> $LOGFILE 2>&1
deactivate

exit 0

