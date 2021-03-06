# MOC HIL User Level Slurm Reservations (ULSR)

V0.5  15-Aug-2017

# Introduction

ULSR software allows a non-privileged Slurm user to reserve Slurm
compute nodes for HIL operations.  The nodes may be later released and
returned to the pool of Slurm compute nodes for use by others.

At present, two commands, run in the Slurm partition environment, are
used to manage Slurm HIL reservations:

  * ```hil_reserve```
  * ```hil_release```

These commands are executed as Slurm jobs via ```srun(1)``` and ```sbatch(1).```

Other software components perform HIL node and network management
operations on nodes reserved and freed using the above commands.  A
program goal is to have these components execute automatically without
user or administrator intervention.

## Usage

To reserve a HIL node, specify the ```hil_reserve``` command as a job
to the Slurm ```srun(1)``` or ```sbatch(1)``` command:

```
$ srun hil_reserve
```

To verify the reservation was created, run the ```scontrol show
reservation``` command:

``` 
$ scontrol show reservation
```
If successful, two reservations similiar to the following should appear:

```
ReservationName=flexalloc_MOC_reserve_centos_1000_2017-06-26T17:20:32
StartTime=2017-06-26T17:20:32 EndTime=2017-06-26T21:25:32
Duration=04:05:00 Nodes=server1 NodeCnt=1 CoreCnt=1 Features=(null)
PartitionName=(null) Flags=MAINT,IGNORE_JOBS,S PEC_NODES,ALL_NODES
TRES=cpu=1 Users=centos Accounts=(null) Licenses=(null) State=ACTIVE
BurstBuffer=(null) Watts=n/a 
```

```
ReservationName=flexalloc_MOC_release_centos_1000_2017-06-26T17:20:32
StartTime=2017-06-26T17:20:32 EndTime=2017-06-26T21:25:32
Duration=04:05:00 Nodes=server1 NodeCnt=1 CoreCnt=1 Features=(null)
PartitionName=(null) Flags=MAINT,IGNORE_JOBS,S PEC_NODES,ALL_NODES
TRES=cpu=1 Users=centos Accounts=(null) Licenses=(null) State=ACTIVE
BurstBuffer=(null) Watts=n/a 
```

Note that Slurm allows these reservations to temporally overlap due to
the use of the ```MAINT``` flag during reservation creation.

When finished, to release a HIL node, specify the ```hil_release```
command to ```srun(1)``` or ```sbatch(1)```, additionally specifying
**the HIL reserve reservation name** as the reservation in which to
run the job:

```
$ srun --reservation=flexalloc_MOC_reserve_centos_1000_2017-06-26T17:20:32 hil_release
```
This will ultimately cause removal of both the reserve and release
reservations.  

## Resource Sharing

Nodes placed in a Slurm HIL reservation are marked as exclusive and
may not be shared among users.

## Restrictions on User Names and UIDs

Reservations are named after the user who invoked the ```srun
hil_reserve``` command.  The user's name and UID are passed to the
Slurmctld prolog and epilog through the ```SLURM_JOB_USER``` and
```SLURM_JOB_UID``` environment variables.

Priviliged users may specify the user ID with which to create Slurm
reservations by specifying the ```--uid=<name>``` argument.  It is
recommended that the ```srun``` and ```sbatch``` commands **not** be
specified with the ```--uid``` argument, however, as processing Slurm
HIL reservations with alternate or additional user names has not been
tested.

At present, only the user named in the reservation may release the
reservation via ```hil_release```.  Of course, a privileged user may
update or delete reservations using ```scontrol```, but the system
state after such an opertion will be **undefined**.

## Reservation Naming

HIL reservations created using ```hil_reserve``` are named as follows:
```
flexalloc_MOC_reserve_<username>_<uid>_<start_time>
```
and
```
flexalloc_MOC_release_<username>_<uid>_<start_time>
```

An example:
```
flexalloc_MOC_reserve_centos_1000_2017-06-26T17:20:32
```

## Reservation Start and End Times

The reserve and release reservation start times may differ from the
time at which the ```hil_reserve``` command is run.  Reservations are
created by the ```slurmctld``` prolog and epilog only when the
requested resources become available and the job is scheduled for
execution.  Thus the reservation start times may be substantially
different from the time-of-day at which the ```srun``` command is
invoked.


## Two-Screen Management Model

All HIL nodes are known, by common names, to the Slurm management
functions and to the HIL management functions.  The nodes exist in
both the Slurm partition and the HIL partition simultaneously, in
advance of any reservation and release operations.

In the Slurm partition, nodes marked with the HIL property and perhaps
otherwise designated by system administration may be thought of as
available for loan to a HIL instance, or on loan to a HIL instance.

  * Nodes which have been placed in a Slurm HIL reservation may be
    considered as on loan to a HIL instance.  They may exist in the
    HIL free pool or be allocated to a HIL project and a HIL end user.

  * Nodes which are not in a Slurm HIL reservation, but which are
    marked with the ```HIL``` property, may be considered as available
    for loan to a HIL instance. They do not reside in the HIL free
    pool nor are they part of a HIL project.

Once a Slurm server node has been placed in a Slurm HIL reservation
with ```hil_reserve```, it may be necessary for the HIL end user to
run HIL management commands to cause the server node to fully
participate in a HIL user project.  This requirement may be
interpreted as consistent with a 'two-screen' management model.


# Assumptions, Restrictions, Notes

Beyond any requirements imposed by the HIL software and Slurm, the
following apply to the user level Slurm reservation software.

  1. All nodes in the HIL reservation pool are configured in a single
  Slurm partition.  

  2. The Slurm controller node in the partition is not available for
  HIL operations and is **not** marked with the ```HIL``` feature.

  3. Slurm compute nodes must be marked with the ```HIL``` feature in
  order to be placed in a HIL reservation.  Features are defined in
  the ```slurm.conf``` file or may be added to a node by a privileged
  user via the ```scontrol update``` command.  Refer to the Slurm
  documenation for a description of how to do this.

  4. HIL nodes may be released from a HIL reservation through
  ```hil_release```, even though they are not up and running Linux.
  Some error messages may appear in the Slurmctld log file.  Note that
  detailed system behavior has not been fully evaluated and is likely
  to evolve over time.

  5. Python v2.7 must be installed on the Slurm controller node.

  6. The ```hil_reserve``` and ```hil_release``` commands must be
  available on both the Slurm controller node and on the compute nodes
  which form the target of the HIL bare node operations.  This is
  accomplished during the ULSR software installation process.


# Logging

Slurm and the HIL reservation system maintain several log files which
may be reviewed as necessary to gain insight into system behavior.

  * The Slurm control daemon (```slurmctld```) running on the Slurm
  controller node writes to a log file, the location of which is
  defined by the ```SlurmctldLogFile``` parameter in the
  ```slurm.conf``` file.

  * HIL reservation operations performed by the Slurmctld prolog and
    epilog are logged to a file on the Slurm controller node.  The
    location of this file is configured in the
    ```hil_slurm_settings.py``` file.  By default, the location is
    ```/var/log/slurm-llnl/hil_prolog.log```.

  * HIL reservation operations performed by the HIL periodic monitor
  are also logged to a file on the Slurm controller node.  The
  location of this file is configured in the
  ```hil_slurm_settings.py``` file.  By default, the location is
  ```/var/log/slurm-llnl/hil_monitor.log```. 


# Implementation Details

## Software Components and Structure

The ULSR software running in the context of the Slurm partition
consists of the following:

  1. The ```hil_reserve``` and ```hil_release``` user commands
  described above.

  2. A dedicated Slurm control daemon prolog function, which runs in
  the context of the Slurm control daemon on the Slurm controller
  node.

  3. One or more periodic processors, scheduled by ```cron(8)```,
  which monitor the set of Slurm reservations and invoke HIL control
  operations to move nodes between HIL projects and the HIL free pool.

  4. A MOC HIL client interface, used by the ULSR code to remotely
  execute HIL commands on the nodes placed into and freed from HIL
  reservations, and on the switches terminating the physical network
  links which interconnect the nodes.

  5. A Slurm partition instance.

  6. A MOC HIL cluster instance.


## HIL Reservation Management Commands

The ```hil_reserve``` and ```hil_release``` commands are implemented
as bash(1) shell scripts, which do little more than cause the
```slurmctld`` prolog and epilog to run and recognize that the user
wishes to reserve or release HIL nodes.  

These names are reserved in that they are recognized by the Slurm
control daemon prolog and epilog as triggers for specific user level
HIL reservation operations.

## Slurm Control Daemon Prolog and Epilog

The ```slurmctld``` prolog does the work required to place nodes in a
HIL reservation.  The prolog consists of a ```bash``` script which
invokes a common Python program used for both the prolog and the
epilog.  Prolog function is selected via an argument to the Python
script.  The epilog is implemented in an identical manner.

The work required to release nodes from a HIL reservation is performed
by the ```slurmctld``` epilog and by the Slurm HIL periodic monitor.
As the reservation to be released is in use at the time the prolog
runs (it is used to run the ```hil_release``` job), it is not possible
to delete the reservation in the prolog itself.

### Communication between Slurm Components

The ```slurmctld``` prolog and epilog execution environment provides
very limited support for communication between the user, the user's
job, and the prolog and epilog, apart from Linux file system I/O.  For
example, it is not possible for the prolog or epilog to write status
information to the user's TTY, nor is is possible for the user's job
to pass arguments to the prolog or epilog.  Note: It may be possible
to output information to the user through a SPANK plugin, but that
possibility is not considered further here.

The name of the job submitted via ```srun``` or ```sbatch``` is
available to the prolog and epilog through a very limited set of
environment variables.  Also available in the environment are the user
name, user ID, and job node list.  Other information regarding the
Slurm execution environment is available through subprocess execution
of various ```scontrol show``` commands, for example, ```scontrol show job```.


## Periodic Reservation Monitor

The HIL reservation monitor runs periodically on the Slurm controller
node and looks for changes in Slurm HIL reservations.  More
specifically, the reservation monitor looks for Slurm HIL release
reservations which do not have corresponding reserve reservations.

For each singleton release reservation found, the HIL reservation
monitor:

  1. Invokes the HIL client API to remove the nodes in the reservation
  from the HIL user project or HIL free pool.

  2. Deletes the Slurm HIL release reservation.

If the HIL client operations fail, the Slurm HIL release reservation
is left in place, so that the periodic reservation monitor can retry
the operation.


## HIL Client Interface

To be supplied.

# Software Installation

## HIL Software Installation

TEMPORARY

(The following assumes Slurm-LLNL version 15 or greater is installed
and running.  The installation is targeted on the Slurm controller node)

On the Slurm controller node, create a virtual environment:
```
$ mkdir <HIL_INSTALL_DIR>
$ cd <HIL_INSTALL_DIR>
$ virtualenv ve
$ source ve/bin/activate
```
Fetch the software from GitHub:
``` 
$ git clone git@github.com:mghpcc-projects/user_level_slurm_reservations.git
$ cd user_level_slurm_reservations
```

_CAVEAT_: This must be repeated on all nodes in the Slurm partition, or
filesystem sharing must be used/


## Support Libraries

### python-hostlist

Install the ```python-hostlist``` package on the Slurm controller node:
```
$ cd /usr/local/lib/python2.7/site-packages
$ wget https://www.nsc.liu.se/~kent/python-hostlist/python-hostlist-1.17.tar.gz
$ tar xvf python-hostlist-1.17.tar.gz
$ cd python-hostlist-1.17
$ python setup.py build
$ python setup.py install
```


# Slurm Software Configuration

Slurm software configuration is performed via the ```slurm.conf```
file.  Once changes to this file have been made, copies must be pushed
to all nodes in the Slurm cluster.  In order for changes to take
effect, the ```slurmctld``` must be restarted on the controller, and
the ```slurmd``` must be restarted on the compute nodes.

By default, the ```slurm.conf``` file resides in ```/etc/slurm-llnl/slurm.conf.```

## SlurmCtld Prolog and Epilog Installation

[NEEDS UPDATE to reflect coexistence with other Slurm prolog / epilog modules]

The SlurmCtld prolog and epilog must be specified:

```
PrologSlurmctld=/<install_dir>/prolog/hil_slurmctld_prolog.sh
EpilogSlurmctld=/<install_dir>/prolog/hil_slurmctld_epilog.sh
```

## Compute Nodes Marked with HIL Feature

Slurm compute nodes which are intended to be placed in a HIL
reservation must be marked in the Slurm cluster configuration as
having the Slurm feature 'HIL'.

## Partition MaxTime and DefaultTime

The partition MaxTime and DefaultTime must be set so that to values
other than 'INFINITE' or 'UNLIMITED'.  Otherwise, the
```hil_reserve``` and ```hil_release``` commands may be queued and
blocked when other reservations, starting at future times, exist in
the partition and include the Slurm compute nodes intended for use by
HIL.

In the following example, the illustrated times are arbitrary.

```
PartitionName=debug Nodes=server[1] Default=YES DefaultTime=00:05:00 MaxTime=06:00:00 State=UP Shared=No
```

## Default Nodes

Might not want a HIL node to be among the partition default nodes.

## Node Sharing and Oversubscription

Must be disabled.

<EOF>


