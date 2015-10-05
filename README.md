## About

Docker host as Vagrant box created with [kitchen-docker](https://github.com/portertech/kitchen-docker) in mind. Provides a Docker host and Squid as caching proxy. It doesn't have anything [Test Kitchen](http://kitchen.ci) specific per-se, but it provides a consistent development environment.

## Dependencies

 * [VirtualBox](https://www.virtualbox.org)
 * [Vagrant](https://www.vagrantup.com)
 * [ChefDK](https://downloads.chef.io/chef-dk/)
 * [vagrant-berkshelf](https://github.com/berkshelf/vagrant-berkshelf)
 * [Docker](https://www.docker.com) client

The vagrant-berkshelf plugin may be easily installed with:

```bash
vagrant plugin install vagrant-berkshelf
```

## How to use

For starting the VM, simply issue a `vagrant up` command in the root directory of this project. By default, it uses 4 virtual cores and 8192 GB of RAM. You may either edit the supplied Vagrantfile or export VB_CPUS and / or VB_MEM environment variables with the desired values.

The VM itself uses a host-only network adapter with the IP address 192.168.99.100. This makes it sort of a drop-in replacement for docker-machine. The Docker socket isn't TLS enabled though.

To tell the Docker client where to find the host, simply:

```bash
export DOCKER_HOST=tcp://192.168.99.100:2375
```

To check that the Docker connection is OK:

```bash
docker info
Containers: 0
Images: 0
Storage Driver: devicemapper
 Pool Name: docker-253:0-68062095-pool
 Pool Blocksize: 65.54 kB
 Backing Filesystem: xfs
 Data file: /dev/loop0
 Metadata file: /dev/loop1
 Data Space Used: 1.821 GB
 Data Space Total: 107.4 GB
 Data Space Available: 38.24 GB
 Metadata Space Used: 1.479 MB
 Metadata Space Total: 2.147 GB
 Metadata Space Available: 2.146 GB
 Udev Sync Supported: true
 Deferred Removal Enabled: false
 Data loop file: /var/lib/docker/devicemapper/devicemapper/data
 Metadata loop file: /var/lib/docker/devicemapper/devicemapper/metadata
 Library Version: 1.02.93-RHEL7 (2015-01-28)
Execution Driver: native-0.2
Logging Driver: json-file
Kernel Version: 3.10.0-229.el7.x86_64
Operating System: CentOS Linux 7 (Core)
CPUs: 2
Total Memory: 993.2 MiB
Name: kitchen-docker-host
ID: 77ZQ:24HX:YGI2:ETAX:GTED:ZEO3:35XE:XS7I:S3WN:6UTT:7ZLI:SAAS
```

To use it with Test Kitchen, you need to install the kitchen-docker gem and to specify docker as Kitchen driver.

To use the Squid caching proxy you need to tell Test Kitchen to use http_proxy.

```yml
driver:
  name: vagrant
  http_proxy: http://192.168.99.100:3128

provisioner:
  chef_omnibus_url: http://www.chef.io/chef/install.sh
  client_rb:
    http_proxy: http://192.168.99.100:3128
```

The only thing that doesn't seem to belong here is chef_omnibus_url. However, the Omnibus installer defaults to HTTPS, unless the URL to install.sh uses HTTP. This allows Squid to cache the Chef package which is quite large at ~40 MB.

The whole configuration may be bit smater as in [this example](https://gist.github.com/fnichol/7551540).
