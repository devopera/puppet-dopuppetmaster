[devopera](http://devopera.com)-[dopuppetmaster](http://devopera.com/module/dopuppetmaster)
=====================

The Puppetmaster is the central tenet of a puppet infrastructure.  This Devopera puppet module configures a puppetmaster that is itself puppetable, uses stored configs in PuppetDB and optionally links to Nagios for monitoring.

Changelog
---------

2014-01-15

 * Replaced nested $puppet_repo with $puppet_repo_X vars to handle defaults properly

2013-08-27

 * Moved across to docommon::fireport alias for opening firewall ports

Usage
-----

Setup a basic puppetmaster, replace local /etc/puppet directory with Devopera repo as starting point

    class { 'dopuppetmaster' :
      user => $user,
      # setup puppetmaster with devopera-puppet open read-only repo
      puppet_repo_source => 'https://github.com/devopera/puppet.git',
      environments => {
        'production' => {
           comment => 'production is the default environment',
           manifest => '$confdir/manifests/devopera.site.pp',
        },
        'devopera' => {
           comment => 'for all devopera VMs and builds',
           manifest => '$confdir/manifests/devopera.site.pp',
        },
      },
      # set this machine up as its own puppetmaster, i.e. not use original
      master_use_original => false,
      require => Class['dorepos'],
    }

Copyright and License
---------------------

Copyright (C) 2012 Lightenna Ltd

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
