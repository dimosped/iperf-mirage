SHELL := /bin/bash

# Define a BACKEND variable usable in sub-Makefiles

BACKEND := $(shell opam list --installed --short mirage-xen)

ifeq ($(strip $(BACKEND)),mirage-xen)
	BACKEND := --xen
else
	BACKEND := --unix
endif

.PHONY: all


all: client server
	@

server:
	cd src/server; mirari configure $(BACKEND)
	cd src/server; mirari build $(BACKEND)
	mkdir -p ./bin/xen
	find src/server ! -type l -name *.xen | xargs -i -n 1 cp {} ./bin/xen/iperfServer.xen
	#sudo cp ./bin/xen/iperfServer.xen /boot/guest/

client:
	cd src/client; mirari configure $(BACKEND)
	cd src/client; mirari build $(BACKEND)
	mkdir -p ./bin/xen
	find src/client ! -type l -name *.xen | xargs -i -n 1 cp {} ./bin/xen/iperfClient.xen
	#sudo cp ./bin/xen/iperfClient.xen /boot/guest/

clean:
	cd ./src/client; mirari configure $(BACKEND); mirari clean
	cd ./src/server; mirari configure $(BACKEND); mirari clean
	rm -f ./bin/xen/*.xen

install:
	cd bin; ./installMirageVM.sh all install

installClient:
	cd bin; ./installMirageVM.sh client install

installServer:
	cd bin; ./installMirageVM.sh server install

cinstall:
	cd bin; ./installMirageVM.sh all cinstall

cinstallClient:
	cd bin; ./installMirageVM.sh client cinstall

cinstallServer:
	cd bin; ./installMirageVM.sh server cinstall

uninstall:
	cd bin; ./installMirageVM.sh all uninstall

uninstallClient:
	cd bin; ./installMirageVM.sh client uninstall

uninstallServer:
	cd bin; ./installMirageVM.sh server uninstall

