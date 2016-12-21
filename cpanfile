requires 'Log::Any';
requires 'Plack';
requires 'HTTP::Message';
requires 'JSON::MaybeXS';

on 'test' => sub {
    requires 'Test::Most';
};
