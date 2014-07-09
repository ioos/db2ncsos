db2ncsos
========

scripti xenia_to_netcdf.pl goes from database query(directed by station_list.txt) -> hash -> ncSOS/NODC compatible netcdf using file template ncSOS_template_test.txt

- dependent on linux shell commands and ncgen

- sql query to satisfy hash(hashes are limited by memory available) of 

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

- hardcoded vocab lookups - could be redone as external file listing lookup
- missing vocab lookups currently cause ncgen to fail - probably add some email notification here

- station_list.txt contains a listing of $platform_handle = $organization.$name.$type like 'fau.lobo_1.'

- ncSOS_template_test.txt global attributes should be changed to match their usage case

- gen_platform_list.pl queries database for specific stations to add to station_list.txt and provides bash mkdir commands and thredds xml config.  For generalized usage, the station_list.txt file could be provided skipping the station_list.txt generation.

- file run as 'perl xenia_to_netcdf.pl' which is cron run every 6 hours generating the previous 6 hours data as station netcdf files for IOOS ncSOS based usage/query

- file run as 'perl xenia_to_netcdf.pl monthly' cron run monthly to generate the previous month of data as station netcdf files for NODC submission - note changes in 'monthly' output directory
  - note that 'monthly' files for NODC submission also generate an associated md5sum file which NODC processes use to detect changes in files

- note earlier discussion points at https://groups.google.com/forum/#!topic/ioos_tech/PXdZXGUqNWo

  1. assumes same depth for measurements within the file(like all water at same depth or all met at same altitude)

  2. the use of 'timeSeries','obs' is not thredds file aggregation friendly where thredds expects 'time' as the 'outside' variable to be joined on

- points which came up during the NODC submission process
 - file breakout - by organization, platform, etc
 - platform,instrumentation metadata in netcdf global attributes
 - general technical,qc,process documentation 
 - possible archive duplication/overlap with other archive efforts
 - NODC data access stats request - new vs returning, return frequency,link/data focus
 - note also that the archive files submitted are 'single-pass' on recent data and that the data provider may have further updates not processed to these archive submissions

==

run 'perl xenia_to_netcdf_file.pl archive' with sample station_list_file.txt and temp_buoy files to produce platform combined files.  This works using a simple date/value listing and initial metadata header line in the buoy files along with some platform metadata and file search pattern in the station_list_file.txt file

This approach allows creation of a combined platform file from several individual output time-series files tagged with similar filename prefixes and header line metadata.


