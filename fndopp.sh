#!/bin/bash
########################################################################################################
# Name          : ebs-checks-fndopp.sh
# Author        : Sagar Fale
# Date          : 29/12/2022
#
# Description:  - This script will check if DB is up and running
#
# Usage         : ebs-checks-fndopp.sh - v2
#
#
# Modifications :
#
# When         Who               What
# ==========   ===========    ================================================================
# 29/12/2022   Sagar Fale     Initial draft version
# 31/12/2022   Sagar Fale     adding db down logic
# 12/01/2022   Sagar Fale     addition of multiple FNDOPP logic
########################################################################################################

script_base=/home/applmgr/scripts
HOSTNAME=`hostname`
mkdir -p /home/applmgr/scripts_itc/log
HOST=`hostname | awk -F\. '{print $1}'`
tlog=`date "+fndopp_check-%d%b%Y_%H%M".log`
script_base=/home/applmgr/scripts_itc
logfile=`echo /home/applmgr/scripts_itc/log/${tlog}`


### specify the apps password in hidden for secirity purposes
apps_pass=`cat ${script_base}/.appspass`
. /XXXXXX/applmgr/EBSapps.env RUN

## specify your email here
MAIL_LIST=xxxx@gmail.com

sendemail_notify()
   {
      (
         echo "Subject: ${tempvalue}"
         echo "TO: $MAIL_LIST"
         echo "FROM: prod@mgrc.com"
         echo "MIME-Version: 1.0"
         echo "Content-Type: text/html"
         echo "Content-Disposition: inline"
      )  | /usr/sbin/sendmail $MAIL_LIST
}

sendemail_notify_t()
   {
      (
         echo "Subject: ${tempvalue}"
         echo "TO: $MAIL_LIST"
         echo "FROM: prod@mgrc.com"
         echo "MIME-Version: 1.0"
         echo "Content-Type: text/html"
         echo "Content-Disposition: inline"
         cat ${attachement_name}
      )  | /usr/sbin/sendmail $MAIL_LIST -t
}


fndopp_check()
{

target_proc=`sqlplus -s apps/${apps_pass} <<EOF
   set feedback off pause off pagesize 0 verify off linesize 500 term off
   set pages 80
   set head off
   set line 120
   set echo off
   select TARGET_PROCESSES from fnd_concurrent_queues where CONCURRENT_QUEUE_ID= (select CONCURRENT_QUEUE_ID from FND_CONCURRENT_QUEUES where CONCURRENT_QUEUE_NAME='FNDCPOPP'); 
EOF
` 

sqlplus -s apps/${apps_pass} <<EOF > ${script_base}/pid.data
   set feedback off pause off pagesize 0 verify off linesize 500 term off
   set pages 80
   set head off
   set line 120
   set echo off
   select OS_PROCESS_ID  from  fnd_concurrent_processes where process_status_code='A' and  CONCURRENT_QUEUE_ID=(select CONCURRENT_QUEUE_ID from  FND_CONCURRENT_QUEUES where  CONCURRENT_QUEUE_NAME='FNDCPOPP');
   exit
EOF

sed -i  '/\S/!d' ${script_base}/pid.data

count=0
for i in `cat ${script_base}/pid.data`
do
ps -ef |grep  DCLIENT_PROCESSID=$i | grep -v grep
if [ $? -eq 0 ] ; then 
echo "Process is running."
count=$((${count}+1)) 
else 
echo "invalid process"
fi 
echo "Count is $count"
done	
echo "main count is : $count"

if [ ${target_proc} -eq ${count} ]; then 
   echo "no need of any sending email"  >> ${logfile}
   tempvalue="FNDOPP RUNNING on $TWO_TASK : $HOSTNAME" >> ${logfile}
else
   sqlplus -s apps/${apps_pass} <<EOF
               set feedback off pause off pagesize 0 verify off linesize 500 term off
               set pages 80
               set head on
               set line 120
               set echo off
               set pagesize 50000
               set markup html on
               spool fndopp.html
               select to_char(PROCESS_START_DATE,'dd-mm-yy:hh24:mi:ss') START_DATE ,CONCURRENT_PROCESS_ID,  
              decode(PROCESS_STATUS_CODE, 
            'A','Active',
            'C','Connecting',
            'D','Deactiviating',
            'G','Awaiting Discovery',
            'K','Terminated',
            'M','Migrating',
            'P','Suspended',
            'R','Running',
            'S','Deactivated',
            'T','Terminating',
            'U','Unreachable',
            'Z' ,'Initializing') STATUS,gsm_internal_info from  fnd_concurrent_processes where CONCURRENT_QUEUE_ID=(select  CONCURRENT_QUEUE_ID from  FND_CONCURRENT_QUEUES where  CONCURRENT_QUEUE_NAME='FNDCPOPP') order by PROCESS_START_DATE  desc;
            set markup html off
            spool off
            exit
EOF
tempvalue="FNDOPP NOT RUNNING on $TWO_TASK : $HOSTNAME"
attachement_name='fndopp.html'
sendemail_notify_t ${attachement_name}
fi 
}


   output3=`sqlplus -s apps/${apps_pass} <<EOF
   set feedback off pause off pagesize 0 heading off verify off linesize 500 term off
   select open_mode  from v\\$DATABASE;
   exit
EOF
`
   if [ "$output3" = "READ WRITE" ] 
   then 
   date  >> ${logfile}
   echo "Calling function to check FNDOPP.." >> ${logfile}
   fndopp_check
   else
   date  >> ${logfile}
   echo "DB is not up and running" >> ${logfile}
   tempvalue="DB NOT RUNNING on $TWO_TASK : $HOSTNAME"
   sendemail_notify
   fi
