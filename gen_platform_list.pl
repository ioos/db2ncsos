#!/usr/bin/perl

print `date`;

use strict;
use Config::IniFiles;
use DBI;

#####################
#config
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

#################

open(FILE,">$target_dir/station_list.txt");
open(FILE2,">$target_dir/mkdir.sh");
open(FILE3,">$target_dir/thredds.xml");

my $sql = qq{ select row_id,short_name,url from organization where row_id in (50,9,39,3,51,52,53,54,55,56) };
#my $sql = qq{ select row_id,short_name,url from organization where row_id in (39) };
 
my $sth = $dbh->prepare($sql);
$sth->execute();

my $last_org_name = "";
my $start_tag = "";

while (my (
    $org_id,
    $org_name,
    $org_url
  ) = $sth->fetchrow_array) {

my $sql_2 = qq{ select platform_handle from platform where organization_id = $org_id and active <= 3 and platform_handle not like '%.radar%' and platform_handle not like '%.rs' and platform_handle not like '%.service' };
my $sth_2 = $dbh->prepare($sql_2);
$sth_2->execute();


#print "$platform_handle:$obs_type:$uom_type:$m_date:$m_z:$sorder:$m_value\n"; #debug
#platform_handle = lc($platform_handle);

while (my (
    $platform_handle
  ) = $sth_2->fetchrow_array) {


#skip platforms without recent data on multi_obs table
my $sql_3 = qq{ select count(*) from multi_obs where platform_handle = '$platform_handle' limit 1 };
my $sth_3 = $dbh->prepare($sql_3);
$sth_3->execute();
my ($row_count) = $sth_3->fetchrow_array;
if ($row_count == 0) { print "$platform_handle\n"; next; }


print FILE "$org_name,$org_url,$platform_handle\n";

my $lc_platform_handle = lc($platform_handle);
print FILE2 "mkdir $lc_platform_handle\n";

my $xml_content = "";

if ($org_name ne $last_org_name) { $xml_content .= "$start_tag\n<dataset name=\"$org_name\">\n"; $last_org_name = $org_name; $start_tag = "</dataset>\n"; }

$xml_content .= <<END;
  <dataset name=\"$lc_platform_handle\" ID=\"id_$lc_platform_handle\" urlPath=\"$lc_platform_handle.nc\">
    <serviceName>all</serviceName>
    <netcdf xmlns=\"http://www.unidata.ucar.edu/namespaces/netcdf/ncml-2.2\">
      <aggregation dimName=\"time\" type=\"joinExisting\" recheckEvery=\"30 min\">
        <scan location=\"/nc/$lc_platform_handle/\" suffix=\"$lc_platform_handle*.nc\" subdirs=\"false\" />
      </aggregation>
    </netcdf>
  </dataset>

  <datasetScan name=\"$lc_platform_handle monthly files\" ID=\"$lc_platform_handle\_files\" path=\"$lc_platform_handle\_files\" location=\"/nc/monthly/$lc_platform_handle/\">

    <metadata inherited=\"true\">
      <serviceName>monthly</serviceName>
    </metadata>

    <filter>
      <include wildcard=\"*\"/>
    </filter>

  </datasetScan>
END


print FILE3 $xml_content;

} #while platform

} #while org

print FILE3 "</dataset>\n";

close(FILE);
close(FILE2);
close(FILE3);

exit 0;


