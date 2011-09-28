#!/usr/bin/perl

use strict;
use warnings;
use feature qw(switch);
use LWP::Simple;
use POE;
use POE qw(Component::IRC);
use POE::Component::IRC::Common qw( :ALL );
use XML::Simple;
use XML::FeedPP;

# autoflush
$|=1;

if(!$ARGV[0]){
	die "Unspecified channel";
}

my $version = '0.2';

my $config = XMLin('config.xml');

my $nickname = $config->{nick};
my $username = $config->{user};
my $server = $config->{server}->{content};
my $usessl = $config->{server}->{ssl} eq "yes" ? 1 : 0;
my $port = $config->{port};
# Si el servidor dispone de NickServ este es el password
my $nickpass = $config->{nickpass};
# Termino buscado
my $term = $config->{term};
# Tiempo de espera de actualizacion de feeds
my $delay = $config->{delay};

my $ircname = 'WLPressBot v'.$version.' - Everything is true - Everything is permissible!';

my @channels = ('#'.$ARGV[0]);

my $joined = 0;

my $aggregator = Aggregator->new();

open FEEDLIST, "feedlist" or die $!;
while(<FEEDLIST>){
	chomp;
	$aggregator->addFeed($_);
}
close FEEDLIST;

my $irc = POE::Component::IRC->spawn( 
    nick => $nickname,
    username => $username,
    ircname => $ircname,
    server => $server,
	port => $port,
	usessl => $usessl,
) or die "Oh noooo! $!";

POE::Session->create( package_states => [ main => [ qw(_default _start irc_001 irc_public irc_msg irc_join irc_part irc_quit irc_kick irc_nick) ], ],	heap => { irc => $irc }, );

POE::Session->create(
	inline_states => {
		_start => sub { $_[KERNEL]->yield("next") },
		next   => sub {
			if( $joined == 1 ){
				for my $feed (@{$aggregator}) {
					print "READING ",$feed->getURL(),"\n";
					my $date = check_feed($feed->getURL(), $feed->getLastDate(), $term);
					if ($date) {
						$feed->setLastDate($date);
					} else {
						print STDERR "(!) Houston, we have a problem: ",$feed->getURL(),"\n";
					}
				}
				$_[KERNEL]->delay(next => $delay);
			} else {
				$_[KERNEL]->delay(next => 20); # wait a few seconds until joining
			}
		},
	},
);

$poe_kernel->run();

sub check_feed {
	my ($source, $last, $word) = @_;
	
	my $feed = eval { XML::FeedPP->new(URI->new($source)); };

	if ($@) {
		print "$@";
	} else {
		if (defined $feed) {
			if ($feed->get_item()) {
				for my $item ($feed->get_item()) {
					last if( $item->get_pubDate_epoch() <= $last );
					if($item->description()=~/(?i)$word/s) {
						send_msg($channels[0], $item->title()." | ".$item->link());
					}
				}
				return ($feed->get_item())[0]->get_pubDate_epoch();
			}
		}
	}

	# if we are here we have some problem :P
	return;
}

### Class Feed ###
{
	package Feed;
	
	sub new {
		my ($class, $url) = @_;
		my $self = bless {}, $class;

		$self->setURL($url);
		$self->setLastDate(1); # epoch

		return $self;
	}

	sub setURL {
		my ($self, $url) = @_;
		$self->{ URL } = $url;
	}

	sub setLastDate {
		my ($self, $lastdate) = @_;
		$self->{ LASTDATE } = $lastdate;
	}

	sub getURL {
		my ($self) = @_;
		return $self->{ URL };
	}

	sub getLastDate {
		my ($self) = @_;
		return $self->{ LASTDATE };
	}
}

### Class Aggregator ###
{
	package Aggregator;

	sub new {
		my ($class) = @_;
		my $self = bless [], $class;

		return $self;
	}

	sub addFeed {
		my ($self, $url) = @_;
		push @{$self}, Feed->new($url);
	}
}

sub _start {
    my $heap = $_[HEAP];
    my $irc = $heap->{irc};
    
    $irc->yield( register => 'all' );
    $irc->yield( connect => { } );
    return;
}

sub irc_001 {
    my $sender = $_[SENDER];
	my $irc = $sender->get_heap();
    
    print "Connected to ", $irc->server_name(), "\n";
	
	$irc->yield( nickserv => 'IDENTIFY' => $nickpass );
    $irc->yield( join => $_ ) for @channels;
    return;
}

sub irc_public {
    my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];
    
   if($what=~m/!\w/){
	  &evaluator;
		eval brain($nick, $channel, $what);
		if ($@) {
			send_me($channel, "bawww Im dying D:");
		}
   }

	print "irc_public: <$nick> $what\n";

    return;
}

sub irc_msg {
    my ($who, $recipients, $what) = @_[ARG0 .. ARG2];
    my $nick = ( split /!/, $who )[0];

	print "irc_msg: <$nick> $what\n";
    
	return;
}

sub irc_join {
	my ($who, $where) = @_[ARG0, ARG1];
	my $nick = ( split /!/, $who )[0];
    my $channel = $where;
    
	print "irc_join: $nick\n";

	$joined = 1;

    return;
}

sub irc_part {
	my ($who, $where) = @_[ARG0, ARG1];
	my $nick = ( split /!/, $who )[0];
    my $channel = $where;
    
	print "irc_part: $nick\n";
	
	return;
}

sub irc_quit {
	my ($who, $where) = @_[ARG0, ARG1];
	my $nick = ( split /!/, $who )[0];
    my $channel = $where;
    
	print "irc_quit: $nick\n";
	
	return;
}

sub irc_kick {
	my ($kicker, $where, $kickee) = @_[ARG0, ARG1, ARG2];
    
	print "irc_kick: $kicker kicked $kickee\n";
	
	return;
}

sub irc_nick {
	my ($who, $newnick) = @_[ARG0, ARG1];
	my $oldnick = ( split /!/, $who )[0];
    
	print "irc_nick: $oldnick changed to $newnick\n";
	
	return;
}

sub _default {
    my ($event, $args) = @_[ARG0 .. $#_];
    my @output = ( "$event:" );
    
    for my $arg (@$args) {
        if ( ref $arg eq 'ARRAY' ) {
            push( @output, '[' . join(', ', @$arg ) . ']' );
        }
        else {
            push ( @output, "'$arg'" );
        }
    }
    print join ' ', @output, "\n";
    return 0;
}

sub evaluator{
    my $dummy;
    
    open FD, "dummy.pl" or die $!;
    while(<FD>){
        $dummy .= $_;
    }
    close FD;
 
	eval $dummy;
	if ($@) {
		print $@;
	}
}

sub send_msg{
    $irc->yield( privmsg => $_[0] => $_[1] );
}

sub send_me{
    $irc->yield( ctcp => $_[0] => 'ACTION '.$_[1])
}

sub send_notice{
    $irc->yield( notice => $_[0] => $_[1] );
}

sub set_mode{
    $irc->yield( mode => $_[0] => $_[1] );
}

sub delay_event{
	$irc->delay( $_[0], $_[1] );
}

