package LANraragi::Plugin::Metadata::SampleMetadata;

use strict;
use warnings;
no warnings 'uninitialized';

use LANraragi::Model::Plugins;

# Meta-information about your plugin.
sub plugin_info {

    return (
        # Standard metadata
        name        => "Sample Metadata",
        type        => "metadata",
        namespace   => "sample-metadata",
        author      => "psilabs-dev",
        version     => "1.0",
        description => "Metadata example",
        parameters  => [],
        oneshot_arg => "Optional tag to add"
    );

}

# Mandatory function to be implemented by your metadata plugin
sub get_tags {

    shift;
    my $lrr_info = shift;

    my $newtags = "";
    my $oneshot = $lrr_info->{oneshot_param};

    if ($oneshot) {
        $newtags = $oneshot;
    }

    return ( tags => $newtags );
}

1;
