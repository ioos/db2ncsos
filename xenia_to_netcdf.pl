#!/usr/bin/perl

# This script reads from the database query, processes to hash and creates ncSOS/NODC compatible netcdf file

#note 'where m_date > now()' is based on EST/EDT which gives us a 4-5 hour window for latest obs in consideration, will need to add/subtract additional hours for other time zones

print `date`;

use strict;
use Config::IniFiles;
use DBI;

my $date_now = `date --date='6 hour ago' +%Y_%m_%d_%H`;
chomp($date_now);
#print "$date_now\n";
my $db_date_now = `date --date='6 hour ago' +%Y-%m-%dT%H:00:00`;
#my $db_date_now = `date +%Y-%m-%d`;
chomp($db_date_now);
#$db_date_now =~ s/T/ / ;
#print "$db_date_now\n";
#exit 0;

my $dir_monthly = "";
my $sql_date = "m_date >= timestamp '$db_date_now' - interval '6 hour' and m_date < timestamp '$db_date_now'";
my $id_suffix = "";

my ($start_date,$stop_date);

if ($ARGV[0] eq 'monthly') {
  $dir_monthly = "monthly/";
  $id_suffix = "_monthly";

  $start_date = `date --date='1 month ago' +%Y-%m-01`;
  chomp($start_date);
  $stop_date = `date +%Y-%m-01`;
  chomp($stop_date);
  print "$start_date:$stop_date\n";

  $sql_date = "m_date >= '$start_date' and m_date < '$stop_date'";

}


###################################################
open(FILE,"netcdf/station_list.txt");

foreach my $line(<FILE>) {

#min/max time
my ($min_time,$max_time);
my ($min_lat,$max_lat);
my ($min_lon,$max_lon);
my $min_vert = 0;
my $max_vert = 5;

my ($org_name,$org_url,$platform) = split(/,/,$line);
chomp($platform);
print $platform."\n";

#my $platform = @ARGV[0];

#####################
#config
#my $target_dir = '/home/xeniaprod/feeds/obsjson/all/latest_hours_24/';
my $target_dir = './netcdf'; #testing

#####################

#database connect
my $cfg=Config::IniFiles->new( -file => '/home/xeniaprod/config/dbConfig.ini');
my $db_name="xenia";
my $db_user=$cfg->val($db_name,'username');
my $db_passwd=$cfg->val($db_name,'password');
my $dbh = DBI->connect ( "dbi:Pg:dbname=$db_name", $db_user, $db_passwd);
if ( !defined $dbh ) {
       die "Cannot connect to database!\n";
       exit 0;
}

my %latest_obs = ();
my $r_latest_obs = \%latest_obs;

my %datelist = ();
my $r_datelist = \%datelist;

#################
#process sql to hash

#and m_date > strftime('%Y-%m-%dT%H:%M:%S','now','-24 hours') #sqlite

my $sql = qq{
select
     organization.description 
    ,organization.url 
    ,multi_obs.platform_handle
    ,platform.url
    ,obs_type.standard_name
    ,uom_type.standard_name
    ,m_date
    ,m_lon
    ,m_lat
    ,m_z
    ,m_value
    ,sensor.s_order
  from multi_obs
    left join platform on platform.platform_handle=multi_obs.platform_handle
    left join organization on organization.row_id=platform.organization_id
    left join m_type on m_type.row_id=multi_obs.m_type_id
    left join m_scalar_type on m_scalar_type.row_id=m_type.m_scalar_type_id
    left join sensor on sensor.row_id=multi_obs.sensor_id
    left join obs_type on obs_type.row_id=m_scalar_type.obs_type_id  
    left join uom_type on uom_type.row_id=m_scalar_type.uom_type_id  
    where $sql_date and multi_obs.platform_handle like '$platform'   
order by multi_obs.platform_handle,obs_type.standard_name,m_date;
};
   # where m_date > timestamp '$db_date_now' - interval '6 day' and m_date <= timestamp '$db_date_now' and multi_obs.platform_handle like '$platform'   
   # where m_date > timestamp '$db_date_now' - interval '6 hour' and m_date <= timestamp '$db_date_now' and multi_obs.platform_handle like '$platform'   
   # where m_date > timestamp '$db_date_now' - interval '8 day' and m_date <= timestamp '$db_date_now' - interval '1 day' and multi_obs.platform_handle like '$platform'   
   # where d_report_hour = '2013-08-26 05:00:00' and multi_obs.platform_handle like 'carocoops.CAP2.%'   
   # where m_date > now() - interval '3 day' and m_date <= now() - interval '2 day' and multi_obs.platform_handle like 'carocoops.CAP2.%'   
   # where m_date > now() - interval '1 day' and multi_obs.platform_handle like 'carocoops.CAP2.%'   
#  where m_date > now() - interval '1 day'
#where m_date > now() - interval '1 day' and multi_obs.platform_handle like 'scdnr.%'  
#where m_date > now() - interval '1 day' AND sensor.active=1 #JTC 2011-08-11
my $lastPlatform = "";
my $sth = $dbh->prepare($sql);
$sth->execute();

while (my (
    $org_description,
    $org_url,
    $platform_handle,
    $platform_url,
    $obs_type,
    $uom_type,
    $m_date,
    $m_lon,
    $m_lat,
    $m_z,
    $m_value,
    $sorder
  ) = $sth->fetchrow_array) {

#print "$platform_handle:$obs_type:$uom_type:$m_date:$m_z:$sorder:$m_value\n"; #debug
$platform_handle = lc($platform_handle);

$latest_obs{platform_list}{$platform_handle}{org_description} = $org_description;
$latest_obs{platform_list}{$platform_handle}{org_url} = $org_url;
$latest_obs{platform_list}{$platform_handle}{platform_url} = $platform_url;
$latest_obs{platform_list}{$platform_handle}{m_lon} = $m_lon;
$latest_obs{platform_list}{$platform_handle}{m_lat} = $m_lat;

$latest_obs{platform_list}{$platform_handle}{obs_list}{$obs_type}{uom_list}{$uom_type}{sorder_list}{$sorder}{uom_type} = $uom_type;

if ($m_z eq "") { $m_z = '-5'; } #missing z value = -99999 ?
$latest_obs{platform_list}{$platform_handle}{obs_list}{$obs_type}{uom_list}{$uom_type}{sorder_list}{$sorder}{m_z} = $m_z;

$latest_obs{platform_list}{$platform_handle}{obs_list}{$obs_type}{uom_list}{$uom_type}{sorder_list}{$sorder}{m_date}{$m_date}{m_value} = $m_value;

$datelist{$m_date} = -999.9;

} #process sql to hash 


######################################################

my $missing_z = '-99999'; #represents missing z value

#process hash 
foreach my $platform_handle (sort keys %{$r_latest_obs->{platform_list}}) {

my $org_description = $latest_obs{platform_list}{$platform_handle}{org_description};
my $org_url = $latest_obs{platform_list}{$platform_handle}{org_url};
my $platform_url = $latest_obs{platform_list}{$platform_handle}{platform_url};
my $platform_lon = $latest_obs{platform_list}{$platform_handle}{m_lon};
my $platform_lat = $latest_obs{platform_list}{$platform_handle}{m_lat};

if ($platform_lat < $min_lat || $min_lat eq "") { $min_lat = $platform_lat; }
if ($platform_lat > $max_lat || $max_lat eq "") { $max_lat = $platform_lat; }
if ($platform_lon < $min_lon || $min_lon eq "") { $min_lon = $platform_lon; }
if ($platform_lon > $max_lon || $max_lon eq "") { $max_lon = $platform_lon; }

my ($obs_list,$lat_list,$lon_list,$alt_list);

$obs_list = '';
$lat_list = '';
$lon_list = '';
$alt_list = '';
my $all_value_list = '';
my $nc_obs_metadata = '';
my $keyword_list = '';

#foreach my $date (sort keys %{$r_datelist}) {
#  print $date."\n";
#}

#datelist_copy starts empty(-999.9) filled and is populated by $m_value's 
my %datelist_copy = %datelist; 
my $r_datelist_copy = \%datelist_copy;

#obsList
foreach my $obs_type (sort keys %{$r_latest_obs->{platform_list}{$platform_handle}{obs_list}}) {
foreach my $uom_type (sort keys %{$r_latest_obs->{platform_list}{$platform_handle}{obs_list}{$obs_type}{uom_list}}) {
foreach my $sorder (sort keys %{$r_latest_obs->{platform_list}{$platform_handle}{obs_list}{$obs_type}{uom_list}{$uom_type}{sorder_list}}) {

  %datelist_copy = %datelist; 

  my $uom_type = $latest_obs{platform_list}{$platform_handle}{obs_list}{$obs_type}{uom_list}{$uom_type}{sorder_list}{$sorder}{uom_type};
  my $m_z = $latest_obs{platform_list}{$platform_handle}{obs_list}{$obs_type}{uom_list}{$uom_type}{sorder_list}{$sorder}{m_z};
  #if ($m_z eq "$missing_z") { $m_z = "99.99"; } #don't want to confuse others with in-house convention for missing elev

  #below should default range between -5 and 5 meters unless specified larger by parameters
  if ($m_z ne "$missing_z") {
    if ($m_z < $min_vert || $min_vert == 0) { $min_vert = $m_z; }
    if ($m_z > $max_vert) { $max_vert = $m_z; }
  }

#######################

#see http://mmisw.org/ont/ioos/parameter/
#see http://mmisw.org/ont/cf/parameter/
#see http://mmisw.org/ont/ioos/map_ioos_cf/

my $obs_type_standard = "";
my $obs_type_ioos = "";
my $uom_type_standard = $uom_type;

#note - blue_green_algae not found in either cf or ioos vocabs
#note - sorder not supported by ncSOS,etc - may create issue

#fix - solar_radiation - cf name?

if ($obs_type eq 'air_pressure'
 || $obs_type eq 'air_temperature'
 || $obs_type eq 'relative_humidity' 
 || $obs_type eq 'wind_from_direction' 
 || $obs_type eq 'wind_speed'
 || $obs_type eq 'depth'
 || $obs_type eq 'blue_green_algae'
 || $obs_type eq 'solar_radiation'  
) { $obs_type_standard = $obs_type; $obs_type_ioos = $obs_type; } 

if ($obs_type eq 'chl_concentration' ) { $obs_type_standard = 'mass_concentration_of_chlorophyll_a_in_sea_water'; $obs_type_ioos = 'chlorophyll_a'; }
if ($obs_type eq 'bottom_chlorophyll' ) { $obs_type_standard = 'mass_concentration_of_chlorophyll_a_in_sea_water'; $obs_type_ioos = 'chlorophyll_a_bottom'; }
if ($obs_type eq 'surface_chlorophyll' ) { $obs_type_standard = 'mass_concentration_of_chlorophyll_a_in_sea_water'; $obs_type_ioos = 'chlorophyll_a_surface'; }
if ($obs_type eq 'salinity' ) { $obs_type_standard = 'sea_water_salinity'; $obs_type_ioos = $obs_type; }
if ($obs_type eq 'water_temperature' ) { $obs_type_standard = 'sea_water_temperature';  $obs_type_ioos = $obs_type;}
if ($obs_type eq 'wind_gust' ) { $obs_type_standard = 'wind_speed_of_gust';  $obs_type_ioos = $obs_type;}

if ($obs_type eq 'water_level' ) { $obs_type_standard = 'water_surface_height_above_reference_datum'; $obs_type_ioos = 'surface_elevation'; }
if ($obs_type eq 'precipitation' ) { $obs_type_standard = 'precipitation_amount'; $obs_type_ioos = 'precipitation_amount'; }
if ($obs_type eq 'cdom' ) { $obs_type_standard = 'volume_absorption_coefficient_of_radiative_flux_in_sea_water_due_to_dissolved_organic_matter'; $obs_type_ioos = $obs_type; }
if ($obs_type eq 'ph' ) { $obs_type_standard = 'sea_water_ph_reported_on_total_scale'; $obs_type_ioos = 'acidity'; }
if ($obs_type eq 'nitrate' ) { $obs_type_standard = 'mole_concentration_of_nitrate_in_sea_water'; $obs_type_ioos = $obs_type; }
if ($obs_type eq 'phosphate' ) { $obs_type_standard = 'mole_concentration_of_phosphate_in_sea_water'; $obs_type_ioos = $obs_type; }
if ($obs_type eq 'turbidity' ) { $obs_type_standard = 'sea_water_turbidity'; $obs_type_ioos = $obs_type; }
if ($obs_type eq 'water_conductivity' ) { $obs_type_standard = 'sea_water_electrical_conductivity'; $obs_type_ioos = 'conductivity'; }
if ($obs_type eq 'oxygen_concentration' && $uom_type eq 'mg_L-1') { $obs_type_standard = 'mass_concentration_of_oxygen_in_sea_water'; $obs_type_ioos = 'dissolved_oxygen'; }
if ($obs_type eq 'oxygen_concentration' && $uom_type eq 'percent') { $obs_type_standard = 'fractional_saturation_of_oxygen_in_sea_water'; $obs_type_ioos = 'dissolved_oxygen_saturation'; }
if ($obs_type eq 'oxygen_saturation' ) { $obs_type_standard = 'fractional_saturation_of_oxygen_in_sea_water'; $obs_type_ioos = 'dissolved_oxygen_saturation'; }
if ($obs_type eq 'current_speed' ) { $obs_type_standard = 'sea_water_speed'; $obs_type_ioos = 'current_velocity'; }
if ($obs_type eq 'current_to_direction' ) { $obs_type_standard = 'direction_of_sea_water_velocity'; $obs_type_ioos = 'current_to_direction'; }
if ($obs_type eq 'solar_radiation' ) { $obs_type_standard = 'photosynthetically_available_radiation'; $obs_type_ioos = 'photosynthetically_available_radiation'; }
if ($obs_type eq 'significant_wave_height' ) { $obs_type_standard = 'sea_surface_wave_significant_height'; $obs_type_ioos = $obs_type; }
if ($obs_type eq 'significant_wave_to_direction' ) { $obs_type_standard = 'sea_surface_wave_to_direction'; $obs_type_ioos = 'wave_to_direction'; }
if ($obs_type eq 'dominant_wave_period' ) { $obs_type_standard = 'sea_surface_swell_wave_period'; $obs_type_ioos = 'wave_period'; }

if ($obs_type_standard eq "") { print "missing:$obs_type:$uom_type\n"; }
#print "$obs_type:$uom_type\n"; 

#my $obs_type_format = 'http://mmisw.org/ont/ioos/parameter/'.$obs_type; #FIX - not sure where to put prefix in netcdf file at this time
my $obs_type_format = $obs_type_ioos;

#uom conversions
if ($uom_type eq 'm_s-1') { $uom_type_standard = 'm s-1'; }
if ($uom_type eq 'cm_s-1') { $uom_type_standard = 'cm s-1'; }
if ($uom_type eq 'psu') { $uom_type_standard = '1e-3'; }
if ($uom_type eq 'ug_L-1') { $uom_type_standard = 'ug L-1'; }
if ($uom_type eq 'mb') { $uom_type_standard = 'hPa'; }

#######################

my $sorder_format = "";
if ($sorder > 1) { $sorder_format = '_'.$sorder; }

$nc_obs_metadata .= <<"END_OF_LIST";
        float $obs_type_format$sorder_format(time) ;
                $obs_type_format$sorder_format:standard_name = "$obs_type_standard" ;
                $obs_type_format$sorder_format:units = "$uom_type_standard" ;
                $obs_type_format$sorder_format:coordinates = "time lat lon" ;
                $obs_type_format$sorder_format:_FillValue = -999.f ;
                $obs_type_format$sorder_format:grid_mapping = "crs" ;

END_OF_LIST

                #$obs_type_format$sorder_format:depth = $m_z ;  #FIX - leaving off for now as many z/depth are incorrect

$keyword_list .= "$obs_type_standard,";

my $value_list = '';

foreach my $m_date (sort keys %{$r_latest_obs->{platform_list}{$platform_handle}{obs_list}{$obs_type}{uom_list}{$uom_type}{sorder_list}{$sorder}{m_date}}) {

  my $m_value = $latest_obs{platform_list}{$platform_handle}{obs_list}{$obs_type}{uom_list}{$uom_type}{sorder_list}{$sorder}{m_date}{$m_date}{m_value};
  #print "$obs_type:$m_value\n";
  if ($m_value eq '') { $m_value = -999.9; }
  #$m_value = 44.2;

  #if ($m_value ne '-999.9') {
  #  if ($obs_type eq 'air_pressure' && $uom_type eq 'mb') { $m_value = $m_value*100; }
  #}

  $datelist_copy{$m_date} = $m_value;
 
  #print "$platform_handle:$obs_type:$uom_type:$m_date:$m_z:$sorder:$m_value\n"; #debug
  $value_list .= "$m_value,"; 

}

$value_list = '';
foreach my $date (sort keys %{$r_datelist_copy}) {
  $value_list .= $datelist_copy{$date}.",";
}
chop($value_list); #drop trailing comma
$value_list = "$obs_type_format$sorder_format = $value_list ;\n\n";

#substitute spaces for underscore for search engine discovery purposes
my $obs_type_space = $obs_type;
$obs_type_space =~ s/_/ /g;


$lat_list .= "$platform_lat,";
$lon_list .= "$platform_lon,";
$alt_list .= "-$m_z,";

$all_value_list .= $value_list;

} #foreach $sorder

} #foreach $uom
} #foreach $obs
chop($obs_list); #drop trailing comma

chop($lat_list); #drop trailing comma
chop($lon_list); #drop trailing comma
chop($alt_list); #drop trailing comma
chop($keyword_list); #drop trailing comma

#create time list

my $time_list_size = keys %{$r_datelist};
print $time_list_size;
my $time_list_count = 0;

use Time::Local;
#$time = timelocal($sec,$min,$hour,$mday,$mon,$year);
#$time = timegm($sec,$min,$hour,$mday,$mon,$year);


my $time_list = '';
foreach my $m_date (sort keys %{$r_datelist}) {
  #print "m_date:$m_date\n";
  $time_list_count++;
  if ($time_list_count % 1000 == 0) { print"#"; }

  #date conversion
  #m_date like 2009-03-24 12:40:00
  my $year = substr($m_date,0,4);
  my $mon = substr($m_date,5,2);
  $mon--; #mon is zero-indexed
  my $day = substr($m_date,8,2);
  my $hour = substr($m_date,11,2);
  my $min = substr($m_date,14,2);
  my $sec = substr($m_date,17,2);

  #my $m_date_epoch_test = `date +"%s" --date='$m_date' -u`;
  #chomp($m_date_epoch);
  #print $m_date_epoch_test;
  #print "\n$sec,$min,$hour,$day,$mon,$year\n";
  #my $m_date_epoch = timegm(0,0,0,1,0,1970);
  my $m_date_epoch = timegm($sec,$min,$hour,$day,$mon,$year);
  #print $m_date_epoch."\n";
  #print $m_date_epoch_test - $m_date_epoch;

  if ($m_date_epoch < $min_time || $min_time eq "") { $min_time = $m_date_epoch; }
  if ($m_date_epoch > $max_time || $max_time eq "") { $max_time = $m_date_epoch; }

  #$time_list .= "$m_date\Z,";
  $time_list .= "$m_date_epoch,";
}

chop($time_list); #drop trailing comma
$time_list = "time = $time_list ;\n\n";


######################################################

my ($org_name,$platform_name,$package_name) = split(/\./,$platform_handle);
#$platform_handle =~ s/\./:/g ;

##netcdf########################
open (NETCDF_FILE, ">$target_dir/$platform_handle\_data.cdm");

my $nc_template = `cat netcdf/ncSOS_template_test.txt`;

my $timeSeriesLength = 1; #FIX? - could make this smarter for additional stations in one file
#$nc_template =~ s/<TIMESERIES_LENGTH>/$timeSeriesLength/g ;

my $id = "$platform_handle\_$date_now$id_suffix";
$nc_template =~ s/<ID>/$id/g ;
$nc_template =~ s/<STATION_NAME>/$platform_handle/g ;
$nc_template =~ s/<STATION_NAME_LIST>/$platform_handle/g ; #FIX? - could make this smarter for additional stations in one file
my $station_name_length = length($platform_handle);
$nc_template =~ s/<STATION_NAME_LENGTH>/$station_name_length/g ;

$nc_template =~ s/<LAT_LIST>/$platform_lat/g ;
$nc_template =~ s/<LON_LIST>/$platform_lon/g ;
#$nc_template =~ s/<LAT_LIST>/$lat_list/g ;
#$nc_template =~ s/<LON_LIST>/$lon_list/g ;
#$nc_template =~ s/<ALT_LIST>/$alt_list/g ;

$nc_template =~ s/<OBS_METADATA>/$nc_obs_metadata/g ;
$nc_template =~ s/<TIME_LIST>/$time_list/g ;
$nc_template =~ s/<OBS_DATA>/$all_value_list/g ;

$min_time = `date +"%Y-%m-%dT%H:%M:%SZ" --date='1970-01-01 $min_time seconds' -u`;
chomp($min_time);
$nc_template =~ s/<TIME_START>/$min_time/g ;

$max_time = `date +"%Y-%m-%dT%H:%M:%SZ" --date='1970-01-01 $max_time seconds' -u`;
chomp($max_time);
$nc_template =~ s/<TIME_STOP>/$max_time/g ;

my $time_now = `date -u  +%Y-%m-%dT%H:%M:%SZ`;
chomp($time_now);
$nc_template =~ s/<TIME_NOW>/$time_now/g ;

$nc_template =~ s/<MIN_LAT>/$min_lat/g ;
$nc_template =~ s/<MAX_LAT>/$max_lat/g ;
$nc_template =~ s/<MIN_LON>/$min_lon/g ;
$nc_template =~ s/<MAX_LON>/$max_lon/g ;
$nc_template =~ s/<MIN_VERT>/$min_vert/g ;
$nc_template =~ s/<MAX_VERT>/$max_vert/g ;

$nc_template =~ s/<KEYWORD_LIST>/$keyword_list/g ;

$nc_template =~ s/<CREATOR_NAME>/$org_description/g ;
$nc_template =~ s/<CREATOR_URL>/$org_url/g ;

print NETCDF_FILE $nc_template;
close (NETCDF_FILE);

print "/usr/bin/ncgen -o $target_dir/nc/$dir_monthly$platform_handle\/$platform_handle.nc $target_dir/$platform_handle\_data.cdm";
`/usr/bin/ncgen -o $target_dir/nc/$dir_monthly$platform_handle\/$platform_handle\_$date_now.nc $target_dir/$platform_handle\_data.cdm`;
`rm $target_dir/$platform_handle\_data.cdm`;
if ($ARGV[0] eq 'monthly') {
  `cd $target_dir/nc/$dir_monthly$platform_handle; /usr/bin/md5sum $platform_handle\_$date_now.nc > $platform_handle\_$date_now.nc.md5.txt`;
}

} #foreach $platform_handle - process hash to nc


##netcdf########################

$sth->finish;
undef $sth; # to stop "closing dbh with active statement handles"
	    # http://rt.cpan.org/Ticket/Display.html?id=22688

$dbh->disconnect();

print `date`;

} #foreach line

close(FILE);

exit 0;

#--------------------------------------------------------------------
#                   escape_literals
#--------------------------------------------------------------------

#$operator_url = &escape_literals($operator_url);

# Must make sure values don't contain XML reserved chars
sub escape_literals {
my $str = shift;
$str =~ s/</&lt;/gs;
$str =~ s/>/&gt;/gs;
$str =~ s/&/&amp;/gs;
$str =~ s/"/&quot;/gs;
$str =~ s/'/&#39;/gs; 
return ($str);
}

