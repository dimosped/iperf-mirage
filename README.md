iperf-mirage
============

A simple Iperf-like utility, intended to benchmark mirage network stack

-----------------
Prerequisities
-----------------
 - XenServer/XCP, xe toolchain, xapi
 - ocaml - opam
 - mirari, mirage-xen, mirage-net-direct


-----------------
Description
------------------
This is a simple utility which emulates iperf in TCP mode.

This Mirage Application is intended to be used over Xen, but with minor modification in the Makefile, it can easily be ported for the Unix backend.

Please be aware that the scripts found in ./bin automate the installation of Xen guests without using templates.

Feel free to use the xcpInstallMirageVM.sh and xcpUninstallMirageVM.sh for any mirage microkernel, they are general purpose.

ATTENTION:
The xcpUninstallMirageVM.sh will REMOVE the first VM which is found to be installed on XenServer and has Name-Label supplied as the first argument
The "make uninstall" will remove all VMs with name mirageIperf{Server | Client}



---------------------
Installation / Configuration
---------------------
You might need to change the followings to adapt the code to your system's setup (or just to your preference)
 - You'll probably need to modify the two topmost global variables in ./bin/installMirageVM.sh to match your Xen installation settings:
		MY_SR_UUID='4d0bcc33-b22b-8424-800d-5f69fbbad3fe'
		MY_BRIDGE_IFACE='xenbr1'
 - Edit src/server/iperf_server.conf with the IP address of your preference
 - Edit src/client/iperf_client.conf with the IP address of your preference
 - Edit src/server/iperf_client.ml line:93 with the IP address of the iperf_server you have selected
 

------------------
Make targets explained
------------------
(*) Build both client and server
		> make all
(*) Build client or server individually
		> make client
		> make server
(*) Clean both server and client
		> make clean
(*) Install the client and/or server Xen guest, using the generated Xen kernel
		> make install
		> make installCLient
		> make installServer
(*) Remove from XenServer the client and/or server Xen guest(s). Note that this will remove all VMs with name mirageIperf{Server | Client}
		> make uninstall
		> make uninstallClient
		> make uninstallServer
(*) Clean-Install a VM: Remove an existing VMs with name mirageIperf{Server | Client} and then install
		> make cinstall
		> make uninstallClient
		> make cinstallServer
	



------------------
Usage
------------------
Of course, you should first start the server, wait for a few seconds to come up and get ready, and then you start the client.

(*) Build, clean-install, start the Iperf Server VM, open a console
make server
make cinstallServer
sudo xe vm-start vm=YOUR-IPERFSERVER-VM-UUID-HERE 
sudo xe console vm=YOUR-IPERFSERVER-VM-UUID-HERE

(*) Build, clean-install, start the Iperf Client VM, open a console
make client
make cinstallClient
sudo xe vm-start vm=YOUR-IPERFCLIENT-VM-UUID-HERE 
sudo xe console vm=YOUR-IPERFCLIENT-VM-UUID-HERE

(*) Force-stop a Mirage VM
sudo xe vm-shutdown vm=YOUR-VM-UUID-HERE --force


--------------------
TCP logging
--------------------
In order to enable the logging for a TCP flow, you need to do the followings for the Iperf Client:
 - uncomment line 59 in src/client/iperf_client.ml (turns on logging for a specific flow)
 - uncomment lines 70,71 in src/client/iperf_client.ml (obtains prints the collected logs)

Similarly, at the Iperf Server you need to:
 - uncomment line 86 in src/server/iperf_server.ml (turns on logging for a specific flow)
 - uncomment lines 75,76 in src/server/iperf_server.ml (obtains and prints the collected logs)

Printing lengthy logs might take a lot of time. This is mainly due to the fact that Xen console can't cope well with big amounts of output data, therefore, I've added a small delay before printing to the stdout to avoid crashing the console.

In order to collect the logs in a file, you only need to redirect standard output, e.g.:
 sudo xe console vm=YOUR-IPERFSERVER-VM-UUID-HERE  > tools/MirageTcpVis/data/receiverData.log

Please be aware, that printing lengthy logs takes some time. 
The client terminates the connection and exits after everything is printed.
The server expects the client to terminate the connection, then prints own logs and exits.
Feel free to discard any data that the server reports while waiting the client to finish printing.
This waiting time might be several seconds and might affect the zoom-level of your plots. 
The plotting tool however has built-in API that allows to focus on a specific time window of a time-series.
For more, check tools/MirageTcpVis/README

