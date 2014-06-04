db2ncsos
========

scripts to go from database query -> hash -> ncSOS/NODC compatible netcdf using file templates

- dependent on linux 'date' and other shell commands and ncgen

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

- gen_platform_list.pl provides bash and xml content


