#!/bin/ksh
#           report of the Solaris cluster in html format.
#
#Directories Used/Created
# /tmp/audit_tmp/audit_report - html output file and log file store
#   /var/tmp/audit_tmp - directory to store temporary files
#                         which is cleared at the start of a run
# Sections and files are:
# Hardware Information  Variables       master_hw slave_hw master_mem slave_mem master_ser slave_ser master_ker slave_ker
# NIC Cards             File(s)         master_ethtool.tmp slave_ethtool.tmp
# Network IP            File(s)         net_ip.tmp
# Network Link          File(s)         net_link.tmp
### Definitions ###
#Make directory, set up log file, date, check on master server
# Working directory is /var/tmp/audit_tmp
# Report and log file directory is /home/support/audit_report


mkdir -p /var/tmp/audit_tmp
mkdir -p /tmp/audit_tmp/audit_report
rm -rf /var/tmp/audit_tmp/*
topdir=/var/tmp/audit_tmp
_date=`date '+%Y-%m-%d %H:%M:%S'`
_dat=`date '+%Y%m%d%H%M%S'`
log_file="/tmp/audit_tmp/audit_report/audit_log_${_dat}"
_bgcolor="#FFFFFF"
#_bgcolor="#E7E9EA"
_bbgcolor="#E7E9EA"
_errcolor="#FA0000"
_warncolor="#EED81A"
_fcolor="#002561"
#_fcolor="#000000"
_fonterr="#FFFFFF"
_fonthead="#FFFFFF"
_headcolor="#002561"
_errcnt=0
_warncnt=0
_ncolcnt=0
LC_ALL="C"
export LC_ALL
RUNONCLUSTER=TRUE
CLUSTERILL=FALSE


### Function: abort_script ###
#
#   This is called and the script is aborted if a
#   serious error is encountered during runtime
#
# Arguments:
#       $1 - Error message
# Return Values:
#       none
abort_script()
{
if [ "$1" ]; then
    _err_msg_=$1
else
    _err_msg_="ERROR: Script aborted....\n"
fi
echo  "\t\E[1;30;31m[ERROR]    ${_err_msg_} `tput sgr0`" | tee -a $log_file
echo  "\t\E[1;30;31m[ERROR]    Review log file $log_file and temp directory ${topdir} `tput sgr0`" | tee -a $log_file
echo  "\t\E[1;30;31m[ERROR]    Aborting script `tput sgr0`" | tee -a $log_file
exit 1
}

### Function: warn_script ###
#
#   This is called when one section of infomation
#   can't be retrieved
#
# Arguments:
#       $1 - Section name
# Return Values:
#       none
warn_script()
{
_warn_msg_=$1
echo  "\n\t\E[1;30;33m[Warning]  Issue collecting data for '${_warn_msg_}' Section `tput sgr0`" | tee -a $log_file
echo  "\t\E[1;30;33m[Warning]  This data will not be included in the output report `tput sgr0`" | tee -a $log_file
echo  "\t\E[1;30;33m[Warning]  Review the log file $log_file for more details `tput sgr0`" | tee -a $log_file
}

### Function: err_table ###
#
#   This is called to print an error table on the
#   report for a section where the info could
#   not be retrieved
#
# Arguments:
#       $1 - Section name
# Return Values:
#       none
err_table()
{
_err_tab_msg_=$1
print "<table border=2  style='color:${_fonthead}' bgcolor=${_headcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}
printf "<tr><td align='center'>${_err_tab_msg_}</td></tr>\n" >> ${OUTPUT_FILE}
print "</table>" >> ${OUTPUT_FILE}
print "<table border=2  bgcolor="#E5B67C" width=\"100%\" >\n" >> ${OUTPUT_FILE}
printf "<tr><td align='center'>Information for ${_err_tab_msg_} could not be retrieved</td></tr>\n"  >> ${OUTPUT_FILE}
print "</table>" >> ${OUTPUT_FILE}
print "<br><B>"  >> ${OUTPUT_FILE}
(( _ncolcnt++ ))
}

usage() {

${CAT} << EOF

Usage:  ${SCRIPTNAME} [-h]
                [-l ]

Solaris Audit Script

-h      Print help.

-l      Run Audit on this node only instead of whole cluster (default),
            but this must be the master node.

EOF

        return 0

}


cd ${topdir}
echo > $log_file
echo  "\t\E[1;30;32m[INFO]     Running Solaris Audit Script (Revision ${Revision}) at `date '+%Y-%m-%d %H:%M:%S'` `tput sgr0`" | tee -a $log_file
echo  ""

while getopts "hs" opt; do
        case ${opt} in
                h)      # Print help and exit OK
                        usage
                        exit 0
                        ;;
                ?)      # Hint to run usage
                        printf "Run \"${SCRIPTNAME} -h\" for help\n"
                        exit 1
                        ;;
        esac

done

#Determine servers
echo  "\nDetermine servers Section" >> $log_file
echo  "\nChecking the cluster has Master and slave config or not " >> $log_file
CVM_O=`vxlicrep -e | grep -i CVM_full | awk '{print ($3)}'`
if [ $CVM_O == "Enabled" ];then
echo  "RUNNING: Master=`vxdctl -c mode | grep -i "master"`2>> $log_file" >> $log_file
     Vxdctl=`vxdctl -c mode | grep -i master` >> $log_file
         if [ $Vxdctl -ne o ];then
        Master=`hostname` >> $log_file
                Slave=`hastatus -sum | grep -v $Master | awk '{ print ($2)}' | head -5 | tail -1` >> $log_file
      else
          Slave=`hostname` >> $log_file
          Master=`hastatus -sum | grep -v $Slave | awk '{ print ($2)}' | head -5 | tail -1` >> $log_file
          fi
   else
   Master=` hasys -list |sed -e "s/.*:\(.*\).*/\1/"  |  head -1` >> $log_file
   Slave=`hasys -list |sed -e "s/.*:\(.*\).*/\1/"  |  head -2 | tail -1` >> $log_file
 fi

echo  "RUNNING: hastatus -sum > ${topdir}/vcs_sum.tmp" >> $log_file
/opt/VRTS/bin/hastatus -sum > ${topdir}/vcs_sum.tmp
if [ $? -ne 0 ]; then
        abort_script "Failed to run hastatus"
fi


# OK Cluster or Single Node Run
_nodeCnt=`grep "^A" ${topdir}/vcs_sum.tmp | wc -l`
if [ ${_nodeCnt} == 1 ]; then
        RUNONCLUSTER=FALSE
else
        RUNONCLUSTER=TRUE
fi

if [ "$RUNONCLUSTER" = TRUE ]; then
        _runNodes=`grep "^A" ${topdir}/vcs_sum.tmp | grep RUNNING | wc -l`
        if [ ${_runNodes} != 2 ]; then
                RUNONCLUSTER=FALSE
                CLUSTERILL=TRUE
                echo "hastatus System State" > ${topdir}/cluster_ill.tmp
                echo "------------------------" >> ${topdir}/cluster_ill.tmp
                /opt/VRTS/bin/hastatus -sum | grep "^A" | awk '{ print $2 "  STATE=  "$3 }' >> ${topdir}/cluster_ill.tmp
                echo "========================" >> ${topdir}/cluster_ill.tmp
                echo "vxclustadm nidmap output" >> ${topdir}/cluster_ill.tmp
                echo "------------------------" >> ${topdir}/cluster_ill.tmp
                /opt/VRTS/bin/vxclustadm nidmap | awk '{ print $1 "  STATE=  "$4 $5 $6  }' | tail -2 >> ${topdir}/cluster_ill.tmp
                echo "========================" >> ${topdir}/cluster_ill.tmp
        fi
fi

### Data Collection ###


# Name
echo  "\nName Section" >> $log_file
echo  "RUNNING:haclus -display|grep ClusterName | awk '{print ($2)}' > ${topdir}/cluster_name.tmp >> $log_file" >> $log_file
haclus -display|grep ClusterName | awk '{print ($2)}' > ${topdir}/cluster_name.tmp 2>> $log_file
if [ $? -ne 0 ]; then
        abort_script "Unable to determine Cluster name"
fi

# Version
echo  "\nVersion Section" >> $log_file
echo "RUNNING:haclus -value EngineVersion >${topdir}/version.tmp 2>> $log_file" >> $log_file
haclus -value EngineVersion >${topdir}/version.tmp 2>> $log_file
if [ $? -eq 0 ]; then
        _inc_version="Y"
else
        warn_script "Version"
        _inc_version="N"
fi
# Hardware
_inc_hw="Y"
echo  "\nHardware Section" >> $log_file
echo  "RUNNING: master_hw=\ prtdiag | grep "System Configuration:" | sed -e "s/.*:\(.*\).*/\1/" >> $log_file 2>&1" >> $log_file
master_hw=`prtdiag | grep "System Configuration:" | sed -e "s/.*:\(.*\).*/\1/"`>> $log_file 2>&1
if [ $? -ne 0  ]; then
        master_hw="Master model not available"
fi
echo  "RUNNING: master_mem=`prtconf | grep -i "Memory size:" |awk '{print($3)}'` >> $log_file 2>&1" >> $log_file
master_mem=`prtconf | grep -i "Memory size:" |awk '{print($3)}'` >> $log_file 2>&1
if [ $? -ne 0  ]; then
        master_mem="Master memory not available"
fi
master_ker=`uname -r`  >> $log_file 2>&1
if [ $? -ne 0  ]; then
        master_ker="Master kernel version not available"
fi

if [ "$RUNONCLUSTER" = TRUE ]; then

                echo  "RUNNING: slave_hw=`ssh root@$Slave prtdiag | grep "System Configuration:" | sed -e "s/.*:\(.*\).*/\1/"` $log_file 2>&1 " >> $log_file          
                slave_hw=`ssh root@$Slave prtdiag | grep "System Configuration:" | sed -e "s/.*:\(.*\).*/\1/" ` >> $log_file 2>&1
                 if [ $? -ne 0  ]; then
                slave_hw="Slave model not available"
        fi

                 echo  "RUNNING: slave_mem=`ssh root@$Slave prtconf | grep -i "Memory size:" |awk '{print($3)}' `>> $log_file 2>&1"   >> $log_file
                 slave_mem=`ssh root@$Slave prtconf | grep -i "Memory size:" |awk '{print($3)}'` >> $log_file 2>&1
                 if [ $? -ne 0  ]; then
                slave_mem="Slave memory not available"
        fi

                slave_ker=`ssh root@$Slave uname -r`  >> $log_file 2>&1
        if [ $? -ne 0  ]; then
        slave_ker="Slave kernel version not available"
        fi
else
        slave_hw=""
        slave_mem=""
        slave_ker=""
fi

#NIC Card Firmware details
_inc_netint="Y"

#For HP Blades we will have Bnxe NICS so checking apart from Bnxe any other NIC is present.

bnx_c=`dladm show-phys -L | awk '{print ($2)}' | grep -v bnx | wc -l`
        if [$bnx_c -eq 0 ] ; then
           echo -e "unavailable,unavailable,unavailable,unavailable" >> ${topdir}/master_ethtool.tmp
        else
            echo  `kstat -m bnxe -i 0 -n stats | egrep '(version |versionBC)'` >> ${topdir}/master_ethtool.tmp
        fi

if [ "$RUNONCLUSTER" = TRUE ]; then
        ssh root@$Slave bnx_c=`dladm show-phys -L | awk '{print ($2)}' | grep -v bnx | wc -l`
        if [ $? -ne 0  ]; then
                        echo -e "unavailable,unavailable,unavailable,unavailable" >> ${topdir}/slave_ethtool.tmp
                else
                                echo  `kstat -m bnxe -i 0 -n stats | egrep '(version |versionBC)'` >> ${topdir}/master_ethtool.tmp
        fi
fi

# Services

#Number of services running as online in the server
echo  " RUNNING : `svcs -a | grep -i online | wc -l` > ${topdir}/ser_online.tmp 2 >> $log_file " >> $log_file
svcs -a | grep -i online | wc -l > ${topdir}/ser_online.tmp 2>> $log_file
if [ $? -eq 0 ]; then
        _inc_nfs="Y"
else
        warn_script "Services"
        _inc_nfs="N"

echo  " RUNNING : svcs -a | grep -i vcs:default | awk '{print ($1)}' > ${topdir}/vcs_online_stat.tmp 2  >> $log_file " >> $log_file
svcs -a | grep -i vcs:default | awk '{print ($1)}' > ${topdir}/vcs_online_stat.tmp 2>> $log_file
fi
# VCS Services
_inc_vser="Y"
_grp_used=`/opt/VRTS/bin/hagrp -list | grep ${Master} | wc -l`
_res_used=`/opt/VRTS/bin/hares -list | grep ${Master} | wc -l`
if [ "$RUNONCLUSTER" = TRUE ]; then
         for xx in BkupLan PrivLan PubLan StorLan
         do
                        _mas=`grep ${Master} ${topdir}/vcs_sum.tmp | grep "^B" | grep -w ${xx} | awk '{print $NF}'`
                _slv=`grep ${Slave} ${topdir}/vcs_sum.tmp | grep "^B" | grep -w ${xx} | awk '{print $NF}'`
                if [ "${_mas}" == "ONLINE" -a "${_slv}" == "ONLINE" ]; then
                        _xcolor=${_bgcolor}
                        _xfont=${_fcolor}
                else
                        _xcolor=${_errcolor}
                        _xfont=${_fonterr}
                        (( _errcnt++ ))
                fi
                echo  "${xx},${_mas},${_slv},${_xcolor},${_xfont}" >> ${topdir}/vcs_ser_both.tmp
        done
fi

# Fencing
if [ "$RUNONCLUSTER" = TRUE ]; then
        echo  "RUNNING: cat /etc/vxfenmode | grep  "vxfen_mode=" | awk '{print ($1)}' > ${topdir}/fen_stat.tmp 2>> $log_file" >> $log_file
        cat /etc/vxfenmode | grep  "vxfen_mode=" | awk '{print ($1)}' > ${topdir}/fen_stat.tmp 2>> $log_file
        if [ $? -eq 0 ]; then
                _inc_fen="Y"
        else
                warn_script "Fencing"
                _inc_fen="N"
        fi
fi


# Problem VCS Resources
echo  "RUNNING: grep FAULTED ${topdir}/vcs_sum.tmp > ${topdir}/vcs_prob.tmp 2>> $log_file" >> $log_file
if [ "$RUNONCLUSTER" = TRUE ]; then
        grep "^B" ${topdir}/vcs_sum.tmp | egrep -v "ONLINE|OFFLINE" > ${topdir}/vcs_prob.tmp 2>> $log_file
else
        grep "^B" ${topdir}/vcs_sum.tmp | egrep -v "ONLINE|OFFLINE" > ${topdir}/vcs_prob.tmp 2>> $log_file
fi
_inc_vfail="Y"




# Gabconfig
echo -e "RUNNING: gabconfig -a > ${topdir}/gabconf.tmp 2>> $log_file" >> $log_file
gabconfig -a > ${topdir}/gabconf.tmp 2>> $log_file
if [ $? -eq 0 ]; then
        _inc_gab="Y"
else
        warn_script "Gabconfig"
        _inc_gab="N"
fi



### Report Creattion ###

SCName=`cat ${topdir}/cluster_name.tmp`

OUTPUT_FILE=/tmp/audit_tmp/audit_report/SC_Audit_${SCName}_${_dat}.html

print "<html><head><title>${SCNameame} Cluster Audit / Health Check</title>\n"  > ${OUTPUT_FILE}
print "</head>\n" >> ${OUTPUT_FILE}
echo  "<body bgcolor=${_bbgcolor} style=\"font-family:arial\">" >> ${OUTPUT_FILE}


print "<table border=0  bgcolor=${_fonthead} width=\"100%\" >\n" >> ${OUTPUT_FILE}
echo "<tr><td align='center'>  ${SCName} Audit Report ></td></tr>"  >> ${OUTPUT_FILE}
print "</table>" >> ${OUTPUT_FILE}
print "<br><B>"  >> ${OUTPUT_FILE}


# Name
print "<table border=0  bgcolor=${_fonthead} width=\"100%\" >\n" >> ${OUTPUT_FILE}
printf "<tr><td style=\"font-family:arial;color:midnightblue;font-size:40px;text-align:center;font-weight:bold;\"><a href='#link_inf' style='color:midnightblue'>${SCName}</td></tr>\n" >> ${OUTPUT_FILE}
print "</table>" >> ${OUTPUT_FILE}
print "<br><B>"  >> ${OUTPUT_FILE}


# Summary
print "<table border=0  bgcolor=${_headcolor} style='color:${_fonthead}' width=\"100%\" >\n" >> ${OUTPUT_FILE}
echo  "<tr><td align='center'><a href='#link_aud_sum' style='color:${_fonthead}'>Audit Summary</a></td></tr>" >> ${OUTPUT_FILE}
print "</table>" >> ${OUTPUT_FILE}
print "<table border=0  bgcolor=${_bgcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}
echo  "<tr><td style='color:${_fonterr}' bgcolor=${_errcolor} align='center'>Errors Reported<td style='color:${_fonterr}' bgcolor=${_errcolor} align='center'>QXerrQX</td>" >> ${OUTPUT_FILE}
echo  "<td style='color:${_fcolor}' bgcolor=${_warncolor} align='center'>Warnings Reported<td style='color:${_fcolor}' bgcolor=${_warncolor} align='center'>QXwarnQX</td>" >> ${OUTPUT_FILE}
echo  "<td style='color:${_fcolor}' bgcolor='#E5B67C' align='center'>Information Not Collected<td style='color:${_fcolor}' bgcolor='#E5B67C' align='center'>QXncolQX</td></tr>"  >> ${OUTPUT_FILE}
print "</table>" >> ${OUTPUT_FILE}
print "<br><B>"  >> ${OUTPUT_FILE}


# Version
if [ "${_inc_version}" == "Y" ]; then
        print "<table border=0  bgcolor=${_headcolor} style='color:${_fonthead}' width=\"100%\" >\n" >> ${OUTPUT_FILE}
        printf "<tr><td align='center'><a href='#link_ver' style='color:${_fonthead}'>Version</td></tr>\n" >> ${OUTPUT_FILE}
        print "</table>" >> ${OUTPUT_FILE}
        print "<table border=0  bgcolor=${_bgcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}

        exec 3< ${topdir}/version.tmp
        read line <&3
        printf "<tr style='color:${_font}' bgcolor=${_color}><td align='center'>${line}</td></tr>\n"  >> ${OUTPUT_FILE}
        _numline=`cat ${topdir}/version.tmp | wc -l`
        if [ "${_numline}" -gt "1" ]; then
                echo  "<tr bgcolor=${_headcolor} style='color:${_fonthead}'><td align='center'>Version History</td></tr>"  >> ${OUTPUT_FILE}
                while read line <&3
                do
                        printf "<tr style='color:${_font}' bgcolor=${_color}><td align='center'>${line}</td></tr>\n"  >> ${OUTPUT_FILE}
                done
        fi
        print "</table>" >> ${OUTPUT_FILE}
        exec 3>&-
        IFS=" "
else
        err_table "Version"
fi

        print "<br><B>"  >> ${OUTPUT_FILE}


# Cluster State
if [ "$CLUSTERILL" = TRUE ]; then
        print "<table border=0  bgcolor=${_headcolor} style='color:${_fonthead}' width=\"100%\" >\n" >> ${OUTPUT_FILE}
        printf "<tr><td align='center'><a href='#link_ver' style='color:${_fonthead}'>Cluster In Non Expected State</td></tr>\n" >> ${OUTPUT_FILE}
        print "</table>" >> ${OUTPUT_FILE}
        print "<table border=0  bgcolor=${_bgcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}
        _color=${_errcolor}
        _font=${_fonterr}
        (( _errcnt++ ))
        exec 3< ${topdir}/cluster_ill.tmp
        while read line <&3
        do
                printf "<tr style='color:${_font}' bgcolor=${_color}><td align='center'>${line}</td></tr>\n"  >> ${OUTPUT_FILE}
        done
        print "</table>" >> ${OUTPUT_FILE}
        print "<br><B>"  >> ${OUTPUT_FILE}
        exec 3>&-
        IFS=" "
fi

# Hardware Information
if [ "${_inc_hw}" == "Y" ]; then
        print "<table border=0 bgcolor=${_headcolor} style='color:${_fonthead}' width=\"100%\" >\n" >> ${OUTPUT_FILE}
        printf "<tr><td align='center'><a href='#link_hwi' style='color:${_fonthead}'>Hardware Information</td></tr>\n" ${Master}  >> ${OUTPUT_FILE}
        print "</table>" >> ${OUTPUT_FILE}

        print "<table border=0 bgcolor=${_bgcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}
       printf "<tr style='color:${_fonthead}' bgcolor=${_headcolor}><td align='center'>Node/HW</td><td align='center'>${Master}</td><td align='center'>${Slave}</td></tr>\n"  >> ${OUTPUT_FILE}
        if [ "$RUNONCLUSTER" = TRUE ]; then
                if [ "${master_hw}" != "${slave_hw}" ]; then
                        _color=${_errcolor}
                        _font=${_fonterr}
                        (( _errcnt++ ))
                else
                        _color=${_bgcolor}
                        _font=${_fcolor}
                fi
        else
                _color=${_bgcolor}
                _font=${_fcolor}
        fi
        echo  "<tr style='color:${_font}' bgcolor=${_color}><td align='center'>Model</td><td align='center'>${master_hw}</td><td align='center'>${slave_hw}</td></tr>"  >> ${OUTPUT_FILE}
        if [ "$RUNONCLUSTER" = TRUE ]; then
                if [ "${master_mem}" != "${slave_mem}" ]; then
                        _color=${_errcolor}
                        _font=${_fonterr}
                        (( _errcnt++ ))
                else
                        _color=${_bgcolor}
                        _font=${_fcolor}
                fi
        else
                _color=${_bgcolor}
                _font=${_fcolor}
        fi
        echo  "<tr style='color:${_font}' bgcolor=${_color}><td align='center'>Memory</td><td align='center'>${master_mem}</td><td align='center'>${slave_mem}</td></tr>"  >> ${OUTPUT_FILE}
        _color=${_bgcolor}
        _font=${_fcolor}
        if [ "$RUNONCLUSTER" = TRUE ]; then
                if [ "${master_ker}" != "${slave_ker}" ]; then
                        _color=${_errcolor}
                        _font=${_fonterr}
                        (( _errcnt++ ))
                else
                        _color=${_bgcolor}
                        _font=${_fcolor}
                fi
        else
                _color=${_bgcolor}
                _font=${_fcolor}
        fi
        echo  "<tr style='color:${_font}' bgcolor=${_color}><td align='center'>Kernel Version</td><td align='center'>${master_ker}</td><td align='center'>${slave_ker}</td></tr>"  >> ${OUTPUT_FILE}
        print "</table>" >> ${OUTPUT_FILE}
else
        err_table "Hardware Information"
fi

        print "<br><B>"  >> ${OUTPUT_FILE}

# VCS Services
if [ "${_inc_vser}" == "Y" ]; then
        IFS=","
        print "<table border=0  style='color:${_fonthead}' bgcolor=${_headcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}
        printf "<tr><td align='center'><a href='#link_csv' style='color:${_fonthead}'>Core  VCS Services     (Groups used=${_grp_used} / Resources used=${_res_used})</td></tr>\n" >> ${OUTPUT_FILE}
        print "</table>" >> ${OUTPUT_FILE}
        print "<table border=0  bgcolor=${_bgcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}

        echo  "<tr style='color:${_fonthead}' bgcolor=${_headcolor}><td>Service</td><td>${Master}</td><td>${Slave}</td></tr>" >> ${OUTPUT_FILE}
        exec 3< ${topdir}/vcs_ser_both.tmp
        while read _ser _mas _slv _col _fnt <&3
        do
                echo  "<tr style='color:${_fnt}' bgcolor=${_col}><td>${_ser}</td><td>${_mas}</td><td>${_slv}</td></tr>" >> ${OUTPUT_FILE}
        done

        print "</table>" >> ${OUTPUT_FILE}
        exec 3>&-
        IFS=" "
else
        err_table "VCS Services"
fi

print "<br><B>"  >> ${OUTPUT_FILE}

# Fencing
if [ "$RUNONCLUSTER" = TRUE ]; then
        if [ "${_inc_fen}" == "Y" ]; then
                print "<table border=0  style='color:${_fonthead}' bgcolor=${_headcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}
                printf "<tr><td align='center'><a href='#link_fen' style='color:${_fonthead}'>Fencing</td></tr>\n" >> ${OUTPUT_FILE}
                print "</table>" >> ${OUTPUT_FILE}
                print "<table border=0  bgcolor=${_bgcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}
				cat ${topdir}/fen_stat.tmp  > ${topdir}/fen_statx.tmp ; 
                                 cp ${topdir}/fen_statx.tmp ${topdir}/fen_stat.tmp ;
				_fen_stat=`cat ${topdir}/fen_statx.tmp`
				if [ "$RUNONCLUSTER" = TRUE ]; then
                        if [ ${_fen_stat} == "vxfen_mode=scsi3" ]; then
                                _color=${_bgcolor}
                                _font=${_fcolor}
								echo  "<tr style='color:${_font}' bgcolor=${_color}><td>Status</td><td>${_fen_stat}</td></tr>\n"  >> ${OUTPUT_FILE}
                        else
                                _color=${_errcolor}
                                _font=${_fonterr}
                                (( _errcnt++ ))
                        fi
                else
                        _color=${_bgcolor}
                        _font=${_fcolor}
                fi
				echo  "<tr style='color:${_font}' bgcolor=${_color}><td>Status</td><td>${_fen_stat}</td></tr>\n"  >> ${OUTPUT_FILE}
				print "</table>" >> ${OUTPUT_FILE}
		else
                err_table "Fencing"
        fi

        print "<br><B>"  >> ${OUTPUT_FILE}

fi


# Problem VCS Resources
if [ "${_inc_vfail}" == "Y" ]; then
        print "<table border=0  style='color:${_fonthead}' bgcolor=${_headcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}
        printf "<tr><td align='center'><a href='#link_vcs' style='color:${_fonthead}'>Other VCS Resource Issues</td></tr>\n" >> ${OUTPUT_FILE}
        print "</table>" >> ${OUTPUT_FILE}
        print "<table border=0  bgcolor=${_bgcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}

        _numline=`wc -l ${topdir}/vcs_prob.tmp`
        _nmline=${_numline%% *}
        if [ "${_nmline}" == "0" ]; then
                printf "<tr style='color:${_fcolor}' bgcolor=${_bgcolor}><td align='center'>No Other VCS Resource Issues</td></tr>\n"  >> ${OUTPUT_FILE}
        else
                printf "<tr style='color:${_fonthead}' bgcolor=${_headcolor}><td>Group</td><td>System</td><td>Probed</td><td>AutoDisabled</td><td>State</td></tr>\n"  >> ${OUTPUT_FILE}
                exec 3< ${topdir}/vcs_prob.tmp
                while read tag group sys probe autod state <&3
                do
                printf "<tr style='color:${_fonterr}' bgcolor=${_errcolor}><td>${group}</td><td>${sys}</td><td>${probe}</td><td>${autod}</td><td>${state}</td></tr>\n"  >> ${OUTPUT_FILE}
                (( _errcnt++ ))
                done
                exec 3>&-
                IFS=" "
        fi
        print "</table>" >> ${OUTPUT_FILE}
else
        err_table "Other VCS Resource Issues"
fi

print "<br><B>"  >> ${OUTPUT_FILE}


# Gabconfig
if [ "${_inc_gab}" == "Y" ]; then
        print "<table border=0  style='color:${_fonthead}' bgcolor=${_headcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}
        printf "<tr><td align='center'><a href='#link_gab' style='color:${_fonthead}'>Gabconfig</td></tr>\n" >> ${OUTPUT_FILE}
        print "</table>" >> ${OUTPUT_FILE}
        print "<table border=0  bgcolor=${_bgcolor} width=\"100%\" >\n" >> ${OUTPUT_FILE}

        exec 3< ${topdir}/gabconf.tmp
        read line <&3
        printf "<tr style='color:${_fonthead}' bgcolor=${_headcolor}><td align='center'>${line}</td></tr>\n"  >> ${OUTPUT_FILE}
        read line <&3

        while read line <&3
        do
                if [ "$RUNONCLUSTER" = TRUE ]; then
                        if [[ $line == *01 ]]; then
                                _color=${_bgcolor}
                                _font=${_fcolor}
                        else
                                _color=${_errcolor}
                                _font=${_fonterr}
                                (( _errcnt++ ))
                        fi
                else
                        _color=${_bgcolor}
                        _font=${_fcolor}
                fi
                echo  "<tr style='color:${_font}' bgcolor=${_color}><td align='center'>${line}</td></tr>"  >> ${OUTPUT_FILE}
        done
        print "</table>" >> ${OUTPUT_FILE}
        exec 3>&-
        IFS=" "
else
        err_table "Gabconfig"
fi

print "<br><B>"  >> ${OUTPUT_FILE}

# Report End
print "<br><B><font size="2"> Audit Script Revision ${Revision} - Report generated on ${_date}" >> ${OUTPUT_FILE}
print "</body></html>" >> ${OUTPUT_FILE}

cat ${OUTPUT_FILE} | sed "s/QXerrQX/${_errcnt}/" | sed "s/QXwarnQX/${_warncnt}/" | sed "s/QXncolQX/${_ncolcnt}/" > ${topdir}/rep.tmp
mv ${topdir}/rep.tmp ${OUTPUT_FILE}



echo  "\t\E[1;30;32m[INFO] Report generated to ${OUTPUT_FILE} `tput sgr0`" | tee -a $log_file
echo  ""


_exit_code=0
if [ "${_errcnt}" -gt 0 ]; then
        _exit_code=1
fi
if [ "${_warncnt}" -gt 0 ]; then
        _exit_code=3
fi
if [ "${_errcnt}" -gt 0 -a "${_warncnt}" -gt 0 ]; then
        _exit_code=2
fi



