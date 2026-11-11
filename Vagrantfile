# -*- mode: ruby -*-
# vi: set ft=ruby :

# Choose your base box:
# - "archlinux/archlinux" (Arch/Manjaro rolling base - Recommended)
# - "generic/ubuntu2204"  (Ubuntu 22.04 LTS fallback)
BOX_NAME = ENV['VAGRANT_BOX'] || "archlinux/archlinux"

Vagrant.configure(2) do |config|
  config.vm.box = BOX_NAME

  # Network configuration (DHCP by default)
  # config.vm.network "private_network", ip: "192.168.56.10"

  # Shared folders:
  # Mount the parent Eurorack workspace directory into /vagrant/workspace
  config.vm.synced_folder "../", "/vagrant/workspace", create: true

  config.vm.provider "virtualbox" do |vb|
    vb.name = "mutable-dev-environment"
    vb.memory = "4096"
    vb.cpus = 4

    # Enable USB 2.0 (EHCI) / USB 3.0 (xHCI) controller
    vb.customize ['modifyvm', :id, '--usb', 'on']
    vb.customize ['modifyvm', :id, '--usbehci', 'on'] rescue nil

    # USB device filters for programmers:
    # ST-Link V2
    vb.customize ['usbfilter', 'add', '0', '--target', :id, '--name', 'ST-Link V2', '--vendorid', '0x0483', '--productid', '0x3748']
    # ST-Link V2-1
    vb.customize ['usbfilter', 'add', '1', '--target', :id, '--name', 'ST-Link V2-1', '--vendorid', '0x0483', '--productid', '0x374b']
    # ST-Link V3
    vb.customize ['usbfilter', 'add', '2', '--target', :id, '--name', 'ST-Link V3', '--vendorid', '0x0483', '--productid', '0x3753']
    vb.customize ['usbfilter', 'add', '3', '--target', :id, '--name', 'ST-Link V3 (Alt)', '--vendorid', '0x0483', '--productid', '0x374d']
    # Olimex OpenOCD JTAG adapters
    vb.customize ['usbfilter', 'add', '4', '--target', :id, '--name', 'Olimex ARM-USB-TINY-H', '--vendorid', '0x15BA', '--productid', '0x002a']
    vb.customize ['usbfilter', 'add', '5', '--target', :id, '--name', 'Olimex ARM-USB-OCD-H', '--vendorid', '0x15BA', '--productid', '0x002b']
    vb.customize ['usbfilter', 'add', '6', '--target', :id, '--name', 'Olimex OpenOCD JTAG', '--vendorid', '0x15BA', '--productid', '0x0003']
    # Atmel AVRISP mkII
    vb.customize ['usbfilter', 'add', '7', '--target', :id, '--name', 'AVRISP mkII', '--vendorid', '0x03EB', '--productid', '0x2104']
    # FTDI serial adapter
    vb.customize ['usbfilter', 'add', '8', '--target', :id, '--name', 'FTDI serial adapter', '--vendorid', '0x0403', '--productid', '0x6001']
  end

  # Provisioning based on distribution
  if BOX_NAME.include?("arch") || BOX_NAME.include?("manjaro")
    config.vm.provision :shell, path: "setup-manjaro.sh"
  else
    config.vm.provision :shell, path: "0_install-toolchain-ubuntu.sh"
  end

  # Clone or update https://github.com/racoonhead/eurorack.git
  repo_url = ENV['USER_GITHUB_URL'] || "https://github.com/racoonhead/eurorack.git"
  config.vm.provision :shell, path: "1_clone-code.sh", args: repo_url, privileged: false

  # After login, automatically navigate to workspace if present
  config.vm.provision :shell, inline: <<-SHELL
    if [ -d "/vagrant/workspace/eurorack" ]; then
      echo "cd /vagrant/workspace/eurorack" >> /home/vagrant/.bashrc
    elif [ -d "/vagrant/workspace" ]; then
      echo "cd /vagrant/workspace" >> /home/vagrant/.bashrc
    fi
  SHELL
end
