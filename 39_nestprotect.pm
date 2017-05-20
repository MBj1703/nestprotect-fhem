# $Id: 39_nestprotect.pm 14 2017-05-20 21:30:00Z mitch $
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


=pod
=item summary    module for nestprotect smoke & co detector
=item summary_DE Modul für NestProtect Rauch und CO Warner
=begin html

<a name="nestprotect"></a>
<h3>nestprotect</h3>
<ul>
  Defines a device to integrate a nestprotect detector into fhem.<br><br>

  Notes:
  <ul>
    <li>JSON has to be installed on the FHEM host.</li>
    <li>Perl Module Encode has to be installed on the fhem host. (Ubuntu: liblatex-encode-perl)</li></ul><br><br>
    You need a developer account at nest (developers.nest.com)<br>
    <ul><li>in the dev account create a product</li>
    <li>leave the Redirect URI empty</li>
    <li>give permission to smoke+co alarm</li></ul>
    <br>
    Now you can select your product. At the product view you will find your Product ID, the Product Secret and the Authorization URL.<br>
    The Product ID and the Product Secret is needed later as attribut for the device.<br><br>
    
    Next you have to create your PIN. Just copy your Authorization URL into your Browser<br>
    Now you will get a site "Works with Nest" where you have to click "Annehmen" and you will get your PIN finaly<br><br>
    
    After defining your device you need to set ProductID and ProductSecret Attributs first!<br>
    Next you need to "set token" to get a valid token from the API<br><br>
    
    The module will create a additional at device ($name.Poll) which runs "get update" every 5 minutes.<br>
    This is a workaround, because Interval is not implemented yet.<br>
    
    <br><br>

  <a name="nestprotect_Define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; nestprotect &lt;PIN&gt;</code><br>
    <br>

    Defines a nestprotect device.<br><br>

    Examples:
    <ul>
      <code>define NestWohnzimmer nestprotect ABCDEFG</code><br>
    </ul>
  </ul><br>

  <a name="nestprotect_Readings"></a>
  <b>Readings</b>
  <ul>
    <li>battery<br>
      the battery level. (ok/replace)</li>
    <li>co_status<br>
      the CO level. (ok/warning/emergency)</li>
    <li>device_id<br>
      your Device ID.</li>
    <li>language<br>
      Your language in the nestprotect.</li>
    <li>last_seen<br>
      last connection to nest cloud.</li>
    <li>name<br>
      the name of your nestprotect.</li>
    <li>online<br>
      nestprotect is connected to internet. (1/0)</li>
    <li>smoke_status<br>
      the smoke level. (ok/warning/emergency)</li>
    <li>softwareversion<br>
      nestprotect software version. (1/0)</li>
    <li>token<br>
      your API token.</li>
    <li>token_expire_in<br>
      your APi token expire time in seconds. (you need to renew after this time)</li>
  </ul><br>

  <a name="harmony_Internals"></a>
  <b>Internals</b>
  <ul>
    <li>PIN<br>
      your PIN to generate the token.</li>
  </ul><br>


  <a name="harmony_Set"></a>
  <b>Set</b>
  <ul>
    <li>update<br>
      request an update at the nest API to refresh readings</li>
      
  </ul><br><br>

  <a name="harmony_Get"></a>
  <b>Get</b>
  <ul>
    <li>token<br>
      request your token fom the nest API.<br>
      this is needed only once after creating the device.</li>
  </ul><br><br>


  <a name="nestprotect_Attr"></a>
  <b>Attributes</b>
  <ul>
    <li>Interval<br>
    interval time in seconds to refresh readings (set update) -> not implemented yet</li>
    <li>ProductID<br>
    please enter your Product ID form your product at the dev account</li>
    <li>ProductSecret<br>
    please enter your ProductSecret form your product at the dev account</li>
    <li>disable<br>
    1 = disable the module</li>
  </ul>
</ul>

=end html
=cut
