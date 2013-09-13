#!/bin/bash

#Copyright (c) 2013 Dimosthenis Pediaditakis <dimosthenis.pediaditakis@cl.cam.ac.uk>
# 
#Permission to use, copy, modify, and distribute this software for any
#purpose with or without fee is hereby granted, provided that the above
#copyright notice and this permission notice appear in all copies.
#
#THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
#WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
#MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
#ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
#WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
#ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
#OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.


#set -x 

MY_SR_UUID='4d0bcc33-b22b-8424-800d-5f69fbbad3fe'
MY_BRIDGE_IFACE='xenbr1'
SERVER_VM_NAME='mirageIperfServer'
SERVER_KERN_NAME='./xen/iperfServer.xen'
CLIENT_VM_NAME="mirageIperfClient"
CLIENT_KERN_NAME='./xen/iperfClient.xen'
SWITCH_VM_NAME="mirageSwitch"
SWITCH_KERN_NAME='/boot/guest/mirageSwitch.xen'
EXISTING_VM_UUIDS=''

usage(){
	echo Usage : `basename $0` MODULE ACTION
        echo "        MODULE = server | client | switch | all"
        echo "        ACTION = install | cinstall | uninstall"
        exit 1
}

installMirageVM(){
	[ -z "$1" ] && { echo "ERROR: installMirageVM() requires a VM name to be passed as argument"; exit 1; }
	VM_NAME=$1
	[[ -z "$2" || ! -x $2 ]] && { echo "ERROR: installMirageVM() requires an existing XEN kernel to be passed as argument"; exit 1; }
	KERNEL_LOC=$2
	echo "Installing Mirage VM ${VM_NAME}"
	if [[ -n "${3}" ]]; then
		sudo ./xcpInstallMirageVM.sh -s ${MY_SR_UUID} -i "${3}" -b ${MY_BRIDGE_IFACE} -n ${VM_NAME} ${KERNEL_LOC}
	else
		sudo ./xcpInstallMirageVM.sh -s ${MY_SR_UUID} -i random -b ${MY_BRIDGE_IFACE} -n ${VM_NAME} ${KERNEL_LOC}
	fi
	[ $? -ne 0 ] && { echo "ERROR: Failed to install VM (${VM_NAME}, ${KERNEL_LOC}). Exiting..."; exit 1; }
}

deleteVM(){
	[ -z "$1" ] && { echo "ERROR: deleteVM() requires a VM name to be passed as argument"; exit 1; }
	VM_NAME=$1
        echo "Removing all VMs with name ${VM_NAME}"
	getVMbyName $VM_NAME
	EXISTING_VM_UUIDS=$(echo $EXISTING_VM_UUIDS | tr , '\n')
	[ -z $EXISTING_VM_UUIDS ] && return
	while read -r currUUID; do
		echo "Deleting VM with UUID:${currUUID}"
		./xcpUninstallMirageVM.sh $currUUID
		[ $? -ne 0 ] && { echo "ERROR: Failed to uninstall VM (${currUUID}). Exiting..."; exit 1; }
	done <<< "$EXISTING_VM_UUIDS"
}

getVMbyName(){
	[ -z "$1" ] && { echo "ERROR: getVMbyName() requires a VM name to be passed as argument"; exit 1; }
	VM_NAME=$1
	EXISTING_VM_UUIDS=$(sudo xe vm-list name-label=${VM_NAME} --minimal)
}


if [ $# -lt 2 ]; then
	echo -e "Too few arguments...\n"
        usage
fi

case $1 in
        "server")
                MODULE="server"
                ;;
        "client")
                MODULE="client"
                ;;
        "switch")
                MODULE="switch"
                ;;
         "all")
                MODULE="all"
                ;;
        *) echo -e "Invalid module name ($1).\n"
	   usage
	   exit 1;;
esac

case $2 in
        "install")
                ACTION="install"
                if [[ "${MODULE}" == "server" ||  "${MODULE}" == "all" ]]; then
                        installMirageVM $SERVER_VM_NAME $SERVER_KERN_NAME
                fi
                if [[ "${MODULE}" == "client" ||  "${MODULE}" == "all" ]]; then
                        installMirageVM $CLIENT_VM_NAME $CLIENT_KERN_NAME
                fi
                if [[ "${MODULE}" == "switch" ||  "${MODULE}" == "all" ]]; then
                        installMirageVM $SWITCH_VM_NAME $SWITCH_KERN_NAME "random"
                fi
                 ;;
        "cinstall")
                ACTION="cinstall"
                if [[ "${MODULE}" == "server" ||  "${MODULE}" == "all" ]]; then
                        deleteVM $SERVER_VM_NAME
                        installMirageVM $SERVER_VM_NAME $SERVER_KERN_NAME
                fi
                if [[ "${MODULE}" == "client" ||  "${MODULE}" == "all" ]]; then
                        deleteVM $CLIENT_VM_NAME
                        installMirageVM $CLIENT_VM_NAME $CLIENT_KERN_NAME
                fi
		if [[ "${MODULE}" == "switch" ||  "${MODULE}" == "all" ]]; then
                        deleteVM $SWITCH_VM_NAME
                        installMirageVM $SWITCH_VM_NAME $SWITCH_KERN_NAME "random random"
                fi
                ;;
        "uninstall")
                ACTION="uninstall"
                if [[ "${MODULE}" == "server" ||  "${MODULE}" == "all" ]]; then
                        deleteVM $SERVER_VM_NAME
                fi
                if [[ "${MODULE}" == "client" ||  "${MODULE}" == "all" ]]; then
                        deleteVM $CLIENT_VM_NAME
                fi
                if [[ "${MODULE}" == "switch" ||  "${MODULE}" == "all" ]]; then
                        deleteVM $SWITCH_VM_NAME
                fi
                ;;
        *) echo -e "Invalid action ($2).\n"
	   usage
	   exit 1;;
esac


echo "Done performing action:${ACTION} for ${MODULE}"
