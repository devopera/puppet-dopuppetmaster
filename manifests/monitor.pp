class dopuppetmaster::monitor (

  # class arguments
  # ---------------
  # setup defaults

  $puppet_server = 'puppetmaster',

  # end of class arguments
  # ----------------------
  # begin class

) {

  case $puppet_server {
    'puppetserver': {
      $check_name = 'puppetserver'
    }
    default: {
      $check_name = 'puppetmaster'
    }
  }

  @nagios::service { "int:process_${check_name}-dopuppetmaster-${::fqdn}":
    check_command => "check_nrpe_procs_${check_name}",
  }
  @nagios::service { "int:process_puppetdb-dopuppetmaster-${::fqdn}":
    check_command => "check_nrpe_procs_puppetdb",
  }

}
