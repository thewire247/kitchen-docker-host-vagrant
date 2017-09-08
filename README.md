## About

This branch uses Veertu Desktop which is macOS / OS X specific rather than VirtualBox which is cross platform. For a cross platform implementation, please checkout the [virtualbox](https://github.com/SaltwaterC/kitchen-docker-host-vagrant/tree/virtualbox) branch.

Docker host as Vagrant box created with [kitchen-docker](https://github.com/portertech/kitchen-docker) in mind. Provides a Docker host and Squid as caching proxy. It doesn't have anything [Test Kitchen](http://kitchen.ci) specific per-se, but it provides a consistent development environment. This document also contains a list of speed hacks to make Test Kitchen a lot more faster compared to its defaults.

The machine is also implemented using Test Kitchen using the kitchen-vagrant driver. It used to be implemented with Vagrant and vagrant-berkshelf, however, vagrant-berkshelf has the bad habit of breaking quite often.

## Dependencies

 * [ChefDK](https://downloads.chef.io/chef-dk/) 2+
 * [Veertu Desktop](https://veertu.com/veertu-desktop/)
 * [Vagrant](https://www.vagrantup.com) 1.9.2+
 * [vagrant-veertu](https://github.com/veertuinc/vagrant-veertu) Vagrant plug-in
 * [Docker](https://www.docker.com) client

Vagrant 1.9.2+ is required. The previous versions (up to 1.9) stopped working properly with Atlas.

## How to use

For starting the VM, simply issue a `rake up` command in the root directory of this project.

By default, it uses 4 virtual cores and 4096 GB of RAM and zram support. Export VB_CPUS and / or VB_MEM environment variables with the desired values to customize.

The VM itself uses a shared network adapter with the IP address exported as the environment variable KDH_IP (see setup instruction below).

To tell the Docker client where to find the host, simply:

```bash
source ~/.kdh-ip
export DOCKER_HOST=tcp://$KDH_IP:2375
```

The .kdh-ip file is created by `rake up` (alias of `converge`) or `rake converge`.

To check whether the Docker connection is OK:

```bash
Containers: 0
 Running: 0
 Paused: 0
 Stopped: 0
Images: 0
Server Version: 17.03.0-ce
Storage Driver: overlay
 Backing Filesystem: xfs
 Supports d_type: true
Logging Driver: json-file
Cgroup Driver: cgroupfs
Plugins:
 Volume: local
 Network: bridge host macvlan null overlay
Swarm: inactive
Runtimes: runc
Default Runtime: runc
Init Binary: docker-init
containerd version: 977c511eda0925a723debdc94d09459af49d082a
runc version: a01dafd48bc1c7cc12bdb01206f9fea7dd6feb70
init version: 949e6fa
Security Options:
 seccomp
  Profile: default
Kernel Version: 3.10.0-514.el7.x86_64
Operating System: CentOS Linux 7 (Core)
OSType: linux
Architecture: x86_64
CPUs: 4
Total Memory: 3.702 GiB
Name: kdh-centos-73.vagrantup.com
ID: LZCX:SICI:GNYY:AWXN:DTE3:WMBT:DHQ4:6FZB:BULH:M7EJ:WPVZ:CDUA
Docker Root Dir: /var/lib/docker
Debug Mode (client): false
Debug Mode (server): false
Registry: https://index.docker.io/v1/
Experimental: false
Insecure Registries:
 127.0.0.0/8
Live Restore Enabled: false
```

To use it with Test Kitchen, you need to install the kitchen-docker gem and to specify docker as Kitchen driver.

To use the Squid caching proxy you need to tell Test Kitchen to use http_proxy.

```yml
driver:
  name: docker
  http_proxy: http://<%= ENV['KDH_IP'] %>:3128

provisioner:
  chef_omnibus_url: http://www.opscode.com/chef/install.sh
  client_rb:
    http_proxy: http://<%= ENV['KDH_IP'] %>:3128
```

The only thing that doesn't seem to belong here is chef_omnibus_url. However, the Omnibus installer defaults to HTTPS, unless the URL to install.sh uses HTTP. This allows Squid to cache the Chef package which is quite large at ~40 MB.

The whole configuration may be bit smarter as in [this example](https://gist.github.com/fnichol/7551540).

## Speed up the Kitchen file transfer

By default, Test Kitchen with the kitchen-docker driver, uses SCP as transport backend. SCP is painfully slow for most of the tasks regarding file transfer to a Kitchen container. This cancels any speed gains from using containers instead of virtual machines provisioned by Vagrant. The rsync transport saves the day.

```bash
gem install kitchen-transport-rsync # or add it to your Gemfile
```

You need to install rsync inside the Kitchen container. These .kitchen.yml bits show you how to do it for Red Hat and Debian based distributions without a custom Dockerfile:

```yml
driver:
  name: docker
  provision_command:
  - if [ -x /usr/bin/yum ]; then yum -y install rsync; fi; if [ -x /usr/bin/apt-get ]; then apt-get -y install rsync; fi

transport:
  name: rsync
```

While provision_command accepts an array, doing a one liner gets the job done in one stage instead of two, which makes the Kitchen provisioning to be bit faster. Also, the commands themselves need to be wrapped in if statements as a non-zero exit stops the provisioning (equivalent to a script running with set -e).

kitchen-transport-rsync works with Test Kitchen 1.4.2, probably 1.4.x.

## Better usage of Docker caching

Docker itself saves each stage (layer) which is built from the Dockerfile which is generated by kitchen-docker. Unfortunately, there's a major cache buster which is the SSH key pair. A simple solution is to use public_key and private_key configuration options for the docker driver. By using static keys, the generated Dockerfile has identical layers which roughly translates in a provisioning that takes little over one second instead of more than twenty seconds. The Docker image commits are fairly cheap, but they don't come for free.

Example:

```yml
driver:
  name: docker
  public_key: ../kitchen_id_rsa.pub
  private_key: ../kitchen_id_rsa
```

If the provisioning fails, it means that you're using a kitchen-docker version that [isn't patched to strip the whitespace](https://github.com/portertech/kitchen-docker/pull/167) from the public_key. You'll need to remove the newline at the end of the key.

Caching the Chef Omnibus installation also brings performance improvements as it removes one more redundant step.

Example:

```yml
driver:
  name: docker
  provision_command:
    - curl -L http://www.opscode.com/chef/install.sh -o /tmp/install.sh && bash /tmp/install.sh -v 13.2.20

provisioner:
  name: chef_zero
  require_chef_omnibus: true # just checks the presence of a Chef Omnibus installation instead of passing a Chef version
```

## Thick containers for Docker

Even though this isn't the usual use case, Docker is perfectly capable of running traditional containers (i.e. OpenVZ like). These thick containers behave more like a virtual machine, but they are very quick to provision unlike actual VM's.

Some of the goals for these Dockerfile templates:

 * Have an actual init system as PID 1.
 * The init should actually start services inside the container. Sometimes, this may be rather difficult with upstart / systemd.
 * Have a working SSH service.
 * The containers should respond to shutdown commands in a consistent way.
 * Have all the basic bits baked into the images (rsync, Chef Omnibus).

kitchen-docker supports custom Dockerfiles via the [dockerfile](https://github.com/portertech/kitchen-docker#dockerfile) driver configuration option.

This is the list of supported distributions with these Dockerfiles:

 * CentOS 6.8
 * CentOS 7.2 (may be used for targeting Amazon Linux)
 * Ubuntu 15.10
 * Debian 8.2

For systemd to work, it requires at least CAP_SYS_ADMIN. For the shutdown support to work, I had to run the containers in privileged mode. There's too much work to figure out an exact list of capabilities and there's no guarantee as privileged provides more privileges than enabling all the supported capabilities.

The Dockerfiles are ERB templates which are rendered by kitchen-docker. There's a couple of variables:

 * public_key - kitchen-docker already has this defined, whether you're using the generated keys or you're using static keys
 * chef_version

chef_version by itself isn't defined in kitchen-docker, but the ERB context includes all the variables passed to the driver config, therefore you have a lot of flexibility.

Example:

```yml
driver:
  name: docker
  chef_version: 13.2.20

platforms:
- name: centos-6.8
  driver_config:
    dockerfile: "../centos-6.8"
```

For a development machine, I use Docker in a VM even for a host that supports it natively, therefore the SSH inside the container *is* a hard dependency. The reason for this statement is the fact that the volumes feature essentially provide [root access to the host](http://reventlov.com/advisories/using-the-docker-command-to-root-the-host) for all the users who have access to the Docker socket.

## Monkey-patching the docker driver

[This article](https://medium.com/brigade-engineering/reduce-chef-infrastructure-integration-test-times-by-75-with-test-kitchen-and-docker-bf638ab95a0a) explains the basics of speeding up kitchen-docker. Even though patching the driver isn't necessary, docker exec is much faster than SSH, and the containers are removed in a clean way. I think Docker got better regarding the resource leaks, but I wouldn't put that to the test.

```ruby
require 'kitchen/driver/docker'

module Kitchen
  module Driver
    class Docker < Kitchen::Driver::SSHBase
      # monkey-patch kitchen login to use docker exec instead of ssh
      def login_command(state)
        LoginCommand.new 'docker', ['exec', '-it', state[:container_id], 'su', '-', 'kitchen']
      end

      # monkey-patch kitchen destroy
      def rm_container(state)
        cont_id = state[:container_id]
        docker_command "exec #{cont_id} poweroff"
        docker_command "wait #{cont_id}"
        docker_command "rm #{cont_id}"
      end
    end
  end
end
```

It can be easily loaded with something like:

```yml
# <% load "#{File.dirname(__FILE__)}/../kitchen_docker.rb" %>
---
driver:
  name: docker
```

## How to turn your Test Kitchen into a fast-food joint

Having complex cookbooks with multiple code paths to test means you have to declare multiple test suites. Same applies if you target multiple platforms where you're looking for consistency. The issue is that by default Test Kitchen runs everything sequentially, therefore it means you don't get any benefit from a multi-core CPU.

Test Kitchen also supports a concurrent mode, but Unfortunately this isn't documented in a very visible way. Going at ludicrous speed is easy as the only thing you need to do is to pass the "-c" flag.

Example:

```bash
kitchen create -c
kitchen converge -c
kitchen verify -c
kitchen destroy -c
```

By default, the concurrency limit is at 9999 which is a reasonable value given the fact that it's unlikely to have so many cores. The concurrency flag accepts a numeric value to indicate the number of threads to run if the number of instances is too large for your CPU to handle.

The only drawback of the concurrent mode is the fact that the console output becomes virtually unreadable. However, the logs from .kitchen/logs are really valuable in this case and you may run a single suite at any point.

Example:

```bash
# run only the 'default' suite
kitchen converge default
kitchen verify default
```

## Caching commonly used chef_gem resources

If you have a commonly used gem installed by the chef_gem resource, it pays off to leverage the Dockerfiles to have that gem preinstalled in a Docker image. For example, interfacing with AWS may require aws-sdk-core to be available in your Chef cookbooks.

Adding something like this RUN command to your Dockerfile's speeds up the kitchen converge:

```
RUN /opt/chef/embedded/bin/gem install --no-user-install --install-dir \
  /opt/chef/embedded/lib/ruby/gems/2.1.0 aws-sdk-core
```

If you need a specific gem version, it may be specified like `aws-sdk-core:2.2.34`.

Another advantage of baking Ruby gems into Docker images is the fact that it removes the need to download stuff from rubygems.org which is useful when the service is experiencing hiccups.

## Preinstalling busser, busser-serverspec, and serverspec

Using Test Kitchen verifier with a busser is a repetitive and time wasting activity. It also depends on rubygems.org. In this example I'm using the serverspec busser, but it should be applicable for the rest as well.

Drop another layer using a RUN command like this:

```
# setup busser/serverspec to speed up kitchen verify
RUN su - kitchen -c 'BUSSER_ROOT="/tmp/verifier"; export BUSSER_ROOT; \
  GEM_HOME="/tmp/verifier/gems"; export GEM_HOME; \
  GEM_PATH="/tmp/verifier/gems"; export GEM_PATH; \
  GEM_CACHE="/tmp/verifier/gems/cache"; export GEM_CACHE; \
  /opt/chef/embedded/bin/gem install --no-rdoc --no-ri \
  --no-format-executable -n /tmp/verifier/bin --no-user-install \
  busser busser-serverspec serverspec'
```

This should setup all the required Ruby gems to have them ready for a `kitchen verify`.
