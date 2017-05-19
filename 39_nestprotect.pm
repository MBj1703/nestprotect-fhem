# $Id: 39_nestprotect.pm 13 2017-05-18 18:10:00Z mbj1703 $
# 
# vielen Dank für die großartige Hilfe von CoolTux, amenomade, dev0 und Thorsten Pferdekaemper
# ohne euch hätte ich das nie hinbekommen
# 

package main;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);    
use Encode qw(decode encode);
#use HttpUtils;
use JSON;

sub
nestprotect_Initialize($)
{
  my ($hash) = @_;

  #$hash->{ReadFn}   = "nestprotect_Read";

  $hash->{DefFn}    = "nestprotect_Define";
  #$hash->{NOTIFYDEV} = "global";
  #$hash->{NotifyFn} = "nestprotect_Notify";
  $hash->{UndefFn}  = "nestprotect_Undefine";
  $hash->{SetFn}    = "nestprotect_Set";
  $hash->{GetFn}    = "nestprotect_Get";
  $hash->{AttrFn}   = "nestprotect_Attr";
  $hash->{AttrList} = "ProductID ".
                      "ProductSecret ".
                      "Interval ".
			          "disable:1,0 ".
			          $readingFnAttributes;  
}

sub
nestprotect_Define($$)
{
  my ($hash, $def) = @_;

  my @a = split("[ \t][ \t]*", $def);

  return "Usage: define <name> nestprotect pin"  if(@a <3);
  return "please check if cURL is installed" unless( -X "/usr/bin/curl" );

  my $name = $a[0];
  my $pin = $a[2];
  
  $hash->{NAME} = $name;
  $hash->{PIN} = $pin;

  #erlaubt nur eine Definition
  my $d = $modules{$hash->{TYPE}}{defptr};
  return "$hash->{TYPE} device already defined as $d->{NAME}." if( defined($d) && $name ne $d->{NAME} );
  $modules{$hash->{TYPE}}{defptr} = $hash;
  
  my $nesttoken = ReadingsVal($name, "token", "");

  $hash->{STATE} = 'active';
  
  $attr{$name}{"event-on-change-reading"} = ".*";
  $attr{$name}{"Interval"} = "300";
  
  fhem("define $name.Poll at +*00:05 set $name update");
  
  #InternalTimer(gettimeofday()+2, "nestprotect_GetUpdate", $hash, 0);
  
  Log3 $name, 3, "nestprotect ($name) defined";
  
  return undef;
}

sub
nestprotect_Undefine($$)
{
  my ($hash, $arg) = @_;

  delete $modules{$hash->{TYPE}}{defptr};
  RemoveInternalTimer($hash);

  return undef;
}

sub
nestprotect_Set($$@)
{
  my ($hash, $name, $cmd) = @_;
  
  my $nesttoken = ReadingsVal($name, "token", "");

  my $list = "update:noArg";

  if ( $cmd eq 'update' ) {
  
  Log3 $name, 5, "$nesttoken";
  
  if ($nesttoken eq "") {
   return "no token, can not do update";
   $hash->{STATE} = 'no token';
   Log3 $name, 5, "update failed, please get token first";
   }
  
    $hash->{STATE} = 'updating';
    Log3 $name, 5, "updating";
       
       my $command = 'curl -s -L -H "Content-Type: application/json" -H "Authorization: Bearer '. $nesttoken.'" -X GET "https://developer-api.nest.com/"';
       
       Log3 $name, 5, "curl command sent";
       
       my $output = qx($command);

       my $result = decode_json ($output);
       
       Log3 $name, 5, "$output";
       
       #my $deviceid = $result->{smoke_co_alarms};
       my $deviceid = (keys(%{$result->{devices}{smoke_co_alarms}}))[0];
       
       readingsSingleUpdate($hash, "device_id", $deviceid, 0);
       
       Log3 $name, 5, "device id fuer $name lautet $deviceid";

       my $nestname = $result->{devices}->{smoke_co_alarms}->{$deviceid}->{name};
       my $nestlocale = $result->{devices}->{smoke_co_alarms}->{$deviceid}->{locale};
       my $nestsoftware = $result->{devices}->{smoke_co_alarms}->{$deviceid}->{software_version};
       my $nestisonline = $result->{devices}->{smoke_co_alarms}->{$deviceid}->{is_online};
       my $nestconection = $result->{devices}->{smoke_co_alarms}->{$deviceid}->{last_connection};
       my $nestbattery = $result->{devices}->{smoke_co_alarms}->{$deviceid}->{battery_health};
       my $nestco = $result->{devices}->{smoke_co_alarms}->{$deviceid}->{co_alarm_state};
       my $nestsmoke = $result->{devices}->{smoke_co_alarms}->{$deviceid}->{smoke_alarm_state};

       Log3 $name, 4, "nestprotect update done";

        my $reading2 = "name";
        my $reading3 = "language";
        my $reading4 = "softwareversion";
        my $reading5 = "online";
        my $reading6 = "last_seen";
        my $reading7 = "battery";
        my $reading8 = "co_status";
        my $reading9 = "smoke_status";

        readingsBeginUpdate($hash);
        
        readingsBulkUpdate($hash, $reading2, $nestname, 0);
        readingsBulkUpdate($hash, $reading3, $nestlocale, 0);
        readingsBulkUpdate($hash, $reading4, $nestsoftware, 0);
        readingsBulkUpdate($hash, $reading5, $nestisonline, 1);
        readingsBulkUpdate($hash, $reading6, $nestconection, 1);
        readingsBulkUpdate($hash, $reading7, $nestbattery, 1);
        readingsBulkUpdate($hash, $reading8, $nestco, 1);
        readingsBulkUpdate($hash, $reading9, $nestsmoke, 1);
        
        readingsEndUpdate($hash, 1);
        
        if ($reading5 = '1') {
           readingsSingleUpdate($hash, "state", "connected", 1);
        } else {
           readingsSingleUpdate($hash, "state", "offline", 1);
        }
        
        #my $interval = AttrVal($name, "Interval", "");
        #$hash->{INTERVAL} = $interval;
        $hash->{STATE} = "updated";
        
        #RemoveInternalTimer($hash);
	    #InternalTimer(gettimeofday()+$hash->{INTERVAL}, "nestprotect_Update", $hash);
    
       
    return undef;
    
    }

  return "Unknown argument $cmd, choose one of $list";
}

sub
nestprotect_Get($$@)
{
  my ($hash, $name, $cmd) = @_;
  
  my $nesttoken = ReadingsVal($name, "token", "");
  
  my $list = "token:noArg";

  if( $cmd eq 'token' ) {
  
    if ($nesttoken ne "") {
      return "token already provided";
      Log3 $name, 5, "token already provided";
    }
  
  my $pin = $hash->{PIN};
  
  my $clientid = AttrVal($name, "ProductID", "");
  my $productsecret = AttrVal($name, "ProductSecret", "");
  
  Log3 $name, 5, "ProductID: $clientid, ProductSecret: $productsecret";
  
  if ($clientid eq "") {
    return "please set ProductID as attribut";
    Log3 $name, 5, "ProductID not set in attributs";
    $hash->{STATE} = "ProductID missing";
    } elsif ($productsecret eq "") {
    return "please set ProductSecret as attribut";
    Log3 $name, 5, "ProductSecret not set in attributs";
    $hash->{STATE} = "ProductSecret missing";
    }

my $tokenrequest = 'curl -X POST -d "code='.$pin.'&client_id='.$clientid.'&client_secret='.$productsecret.'&grant_type=authorization_code" "https://api.home.nest.com/oauth2/access_token"';
  
  Log3 $name, 5, "token requested";
  
  my $tokentask = qx($tokenrequest);
  
  my $tokenfeedback = decode_json $tokentask;
  
  Log3 $name, 5, "$tokentask";
  
  my $error = $tokenfeedback->{error};
  
         if ($error eq "oauth2_error") {
           readingsSingleUpdate($hash, "state", "authorization code not found", 1);
           return "authorization code not found, please double check pin";
           return undef;
        }
  
  my $nesttoken = $tokenfeedback->{access_token};
  my $nesttokenexpire = $tokenfeedback->{expires_in};
  
  readingsSingleUpdate($hash, "token", $nesttoken, 0);
  readingsSingleUpdate($hash, "token_expire_in", $nesttokenexpire, 0);
  
  $hash->{TOKEN} = $nesttoken;
  $hash->{STATE} = "token done";

    return undef;

  }
  
  return "Unknown argument $cmd, choose one of $list";
  
}

sub
nestprotect_Attr($$$)
{
   my ($cmd,$name,$attr_name,$attr_value) = @_;

   Log3 $name, 5, "enter attr $name: $name, attrName: $attr_name";
	
   Log3 $name, 5, "exit attr";
   
  return;
}        

1;
