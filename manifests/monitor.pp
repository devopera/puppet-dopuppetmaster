class dopuppetmaster::monitor (

  # class arguments
  # ---------------
  # setup defaults

  # end of class arguments
  # ----------------------
  # begin class

) {

  @nagios::service { "int:process_puppetmaster-dopuppetmaster-${::fqdn}":
    check_command => "check_nrpe_procs_puppetmaster",
  }
  @nagios::service { "int:process_puppetdb-dopuppetmaster-${::fqdn}":
    check_command => "check_nrpe_procs_puppetdb",
  }

}
