# Vagrantfile ג€” defines two Linux VMs for this lab.
#
# WHY Vagrant?
#   Vagrant lets you describe a VM in a plain text file and spin it up with
#   one command. Anyone who clones this repo gets the exact same machines.
#   This is the core idea behind Infrastructure as Code (IaC).
#
# HOW it works:
#   1. Vagrant reads this file
#   2. It tells VirtualBox to create VMs matching the config below
#   3. It runs the matching provision.sh script inside the VM automatically
#
# Network: both VMs get a private IP on a host-only network (192.168.56.x).
#   Your laptop can reach them at that IP, but they are isolated from the internet.

Vagrant.configure("2") do |config|

  # ג”€ג”€ Ubuntu Node ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
  config.vm.define "ubuntu-node" do |ubuntu|
    ubuntu.vm.box      = "ubuntu/jammy64"   # Ubuntu 22.04 LTS
    ubuntu.vm.hostname = "ubuntu-node"

    # Static private IP ג€” always reachable at this address from your laptop
    ubuntu.vm.network "private_network", ip: "192.168.56.10"

    # Port forward: curl localhost:8080 on your laptop ג†’ hits nginx inside the VM
    ubuntu.vm.network "forwarded_port", guest: 80, host: 8080

    ubuntu.vm.provider "virtualbox" do |vb|
      vb.name   = "ubuntu-node"
      vb.memory = "1024"   # 1 GB RAM
      vb.cpus   = 1
    end

    # Vagrant runs this script as root inside the VM after first boot
    ubuntu.vm.provision "shell", inline: "bash /vagrant/scripts/ubuntu/provision.sh"
  end

  # ג”€ג”€ Fedora Node ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€ג”€
  config.vm.define "fedora-node" do |fedora|
    fedora.vm.box      = "bento/fedora-39"   # Fedora 39
    fedora.vm.hostname = "fedora-node"

    fedora.vm.network "private_network", ip: "192.168.56.11"

    # Fedora nginx reachable at localhost:8081 from your laptop
    fedora.vm.network "forwarded_port", guest: 80, host: 8081

    fedora.vm.provider "virtualbox" do |vb|
      vb.name   = "fedora-node"
      vb.memory = "1024"
      vb.cpus   = 1
    end

    fedora.vm.provision "shell", inline: "bash /vagrant/scripts/fedora/provision.sh"
  end

end

