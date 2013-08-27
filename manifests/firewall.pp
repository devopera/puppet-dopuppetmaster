class dopuppetmaster::firewall (

  # class arguments
  # ---------------
  # setup defaults

  # end of class arguments
  # ----------------------
  # begin class

) {

  @docommon::fireport { '08140 Puppetmaster Service':
    protocol => 'tcp',
    port => '8140',
  }
  @docommon::fireport { '08081 PuppetDB Service':
    protocol => 'tcp',
    port => '8081',
  }

}
