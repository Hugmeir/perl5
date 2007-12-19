use strict;
use warnings;

BEGIN {
    if ($ENV{'PERL_CORE'}){
        chdir 't';
        unshift @INC, '../lib';
    }
    use Config;
    if (! $Config{'useithreads'}) {
        print("1..0 # Skip: Perl not compiled with 'useithreads'\n");
        exit(0);
    }
    if ($] < 5.010) {
        print("1..0 # Skip: Needs Perl 5.10.0 or later\n");
        exit(0);
    }
}

use ExtUtils::testlib;

BEGIN {
    $| = 1;
    print("1..23\n");   ### Number of tests that will be run ###
};

use threads;
use threads::shared;

my $TEST;
BEGIN {
    share($TEST);
    $TEST = 1;
}

sub ok {
    my ($ok, $name) = @_;

    lock($TEST);
    my $id = $TEST++;

    # You have to do it this way or VMS will get confused.
    if ($ok) {
        print("ok $id - $name\n");
    } else {
        print("not ok $id - $name\n");
        printf("# Failed test at line %d\n", (caller)[2]);
    }

    return ($ok);
}

ok(1, 'Loaded');

### Start of Testing ###

{ package Jar;
    my @jar :shared;

    sub new
    {
        bless(&threads::shared::share({}), shift);
    }

    sub store
    {
        my ($self, $cookie) = @_;
        push(@jar, $cookie);
        return $jar[-1];        # Results in destruction of proxy object
    }

    sub peek
    {
        return $jar[-1];
    }

    sub fetch
    {
        pop(@jar);
    }
}

{ package Cookie;

    sub new
    {
        my $self = bless(&threads::shared::share({}), shift);
        $self->{'type'} = shift;
        return $self;
    }

    sub DESTROY
    {
        delete(shift->{'type'});
    }
}

my $C1 = 'chocolate chip';
my $C2 = 'oatmeal raisin';
my $C3 = 'vanilla wafer';

my $cookie = Cookie->new($C1);
ok($cookie->{'type'} eq $C1, 'Have cookie');

my $jar = Jar->new();
$jar->store($cookie);

ok($cookie->{'type'}      eq $C1, 'Still have cookie');
ok($jar->peek()->{'type'} eq $C1, 'Still have cookie');
ok($cookie->{'type'}      eq $C1, 'Still have cookie');

threads->create(sub {
    ok($cookie->{'type'}      eq $C1, 'Have cookie in thread');
    ok($jar->peek()->{'type'} eq $C1, 'Still have cookie in thread');
    ok($cookie->{'type'}      eq $C1, 'Still have cookie in thread');

    $jar->store(Cookie->new($C2));
    ok($jar->peek()->{'type'} eq $C2, 'Added cookie in thread');
})->join();

ok($cookie->{'type'}      eq $C1, 'Still have original cookie after thread');
ok($jar->peek()->{'type'} eq $C2, 'Still have added cookie after thread');

$cookie = $jar->fetch();
ok($cookie->{'type'}      eq $C2, 'Fetched cookie from jar');
ok($jar->peek()->{'type'} eq $C1, 'Cookie still in jar');

$cookie = $jar->fetch();
ok($cookie->{'type'}      eq $C1, 'Fetched cookie from jar');
undef($cookie);

share($cookie);
$cookie = $jar->store(Cookie->new($C3));
ok($jar->peek()->{'type'} eq $C3, 'New cookie in jar');
ok($cookie->{'type'}      eq $C3, 'Have cookie');

threads->create(sub {
    ok($cookie->{'type'}      eq $C3, 'Have cookie in thread');
    $cookie = Cookie->new($C1);
    ok($cookie->{'type'}      eq $C1, 'Change cookie in thread');
    ok($jar->peek()->{'type'} eq $C3, 'Still have cookie in jar');
})->join();

ok($cookie->{'type'}      eq $C1, 'Have changed cookie after thread');
ok($jar->peek()->{'type'} eq $C3, 'Still have cookie in jar');
undef($cookie);
ok($jar->peek()->{'type'} eq $C3, 'Still have cookie in jar');
$cookie = $jar->fetch();
ok($cookie->{'type'}      eq $C3, 'Fetched cookie from jar');

# EOF
