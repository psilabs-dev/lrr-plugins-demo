package LANraragi::Plugin::Managed::Metadata::TitleSuffix2;

use strict;
use warnings;
no warnings 'uninitialized';

use LANraragi::Model::Plugins;

# Meta-information about your plugin.
sub plugin_info {

    return (
        # Standard metadata
        name        => "Title Suffix 2",
        type        => "metadata",
        namespace   => "title-suffix-2",
        author      => "koyomi",
        version     => "1.0",
        description => "Adds a '-2' suffix to the current title",
        parameters  => [],
        oneshot_arg => "Optional tag to add"
    );

}

# Mandatory function to be implemented by your metadata plugin
sub get_tags {

    shift;
    my $lrr_info = shift;

    my $title = $lrr_info->{archive_title} // "";

    return ( tags => "", title => "$title-2" );
}

1;
