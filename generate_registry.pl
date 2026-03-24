#!/usr/bin/env perl
# Generates registry.json by scanning Plugin/ for valid LRR plugins.
# Parses plugin_info() as text — does not load or execute plugin files.
#
# Usage: perl generate_registry.pl [plugin_dir]
#   plugin_dir defaults to "Plugin" relative to this script's directory.
use strict;
use warnings;

use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);
use File::Basename qw(dirname);
use File::Find;

my $script_dir  = dirname(abs_path($0));
my $plugin_dir  = $ARGV[0] // "$script_dir/Plugin";
my $output_file = "$script_dir/registry.json";

die "Plugin directory not found: $plugin_dir\n" unless -d $plugin_dir;

my %plugins;

find(
    sub {
        return unless /\.pm$/;
        my $filepath = $File::Find::name;

        my $rel_path = $filepath;
        $rel_path =~ s/^\Q$script_dir\E\/?//;

        open(my $fh, '<:raw', $filepath) or do {
            warn "Cannot read $filepath: $!\n";
            return;
        };
        my $content = do { local $/; <$fh> };
        close $fh;

        my $sha256 = sha256_hex($content);

        # Extract plugin_info block as text
        unless ($content =~ /sub\s+plugin_info\s*\{.*?return\s*\((.*?)\)\s*;/s) {
            warn "Skipping $rel_path: no plugin_info found\n";
            return;
        }
        my $info_block = $1;

        # Parse key => "value" pairs
        my %info;
        while ($info_block =~ /(\w+)\s*=>\s*"([^"]*)"/g) {
            $info{$1} = $2;
        }

        my $namespace = $info{namespace};
        unless ($namespace) {
            warn "Skipping $rel_path: no namespace defined\n";
            return;
        }

        for my $required (qw(name type author version description)) {
            unless (defined $info{$required}) {
                warn "Skipping $rel_path: missing '$required' in plugin_info\n";
                return;
            }
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

# Write JSON with sorted keys, 4-space indentation
open(my $out, '>:utf8', $output_file) or die "Cannot write $output_file: $!\n";
print $out "{\n";
print $out "    \"plugins\": {\n";

my @namespaces = sort keys %plugins;
for my $i (0 .. $#namespaces) {
    my $ns   = $namespaces[$i];
    my $p    = $plugins{$ns};
    my $tail = ($i < $#namespaces) ? "," : "";

    print $out "        \"$ns\": {\n";

    my @fields = (
        [ "name",        $p->{name} ],
        [ "type",        $p->{type} ],
        [ "author",      $p->{author} ],
        [ "version",     $p->{version} ],
        [ "description", $p->{description} ],
        [ "path",        $p->{path} ],
        [ "sha256",      $p->{sha256} ],
    );

    for my $j (0 .. $#fields) {
        my ($key, $val) = @{ $fields[$j] };
        my $comma = ($j < $#fields) ? "," : "";
        print $out "            \"$key\": \"$val\"$comma\n";
    }

    print $out "        }$tail\n";
}

print $out "    }\n";
print $out "}\n";
close $out;

print "\nWrote $output_file ($count plugins)\n";
