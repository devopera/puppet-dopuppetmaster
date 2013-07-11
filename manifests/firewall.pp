class dopuppetmaster::firewall (

  # class arguments
  # ---------------
  # setup defaults

  # end of class arguments
  # ----------------------
  # begin class

) {

  @firewall { '08140 Puppetmaster Service':
    protocol => 'tcp',
    port => '8140',
  }
  @firewall { '08081 PuppetDB Service':
    protocol => 'tcp',
    port => '8081',
  }

}
