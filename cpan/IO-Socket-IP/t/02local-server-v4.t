#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use IO::Socket::IP;

use IO::Socket::INET;
use Socket qw( inet_ntoa unpack_sockaddr_in );

# Some odd locations like BSD jails might not like INADDR_LOOPBACK. We'll
# establish a baseline first to test against
my $INADDR_LOOPBACK = do {
   my $localsock = IO::Socket::INET->new( LocalAddr => "localhost", Listen => 1 );
   $localsock->sockaddr;
};
my $INADDR_LOOPBACK_HOST = inet_ntoa( $INADDR_LOOPBACK );
if( $INADDR_LOOPBACK ne INADDR_LOOPBACK ) {
   diag( "Testing with INADDR_LOOPBACK=$INADDR_LOOPBACK_HOST; this may be because of odd networking" );
}
my $INADDR_LOOPBACK_HEX = unpack "H*", $INADDR_LOOPBACK;

foreach my $socktype (qw( SOCK_STREAM SOCK_DGRAM )) {
   my $testserver = IO::Socket::IP->new(
      ( $socktype eq "SOCK_STREAM" ? ( Listen => 1 ) : () ),
      LocalHost => "127.0.0.1",
      Type      => Socket->$socktype,
   );

   ok( defined $testserver, "IO::Socket::IP->new constructs a $socktype socket" ) or
      diag( "  error was $@" );

   is( $testserver->sockdomain, AF_INET,           "\$testserver->sockdomain for $socktype" );
   is( $testserver->socktype,   Socket->$socktype, "\$testserver->socktype for $socktype" );

   is( $testserver->sockhost, $INADDR_LOOPBACK_HOST, "\$testserver->sockhost for $socktype" );
   like( $testserver->sockport, qr/^\d+$/, "\$testserver->sockport for $socktype" );

   my $socket = IO::Socket::INET->new(
      PeerHost => "127.0.0.1",
      PeerPort => $testserver->sockport,
      Type     => Socket->$socktype,
      Proto    => ( $socktype eq "SOCK_STREAM" ? "tcp" : "udp" ), # Because IO::Socket::INET is stupid and always presumes tcp
   ) or die "Cannot connect to PF_INET - $@";

   my $testclient = ( $socktype eq "SOCK_STREAM" ) ? 
      $testserver->accept : 
      do { $testserver->connect( $socket->sockname ); $testserver };

   ok( defined $testclient, "accepted test $socktype client" );
   isa_ok( $testclient, "IO::Socket::IP", "\$testclient for $socktype" );

   is( $testclient->sockdomain, AF_INET,           "\$testclient->sockdomain for $socktype" );
   is( $testclient->socktype,   Socket->$socktype, "\$testclient->socktype for $socktype" );

   is_deeply( [ unpack_sockaddr_in $socket->sockname ],
              [ unpack_sockaddr_in $testclient->peername ],
              "\$socket->sockname for $socktype" );

   is_deeply( [ unpack_sockaddr_in $socket->peername ],
              [ unpack_sockaddr_in $testclient->sockname ],
              "\$socket->peername for $socktype" );

   is( $testclient->sockport, $socket->peerport, "\$testclient->sockport for $socktype" );
   is( $testclient->peerport, $socket->sockport, "\$testclient->peerport for $socktype" );

   # Unpack just so it pretty prints without wrecking the terminal if it fails
   is( unpack("H*", $testclient->sockaddr), $INADDR_LOOPBACK_HEX, "\$testclient->sockaddr for $socktype" );
   is( unpack("H*", $testclient->peeraddr), $INADDR_LOOPBACK_HEX, "\$testclient->peeraddr for $socktype" );
}

done_testing;
