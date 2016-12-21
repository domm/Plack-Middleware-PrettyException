requires 'Log::Any';
requires 'Plack';
requires 'HTTP::Message';
requires 'JSON::MaybeXS';
requires 'HTTP::Request::Common';

on 'test' => sub {
    requires 'Test::Most';
};
