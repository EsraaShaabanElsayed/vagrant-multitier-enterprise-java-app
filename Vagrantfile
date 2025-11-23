Vagrant.configure('2') do |config|
  config.vm.define "mariadb" do |machine|
    machine.vm.box = 'eurolinux-vagrant/centos-stream-9'
    machine.vm.network "private_network", ip: '192.168.56.15'
    machine.vm.hostname = "mariadb"
    machine.vm.provider "virtualbox" do |vb|
      vb.name = "db01"
      vb.cpus = '1'
      vb.memory = '2048'
    end
    machine.vm.provision "shell", path: "provisioning/mariadb.sh"
  end
  config.vm.define "mc" do |machine|
    machine.vm.box = 'eurolinux-vagrant/centos-stream-9'
    machine.vm.network "private_network", ip: '192.168.56.14'
    machine.vm.hostname = "mc"
    machine.vm.provider "virtualbox" do |vb|
      vb.name = "mc"
      vb.cpus = '1'
      vb.memory = '1024'
    end
    machine.vm.provision "shell", path: "provisioning/mc.sh"
  end
  config.vm.define "rmq" do |machine|
    machine.vm.box = 'eurolinux-vagrant/centos-stream-9'
    machine.vm.network "private_network", ip: '192.168.56.13'
    machine.vm.hostname = "rmq"
    machine.vm.provider "virtualbox" do |vb|
      vb.name = "rmq"
      vb.cpus = '1'
      vb.memory = '1024'
    end
    machine.vm.provision "shell", path: "provisioning/rmq.sh"
  end
  config.vm.define "tomcat" do |machine|
    machine.vm.box = 'eurolinux-vagrant/centos-stream-9'
    machine.vm.network "private_network", ip: '192.168.56.12'
    machine.vm.hostname = "tomcat"
    machine.vm.provider "virtualbox" do |vb|
      vb.name = "app01"
      vb.cpus = '1'
      vb.memory = '4200'
    end
    machine.vm.provision "shell", path: "provisioning/tomcat.sh"
  end
    config.vm.define "nginx" do |machine|
    machine.vm.box = 'ubuntu/jammy64'
    machine.vm.network "private_network", ip: '192.168.56.11'
    machine.vm.hostname = "nginx"
    machine.vm.provider "virtualbox" do |vb|
      vb.name = "web01"
      vb.cpus = '1'
      vb.memory = '800'
    end
    machine.vm.provision "shell", path: "provisioning/nginx.sh"
  end
end
