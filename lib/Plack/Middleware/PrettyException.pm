package Plack::Middleware::PrettyException;

# ABSTRACT: Capture exceptions and present them as HTML or JSON

our $VERSION = '0.900';

use 5.010;
use strict;
use warnings;
use parent qw(Plack::Middleware);
use Plack::Util;
use Plack::Util::Accessor qw(error_root);
use HTTP::Headers;
use JSON::MaybeXS qw(encode_json);
use HTTP::Status qw(is_error);
use Scalar::Util 'blessed';
use Log::Any qw($log);

sub call {
    my $self = shift;
    my $env  = shift;

    my $r;
    my $error;
    my $died = 0;
    eval {
        $r = $self->app->($env);
        1;
    } or do {
        my $e = $@;
        $died = 1;
        if ( blessed($e) ) {
            if ( $e->can('message') ) {
                $error = $e->message;
            }
            else {
                $error = '' . $e;
            }
            $r->[0] = $e->can('status_code') ? $e->status_code : $e->can('http_status') ? $e->http_status : 500;
            $r->[0] ||= 500;
        }
        else {
            $r->[0] = 500;
            $error = $e;
        }
    };

    return Plack::Util::response_cb($r, sub {
        my $r = shift;

        if (!$died && !is_error($r->[0])) {
            # all is ok!
            return;
        }

        # there was an error!

        unless ($error) {
            my $body = $r->[2] || 'error not found in body';
            $error = ref($body) eq 'ARRAY' ? join( '', @$body ) : $body;
        }

        my $location = join('', map { $env->{$_} } qw(HTTP_HOST SCRIPT_NAME REQUEST_URI));
        $log->error( $location . ': ' . $error );

        my $orig_headers = HTTP::Headers->new(@{$r->[1]});
        my $err_headers = Plack::Util::headers([]);
        my $err_body;

        # it already is JSON, so return that
        if ( $orig_headers->content_type =~ m{application/json}i ) {
            return;
        }
        # client requested JSON, so render errors as JSON
        elsif (
            exists $env->{HTTP_ACCEPT}
                && $env->{HTTP_ACCEPT} =~ m{application/json}i
            ) {
            $err_headers->set('content-type'=>'application/json');
            $err_body = encode_json( { status => 'error', message => "" . $error } );
        }
        # return HTML as default
        else {
            $err_headers->set('content-type'=>'text/html;charset=utf-8');
            $err_body = $self->render_html_error( $r->[0], $error );
        }
        $r->[1] = $err_headers->headers;
        $r->[2] = [$err_body];
        return;
    });
}

sub render_html_error {
    my ($self, $status, $error) = @_;

    $status ||='unknown HTTP status code';
    $error  ||='unknown error';
    return <<"UGLYERROR";
<html>
  <head><title>Error $status</title></head>
  <body>
    <h1>Error $status</h1>
    <p>$error</p>
  </body>
</html>
UGLYERROR
}

1;

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

TODO

=head2 Finetune HTML output via subclassing

TODO

=head1 THANKS

Thanks to

=over

=item *

L<validad.com|https://www.validad.com/> for supporting Open Source.

=item *

L<oe1.orf.at|http://oe1.orf.at> for the motivation to extract the code from the Validad stack.

=back

