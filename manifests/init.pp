class dopuppetmaster (

  # class arguments
  # ---------------
  # setup defaults

  $user,
  $group = 'puppet',

  $puppet_repo_source = undef,
  $puppet_repo_provider = 'git',
  $puppet_repo_path = '/etc/puppet',

  # define the default environments for this puppetmaster
  $environments = {
    'production' => {
      comment => 'production is the default environment',
      manifest => '$confdir/manifests/site.pp',
    },
  },
  
  # enable environments, disabled by default in Puppet >= 3.5.1
  $environmentpath = '$confdir/environments',

  # by default merge this repo into the current puppet config
  $puppet_repo_merge = true,
  
  # open up firewall port and monitor
  $firewall = true,
  $monitor = true,

  # by default, split the ssl dirs so the new puppetmaster can connect to its old puppetmaster
  $masterssl_name = 'masterssl',
  
  # by default, use original puppet master
  $master_use_original = true,

  # setup puppetdb and stored configs,
  $use_puppetdb = true,

  # end of class arguments
  # ----------------------
  # begin class

) {

  # open firewall ports and monitor
  if ($firewall) {
    class { 'dopuppetmaster::firewall' : }
  }
  if ($monitor) {
    class { 'dopuppetmaster::monitor' : }
  }

  # if we've got a message of the day, include
  @domotd::register { "Puppetmaster(8140)" : }
  @domotd::register { "PuppetDB(8081)" : }  

  # install puppet master package, run puppet master on startup
  case $operatingsystem {
    # when settings names, can't assume that puppetdb is included
    centos, redhat, fedora: {
      $package_name = 'puppet-server'
      $service_name = 'puppetmaster'
    }
    ubuntu, debian: {
      $package_name = 'puppetmaster'
      $service_name = 'puppetmaster'
    }
  }
  package { 'install-puppet-master':
    name => $package_name,
    ensure => 'present',
  }

  # install puppet testing gems
  package { ['rspec', 'mocha']:
    ensure   => 'present',
    provider => 'gem',
  }

  # setup repo
  if ($puppet_repo_source != undef) {
  
    # setup vars
    $filepath = $puppet_repo_path
    $creates_dep = ".${puppet_repo_provider}"
    $tmp_puppet_folder = '/tmp/puppet-old-etc'
    
    # if a directory exists (and it's not a repo) on the file path, move it and create a new one (with perms) but keep it empty
    exec { 'move-puppet-collision':
      path => '/bin:/usr/bin',
      command => "mv ${filepath} ${tmp_puppet_folder} && chown -R ${user}:${group} ${tmp_puppet_folder} && mkdir ${filepath} && chown ${user}:${group} ${filepath} && chmod 6755 ${filepath}",
      onlyif => "test -d ${filepath} && test ! -d ${filepath}/${creates_dep}",
      require => Package['install-puppet-master'],
    }->

    # can't just use stickdir here because it creates a dependency cycle
    #docommon::stickydir { 'dopuppetmaster-sticky-etc-puppet' :
    #  filename => "${filepath}",
    #  user => $user,
    #  group => $group,
    #  recurse => true,
    #}->
    # set the sticky permissions on that directory
    docommon::setfacl { 'dopuppetmaster-sticky-etc-puppet' :
      filename => "${filepath}",
      acl => "-dm u::rwx -m g::r-x -m o::---",
    }->
    # recursively set the permissions only on directories (because files are a git-mixture of 644 and 755)
    docommon::setperms { 'dopuppetmaster-sticky-etc-puppet' :
      filename => "${filepath}",
      user => $user,
      group => $group,
      mode => false,
      recurse => true,
    }->

    # checkout the repo into target path
    dorepos::getrepo { 'puppet':
      provider => $puppet_repo_provider,
      # get path: find the first part of the string before the last slash that's followed by a character
      path => regsubst($filepath, '^(.+)/(.+)$', '\1'),
      source => $puppet_repo_source,
      provider_options => '--recursive',
      require => [Class['dorepos'], Package['install-puppet-master']],
      user => $user,
      group => $group,
      # don't force all the script files to +x bit
      force_perms_onsh => false,
      # don't update the repo if already there
      force_update => false,
      # do put all the submodules on their master branch
      submodule_branch => 'master',
      force_submodule_branch => true,
    }

    if ($puppet_repo_merge) {
      # merge files from old into new if an 'old' exists (we've just moved it)
      exec { 'copy-puppet-collision':
        path => '/bin:/usr/bin',
        command => "cp -R /tmp/puppet-old-etc/* ${filepath}",
        user => $user,
        group => $group,
        onlyif => "test -d /tmp/puppet-old-etc",
        require => Dorepos::Getrepo['puppet'],
        before => File['common-puppet-symlink'],
      }
    }
    
  } else {
    $filepath = '/etc/puppet'
  }

  # create symlink in user's home directory
  file { 'common-puppet-symlink':
    path => "/home/${user}/puppet",
    ensure => 'link',
    target => "${filepath}",
    require => [Package['install-puppet-master']],
  }->
  
  # create a service (and auto-start) with exactly the same name as the one that puppetdb::master::config looks for
  # which stops puppetdb::master::config re-creating it
  service { "${service_name}" :
    ensure => running,
    enable => true,
    tag => 'service-sensitive',
  }

  # use the template to generate a new puppet.conf and restart puppetmaster
  file { 'setup-puppetmaster-conf' :
    path => '/etc/puppet/puppet.conf',
    content => template('dopuppetmaster/puppet.conf.erb'),
    owner => $user,
    group => $group,
    notify => Service["${service_name}"],
  }

  # optionally setup puppetDB
  if (use_puppetdb) {
    # configure puppetDB and its underlying database
    class { 'puppetdb':
      database => 'embedded',
      # raise heap memory limit from 192m to 512m
      java_args => { '-Xmx' => '512m' },
      require => [File['setup-puppetmaster-conf']],
    }->
    
    # Configure the puppet master to use puppetdb
    class { 'puppetdb::master::config':
      # don't put lines into puppet.conf (because it's versioned and dynamically generated)
      manage_storeconfigs => false,
      # don't check the connection because it fails on the nth run
      strict_validation => false,
    }->
    # puppetdb module creates config owned by root, but change to $user
    exec { 'puppetdb-fix-config-ownership' :
      path => '/bin:/sbin:/usr/bin',
      command => "chown ${user}:puppet /etc/puppet/puppetdb.conf",        
    }->

    # Ensure the puppetmaster service is running to initially generate its certs
    exec { 'puppetmaster-pre-regen-start' :
      path => '/bin:/sbin:/usr/bin',
      command => "service ${service_name} start",
      creates => "/var/lib/puppet/${masterssl_name}/certs/ca.pem",
    }->
    # Force puppetdb to regenerate its certificate and restart the service
    exec { 'puppetmaster-regen-ssl' :
      path => '/bin:/usr/sbin:/usr/bin',
      command => 'rm -rf /etc/puppetdb/ssl && puppetdb-ssl-setup -f',
      # notify didn't produce a consistent state after restart
      # notify => [Service['puppetdb'], Service["${service_name}"]],
    }->
    # restart puppetdb, then puppetmaster
    exec { 'puppetmaster-restart-after-puppetdb' :
      path => '/sbin',
      command => "service ${::puppetdb::params::puppetdb_service} restart && service ${service_name} restart",
      tag => 'service-sensitive',
    }
    
    # use resource collector to make puppetdb service-sensitive
    Service <| title == "${::puppetdb::params::puppetdb_service}" |> {
      tag => 'service-sensitive',
    }
  }
  
  # don't forget to remove /tmp/puppet-old-etc if it exists
  exec { 'delete-puppet-old' :
    path => '/bin:/usr/bin',
    command => "rm -rf /tmp/puppet-old-etc",
    onlyif => "test -d /tmp/puppet-old-etc",
    require => [File['setup-puppetmaster-conf']],
  }
}
