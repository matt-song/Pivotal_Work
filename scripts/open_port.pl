#!/usr/bin/perl 
use strict;
use strict;
use IO::Socket;

my $socket = new IO::Socket::INET 
(
    LocalHost => 'aio2',
    LocalPort => '7070',
    Proto => 'tcp',
    Listen => 1,
    Reuse => 1,
) || die ("Failed to create socket：$!\n");

my $new_socket = $socket->accept();

while(<$new_socket>) 
{
    print $_;
}