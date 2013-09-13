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


#set -e
#set -x

[ ! $1 ] && { echo "You need to supply a valid VM UUID. Exiting"; exit 1; }


XE="xe"
[ "$(id -u)" != "0" ] && XE="sudo xe"

VM_UUID=$(${XE} vm-list uuid=$1 --minimal)
[ ! $VM_UUID  ] && { echo "ERROR: No VM was found with the supplied UUID"; exit 1; }

VM_STATE=$(${XE} vm-list uuid=${VM_UUID} params=power-state --minimal)
[ "${VM_STATE}" == "running" ] && { echo "ERROR: The VM cannot be deleted as it is still running"; exit 1; }

VM_VDI=$(${XE} vm-disk-list vm=${VM_UUID} vdi-params=uuid --minimal | cut -d, -f1)
[ ! $VM_VDI  ] && echo "No VDI was found for the VM with the supplied UUID"

VM_VIF=$(${XE} vm-vif-list vm=${VM_UUID} --minimal)
[ ! $VM_VIF  ] && echo "No VIF was found for the VM with the supplied UUID"

# Delete the VM
${XE} vm-destroy uuid=${VM_UUID}
[ $? -ne 0 ] && { echo "ERROR: Failed to destroy the VM"; exit 1; }

# Delete the disk
if [ ${VM_VDI} ]
then
	${XE} vdi-destroy uuid=${VM_VDI}
	[ $? -ne 0 ] && { echo "Failed to destroy the VM"; exit 1; }
	echo "Destroyed the VDI"
fi

echo "The VM has been uninstalled successfully!"

