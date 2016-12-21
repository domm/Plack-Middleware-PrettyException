use strict;
use warnings;
use FindBin;
use Test::More;
use HTTP::Request::Common;
use Plack::Test;
use Plack::Builder;

my $handler = builder {
    enable "Plack::Middleware::PrettyException";

    sub {
        my $env = shift;

        my $path = $env->{PATH_INFO};
        if ( $path eq '/ok' ) {
            return [ 200, [ 'Content-Type' => 'text/plain' ], ['all ok'] ];
        }
        elsif ( $path eq '/error' ) {
            return [
                400, [ 'Content-Type' => 'text/plain' ],
                ['there was an error']
            ];
        }
        elsif ( $path eq '/jsonerror' ) {
            return [
                400,
                [ 'Content-Type' => 'application/json' ],
                ['{"status":"jsonerror"}']
            ];
        }
        elsif ( $path eq '/die' ) {
            die 'argh!';
        }
        elsif ( $path eq '/exception' ) {

        }
    };
};

test_psgi
    app    => $handler,
    client => sub {
    my $cb = shift;
    {
        subtest 'all ok' => sub {
            my $res = $cb->( GET "http://localhost/ok" );
            is( $res->code,    200,      'status' );
            is( $res->content, 'all ok', 'content' );
        };

        subtest 'app returned error' => sub {
            my $res = $cb->( GET "http://localhost/error" );
            is( $res->code, 400, 'status' );
            is( $res->header('Content-Type'),
                'text/html;charset=utf-8', 'content-type' );
            like( $res->content, qr{<h1>Error 400</h1>}, 'heading' );
            like(
                $res->content,
                qr{<p>there was an error</p>},
                'error message'
            );
        };

        subtest 'app returned error, client requested json' => sub {
            my $res = $cb->(
                GET "http://localhost/error",
                'Accept' => 'application/json'
            );
            is( $res->code, 400, 'status' );
            is( $res->header('Content-Type'),
                'application/json', 'content-type' );
            like(
                $res->content,
                qr/"message":"there was an error"/,
                'json'
            );
        };

        subtest 'app returned jsonerror' => sub {
            my $res = $cb->( GET "http://localhost/jsonerror" );
            is( $res->code, 400, 'status' );
            is( $res->header('Content-Type'),
                'application/json', 'content-type' );
            is( $res->content, '{"status":"jsonerror"}',
                'json payload' );

        };

        subtest 'app returned jsonerror, client requested json' => sub {
            my $res = $cb->(
                GET "http://localhost/jsonerror",
                'Accept' => 'application/json'
            );
            is( $res->code, 400, 'status' );
            is( $res->header('Content-Type'), 'application/json', 'content-type' );
            is( $res->content, '{"status":"jsonerror"}', 'json payload' );
        };
        subtest 'app died' => sub {
            my $res = $cb->( GET "http://localhost/die" );

            is( $res->code, 500, 'status' );
            like( $res->content, qr{<h1>Error 500</h1>}, 'heading' );
            like( $res->content, qr{<p>argh! at }, 'error message' );
        };

        subtest 'app died, client requested json' => sub {
            my $res = $cb->( GET "http://localhost/die", 'Accept'=>'application/json' );
            is( $res->code, 500, 'status' );
            like( $res->content, qr/{"message":"argh! at/, 'json payload' );
        };
    }
    };

done_testing;
