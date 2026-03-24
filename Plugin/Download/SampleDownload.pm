package LANraragi::Plugin::Download::SampleDownload;

use strict;
use warnings;
no warnings 'uninitialized';

# Meta-information about your plugin.
sub plugin_info {

    return (
        # Standard metadata
        name        => "Sample Downloader",
        type        => "download",
        namespace   => "sample-downloader",
        author      => "psilabs-dev",
        version     => "1.0",
        description => "Downloader example",
    );

}

# Mandatory function to be implemented by your downloader
sub provide_url {
    shift;
    my $lrr_info = shift;

    # Get the URL to download
    my $url = $lrr_info->{url};

    # Wow!
    return ( download_url => $url . "/download" );
}

1;
