use strict;
use warnings;

sub brain {
    my ($nick, $channel, $what) = @_;
    
    given($what){
		### Commands ###
		when (/!(title|t) http:\/\/(.+?)( |$)/)	{	send_me($channel, get_title($2) ); }

		### Easter eggs ;D ###
		when (/!hi/)		{	send_msg($channel, 'hello '.$nick.'! nice to see you :D'); }
		when (/!shodan/)	{	send_msg($channel, 'Look at you, hacker. A pathetic creature of meat and bone, panting and sweating as you run through my corridors. How can you challenge a perfect, immortal machine?'); }
		when (/!tron/)		{	send_msg($channel, 'This is the key to a new order. This code disk means freedom.'); }
		when (/!joshua/)	{	send_msg($channel, 'Greetings, Professor Falken.'); }
		when (/!$nickname/)	{	send_msg($channel, 'Back off man. I\'m a scientist.'); }

		### Undefined command reply ###
		default {
			my @r = ('sorry?', 'I\'m not sure what you mean', 'I don\'t understand...');
			send_msg($channel, $r[rand @r]);
		}
    }
}

# esta rutina tiene aire de insegura, tener cuidado...
sub get_title{
	my $url = $_[0];
	my $content = get('http://'.$url);
	$content=~s/&amp;/&/g;
	$content=~s/&nbsp;/ /g;
	$content=~s/&quot;/"/g;
	$content=~s/&reg;/(r)/g;
	
	if($content=~/<title>(.+?)<\/title>/s){
		my $title=$1;
		$title=~s/[\t|\n]//g;
		return $title;
	}
	
	return 'title tag not found';
}

