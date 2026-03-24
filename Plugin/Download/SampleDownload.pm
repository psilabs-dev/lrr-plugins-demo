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
        author      => "koyomi",
        version     => "1.0",
        description => "Downloads a sample archive from lrr-plugins-demo.",
        url_regex   => "https?:\/\/github\.com\/psilabs-dev\/lrr-plugins-demo.*"
    );

}

# Mandatory function to be implemented by your downloader
sub provide_url {
    shift;
    my $lrr_info = shift;

    return ( download_url => "https://github.com/psilabs-dev/lrr-plugins-demo/raw/refs/heads/main/archive/sample.zip" );
}

1;
