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

* Install [Micro Cloud Foundry](https://www.cloudfoundry.com/micro)
* `ssh` login to Micro Cloud Foundry (Following example is assuming 
  you pick `mylab` as your domain. See Micro Cloud Foundry installation 
  notes above for more details) and create a new user.

        $ ssh vcap@api.mylab.cloudfoundry.me
        vcap@micro:~$ sudo adduser --ingroup admin bob
        vcap@micro:~$ exit

* `ssh` login as a new user and get the latest code from `github`

        bob@micro:~$ git clone https://k1fukumoto@github.com/k1fukumoto/vcdkit.git

* Setup `PATH` to refer pre-installed Ruby runtime

        # chmod a+rx /var/vcap/bosh
        export PATH=/var/vcap/bosh/bin:$PATH

* As root, install VMC command

        root@micro:/# gem install vmc

* Instll mysql adapter, with explictly supplying mysql directory path

        root@micro:/# gem install dm-mysql-adapter -- --with-mysql-dir=/var/vcap/data/packages/mysqlclient/1

* Deploy vcdkit to Micro Cloud Foundry appliance

        bob@micro:~$ cd vcdkit
        bob@micro:~/vcdkit$ vmc target http://api.mylab.cloudfoundry.me
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
