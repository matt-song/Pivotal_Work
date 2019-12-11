#!/usr/bin/perl
use strict;
use DBI;
my $host = "smdw";
my $driver = "ODBC";
my $DB = "gpadmin";
my $DSN = "Greenplum Wire Protocol";
my $user = "gpadmin";
my $password = "abc123";
### connect to the DB via ODBC ###
my $dbh =DBI->connect("dbi:ODBC:$DSN",$user,$password) or die $DBI::errstr;
### prepare the connection ###
my $query = qq(select * from pg_class limit 10);
my $sth = $dbh->prepare($query);
$sth->execute();
# Fetch and display the result #
while ( my @row = $sth->fetchrow_array ) {
   print "@row\n";
}
$sth->finish();
$dbh->disconnect();

