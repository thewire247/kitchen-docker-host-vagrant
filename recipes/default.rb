# kitchen-docker-host::default

package 'postfix' do
  action :remove
end

include_recipe 'sysctl::default'
include_recipe 'yum-epel::default'

package %w[htop squid bc]

remote_file '/etc/yum.repos.d/docker-ce.repo' do
  source 'https://download.docker.com/linux/centos/docker-ce.repo'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

package 'docker-ce' do # ~FC009
  flush_cache [:before]
  version '18.09.2-3.el7'
end

docker_service 'default' do
  install_method 'none'
  host %w[tcp://0.0.0.0:2375]
  bip '172.17.42.1/16'
  storage_driver 'devicemapper'
  storage_opts %w[dm.basesize=20G]
  action %i[create start]
end

service 'docker' do
  action %i[start enable]
end

cookbook_file '/etc/squid/squid.conf' do
  source 'etc.squid.squid.conf'
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, 'service[squid]', :delayed
end

service 'squid' do
  action %i[enable start]
end

%w[
  net.ipv4.ip_forward
  net.ipv6.conf.all.forwarding
  net.bridge.bridge-nf-call-iptables
  net.bridge.bridge-nf-call-ip6tables
].each do |param|
  sysctl_param param do
    value 1
    notifies :restart, 'service[docker]', :delayed
  end
end

cookbook_file '/etc/init.d/zram' do
  source 'etc.init.d.zram'
  owner 'root'
  group 'root'
  mode '0755'
  notifies :restart, 'service[zram]', :delayed
end

service 'zram' do
  action %i[enable start]
end

service 'firewalld' do
  action %i[stop disable]
  notifies :restart, 'service[docker]', :delayed
end

service 'docker' do
  action %i[enable start]
end

include_recipe 'selinux::disabled'
