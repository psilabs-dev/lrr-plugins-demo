#!/usr/bin/env perl
use strict;
use warnings;

use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);
use File::Basename qw(dirname);
use File::Spec;
use JSON::PP qw(decode_json);
use POSIX qw(strftime);

use constant MAX_ARTIFACT_SIZE => 1024 * 1024 * 1024;

my $script_dir    = dirname(abs_path($0));
my $artifact_root = "$script_dir/artifacts";
my $output_file   = "$script_dir/registry.json";
my $now           = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime);

die "Artifact directory not found: $artifact_root\n" unless -d $artifact_root;
die "Manifest not found: $output_file\n"             unless -f $output_file;

my @PLUGIN_INFO_FIELDS = qw(name type namespace author version description);
my %VALID_TYPES        = map { $_ => 1 } qw(metadata download login script);

my $existing_manifest = decode_json_file($output_file);
my $existing_plugins  = load_existing_plugins($existing_manifest);
my %plugins;

for my $namespace (list_child_directories($artifact_root)) {
    my $namespace_dir = File::Spec->catdir($artifact_root, $namespace);

    die "Manifest is missing plugin record for namespace '$namespace'\n"
        unless exists $existing_plugins->{$namespace};

    my $existing_plugin = $existing_plugins->{$namespace};

    $plugins{$namespace} = {
        namespace => $existing_plugin->{namespace},
        type      => $existing_plugin->{type},
        channels  => $existing_plugin->{channels},
        versions  => {},
    };

    for my $version (list_child_directories($namespace_dir)) {
        my $version_dir = File::Spec->catdir($namespace_dir, $version);
        my @artifacts   = grep { /\.pm\z/ } list_child_files($version_dir);

        die "Expected exactly one plugin artifact in $version_dir\n"
            unless @artifacts == 1;

        my $filename         = $artifacts[0];
        my $full_path        = File::Spec->catfile($version_dir, $filename);
        my $canonical_path   = validate_artifact_path($full_path);
        my $rel_path         = rel_to_root($full_path);
        my $artifact_content = read_file_raw($canonical_path);
        my $artifact_sha256  = sha256_hex($artifact_content);
        my $info             = parse_plugin_artifact_content( $canonical_path, $artifact_content );

        die "Namespace directory mismatch for $rel_path\n"
            unless $info->{namespace} eq $namespace;
        die "Version directory mismatch for $rel_path\n"
            unless $info->{version} eq $version;
        die "Unsupported plugin type '$info->{type}' in $rel_path\n"
            unless $VALID_TYPES{ $info->{type} };
        die "Manifest type mismatch for namespace '$namespace'\n"
            unless $existing_plugin->{type} eq $info->{type};

        my $existing_record = $existing_plugin->{versions}{$version};
        if ($existing_record) {
            die "Published artifact bytes changed for existing $namespace/$version\n"
                unless $existing_record->{sha256} eq $artifact_sha256;
        }

        $plugins{$namespace}{versions}{$version} = {
            version      => $info->{version},
            name         => $info->{name},
            author       => $info->{author},
            description  => $info->{description},
            artifact     => $rel_path,
            sha256       => $artifact_sha256,
            published_at => $existing_record ? $existing_record->{published_at} : $now,
        };
    }

    die "No published versions found for namespace '$namespace'\n"
        unless keys %{ $plugins{$namespace}{versions} };
}

for my $namespace ( sort keys %{$existing_plugins} ) {
    die "Manifest references namespace '$namespace' with no artifact directory\n"
        unless exists $plugins{$namespace};
}

validate_channels( \%plugins );

write_manifest(
    $output_file,
    {
        version      => 1,
        generated_at => $now,
        plugins      => \%plugins,
    }
);

print "Wrote $output_file (" . scalar( keys %plugins ) . " plugins)\n";

sub decode_json_file {
    my ($path) = @_;
    return decode_json( read_file_utf8($path) );
}

sub load_existing_plugins {
    my ($manifest) = @_;

    die "Manifest version must be 1\n"
        unless defined $manifest->{version} && $manifest->{version} == 1;
    die "Manifest generated_at must be a string\n"
        unless defined $manifest->{generated_at} && !ref $manifest->{generated_at};
    die "Manifest plugins must be an object\n"
        unless ref $manifest->{plugins} eq 'HASH';

    my %plugins;

    for my $namespace ( sort keys %{ $manifest->{plugins} } ) {
        my $plugin = $manifest->{plugins}{$namespace};

        die "Plugin record for '$namespace' must be an object\n"
            unless ref $plugin eq 'HASH';
        die "Plugin key '$namespace' must match inner namespace\n"
            unless defined $plugin->{namespace} && $plugin->{namespace} eq $namespace;
        die "Plugin '$namespace' is missing type\n"
            unless defined $plugin->{type};
        die "Plugin '$namespace' has invalid type '$plugin->{type}'\n"
            unless $VALID_TYPES{ $plugin->{type} };
        die "Plugin '$namespace' channels must be an object\n"
            unless ref $plugin->{channels} eq 'HASH';
        die "Plugin '$namespace' versions must be an object\n"
            unless ref $plugin->{versions} eq 'HASH';
        die "Plugin '$namespace' versions must be non-empty\n"
            unless keys %{ $plugin->{versions} };

        $plugins{$namespace} = {
            namespace => $plugin->{namespace},
            type      => $plugin->{type},
            channels  => $plugin->{channels},
            versions  => {},
        };

        for my $version ( sort keys %{ $plugin->{versions} } ) {
            my $record = $plugin->{versions}{$version};

            die "Version record for '$namespace/$version' must be an object\n"
                unless ref $record eq 'HASH';
            die "Version key '$namespace/$version' must match inner version\n"
                unless defined $record->{version} && $record->{version} eq $version;
            die "Version record for '$namespace/$version' is missing published_at\n"
                unless defined $record->{published_at};
            die "Version record for '$namespace/$version' is missing sha256\n"
                unless defined $record->{sha256};

            $plugins{$namespace}{versions}{$version} = {
                published_at => $record->{published_at},
                sha256       => $record->{sha256},
            };
        }
    }

    return \%plugins;
}

sub validate_channels {
    my ($plugins) = @_;

    for my $namespace ( sort keys %{$plugins} ) {
        my $channels = $plugins->{$namespace}{channels};

        die "Plugin '$namespace' must contain only 'latest' in channels\n"
            unless keys(%{$channels}) == 1 && exists $channels->{latest};

        my $target_version = $channels->{latest};
        die "Channel target for '$namespace' must be a string\n"
            unless defined $target_version && !ref $target_version && length $target_version;
        die "Channel 'latest' for '$namespace' points to unknown version '$target_version'\n"
            unless exists $plugins->{$namespace}{versions}{$target_version};
    }
}

sub parse_plugin_artifact_content {
    my ( $path, $content ) = @_;
    my ($info_body) = $content =~ /sub\s+plugin_info\s*\{(.*?)^\}/ms;
    die "No plugin_info found in $path\n" unless defined $info_body;

    my %info;
    for my $field (@PLUGIN_INFO_FIELDS) {
        if ( $info_body =~ /\b$field\s*=>\s*"((?:[^"\\]|\\.)*)"/s ) {
            $info{$field} = $1;
        } elsif ( $info_body =~ /\b$field\s*=>\s*'((?:[^'\\]|\\.)*)'/s ) {
            $info{$field} = $1;
        } else {
            die "Missing '$field' in plugin_info for $path\n";
        }
    }

    $info{description} =~ s/\s*\n\s*/ /g;
    return \%info;
}

sub validate_artifact_path {
    my ($path) = @_;

    my $canonical_path = abs_path($path);
    die "Artifact path cannot be canonicalized: $path\n" unless defined $canonical_path;

    my $registry_root = abs_path($script_dir);
    die "Registry root cannot be canonicalized: $script_dir\n" unless defined $registry_root;

    die "Artifact escapes registry root after canonicalization: $path\n"
        unless index( $canonical_path, "$registry_root/" ) == 0;

    die "Artifact is not a regular file after canonicalization: $path\n"
        unless -f $canonical_path;

    my $size = -s $canonical_path;
    die "Artifact size is unavailable after canonicalization: $path\n"
        unless defined $size;
    die "Artifact exceeds MAX_ARTIFACT_SIZE (" . MAX_ARTIFACT_SIZE . " bytes): $path\n"
        if $size > MAX_ARTIFACT_SIZE;

    return $canonical_path;
}

sub list_child_directories {
    my ($dir) = @_;
    opendir( my $dh, $dir ) or die "Cannot open $dir: $!\n";
    my @entries = sort grep {
        $_ ne '.'
            && $_ ne '..'
            && -d File::Spec->catdir( $dir, $_ )
    } readdir($dh);
    closedir $dh or die "Cannot close $dir: $!\n";
    return @entries;
}

sub list_child_files {
    my ($dir) = @_;
    opendir( my $dh, $dir ) or die "Cannot open $dir: $!\n";
    my @entries = sort grep {
        $_ ne '.'
            && $_ ne '..'
            && -f File::Spec->catfile( $dir, $_ )
    } readdir($dh);
    closedir $dh or die "Cannot close $dir: $!\n";
    return @entries;
}

sub rel_to_root {
    my ($path) = @_;
    my $rel = $path;
    $rel =~ s/^\Q$script_dir\E\/?//;
    return $rel;
}

sub read_file_raw {
    my ($path) = @_;
    open( my $fh, '<:raw', $path ) or die "Cannot read $path: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh or die "Cannot close $path: $!\n";
    return $content;
}

sub read_file_utf8 {
    my ($path) = @_;
    open( my $fh, '<:utf8', $path ) or die "Cannot read $path: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh or die "Cannot close $path: $!\n";
    return $content;
}

sub write_manifest {
    my ( $path, $data ) = @_;
    open( my $fh, '>:utf8', $path ) or die "Cannot write $path: $!\n";
    print {$fh} JSON::PP->new->canonical->pretty->encode($data);
    close $fh or die "Cannot close $path: $!\n";
}
