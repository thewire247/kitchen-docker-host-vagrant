module VagrantPlugins
  module GuestLinux
    class Plugin < Vagrant.plugin('2')
      guest_capability('linux', 'change_host_name') { Cap::ChangeHostName }
      guest_capability('linux', 'configure_networks') { Cap::ConfigureNetworks }
    end
  end
end
