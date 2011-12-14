vCloud Datacenter Operation Utilities (a.k.a. VCDKIT)
=====================================================

What is VCDKIT?
---------------

VCDKIT is a set of utility scripts which aims to help operations of
large scale [vCloud Datacenter](http://www.vmware.com/solutions/cloud-computing/public-cloud/vcloud-datacenter-services.html).
It is entirely written in Ruby for easier/flexible deployments.

With VCDKIT, vCloud administrator can do:

* Backup & restore vApp meta-data 
* Associate hardware errors(ESX host failure, Datastore failure) with affected vCD organization(tenant)
* Track peak Windows VM count for monthly license billing

Installation
---------------

### Install Instruction for CentOS6-minimal install image

* Create vcdkit user for installation and deployment

        [root@vcdkit-01 ~]# useradd -g wheel vcdkit
        [root@vcdkit-01 ~]# passwd vcdkit
        [root@vcdkit-01 ~]# yum install sudo git
        [root@vcdkit-01 ~]# vi /etc/sudoers # uncomment line for wheel group

* Get the latest code from `github` and run install script

        [vcdkit@vcdkit-01 ~]$ git clone https://k1fukumoto@github.com/k1fukumoto/vcdkit2.git
        [vcdkit@vcdkit-01 ~]$ cd vcdkit2
        [vcdkit@vcdkit-01 vcdkit2]$ script/vcdkit-install.sh

* Download Oracle Instant Client from [Oracle site](http://www.oracle.com/technetwork/database/features/instant-client/index-097480.html) and install

        [vcdkit@vcdkit-01 Download]$ sudo rpm -ivh \
            oracle-instanceclient11.2-basic-11.2.0.3.0-1.x86_64.rpm \
            oracle-instanceclient11.2-devel-11.2.0.3.0-1.x86_64.rpm

* Download and install Ruby Oracle interface (OCI8)

        [vcdkit@vcdkit-01 Download]$ wget http://rubyforge.org/frs/download.php/74997/ruby-oci8-2.0.6.tar.gz
        [vcdkit@vcdkit-01 Download]$ tar zxvf ruby-oci8-2.0.6.tar.gz
        [vcdkit@vcdkit-01 Download]$ cd ruby-oci8-2.0.6
        [vcdkit@vcdkit-01 ruby-oci8-2.0.6]$ export LD_LIBRARY_PATH=/usr/lib/oracle/11.2/client64/lib
        [vcdkit@vcdkit-01 ruby-oci8-2.0.6]$ ruby setup.rb config
        [vcdkit@vcdkit-01 ruby-oci8-2.0.6]$ make
        [vcdkit@vcdkit-01 ruby-oci8-2.0.6]$ sudo make install

* Download VIX API from [VMware site](https://www.vmware.com/support/developer/vix-api) and install

        [vcdkit@vcdkit-01 Download]$ sudo sh VMware-VIX-1.11.0-471780.x86_64.bundle
        [vcdkit@vcdkit-01 Download]$ cp /usr/lib/vmware-vix/vix-perl.tar.gz .
        [vcdkit@vcdkit-01 Download]$ tar zxvf vix-perl.tar.gz
        [vcdkit@vcdkit-01 download]$ cd vix-perl
        [vcdkit@vcdkit-01 vix-perl]$ sudo perl -MCPAN -eshell
        cpan[1] > force install ExtUtils::MakeMaker
        [vcdkit@vcdkit-01 vix-perl]$ perl Makefile.PL
        [vcdkit@vcdkit-01 vix-perl]$ make
        [vcdkit@vcdkit-01 vix-perl]$ sudo make install

* Setup VCDKIT, LD_LIBRARY_PATH variable and search path to script directory

        export LD_LIBRARY_PATH=/usr/lib/oracle/11.2/client64/lib:/usr/lib/vmware-vix
        export VCDKIT=/home/vcdkit/vcdkit2
        export PATH=$VCDKIT/script:$VCDKIT/cron:$PATH         

* Setup Server setting. Edit `$VCDKIT/config/vcloud_servers.yml`

* Create a small dummy vApp template like as following one:
  * Organization: Admin
  * Org VDC: Basic - Admin
  * vApp Template
    * Name : VCDKITTEST-TMPL
    * VM Name: VCDKITTEST-VM-01
    * VM Spec: 1 vCPU x 4MB RAM x 4MB Disk (no network connection)

* Edit test configuration to match vApp information created above. Edit `$VCDKIT/test/config.yml`      

* Test installation
        
        [vcdkit@vcdkit-01 vcdkit2]$ cd test
        [vcdkit@vcdkit-01 test]$ sudo gem install rake
        [vcdkit@vcdkit-01 test]$ rake

* (Optional) Setup mailer configuration. Edit `$VCDKIT/config/mailer.xml`
* Setup cron jobs. Modify and install `$VCDKIT/cron/crontab.conf`

### Install Instruction for Micro Cloud Foundry

* Install [Micro Cloud Foundry](https://www.cloudfoundry.com/micro)
* `ssh` login to Micro Cloud Foundry (Following example is assuming 
  you pick `mylab` as your domain. See Micro Cloud Foundry installation 
  notes above for more details) and create a new user.

        $ ssh vcap@api.mylab.cloudfoundry.me
        vcap@micro:~$ sudo adduser --ingroup admin vcdkit
        vcap@micro:~$ exit

* `ssh` login as a new user and get the latest code from `github`

        vcdkit@micro:~$ git clone https://k1fukumoto@github.com/k1fukumoto/vcdkit2.git

* Setup `PATH` to refer pre-installed Ruby runtime

        # chmod a+rx /var/vcap/bosh
        export PATH=/var/vcap/bosh/bin:$PATH

* As root, install VMC command

        root@micro:/# gem install vmc

* Install mysql adapter, with explictly supplying mysql directory path

        root@micro:/# gem install dm-mysql-adapter -- --with-mysql-dir=/var/vcap/data/packages/mysqlclient/1

* Deploy vcdkit to Micro Cloud Foundry appliance

        vcdkit@micro:~$ cd vcdkit2
        vcdkit@micro:~/vcdkit2$ vmc target http://api.mylab.cloudfoundry.me
        Succesfully targeted to [http://api.mylab.cloudfoundry.me]

        bob@micro:~/vcdkit$ vmc register
        Email: bob@vmware.com
        Password: ********
        Verify Password: ********
        Creating New User: OK
        Successfully logged into [http://api.kfactory.cloudfoundry.me]

        bob@micro:~/vcdkit$ bundle pack
        bob@micro:~/vcdkit$ vmc push vcdkit
        Would you like to deploy from the current directory? [Yn]: 
        Application Deployed URL ["vcdkit.kfactory.cloudfoundry.me"]: 
        Detected a Sinatra Application, is this correct? [Yn]: 
        Memory Reservation ("64M", "128M", "256M", "512M", "1G") ["128M"]: 
        Creating Application: OK
        Would you like to bind any services to 'vcdkit'? [yN]: y
        The following system services are available
        1: mongodb
        2: mysql
        3: postgresql
        4: rabbitmq
        5: redis
        Please select one you wish to provision: 2
        Specify the name of the service ["mysql-53f8e"]: 
        Creating Service: OK
        Binding Service [mysql-53f8e]: OK
        Uploading Application:
        Checking for available resources: OK
        Processing resources: OK
        Packing application: OK
        Uploading (4M): OK   
        Push Status: OK
        Staging Application: OK
        Starting Application: OK

* Go to portal site http://vcdkit.mylab.cloudfoundry.me

Configuration
---------------

### Connection Settings

1.  Click `Change Settings` link in `HOME` page
1.  Appropriately change connection settings for vCD and vCenter.
    For vCD, ensure to specify System Organization account. 
