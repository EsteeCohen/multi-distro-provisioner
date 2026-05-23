# Makefile — the single entry point for all lab operations.
#
# WHY a Makefile?
#   Instead of remembering long vagrant/ssh commands, you type "make up"
#   and it handles everything. It's a standard tool in Linux projects.
#
# HOW make works:
#   Each block is a "target":
#     target-name: dependencies
#     [TAB] command to run
#
#   IMPORTANT: the indentation MUST be a real TAB character, not spaces.

.PHONY: up down ssh-ubuntu ssh-fedora provision-ubuntu provision-fedora \
        provision-all status clean help

# Default target — runs when you type "make" with no arguments
help:
	@echo ""
	@echo "multi-distro-provisioner — available commands:"
	@echo ""
	@echo "  make up               Start both VMs"
	@echo "  make down             Stop and destroy both VMs"
	@echo "  make status           Show VM status"
	@echo ""
	@echo "  make provision-ubuntu Run provisioner on ubuntu-node"
	@echo "  make provision-fedora Run provisioner on fedora-node"
	@echo "  make provision-all    Provision both VMs"
	@echo ""
	@echo "  make ssh-ubuntu       SSH into ubuntu-node"
	@echo "  make ssh-fedora       SSH into fedora-node"
	@echo ""
	@echo "  make clean            Destroy VMs and remove .vagrant directory"
	@echo ""

up:
	vagrant up

down:
	vagrant halt

status:
	vagrant status

ssh-ubuntu:
	vagrant ssh ubuntu-node

ssh-fedora:
	vagrant ssh fedora-node

provision-ubuntu:
	vagrant provision ubuntu-node

provision-fedora:
	vagrant provision fedora-node

provision-all: provision-ubuntu provision-fedora

clean:
	vagrant destroy -f
	rm -rf .vagrant
