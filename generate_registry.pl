#!/usr/bin/env perl
# Generates registry.json by scanning Plugin/ for valid LRR plugins.
# Usage: perl generate_registry.pl [plugin_dir]
#   plugin_dir defaults to "Plugin" relative to this script's directory.
use strict;
use warnings;

use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);
use File::Basename qw(dirname);
use File::Find;
use JSON qw(encode_json);

# Configure JSON encoder: sorted keys, 4-space indent
my $JSON = JSON->new->utf8->canonical->pretty->indent_length(4);

my $script_dir  = dirname(abs_path($0));
my $plugin_dir  = $ARGV[0] // "$script_dir/Plugin";
my $output_file = "$script_dir/registry.json";

die "Plugin directory not found: $plugin_dir\n" unless -d $plugin_dir;

my %plugins;

find(
    sub {
        return unless /\.pm$/;
        my $filepath = $File::Find::name;

        # Derive the relative path from the registry root (e.g. Plugin/Metadata/Foo.pm)
        my $rel_path = $filepath;
        $rel_path =~ s/^\Q$script_dir\E\/?//;

        # Read file content for SHA-256
        open(my $fh, '<:raw', $filepath) or do {
            warn "Cannot read $filepath: $!\n";
            return;
        };
        my $content = do { local $/; <$fh> };
        close $fh;

        my $sha256 = sha256_hex($content);

        # Validate package declaration
        unless ($content =~ /^package\s+(LANraragi::Plugin::\S+);/m) {
            warn "Skipping $rel_path: no valid package declaration\n";
            return;
        }
        my $package = $1;

        # Load the module
        eval { require $filepath };
        if ($@) {
            warn "Skipping $rel_path: failed to load: $@\n";
            return;
        }

        # Get plugin metadata
        my %info = eval { $package->plugin_info() };
        if ($@ || !%info) {
            warn "Skipping $rel_path: plugin_info() failed: $@\n";
            return;
        }

        my $namespace = $info{namespace};
        unless ($namespace) {
            warn "Skipping $rel_path: no namespace defined\n";
            return;
        }

        if (exists $plugins{$namespace}) {
            warn "Duplicate namespace '$namespace' in $rel_path (already seen in $plugins{$namespace}{path})\n";
            return;
        }

        $plugins{$namespace} = {
            name        => $info{name},
            type        => $info{type},
            author      => $info{author},
            version     => $info{version},
            description => $info{description},
            path        => $rel_path,
            sha256      => $sha256,
        };

        print "  $namespace ($info{name} v$info{version}) -> $rel_path\n";
    },
    $plugin_dir
);

my $count = scalar keys %plugins;
if ($count == 0) {
    die "No valid plugins found in $plugin_dir\n";
}

my $registry = { plugins => \%plugins };
my $json     = $JSON->encode($registry);

open(my $out, '>:utf8', $output_file) or die "Cannot write $output_file: $!\n";
print $out $json;
close $out;

print "\nWrote $output_file ($count plugins)\n";
