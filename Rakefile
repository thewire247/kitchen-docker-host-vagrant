require_relative 'chef_version'

# workaround for https://github.com/test-kitchen/kitchen-vagrant/issues/69
# and https://github.com/test-kitchen/test-kitchen/issues/350
def kitchen_vagrant_exec(cmd)
  vdirs = Dir['.kitchen/**/Vagrantfile'].map { |dir| File.dirname dir }
  vdirs.each do |vd|
    Dir.chdir(vd) do
      sh "vagrant #{cmd}"
    end
  end
end

## Tasks ported from the previous vagrant-berkshelf implementation

desc 'kitchen destroy and cleanup'
task :clean do
  system 'kitchen destroy'
  rm_rf '.kitchen'
  rm_f %w[Berksfile.lock Gemfile.lock]
end

desc 'Clears the Squid cache'
task :clear do
  sh 'kitchen exec -c "sudo service squid stop && sleep 5 && '\
  'sudo rm -rf /var/spool/squid && '\
  'sudo mkdir /var/spool/squid && '\
  'sudo chown squid:squid /var/spool/squid && '\
  'sudo squid -z && sleep 5 && sudo service squid start"'
end

desc 'Halts the box'
task :halt do
  kitchen_vagrant_exec 'halt'
end

namespace 'install' do
  desc 'Installs OS X runtime dependencies; requires brew and caskroom'
  task :osx do
    sh 'brew cask install virtualbox'
    sh 'brew cask install vagrant'
    sh 'brew cask install chefdk'
  end
end

desc 'Alias of converge'
task provision: %i[converge]

desc 'Recreates the machine from scratch and drops to a shell'
task redo: %i[clean provision ssh]

desc 'Reloads the box'
task :reload do
  kitchen_vagrant_exec 'reload'
end

begin
  # Rubocop stuff
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
  STDERR.puts 'Rubocop, or one of its dependencies, is not available.'
end

desc 'Login onto the box'
task :ssh do
  sh 'kitchen login'
end

desc 'Alias of converge'
task up: %i[converge]

## Test Kitchen specific

desc 'kitchen converge'
task :converge do
  require 'rubygems'

  sh 'bundle install'
  Gem.clear_paths

  kitchen_vagrant_exec 'up' unless Dir['.kitchen/**/Vagrantfile'].empty?
  sh 'kitchen converge'
  Rake::Task[:kdh_ip].execute
end

desc 'kitchen verify'
task :verify do
  sh 'kitchen verify'
end

desc 'kitchen verify && rubocop && foodcritic'
task test: %i[converge verify rubocop foodcritic]

desc 'Runs foodcritic'
task :foodcritic do
  sh "foodcritic --chef-version #{CHEF_VERSION} --progress --epic-fail any ."
end

desc 'Runs static code analysis tools'
task lint: %i[rubocop foodcritic]

desc 'Generates the .kdh-ip file'
task :kdh_ip do
  # get kitchen-docker-host IP from Veertu
  require 'ursa'

  ursa = Ursa.new
  ursa.tell(ursa.app('Veertu Desktop'), 'get {id,name} of every vm')
  machines = ursa.execute_script.split(',').collect(&:strip)

  vm_id = machines.index('kitchen-docker-host') - (machines.length / 2)
  vm_id = machines[vm_id]

  ursa.tell(ursa.app('Veertu Desktop'), %(get {ip} of vm id "#{vm_id}"))
  ip = ursa.execute_script.strip

  puts "Found IP #{ip} for VM ID #{vm_id}"
  File.write("#{ENV['HOME']}/.kdh-ip", "export KDH_IP=#{ip}\n")
end
