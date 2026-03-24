package LANraragi::Plugin::Login::SampleLogin;

use strict;
use warnings;
no warnings 'uninitialized';

use Mojo::UserAgent;

# Meta-information about your plugin.
sub plugin_info {

    return (
        # Standard metadata
        name        => "Sample Login",
        type        => "login",
        namespace   => "sample-login",
        author      => "psilabs-dev",
        version     => "1.0",
        description => "Login example",
        parameters  => [
            { type => "string", desc => "Username" },
            { type => "string", desc => "Password" }
        ]
    );

}

# Mandatory function to be implemented by your login plugin
# Returns a Mojo::UserAgent object only!
sub do_login {

    shift;
    my ( $username, $password ) = @_;

    my $ua = Mojo::UserAgent->new;
    return $ua;
}

1;
