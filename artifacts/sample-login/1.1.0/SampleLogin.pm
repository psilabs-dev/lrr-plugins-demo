package LANraragi::Plugin::Managed::Login::SampleLogin;

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
        author      => "koyomi",
        version     => "1.1.0",
        description => "Login example",
        parameters  => {
            username => { type => "string", desc => "Username" },
            password => { type => "string", desc => "Password" },
        }
    );

}

# Mandatory function to be implemented by your login plugin
# Returns a Mojo::UserAgent object only!
sub do_login {

    shift;
    my ($args) = @_;
    my $username = $args->{username};
    my $password = $args->{password};

    my $ua = Mojo::UserAgent->new;
    return $ua;
}

1;
