package LWP::UserAgent::Cache::Memcached;

use strict;
use warnings;
use base qw(LWP::UserAgent);
use Cache::Memcached;

our $VERSION = '0.01';

our %default_cache_args = (
	'servers' => [ "127.0.0.1:11211" ],
	'namespace' => 'lwp-cache',
	'exptime' => 0,
);

sub new {
	my $class = shift;
	my $cache_opt = shift || {};
	my $self = $class->SUPER::new(@_);
	my %cache_args = (%default_cache_args, %$cache_opt);
	$self->{lwp_useragent_cache_memcached_config} = {
		exptime => $cache_args{exptime},
	};
	delete $cache_args{exptime};
	$self->{cache} = Cache::Memcached->new(\%cache_args);
	return $self
}

sub request {
	my $self = shift;
	my @args = @_;
	my $request = $args[0];
	my $uri = $request->uri->as_string;
	my $cache = $self->{cache};

	my $obj = $cache->get( $uri );

	if ( defined $obj ) {

		unless (defined $obj->{expires} and $obj->{expires} <= time()) {
			return HTTP::Response->parse($obj->{as_string});
		}

		if (defined $obj->{last_modified}) {
			$request->header(
				'If-Modified-Since' => HTTP::Date::time2str($obj->{last_modified})
			);
		}

		if (defined $obj->{etag}) {
			$request->header('If-None-Match' => $obj->{etag});
		}

		$args[0] = $request;
	}

	my $res = $self->SUPER::request(@args);
	my $exptime = int($self->{lwp_useragent_cache_memcached_config}->{exptime} || 0);
	$self->set_cache($uri, $res, $exptime) if $res->code eq HTTP::Status::RC_OK;

	return $res;
}

sub set_cache {
	my $self = shift;
	my ($uri, $res, $exptime) = @_;
	my $cache = $self->{cache};

	$cache->set($uri,{
		content       => $res->content,
		last_modified => $res->last_modified,
		etag          => $res->header('Etag') ? $res->header('Etag') : undef,
		expires       => $res->expires ? $res->expires : undef,
		as_string     => $res->as_string,
	},$exptime); 
}

1;
__END__

=head1 NAME

LWP::UserAgent::Cache::Memcached - LWP::UserAgent extension with memcached

=head1 SYNOPSIS

  use LWP::UserAgent::Cache::Memcached;
  my %cache_opt = (
    'namespace' => 'lwp-cache',
    'servers' => [ "10.0.0.15:11211", "10.0.0.15:11212", "/var/sock/memcached",
                   "10.0.0.17:11211", [ "10.0.0.17:11211", 3 ] ],
    'compress_threshold' => 10_000,
    'exptime' => 600,
  );

  my $ua = LWP::UserAgent::Cache::Memcached->new(\%cache_opt);
  my $response = $ua->get('http://search.cpan.org/');

=head1 DESCRIPTION

LWP::UserAgent::Cache::Memcached is a LWP::UserAgent extention.
It handle 'If-Modified-Since' request header with memcached.
memcached are implemented by Cache::Memcached.

=head1 SEE ALSO

L<LWP::UserAgent>, L<Cache::Memcached>

=head1 AUTHOR

This module is derived from L<LWP::UserAgent::WithCache> code, and has been lightly modified since.

Kazuma Shiraiwa

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Kazuma Shiraiwa.
This program is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

=cut
