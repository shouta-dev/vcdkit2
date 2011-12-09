#!/usr/bin/env perl

use lib qw{ blib/lib blib/auto blib/arch blib/arch/auto/VMware blib/arch/auto };

use Getopt::Std;
use POSIX qw(strftime);

use VMware::Vix::Simple;
use VMware::Vix::API::Constants;

getopt("hpvsl");

my $hostname = $opt_h;
my $vmname = $opt_v;
my $username = 'root';
my $password = $opt_p;
my $script = $opt_s;
my $logfile = $opt_l;

my $err;
my $esx;
my $vm;
my @vms;
my %procinfo;
my $exit_code;

open(LOG,">> $opt_l") or die "Cannot open log file";
sub __log {
  my ($sev,$msg) = @_;
  my $now = strftime('%Y-%m-%d %H:%M:%S',localtime);
  print LOG "$now | $sev | $msg\n";
}
sub info {
  __log 'INFO',shift;
}
sub error {
  $msg = shift;
  __log('ERROR',$msg);
  die $msg;
}

($err, $esx) = HostConnect(VIX_API_VERSION, 
			   VIX_SERVICEPROVIDER_VMWARE_VI_SERVER,
			   "https://$hostname/sdk",
			   443, # ignored
			   $username,
			   $password,
			   0, VIX_INVALID_HANDLE);
error("Failed to connect host: $err: ", GetErrorText($err)) if $err != VIX_OK;


@vms = FindRunningVMs($esx, 100);
$err = shift @vms;
error("Failed to find running VMs: $err: ", GetErrorText($err)) if $err != VIX_OK;

foreach (@vms) {
  next unless $_ =~ /$vmname/;

  ($err,$vm) = HostOpenVM($esx,$_,VIX_VMOPEN_NORMAL,VIX_INVALID_HANDLE);
  error("Failed to open VM $_: $err: ", GetErrorText($err)) if $err != VIX_OK;

  $err = VMLoginInGuest($vm,"Administrator",$password,0);
  error("Failed to login guest: $err: ". GetErrorText($err)) if $err != VIX_OK;

  ($err,%procinfo) = VMRunProgramInGuestEx($vm,$script,'',0,VIX_INVALID_HANDLE);
  error("Failed to run script $script: $err: ". GetErrorText($err)) if $err != VIX_OK;

  $exit_code = $procinfo{'EXIT_CODE'};

  ReleaseHandle($vm);
}

HostDisconnect($esx);
exit($exit_code);
