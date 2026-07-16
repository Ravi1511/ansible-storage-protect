# Petascale_Data_Protection

IBM SpectrumProtect
Petascale Data Protection
Document version1.0
Thomas Schreiber
Patrick Luft
Dominic Müller-Wicke
IBM SpectrumProtectdevelopment

© Copyright International Business Machines Corporation2016.
US Government UsersRestricted Rights–Use, duplication or disclosure restricted by GSA ADP Schedule Contract with
IBM Corp.

CONTENTS
Contents.........................................................................................................................iii
List of Figures..................................................................................................................v
List of Tables..................................................................................................................vi
Command-Line Interface (CLI) Examples......................................................................vii
Code Listings................................................................................................................viii
1 Introduction..........................................................................................................1
1.1 Architectural overview..........................................................................................1
1.2 Who should read this paper?................................................................................2
1.3 Stylistic elements that are used in this paper.......................................................2
2 Test environment.................................................................................................3
3 Setting up the environment..................................................................................5
3.1 Planning and configuration....................................................................................5
3.2 Installing the products...........................................................................................5
3.3 Configurationand logging file system...................................................................6
3.4 Logging directory...................................................................................................6
3.5 HSM multiple-server setup....................................................................................7
3.6 General policy rule statements.............................................................................8
4 Active server binding..........................................................................................10
4.1 Verification by using an HSM command.............................................................11
4.2 Verification by using an IBM Spectrum Scale command.....................................11

4.3 Verification by using the IBM Spectrum Scale policy engine..............................11
5 Backup...............................................................................................................13
5.1 Backup processing best practices........................................................................13
5.2 Backup processing...............................................................................................14
6 Restore..............................................................................................................16
6.1 Restore processing..............................................................................................16
7 Migration and recall............................................................................................18
7.1 Migration and recall processing best practices...................................................18
7.2 Migration and recall processing..........................................................................18
7.3 Migration based on fileset granularity................................................................18
7.4 Transparent recall................................................................................................20
7.5 Tape-optimized recall..........................................................................................20
8 Recovering missing stub files.............................................................................22
9 Reconciling a multiple-server file system...........................................................23
10 SOBAR backup processing................................................................................24
11 Recovering from a disaster................................................................................25
Appendix.......................................................................................................................26
References....................................................................................................................27
Notices..........................................................................................................................29
Trademarks.......................................................................................................................31
© Copyright International Business Machines Corporation2016 iv

LIST OFFIGURES
Figure 1: High-level architectural overview........................................................................................2
Figure 2: Test environment................................................................................................................3
© Copyright International Business Machines Corporation2016 v

LIST OFTABLES
Table 1: Logging and configuration files directory.............................................................................6
Table 2: Log directories for themmbackupcommand........................................................................7
Table 3: Log directories for themmapplypolicycommand..............................................................7
Table 4: IBM Spectrum Protect log directories..................................................................................7
Table 5: Documenting the correlation between filesets and servers...............................................10
Table 6: Valuesand numbers of sessions for the RESOURCEUTILIZATION option.....................14
© Copyright International Business Machines Corporation2016 vi

COMMAND-LINEINTERFACE(CLI)
EXAMPLES
CLI 1: Filesets that are created and used in the test environment....................................................4
CLI 2: Adding the HSM management server.....................................................................................7
CLI 3: Adding another HSM server....................................................................................................7
CLI 4: Verifying the HSM multiple-server environment......................................................................8
CLI 5: Showing server bind values..................................................................................................11
CLI 6: Using themmlsattrcommand to get the server name for a file..........................................11
CLI 7: Listing all files with binding for a full file system....................................................................12
CLI 8: Listingall files with binding for a fileset.................................................................................12
CLI 9: Backing up an independent fileset to a server......................................................................15
CLI 10: Querying all files fora file system and server.....................................................................16
CLI 11: Querying all files for a fileset and server.............................................................................16
CLI 12: Restoring files by using a file list.........................................................................................16
CLI 13: Restoring files by using wildcards.......................................................................................16
CLI 14: Running a migration policy on a fileset...............................................................................20
CLI 15: Running a tape-optimized recall operation.........................................................................21
CLI 16: Restoring a directory tree....................................................................................................22
CLI 17: Undeleting stub files............................................................................................................22
CLI 18: Reconciling a file system.....................................................................................................23
© Copyright International Business Machines Corporation2016 vii

CODELISTINGS
Code listing 1:User options in the test environment.........................................................................4
Code listing 2: Server stanzas in the test environment.....................................................................4
Code listing 3: Frequently usedpolicy definition statements.............................................................9
Code listing 4: Policy rule that lists all files that are bound to a server............................................12
Code listing 5: Calculating the number of server sessions..............................................................14
Code listing 6: Calculating the number of backup threads..............................................................14
Code listing 7: Calculating the number of sessions.........................................................................14
Code listing 8: Policy to premigrate all files in a given fileset..........................................................19
Code listing 9: Rule examplefor threshold migration......................................................................19
Code listing 10: Rule example for full premigration.........................................................................20
Code listing 11: Rule example for full migration..............................................................................20
© Copyright International Business Machines Corporation2016 viii

Petascale Data Protection
1 Introduction
You can protect data that scalesup to hundreds of petabytesinanIBM®SpectrumScale™
filesystemthat uses theIBM SpectrumProtect™backup-archiveclientandIBM Spectrum
Protect for Space Management. This paper providesconfiguration guidance for the setup
and operationof data protectionprocessesinthisenvironment.
This paper also introduces the concept of different service levels for data protectionat
thefile system andfilesetlevel.
1.1 Architectural overview
To use this approach, alargeIBM SpectrumScale filesystem is divided intomultiple
independentfilesets. Eachfilesetis protectedby using theIBM SpectrumProtect backup-
archive client andoptionally,withIBM SpectrumProtect for Space Management.IBM
SpectrumProtect for Space Managementcan be used for data tiering toanearline
storagedevicelike tape, and itenables the environment for disaster protectionbyusing
theScale Out Backup and Restore (SOBAR)function.
Onefile systemcorrespondsto one filespaceon theIBM SpectrumProtect server.For
one file system,multipleIBM SpectrumProtect server filespaces can becreated on
different server instances.An independent fileset is a subset of a file system and is
handled as asubset of a file space on the IBM Spectrum Protect server.With this
approach,eachfilesetcan be protected with one physical server. Thisapproachincreases
the maximum data protection capacity by multiplying the maximum server capacityby
the number ofused servers.
Thefollowing figureshows a logical overview of the architecture. TheIBM SpectrumScale
cluster in green on the left side implements a file system that contains several
independentfilesets.TheIBM SpectrumProtect backup-archive client andIBM Spectrum
Protect forSpace Managementareinstalled on the cluster nodes in blue. TheIBM
Spectrum Protect serversin blue on the right side provide the data-protection storage
backend with multipleserverinstances. EachIBM SpectrumScalefilesetcorresponds to
an instance of theIBM Spectrum Protect server:
© Copyright International Business Machines Corporation2016 1

Petascale Data Protection
Figure1:High-level architectural overview
The described data protection environment can be realized with multipleIBM Spectrum
Scale server or client nodes.EachIBM SpectrumScale cluster node that isusedfordata
protection requires the installation and configuration of theIBM SpectrumProtect
backup-archive client and optionally,theIBM SpectrumProtect for Space Management
client.
1.2 Who should read this paper?
Administrators whoare experiencedin protecting IBM Spectrum Scale file systems by
usingIBM SpectrumProtectand who plan todesign and implement a scale-out data
protection infrastructureshould read this paper.In addition,thepaperis intended tohelp
technical salesand servicepersonnelto integrate the technologies into customer
business processesso thata single filesystem namespacecan be splitinto different
service levelsfor backupoperationsand data tiering.
1.3 Stylistic elementsthat areused in this paper
Greenboxesprovidebackground information and describedependenciesthat must be
considered to prevent issues.
Gray boxes show command-line examples. Typically, these examples can be used as
described.
Blue boxes show content from configuration files or other information, such as policy
rules, that isstored in files. The content can be used as is.
© Copyright International Business Machines Corporation2016 2

Petascale Data Protection
2 Test environment
Assumptions:
-TheIBM Spectrum Protect server, IBM Spectrum Protect backup-archive client, and IBM
Spectrum Protect for Space Management are installed and configured.
-Thebase function ofIBM SpectrumScale andIBM SpectrumProtectare verified.
Before you begin:The preferred method is to reviewthe official product documentation
inIBM Knowledge Centerbefore you configure the system environment as described in
this paper.
Thefollowing figure provides an overview of thecompute and storage environment:
Figure2: Test environment
In the figure, theIBM SpectrumScaleclusteris a single-node cluster (node and cluster
name: PERSEUS). The existingNetwork Shared Disks (NSDs)are combined intwodevices
that arecalledgpfs1andgpfs2 andaremounted tomount points/gpfs1and /gpfs2. All
IBM SpectrumScale configuration parametershave default values.The file system has
onerootfilesetand three explicitfilesets (seeCLI 1).Allfilesets are defined as
independentfilesets.
> mmlsfileset /dev/gpfs1
Filesets in file system 'gpfs1':
Name                Status    Path
root                Linked/gpfs1
fileset_1Linked/gpfs1/fileset_1
fileset_2Linked/gpfs1/fileset_2
© Copyright International Business Machines Corporation2016 3

Petascale Data Protection
fileset_3Linked/gpfs1/fileset_3
CLI1:Filesetsthat arecreated and used inthetest environment
IBM SpectrumProtect: The backup-archive client is installed and configured with default
values. Beforeyou installIBM Spectrum Protect for Space Management (hereinafter,the
HSM client),the exportsettingHSMINSTALLMODE=SCOUTFREEwas set to automatically
disable thestandardautomaticmigration,which is not used in this environment. The
followingHSM clientoptions are set in thedsm.optfile:
HSMENABLEIMMEDIATEMIGRATE YES
HSMDISABLEAUTOMIGDAEMONS YES
HSMEXTOBJIDATTR           YES
HSMMULTISERVER            YES
Code listing1:User options inthetest environment
TheIBM SpectrumProtect serversMEDUSA_1 and MEDUSA_2were configured according
totheIBM SpectrumProtect Blueprintfor small installations.To simplify problem analysis
and logging,theserverstanzas(ERRORLOGNAME, HSMLOGNAME)were edited to log in
to different log files. Seethefollowinglisting:
SERVERNAME MEDUSASERV_1
TCPPORT 1500
TCPSERVERADDRESS MEDUSA_1.X.Y.Z
PASSWORDACCESS GENERATE
ASNODENAME       MYTHOLOGY
NODENAME THESEUS
ERRORLOGNAME     /gpfs2/log/dsmerror.medusa1.log
HSMLOGNAME       /gpfs2/log/hsm.medusa1.log
HSMLOGEVENTFLAGSFILE
SERVERNAME MEDUSASERV_2
TCPPORT 1500
TCPSERVERADDRESS MEDUSA_2.X.Y.Z
PASSWORDACCESS GENERATE
ASNODENAME       MYTHOLOGY
NODENAME         PERSEUS
ERRORLOGNAME/gpfs2/log/dsmerror.medusa2.log
HSMLOGNAME/gpfs2/log/hsm.medusa2.log
HSMLOGEVENTFLAGSFILE
Code listing2:Server stanzas inthetestenvironment
© Copyright International Business Machines Corporation2016 4

Petascale Data Protection
3 Settinguptheenvironment
You can set up and configureadata protection environment withmultiple nodesand
multiple servers.
3.1 Planning and configuration
 Review the most recent product documentation to get information about changes
and improvements in the used functions. Both IBM Spectrum Scale and IBM
Spectrum Protect for Space Management provide anFAQ document. Find them in
References.
 When you size the IBM Spectrum Scale cluster, remember that themmbackup
command adds workload (in terms of memory consumption, cluster network I/O,
and CPU) on all cluster nodes that are involved in backup processing. In addition,
all cluster nodes that participate in the backup processing must have sufficient I/O
bandwidth to the IBM Spectrum Scale storage system. Furthermore, adequate
bandwidth must be available for the connection to the IBM Spectrum Protect
server.
 The smallest entity for processing (for the backup-archive client and HSM) is a file
system or fileset. To accelerate the processing for one entity, parallelize it by
distributing the workload to multiple nodes. If multiple entities must be backed up
at the same time, select distinct sets of nodes for each entity. If one entity is
finished, you can start to process another entity by using the same set of nodes.
 Do not mix operating systems for backup and restore processing in a
heterogeneous cluster environment.
 You can use IBM Spectrum Protect include and exclude options to control which
files and directories are backed up. Themmbackupcommand translates these
options into IBM Spectrum Scale policy rules for backup. The translation of these
options into rules can be complex and might have significant impact on scan
performance. For more information, seetechnote 1699569.
3.2 Installing the products
 Before you install HSM packages:Issue thefollowing UNIXshell command:
export HSMINSTALLMODE=SCOUTFREE
In this way, you canautomatically streamlinethe HSM client foruseinIBM
SpectrumScale environments.
 To take advantage of improvements and defect fixes, install the latest versions of
IBM Spectrum Protect and IBM Spectrum Scale.
© Copyright International Business Machines Corporation2016 5

Petascale Data Protection
3.3 Configurationand logging file system
The product functionsthat areused in the multiple-server environment require several
configuration and command input files. These are thedsm.sysanddsm.optfiles for the
IBM SpectrumProtect client configuration or the rule filesthat areused for the different
policy engine runs.The preferred method isto store a copy of these files in a global
working directory toensure that the files areavailable on all nodes in the clusterthat
managethe processing. For the described test environment, a shared file system with
mount point/gpfs2is used. It contains directories for logging and configuration files:
Directory Content
/gpfs2/config
Configuration information, such as copies of thedsm.sys
anddsm.optfiles;policyrule files;and aserver-to-fileset
mapping table
/gpfs2/log
Logging information, such as the following files:mmbackup
log,mmapplypolicylog,dsmerror.log, andhsm.log
Table1:Logging and configuration files directory
The configuration directory is backed up daily toensure that the information isavailable
afterthe accidentaldeletionof dataoradisaster.
3.4 Logging directory
Becauseseveral IBM products and product functions are combined in a multiple-server
data protection environment,log spacemustbe handled with care.Consider the
following items:
1. The use ofone globally available logging directory simplifiesthe analysis ofresults
and problems.
2. Different product functions might generate a significant amount of information
and enough space must be available tostoreit.
The preferredmethod isto log all information in a separateIBM SpectrumScale file
system that is mounted on all affected nodes.You can use thefollowing command-line
parameters and log directory settings toensure thatall logging tools writeto the same
directory:
mmbackup command-line options
| directory | --tsm-servers | -g and-s |
| --- | --- | --- |
| /gpfs1 | MEDUSASERV_2 | /gpfs2/log/mmbackup/gpfs1/root |
| /gpfs1/fileset_1 | MEDUSASERV_1 | /gpfs2/log/mmbackup/gpfs1/fileset_1 |
| /gpfs1/fileset_2 | MEDUSASERV_1 | /gpfs2/log/mmbackup/gpfs1/fileset_2 |
| /gpfs1/fileset_3 | MEDUSASERV_2 | /gpfs2/log/mmbackup/gpfs1/fileset_3 © Copyright International Business Machines Corporation2016 6 |

Petascale Data Protection
Table2:Log directories for themmbackupcommand
mmapplypolicy command-line options
directory -g and-s
/gpfs1 /gpfs2/log/mmapplypolicy/gpfs1/root
/gpfs1/fileset_1 /gpfs2/log/mmapplypolicy/gpfs1/fileset_1
/gpfs1/fileset_2 /gpfs2/log/mmapplypolicy/gpfs1/fileset_2
/gpfs1/fileset_3 /gpfs2/log/mmapplypolicy/gpfs1/fileset_3
Table3:Log directories for themmapplypolicycommand
IBM SpectrumProtect server stanzas
SERVERNAME:MEDUSASERV_1
ERRORLOGNAME /gpfs2/log/dsmerror.medusa1.log
HSMLOGNAME /gpfs2/log/hsm.medusa1.log
SERVERNAME:MEDUSASERV_2
ERRORLOGNAME /gpfs2/log/dsmerror.medusa2.log
HSMLOGNAME /gpfs2/log/hsm.medusa2.log
Table4:IBM SpectrumProtect log directories
3.5 HSM multiple-server setup
This section describes how to setupIBM SpectrumProtect for Space Management to
manage a single file systemby usingmultipleIBM Spectrum Protect servers. Thistype of
setup is calledanHSM multiple-serverenvironment. The setup of the HSM multiple-
serverenvironmentenables active server binding by using the server name attribute as
described inthe previoussection.
Initially,you must addtheHSM managementserverto the file systemas shown in this
example:
> dsmmigfs Add-SErver=MEDUSASERV_1 /gpfs1
CLI2:Adding theHSM managementserver
To enable the HSM multiple-serverenvironment,you must addthe initially used server
and all other available serversto the environmentas shown in this example:
> dsmmigfsADDMultiserver-Server=MEDUSASERV_1 /gpfs1
> dsmmigfsADDMultiserver-Server=MEDUSASERV_2 /gpfs1
CLI3:Adding anotherHSM server
The setup canbe verifiedas shown in the following example:
> dsmmigfs QUERYMultiserver/gpfs1
IBM Tivoli Storage Manager
© Copyright International Business Machines Corporation2016 7

Petascale Data Protection
Command Line Space Management Client Interface
Client Version 7, Release 1, Level 6
Client date/time: 03/21/16   12:57:45
(c) Copyright by IBMCorporation and other(s) 1990, 2016. All Rights Reserved.
Server Name          Bytes [KByte]        Files                Throughput [MByte/s]
---------------------------------------- -------------------- --------------------
MEDUSASERV_1 0                    0                    0
MEDUSASERV_2 0                    0                    0
CLI4:VerifyingtheHSM multiple-server environment
Restriction:As described in theIBM SpectrumProtect for Space Managementproduct
documentation,multiple-server setup tools automatically create sample policy rules for
migration processing.Do not use thesepolicy rules.Instead, use the policy rules that are
described inMigration and recall.
3.6 General policy rule statements
This section describes generalIBM SpectrumScaleinformation lifecycle management
(ILM)rules and policies that are used throughout this paper. These rules are wrapped into
macros,defining a term for an expression, as shown in the following list.
Requirement:If you create a policy file,you must place a list of definitionsin the file
before any rules.
/*=== identify files that are in state premigrated ===*/
define(is_premigrated,
(MISC_ATTRIBUTES LIKE '%M%' AND
MISC_ATTRIBUTES NOT LIKE '%V%'))
/*=== identify files that are in state migrated ===*/
define(is_migrated,
(MISC_ATTRIBUTES LIKE '%V%'))
/*=== identify files that are in state resident ===*/
define(is_resident,
(MISC_ATTRIBUTES NOT LIKE '%M%'))
/*=== allow the comparison of the servername attribute ===*/
define(servername,
(XATTR('dmapi.IBMServ') ))
/*=== exclude list for file that must not be processed from HSM ===*/
© Copyright International Business Machines Corporation2016 8

Petascale Data Protection
define(exlude_list,
(PATH_NAME LIKE '%/.SpaceMan/%'
OR NAME LIKE '%dsmerror.log%'
OR NAME LIKE '%.mmbackup%'))
Code listing3:Frequentlyused policy definitionstatements
© Copyright International Business Machines Corporation2016 9

Petascale Data Protection
4 Active server binding
You can use the active server bindingfunctiontoensure that a file in afilesetissentto
only one server.You can enable active server binding when you implement anHSM
multiple-serverenvironmentthat includesIBM SpectrumProtect for Space Management.
Tip:Active server binding is applied to the server that is namedin the server stanza(see
Test environment).
After you binda filetoa server,the initial backup or migration of the file causesthe
creation of a hidden attribute in the inode of thefile. Any attempt to send the file to a
different server fails.At the same time,IBM SpectrumProtectfor Space Management
functionssuch as backing up files before migration (“backup before migrate”)work as
expected. Furthermore,active server bindingenables the inline copy function.
Tip:Active server binding is anIBM SpectrumProtect for Space Management function,
and theIBM SpectrumProtect backup-archive clientusesthe functioniftheHSM
multiple-serverenvironmentis enabled. Inapure backup environment withoutIBM
SpectrumProtect for Space Management,theactivebindingthat isprovided byIBM
SpectrumProtect tools is not possible. You must take manual steps to ensurethatthe
filesets arealwaysbacked up to the sameIBM SpectrumProtect server.
Beforeyou startoperations tobackup or migrate filesto different servers, you must
documentthecorrelation betweenfilesets and server names. Thisstepis important to
allow the reconstruction of the environment afterasystem failure or a disaster. For the
test environment,the correlation was documentedas follows:
Device:gpfs1
| Fileset | Linkage | Server name |
| --- | --- | --- |
| root | /gpfs1 | MEDUSASERV_2 |
| fileset_1 | /gpfs1/fileset_1 | MEDUSASERV_1 |
| fileset_2 | /gpfs1/fileset_2 | MEDUSASERV_1 |
| fileset_3 | /gpfs1/fileset_3 Table5:Documenting the correlation betweenfilesets andservers Tip:When you bind a file to a server, operations tobackup and migrate filesuse the same server.To change the binding, use one of the following methods: -To changethe binding for an individual file, create a copy of the file and delete the original file. Then, rename the new file to the old file name. After that, back up and migrate the new file. -To recall all files from a server and remove the binding, use the HSM multiple-server commanddsmMultiServerRemove.pl. You can use the following methods to verify that filesarebacked up or migrated with active server binding: © Copyright International Business Machines Corporation2016 10 | MEDUSASERV_2 |

Petascale Data Protection
 By using the HSM commanddsmls(seeVerification by using an HSM command)
 By using theIBM SpectrumScale commandmmlsattr(seeVerification by using
an IBM Spectrum Scale command)
 By using theIBM SpectrumScale policy engine (seeVerification by using an IBM
Spectrum Scale policy engine)
4.1 Verificationbyusing anHSM command
You can obtain the bind information for a file by using the HSM commanddsmls.Asseen
in thefollowingexample,the Srv columndisplays the nameof thebindingserver:
> dsmls rootfile*
IBM Tivoli Storage Manager
Command Line Space Management Client Interface
Client Version 7, Release 1, Level 6
Client date/time: 03/18/16   11:16:37
(c) Copyright by IBM Corporation and other(s) 1990, 2016. All Rights Reserved.
ActS         ResS         ResB   FSt   Srv                      FName
1048576      1048576         1024   rMEDUSASERV_2 rootfile0
1048576      1048576         1024   rMEDUSASERV_2 rootfile1
CLI5:Showingserver bind values
Tip:To obtain a description of all column headers, use the–helpargument of thedsmls
command.
4.2 Verificationby using anIBM SpectrumScale command
You can obtainthe server bind attribute for a fileby using theIBM SpectrumScale
commandmmlsattr.The active server binding function sets an extended attribute
nameddmapi.IBMServ:
> mmlsattr-d-L rootfile1 |grep IBMServ
dmapi.IBMServ:        "MEDUSASERV_2"
CLI6:Using themmlsattrcommandto gettheserver name for a file
4.3 Verificationby using theIBM SpectrumScale policy engine
Due to the limited performance of thedsmlsandmmlsattrcommands,it is more
practical to use theIBM SpectrumScale policy engine to list the filesthatbind to a given
server.For example,to list all files that are bound to serverMEDUSASERV,thefollowing
policy can be used (byusingmacros that aredefined inGeneral policy rule statements):
RULE EXTERNAL LIST 'MEDUSA_RESIDENT' EXEC ''
RULE EXTERNAL LIST 'MEDUSA_PREMIG' EXEC ''
RULE EXTERNAL LIST 'MEDUSA_MIG' EXEC ''
© Copyright International Business Machines Corporation2016 11

Petascale Data Protection
RULE 'resident_files' LIST 'MEDUSA_RESIDENT'
WHERE (is_resident) ANDservername LIKE 'MEDUSASERV_2%'
RULE 'premigrated_files' LIST'MEDUSA_PREMIG'
WHERE (is_premigrated) ANDservername LIKE 'MEDUSASERV_2%'
RULE 'migrated_files' LIST'MEDUSA_MIG'
WHERE (is_migrated) ANDservername LIKE 'MEDUSASERV_2%'
Code listing4:Policy rule thatlistsall files that arebound to a server
The rules, whichmust be stored in apolicy file,can be used to generateliststhat contain
all filesthat arebound to a specified server. Themmapplypolicycommand can be used
to execute the rules. The parameter–Pspecifies the name of filethat containsthe rules.
The following example shows themmapplypolicycommand with the file system scope:
> mmapplypolicygpfs1 -N perseus-P rulefile
-s/gpfs2/log/mmapplypolicy/gpfs1 -g/gpfs2/log/mmapplypolicy/gpfs1
-f/gpfs2/log/mmapplypolicy/gpfs1/scan.out-I defer--scope filesystem
CLI7:Listingall files with binding forafull file system
The following example shows themmapplypolicycommand with thefilesetscope:
> mmapplypolicy/gpfs1/-N perseus-P rulefile
-s/gpfs2/log/mmapplypolicy/gpfs1/root-g/gpfs2/log/mmapplypolicy/gpfs1/root
-f/gpfs2/log/mmapplypolicy/gpfs1/root/scan.out-I defer--scope inodespace
CLI8:Listingall files with binding forafileset
© Copyright International Business Machines Corporation2016 12

Petascale Data Protection
5 Backup
You can use the IBM Spectrum Scalemmbackupcommand in an environment where each
independentfilesetis backed up to an IBM Spectrum Protect server. The IBM Spectrum
Protect server can be different for differentfilesets.
5.1 Backup processing best practices
 Use the processing options-qand--rebuildon themmbackupcommand as seldom
as possible. Rebuilding the shadow database of themmbackupcommand takes
time because the IBM Spectrum Protect server must be queried.
 Consider IBM Spectrum Protect character limitations. Files with control-X, control-
Y, carriage returns, and the new line character in their names can’t be backed up
to IBM Spectrum Protect. The IBM Spectrum Protect processing options
quotesareliteral (in combination with themmbackupcommand option--noquote)
and wildcardsareliteral can help if you are faced with special characters in path or
file names.
 Do not use the IBM Spectrum Protect processing options–subdir=yes, quiet,
scrollprompt, or scrolllines.
 When you run themmbackupcommand, avoid using processing option–B. The
new options--max-backup-count,--max-expire-count, and--max-backup-size
make it possible to fine-tunemmbackupcommand processing. The values that you
use for these options should be multiples of the IBM Spectrum Protect processing
optionstxnbytelimit and TXNGROUPMAX. For more information, see the
mmbackupcommand documentation.
 When you run themmbackupcommand, avoid using processing option-m. The
new options--backup-threads and–expire-threads make it possible to fine-tune
mmbackupcommand processing. The valuesthat areused for these options
should be aligned with the values that are used for the IBM Spectrum Protect
processing options RESOURCEUTILIZATION and MAXSESSIONS, and with the
MAXNUMMP parameter, as explained below.
The IBMSpectrum Protect processing option RESOURCEUTILIZATION defines the
number of consumer and producer threads in thedsmccommand for backup
operations. The following table shows values and session numbers for backup
operations. Expiration processing uses only one session.
RESOURCEUTILIZATION
Value Number of sessions (send+query)
1 1
0 (default), 2 2 (1+1)
3, 4 3 (2+1)
5, 6 4 (3+1)
© Copyright International Business Machines Corporation2016 13

Petascale Data Protection
7 5 (4+1)
8 6 (5+1)
9 7 (6+1)
10 8 (7+1)
Table6: Values and numbersof sessionsfor theRESOURCEUTILIZATIONoption
The total number of backup sessions coming into the server based on the
mmbackupoption–backup-threads and the client processing option
RESOURCEUTILIZATION should be reflected in the setting of the server options
MAXSESSIONS and MAXNUMMP.
#sessions = (#backup-threads * #nodes * (RESOURCEUTILIZATION[VALUE]- 1))
Code listing5: Calculating the number of server sessions
The number of sessions reflects the MAXNUMMP setting for the client node. The
value of the server option MAXSESSIONS should be the sum of the MAXNUMMP
values for all nodes.
The number of backup threads that are configured with themmbackupcommand
depends on the number of mount points that are configured for the node (server
option MAXNUMMP), andcan be calculated as follows:
#backup-threads = #mount-points / (#nodes * (RESOURCEUTILIZATION[VALUE]-
1))
Code listing6: Calculating the number of backup threads
The total number of expire sessions coming into the server basedon the
mmbackupoption–expire-threads should be reflected in the setting of the server
MAXSESSIONS option.
#sessions = (#expire-threads * #nodes)
Code listing7: Calculating the number of sessions
5.2 Backup processing
When you backupafilesetinstead of a file system,thefilesetmust be an independent
filesetwith a separate inode space from the file system.To run afileset-level backup
operation, you must createa snapshot for thefilesetfirst. Then, run themmbackup
commandtoback upthe files from the snapshotbyusing the option–S snapshotname
and–scope inodespace.
For example, you can back up anindependent fileset (fileset_1)to the server
MEDUSASERV_1:
1) create snapshot
> mmcrsnapshot /dev/gpfs1nsd snap1 -jfileset_1
2) backup fileset
© Copyright International Business Machines Corporation2016 14

Petascale Data Protection
> mmbackup/gpfs1/fileset_1/-t full-S snap1
-s/gpfs2/log/mmbackup/gpfs1/fileset_1 -g/gpfs2/log/mmbackup/gpfs1/fileset_1
--tsm-serversMEDUSASERV_1 --scope inodespace
3) delete snapshot
> mmdelsnapshot /dev/gpfs1nsd snap1 -jfileset_1
CLI9:Backing up an independentfilesetto aserver
Requirementfor the initial run of the mmbackup command:The initial run ofthe
mmbackupcommandmust be started with the argument-t full. This ensures that a file
spacefor the filesystemwill be createdontheIBM SpectrumProtect server.
Recommendation to delete snapshots:IBM SpectrumScale snapshots do not support the
data management application protocol interface (DMAPI)completely.BecauseIBM
SpectrumProtect forSpace Management relies on the DMAPI,thisfacthasanimpacton
HSM processing. It is strongly recommendedthat youdelete snapshots immediately after
backup processing has finished.
All otherindependentfilesets,including the rootfileset,can bebacked up with the same
process.Certain parameters,such as thefilesetname, directory,and the server name (--
tsm-servers),mustbe adjusted.
Tip:To learn more aboutprocessing options for themmbackupcommandand howthey
can be used tooptimizebackup performance, seeError! Reference source not found..
© Copyright International Business Machines Corporation2016 15

Petascale Data Protection
6 Restore
You canusetheIBM SpectrumProtect restoreprocessto recovermissingfiles in a multi-
server environmentwhere eachfilesetis mapped to a differentIBM SpectrumProtect
server.In addition totheIBM SpectrumProtect backup-archiveclientGUI,the command-
line client(dsmc)can be used to find files and to restore files from the server backupto
the filesystem.
6.1 Restore processing
Ifmultipleindependentfilesetsof the same file systemarebacked up to the sameIBM
SpectrumProtect server,all files that belong to the given filesystemcan be queried from
this server. In this case,the path for the query is the file system path:
>dsmc query backup -detail-subdir=yes/gpfs1/-servername=MEDUSASERV_1
CLI10:Queryingall files forafilesystem and server
You can use asimilarquery tolistthe filesaccording to asinglefileset, whereby the query
path name is thefilesetpathname:
>dsmc query backup -detail-subdir=yes/gpfs1/fileset_1/-
servername=MEDUSASERV_1
CLI11:Queryingall files forafilesetand server
You canrestorefilesby using thefile liststhat weregenerated from the output of the
previousbackup query:
1) generate file list of all protected files in fileset, where filename starts
with “peter”:
>dsmc query backup "/gpfs1/fileset_1/peter*" -subdir=yes -
servername=MEDUSASERV_1 | grep " B " | awk '{ print $7 }' > restore.list
2) restore the file list
> dsmc restore-filelist=restore.list-servername=MEDUSASERV_1
CLI12:Restoring files by using afile list
You can alsoquery and restore filesbyusing wildcards, as shown in the following
example:
1) restore all files, where filename contains “rob”:
> dsmc restore "/gpfs1/fileset_1/*rob*" -subdir=yes-servername=MEDUSASERV_1
CLI13:Restoring files by usingwildcards
By usingafile list for the restoreoperation, you canstart multiple parallel restore
sessions andpossibly improve the performance of the operation.When you use this
method,a large file list can be broken down intosmaller file lists and these smaller file
© Copyright International Business Machines Corporation2016 16

Petascale Data Protection
listscan be used as input for multiple restore commands (dsmc restore –filelist).
You can distribute the workload to multiple nodesthat are configured for backup
operationsby executing the restore commands with different file lists on different nodes
simultaneously.
Restriction:Restoreoperationsthat are based on filelistsdonot optimize access to files
on theIBM SpectrumProtect server. The filesareprocessed in the orderin which they
werewritten to the file list.The file lists for each restore command should include logical
breaks in the directory structure toprevent too many restore processesfrom writingto
the same directory.
© Copyright International Business Machines Corporation2016 17

Petascale Data Protection
7 Migration and recall
You can use IBM Spectrum Protect for Space Management to migrate and recall files in a
multiple-server environment where each independentfilesetis migrated to an IBM
Spectrum Protect server. The IBM Spectrum Protect server can be different for different
filesets.
7.1 Migration and recall processing best practices
 To improve migration performance to tape, use the IBM Spectrum Protect for
Space Management processing optionhsmgroupedmigrate yes.
 To ensure that expired files can be recovered, do not set the IBM Spectrum
Protect for Space Management processing optionmigfileexpirationto 0.
 IBM Spectrum Protect for Space Management is not a backup program. To avoid
losingmigrated data, specifymigrequiresbackup=yes. Furthermore, use migration
policies that allow the migration of files that have a valid copy in backup.
 Use tape-optimized recall if it can be integrated into your business processes in
terms of accessing migrated files.
7.2 Migration and recall processing
The preferredmethodis to run the migration on eachfilesetwith a separatepolicy
dedicatedtoeachfileset.You can do this by using themmapplypolicyoptionand
specifying--scope inodespaceand the migrationrulesthat aredefined below.
Furthermore,you can usethe policy rule statementFOR FILESETto ensurethatthe
policy scan is focused on the right content. Ifyouplan to applythe same rule that defines
the target server for the migrationtoseveralfilesets, do not usetheFOR FILESET
argument to reduce the number of rule sets to be maintained.
Requirement:The general policy rule statements must be applied here,as well.For more
information, seeGeneral policy rule statements.
7.3 Migrationbasedonfilesetgranularity
As shown inCode listing8, acomplete rulesetwasprepared for afilesetthat has an
active server binding toIBM SpectrumProtect serverMEDUSASERV_1. Therulesetis
stored in file/gpfs2/config/rulefile.MEDUSASERV_1.Definitionsidentify files that are
already migrated, premigrated,or resident.
Furthermore, theservernamedefinitionis used to read theservernameattribute,
where the binding to the serveris stored. The definitionfor the exclude list ensures that
files that must not be migratedare skipped duringthe policy scan. This list should be
adapted to customer needs.The external pool ruleensures that migration is exclusively
to theIBM SpectrumProtect server MEDUSASERV_1. The migration rulealsodefines the
© Copyright International Business Machines Corporation2016 18

Petascale Data Protection
source and the target pool for the migration. In addition, the thresholds can be defined
here.InCode listing8,the threshold definitionensuresthatall filesarepremigrated.
Tip:The definition of the threshold valuesdetermines whetherthe filesarepremigrated,
migrated,or resident.For adescription of therulesthat can be applied, see the following
listings.
Thewhereclause defines which filesareincludedin, and excluded from,the scan.
define(is_premigrated,
(MISC_ATTRIBUTES LIKE '%M%' AND
MISC_ATTRIBUTES NOT LIKE '%V%'))
define(is_migrated,
(MISC_ATTRIBUTES LIKE '%V%'))
define(is_resident,
(MISC_ATTRIBUTES NOT LIKE '%M%'))
define(servername,
(XATTR('dmapi.IBMServ') ))
define(exlude_list,
(PATH_NAME LIKE '%/.SpaceMan/%'
OR NAME LIKE '%dsmerror.log%'
OR NAME LIKE '%.mmbackup%'))
RULE EXTERNAL POOL 'MEDUSASERV_1_POOL' EXEC
'/opt/tivoli/tsm/client/hsm/multiserver/bin/hsmExecScript.pl 'OPTS '-v-server
MEDUSASERV_1'
RULE 'MEDUSASERV_1' MIGRATE
FROM POOL 'system' THRESHOLD(0,100,0)
TO POOL 'MEDUSASERV_1_POOL'
WHERE NOT (exlude_list)
AND NOT (is_migrated)
AND NOT (is_premigrated)
Code listing8:Policy to premigrate all files in a givenfileset
The values of the THRESHOLDpolicy statementdefinewhetherand how filesare
migrated, as shown in theseexamples:
1) Start the threshold migrationin a situation wherethe file systemhas filled up to
90% ofitsavailable space.Migrate files until theminimumthreshold of 80% of the
available spaceis reached.Premigrate files that use 10% (80%minus70%) of the
available space in the filesystem.
RULE 'MEDUSASERV' MIGRATE
FROM POOL 'system' THRESHOLD(90,80,70)
TO POOL 'MEDUSASERV_1'
AND NOT (is_migrated)
Code listing9:Rule exampleforthreshold migration
© Copyright International Business Machines Corporation2016 19

Petascale Data Protection
2) Premigrate all files in the filesystem.
RULE 'MEDUSASERV' MIGRATE
FROM POOL 'system' THRESHOLD(0,100,0)
TO POOL 'MEDUSASERV_1'
AND NOT (is_migrated)
AND NOT (is_premigrated)
Code listing10:Rule exampleforfull premigration
3) Migrate all files in the filesystem.
RULE 'MEDUSASERV' MIGRATE
FROM POOL 'system' THRESHOLD(0,0,0)
TO POOL 'MEDUSASERV_1'
AND NOT (is_migrated)
Code listing11:Rule exampleforfull migration
You must start the policy engineseparatelyfor eachfileset. Thefollowingcommand
shows how the policy engineisstartedwithfilesetlinkage/gpfs1/fileset_3in the test
environment to migrate files based on the policy rulethat isdefined in
/gpfs2/config/rulefile.MEDUSASERV_2.
> mmapplypolicy/gpfs1/fileset_3 -N perseus-s
/gpfs2/log/mmbackup/gpfs1/fileset_3 -g/gpfs2/log/mmbackup/gpfs1/fileset_3 -P
/gpfs2/config/rulefile.MEDUSASERV_2 --scope inodespace
CLI14:Running amigration policy onafileset
7.4 Transparent recall
Transparent recall is intended tobetransparenttotheuser. Therefore, no actionis
requiredforfileset-level migration and active server binding. The function works as
designed.
7.5 Tape-optimized recall
Tape-optimized recall processing optimizes the sequential access to tape storage to
improve recall performance.This functionis designedto work with a dedicatedIBM
SpectrumProtect server.
Performance considerations:Compared to transparent recall,tape-optimized recall has
significantly betterperformance.However, tape-optimized recallrequires that the user
knows which files must be recalled. If businessrequirementsallowintegration oftape-
optimized recall into customer processes,the overall experience with HSM will be much
better compared totransparentrecall processing.
Tip:To generate a list of all filesthat weremigrated for a givenfileset, usethe policy rule
that isdescribed inVerificationby using theIBM SpectrumScale policy engine.
Use the following commands to perform a tape-optimized recall on afilesetfor a
specifiedfile list and server:
© Copyright International Business Machines Corporation2016 20

Petascale Data Protection
>dsmrecall-detail-filelist=recall.list-server=MEDUSASERV_2 /gpfs1
CLI15:Running atape-optimized recalloperation
© Copyright International Business Machines Corporation2016 21

Petascale Data Protection
8 Recovering missing stub files
You can useIBM SpectrumProtect for Space Management to undelete files in a multiple-
server environmentin whichfilesetsare mappedto a server.
You can use theHSM commanddsmmigundeleteto re-create stub files and
premigrated files that wereaccidentallydeletedfromafileset. The command isdesigned
to runatthefile-system level and to work with a dedicatedIBM SpectrumProtect server.
Restrictions:
-HSM migratesonlyregular files. Special files and directories are not migrated. Therefore,
HSM has no information about directory permissions. Dueto this fact,the HSM command
dsmmigundeletedoes not create directories. If parts ofadirectory tree are missing,
theymust be restored fromabackup.
-Thedsmmigundeletecommandworks onthefile-system level. Therefore, allfilesets
that contain data migrated to a dedicated server must be handled in one step.All
affected directory trees must be complete.
Thefollowingcommand examples show how a missingdirectory tree can be re-created
and how thedsmmigundeletecommandisused to re-create stub filesin fileset
/gpfs1/fileset_1andfileset_2:
>dsmc restore-subdir=yes-dirsonly/gpfs1/fileset_1/-servername=MEDUSASERV_1
>dsmc restore-subdir=yes-dirsonly/gpfs1/fileset_2/-servername=MEDUSASERV_1
CLI16:Restoring adirectory tree
> dsmmigundelete-detail-server=MEDUSASERV_1 /gpfs1
CLI17:Undeletingstub files
© Copyright International Business Machines Corporation2016 22

Petascale Data Protection
9 Reconciling a multiple-server file system
You can use theHSM reconcile function to synchronize the informationin afilesystem
with the migration informationthat isstored onanIBM SpectrumProtect server.
The reconcile program is intended to work onthefile-system level for a dedicated server.
Therefore,the program must bestarted once for each server in the multiple-server
environment.The programautomatically synchronizesthe data for allfilesets that have
an active server binding to the given server.Use the command asshown in the following
example:
>dsmreconcileGPFS.pl -server=MEDUSASERV_1 /gpfs1
CLI18:Reconciling afilesystem
© Copyright International Business Machines Corporation2016 23

Petascale Data Protection
10 SOBAR backup processing
You can usetheIBM SpectrumScale andIBM SpectrumProtect SOBARfunctiontoback
up imagesin a multiple-server environmentin whichfilesets are mapped to servers.
In general, the SOBAR backup function is processedat thefile-system level. The data
protection approachthat isdescribed in this paper and implementedat thefileset level
will notaffect the SOBAR backup. All SOBAR function can be used as is.BecauseSOBAR
requires a connection to anIBM SpectrumProtect server to back up the file-system image
files,one of the servers used for fileset data protection can be used for SOBAR image file
backup.You must ensurethat enough free space is available in theIBM SpectrumProtect
server storage pool to store the backupcopy of the SOBAR image files.
For instructions about usingtheSOBAR function, seeScale Out Backup and Restore
(SOBAR).
© Copyright International Business Machines Corporation2016 24

Petascale Data Protection
11 Recovering from a disaster
You can usetheIBM SpectrumScale andIBM SpectrumProtect SOBARfunctionto
perform disaster recovery in a multiple-server environmentin whichfilesets are mapped
to servers.
In general, the SOBAR restore function is processedatthefile-system level. The data
protection approach described in this paper and implementedat thefileset leveldoes not
affect the SOBAR restoreprocess. All SOBAR function can be used as is,and the fileset-
level data protection informationcan be recovered.
For instructions about usingtheSOBAR function, seeScale Out Backup and Restore
(SOBAR).
© Copyright International Business Machines Corporation2016 25

Petascale Data Protection
APPENDIX
© Copyright International Business Machines Corporation2016 26

Petascale Data Protection
REFERENCES
IBM SpectrumProtectproduct documentation inIBM Knowledge Center:
http://www.ibm.com/support/knowledgecenter/SSGSG7/landing/welcome_ssgsg7.html
IBM Spectrum Scale product documentation in IBM Knowledge Center:
http://www.ibm.com/support/knowledgecenter/STXKQY/ibmspectrumscale_welcome.ht
ml
IBM Elastic StorageServer product documentation inIBM Knowledge Center:
https://www.ibm.com/support/knowledgecenter/P8ESS/p8ehc/p8ehc_storage_landing.h
tm
IntegratingIBM SpectrumProtectwith IBM Elastic Storage:
https://www.ibm.com/developerworks/community/wikis/home?lang=en#!/wiki/Tivoli%2
0Storage%20Manager/page/Integrating%20IBM%20Tivoli%20Storage%20Manager%20wi
th%20IBM%20Elastic%20Storage
Tivoli Field Guide–TSM forSpace Management for UNIX-GPFSIntegration:
http://www.ibm.com/support/docview.wss?uid=swg27018848
Tivoli Field Guide–Tivoli Storage Manager for Space Managementin a mixedGPFS
cluster environment:
http://www.ibm.com/support/docview.wss?uid=swg27028178
Tivoli Field Guide-Performance of GPFS/HSM–Tivoli Storage Managerfor Space
Management: Part 1: Automigration:
http://www.ibm.com/support/docview.wss?uid=swg27020987
Considerations for usingIBM SpectrumProtectinclude and exclude options with IBM
Spectrum Scale mmbackup command:
http://www.ibm.com/support/docview.wss?uid=swg21699569
Data Storage Management (XDSM) API:
http://pubs.opengroup.org/onlinepubs/9657099/
IBM SpectrumScale FAQ:
https://www.ibm.com/support/knowledgecenter/STXKQY/gpfsclustersfaq.html
IBM SpectrumProtect for Space Management FAQ:
http://www.ibm.com/support/docview.wss?uid=swg21474412
IBM Spectrum Protect Blueprints:
https://www.ibm.com/developerworks/community/wikis/home?lang=en#!/wiki/Tivoli%2
0Storage%20Manager/page/IBM%20Spectrum%20Protect%20Blueprints
© Copyright International Business Machines Corporation2016 27

Petascale Data Protection
© Copyright International Business Machines Corporation2016 28

Petascale Data Protection
Notices
This information was developed for products and services offered in the US. This material might
be available from IBM in otherlanguages. However, you may be required to own a copy of the
product or product version in that language in order to access it.
IBM may not offer the products, services, or features discussed in this document in other
countries. Consult your local IBM representative for information on the products and services
currently available in your area. Any reference to an IBM product, program, or service is not
intended to state or imply that only that IBM product, program, or service may be used. Any
functionallyequivalent product, program, or service that does not infringe any IBM intellectual
property right may be used instead. However, it is the user's responsibility to evaluate and verify
the operation of any non-IBM product, program, or service.
IBM may havepatents or pending patent applications covering subject matter described in this
document. The furnishing of this document does not grant you any license to these patents. You
can send license inquiries, in writing, to:
IBM Director of Licensing
IBM Corporation
North Castle Drive, MD-NC119
Armonk, NY 10504-1785
US
For license inquiries regarding double-byte character set (DBCS) information, contact the IBM
Intellectual Property Department in your country or send inquiries, in writing, to:
Intellectual Property Licensing
Legal and Intellectual Property Law
IBM Japan Ltd.
19-21, Nihonbashi-Hakozakicho, Chuo-ku
Tokyo 103-8510, Japan
INTERNATIONAL BUSINESS MACHINES CORPORATION PROVIDES THIS PUBLICATION "AS IS"
WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS ORIMPLIED, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
PARTICULAR PURPOSE. Some jurisdictions do not allow disclaimer of express or implied
warranties in certain transactions, therefore, this statement may not apply to you.
This information could include technical inaccuracies or typographical errors. Changes are
periodically made to the information herein; these changes will be incorporated in new editions
of the publication. IBM may make improvements and/or changes in the product(s) and/or the
program(s) described in this publication at any time without notice.
Any references in this information to non-IBM websites are provided for convenience only and do
not in any manner serve as an endorsement of those websites. The materials at those websites
are not part of the materials for this IBM product and use of those websites is at your own risk.
© Copyright International Business Machines Corporation2016 29

Petascale Data Protection
IBM may use or distribute any of the information you provide in any way it believes appropriate
without incurring any obligation to you.
Licensees of this program who wish to have information about it for the purpose of enabling: (i)
the exchange of information between independently created programs and other programs
(including this one) and (ii) the mutual use of the information which has been exchanged, should
contact:
IBM Director of Licensing
IBM Corporation
North Castle Drive, MD-NC119
Armonk, NY 10504-1785
US
Such information may be available, subject to appropriate terms and conditions, includingin
some cases, payment of a fee.
The licensed program described in this document and all licensed material available for it are
provided by IBM under terms of the IBM Customer Agreement, IBM International Program
License Agreement or any equivalent agreement between us.
Information concerning non-IBM products was obtained from the suppliers of those products,
their published announcements or other publicly available sources. IBM has not tested those
products and cannot confirm the accuracy of performance, compatibility or any other claims
related to non-IBMproducts. Questions on the capabilities of non-IBM products should be
addressed to the suppliers of those products.
This information is for planning purposes only. The information herein is subject tochange before
the products described become available.
This information contains examples of data and reports used in daily business operations. To
illustrate them as completely as possible, the examples include the names of individuals,
companies, brands, and products. All of these names are fictitious and any similarity to actual
people or business enterprises is entirely coincidental.
COPYRIGHT LICENSE:
This information contains sample application programs in source language, which illustrate
programming techniques on various operating platforms. You may copy, modify, and distribute
these sample programs in any form without payment to IBM, for the purposes of developing,
using, marketing or distributing application programs conforming to the application programming
interface for the operating platform for which the sample programs are written. These examples
have not been thoroughly tested under all conditions. IBM, therefore, cannot guarantee or imply
reliability, serviceability, or function of these programs. The sample programs are provided "AS
IS", without warranty of any kind. IBM shall not be liable for any damages arising out of your use
of the sample programs.
© Copyright International Business Machines Corporation2016 30

Petascale Data Protection
Trademarks
IBM, the IBM logo, and ibm.com are trademarks or registered trademarks ofInternational
Business Machines Corp., registered in many jurisdictions worldwide. Other product and service
names might be trademarks of IBM or other companies. A current list of IBM trademarks is
available on the web at "Copyright and trademark information" at
www.ibm.com/legal/copytrade.shtml.
Linux is a registered trademark of Linus Torvalds in the United States, other countries, or both.
UNIX is a registered trademark of The Open Group in the United States and other countries.
© Copyright International Business Machines Corporation2016 31
