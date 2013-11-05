class dopuppetmaster::monitor (

  # class arguments
  # ---------------
  # setup defaults

  # end of class arguments
  # ----------------------
  # begin class

) {

  @nagios::service { "int:process_puppetmaster-dopuppetmaster-${::fqdn}":
    check_command => "check_procs!1:!1:!'puppet master'",
  }
  @nagios::service { "int:process_puppetdb-dopuppetmaster-${::fqdn}":
    check_command => "check_procs!1:!1:!puppetdb",
  }

}
