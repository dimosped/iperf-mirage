#!/usr/bin/env bash

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

#-------------------------
#  This script extends the original xcp.sh script authored by  Mike McClurg (Citrix)
#-------------------------


#set -e
#set -x

function usage () {
    echo "Usage:"
    echo "   `basename $0` [-x <xenserver host>] [-s <sr-uuid to place vdi>] <kernel name>"
}

function on_exit () {
    echo " *** Caught an error! Cleaning up."
    if [ -n "${VBD}" ]; then
        echo "Destroying VBD ${VBD}"
        ${SUDO} umount ${MNT}
        ${XE} vbd-unplug uuid=${VBD}
        ${XE} vbd-destroy uuid=${VBD}
    fi
    if [ -n "${VDI}" ]; then
        echo "Destroying VDI ${VDI}"
        ${XE} vdi-destroy uuid=${VDI}
    fi
    if [ -n "${MIRAGE_VM}" ]; then
        echo "Destroying mirage VM ${MIRAGE_VM}"
        ${XE} vm-destroy uuid=${MIRAGE_VM}
    fi
    if [ -e "${MENU_LST}" ]; then
        echo "Removing ${MENU_LST}"
        rm ${MENU_LST}
    fi
    if [ -e "${KERNEL_PATH}.gz" ]; then
        echo "Uncompressing ${KERNEL_PATH}"
        gunzip "${KERNEL_PATH}.gz"
    fi
    echo "Quitting"
}

while getopts ":x:u:s:i:b:n:" option
do
    case $option in
        x ) DOM0_HOST=${OPTARG} ;;
        s ) SR_UUID=${OPTARG}; echo "SR=${SR_UUID}" ;;
	i ) IFACE_MAC=${OPTARG};;
	b ) BRIDGE_IF=${OPTARG};;
	n ) MIRAGE_VM_NAME=${OPTARG};;
        : ) usage
            echo "Option -${OPTARG} requires an argument."
            exit 1;;
        '?' ) usage
            echo "Invalid option -${OPTARG}."
            exit 1 ;;
    esac
done

#echo ${DOM0_HOST}
#echo ${SR_UUID}
#echo ${IFACE_MAC}
#echo ${BRIDGE_IF}
#echo ${MIRAGE_VM_NAME}


# Kernel name will be first unprocessed arguement remaining
ARGS=($@)
TOTALARGS=${#ARGS[@]} 
LAST_ARG_IDX=$((TOTALARGS - 1))
KERNEL_PATH=${ARGS[${LAST_ARG_IDX}]}

# Required args: kernel name, and (if -x then also -u)
if [ -z ${KERNEL_PATH} ]; then
    usage
    echo 'Missing kernel name.'
    exit 1
fi
# Check if mirage kernel is a symlink
[ -h ${KERNEL_PATH} ] && KERNEL_PATH=$(readlink -f ${KERNEL_PATH}) && echo -e "The supplied Mirage kernel is a symlink pointing to:\n ${KERNEL_PATH} "


if [[ -n "${IFACE_MAC}" ]]
then
	read -a IFACES_MACS_ARRAY <<< $IFACE_MAC
	i=0
	for ifaceMac in ${IFACES_MACS_ARRAY[@]}; do
		if [ "${ifaceMac}" == "random" ]
        	then
                	VIF_MAC[$i]="random"
        	else
                	VIF_MAC[$i]=`echo "$ifaceMac" | egrep "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$"`
                	[ ! ${VIF_MAC[$i]}  ] && { echo "Provided a malformed MAC address"; exit 1;  }
        	fi
		echo "The MAC address of the VIF[${i}] will be  ${VIF_MAC[${i}]}"
		i=$(( i + 1 ))
	done
fi


if [ ${MIRAGE_VM_NAME} ]
then
	KERNEL_NAME=${MIRAGE_VM_NAME}
else
	KERNEL_NAME=$(basename ${KERNEL_PATH})
fi
MNT='/mnt/mirageTemp'
SUDO='sudo'
MENU_LST='menu.lst'

# Set XE command depending on whether we're in dom0 or domU
if [ -z "${DOM0_HOST}" ]; then
    XE="xe"
else
    XE="xe -s ${DOM0_HOST}"
    if [ ! -e ${HOME}/.xe ]; then
	echo Please add username= and password= lines to ${HOME}/.xe
	exit 1
    fi
fi

if [ $BRIDGE_IF ]
then
        NET_UUID=$(${XE} network-list bridge=${BRIDGE_IF} --minimal)
        [ ! ${NET_UUID} ] && { echo "No Xen Networks found with bridge ${BRIDGE_IF}"; exit 1; }
fi


MY_VM=$(xenstore-read vm | cut -f 3 -d /)

echo "Using xe command '${XE}', this VM's uuid is ${MY_VM}"

# Default to local SR
if [ -z "${SR_UUID}" ]; then
    SR_UUID=$(${XE} sr-list name-label="Local storage" --minimal)
fi
echo "Using SR ${SR_UUID}"

# Set error handler trap to clean up after an error
trap on_exit EXIT

# Write grub conf to disk
echo "default 0" > ${MENU_LST}
echo "timeout 1" >> ${MENU_LST}
echo "title Mirage" >> ${MENU_LST}
echo " root (hd0)" >> ${MENU_LST}
echo " kernel /boot/${KERNEL_NAME}.gz" >> ${MENU_LST}


# Gzip kernel image
gzip ${KERNEL_PATH}
[ $? -ne 0 ] && { echo "Failed to gzip ${KERNEL_PATH}"; exit 1; }

# Calculate necessary size of VDI
SIZE=0
for i in $(ls -s -1 -k ${KERNEL_PATH}.gz ${MENU_LST} | awk '{print $1}')
do
    SIZE=$((i + SIZE))
done
[ $? -ne 0 ] && { echo "Failed to count ${KERNEL_PATH}.gz bytes size"; exit 1; }
SIZE=${SIZE}KiB

echo "VDI size will be ${SIZE}"

# Create VDI
VDI=$(${XE} vdi-create name-label="${KERNEL_NAME}-vdi" sharable=true \
   type=user virtual-size=${SIZE} sr-uuid=${SR_UUID})
[ $? -ne 0 ] && { echo "Failed to create VDI ${VDI}"; exit 1; }
echo "Created VDI ${VDI}"

# Create VBD (with vdi and this vm)
VBD_DEV=$(${XE} vm-param-get uuid=${MY_VM} \
    param-name=allowed-VBD-devices | cut -f 1 -d \;)
[ $? -ne 0 ] && { echo "Failed to obtain allowed-VBD-devices for VM ${MY_VM}"; exit 1; }
VBD=$(${XE} vbd-create vm-uuid=${MY_VM} vdi-uuid=$VDI device=${VBD_DEV} type=Disk)
[ $? -ne 0 ] && { echo "Created VBD ${VBD} as virtual device number ${VBD_DEV} for VM ${MY_VM}"; exit 1; }
echo "Created VBD ${VBD} as virtual device number ${VBD_DEV}"

# Plug VBD
${XE} vbd-plug uuid=${VBD}
[ $? -ne 0 ] && { echo "Failed to plug VBD ${VBD}"; exit 1; }

# Mount vdi disk
XVD=$(${XE} vbd-list uuid=${VBD} params=device --minimal)
[ $? -ne 0 ] && { echo "Failed to optain UUID for VBD ${VBD}"; exit 1; }
echo "Making ext3 filesystem on /dev/${XVD}"
mke2fs -q -j /dev/${XVD}
[ $? -ne 0 ] && { echo "Failed to make ext3 filesystem on /dev/${XVD}"; exit 1; }
echo "Mounting /dev/${XVD} at ${MNT}"
${SUDO} mount -t ext3 /dev/${XVD} ${MNT}
[ $? -ne 0 ] && { echo "Failed to mount /dev/${XVD} on ${MNT}"; exit 1; }

# Copy grub conf to vdi disk
${SUDO} mkdir -p ${MNT}/boot/grub
[ $? -ne 0 ] && { echo "Failed to create directore /boot/grub at ${MNT}"; exit 1; }
${SUDO} mv ${MENU_LST} ${MNT}/boot/grub/${MENU_LST}
[ $? -ne 0 ] && { echo "Failed to move ${MENU_LST} to ${MNT}/boot/grub/${MENU_LST}"; exit 1; }

# Copy kernel image to vdi disk
${SUDO} cp ${KERNEL_PATH}.gz ${MNT}/boot/${KERNEL_NAME}.gz
[ $? -ne 0 ] && { echo "Failed to copy ${KERNEL_PATH}.gz to ${MNT}/boot/${KERNEL_NAME}"; exit 1; }
gunzip ${KERNEL_PATH}
[ $? -ne 0 ] && { echo "Failed to unzip ${KERNEL_PATH}"; exit 1; }

echo "Wrote ${MENU_LST} and copied kernel to ${MNT}/boot"

# Unmount and unplug vbd
${SUDO} umount ${MNT}
[ $? -ne 0 ] && { echo "Failed to unmount ${MNT}"; exit 1; }
${XE} vbd-unplug uuid=${VBD}
[ $? -ne 0 ] && { echo "Failed to unplug VBD ${VBD}"; exit 1; }
${XE} vbd-destroy uuid=${VBD}
[ $? -ne 0 ] && { echo "Failed to destroy VBD ${VBD}"; exit 1; }

echo "Unmounted /dev/${XVD_} and destroyed VBD ${VBD}."

# Create mirage vm
templateUuid=`sudo xe template-list name-label="Other install media" --minimal | awk '{split($0,a,","); print a[1]}'`
[ -z $templateUuid  ] && { echo "No templates with name 'Other install media found'"; exit 1; }
MIRAGE_VM=$(${XE} vm-install template=$templateUuid new-name-label="${KERNEL_NAME}")
[ $? -ne 0 ] && { echo "Failed to create mirage VM using template $templateUuid"; exit 1; }
${XE} vm-param-set uuid=${MIRAGE_VM} PV-bootloader=pygrub
[ $? -ne 0 ] && { echo "Failed to set the Mirage VM param PV-bootloader to pygrub"; exit 1; }
${XE} vm-param-set uuid=${MIRAGE_VM} HVM-boot-policy=
[ $? -ne 0 ] && { echo "Failed to empty the Mirage VM param HVM-boot-policy"; exit 1; }
${XE} vm-param-clear uuid=${MIRAGE_VM} param-name=HVM-boot-params
[ $? -ne 0 ] && { echo "Failed to unset the Mirage VM param HVM-boot-params"; exit 1; }

# Attach vdi to mirage vm and make bootable
VBD_DEV=$(${XE} vm-param-get uuid=${MIRAGE_VM} \
    param-name=allowed-VBD-devices | cut -f 1 -d \;)
[ $? -ne 0 ] && { echo "Failed to get the value of param allowed-VBD-devices"; exit 1; }
VBD=$(${XE} vbd-create vm-uuid=${MIRAGE_VM} vdi-uuid=${VDI} device=${VBD_DEV} type=Disk)
[ $? -ne 0 ] && { echo "Failed to create disk VBD for Mirage VM"; exit 1; }
${XE} vbd-param-set uuid=$VBD bootable=true
[ $? -ne 0 ] && { echo "Failed to VM's disk as bootable"; exit 1; }

# Create the VIF
i=0
for vifMac in ${VIF_MAC[@]}; do
	VIF=$(${XE} vif-create vm-uuid=${MIRAGE_VM} network-uuid=${NET_UUID} mac=${vifMac} device=${i})
	[ ! ${VIF} ] && { echo "Failed to create a VIF[${i}] with MAC ${vifMac}."; exit 1; }
	i=$(( i + 1 ))
done

# Turn off error handling
trap - EXIT

echo "Successfully created VM ${KERNEL_NAME}: ${MIRAGE_VM}"
