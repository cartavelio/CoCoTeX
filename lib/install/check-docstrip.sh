#!/usr/bin/env bash
# Run with Bash, Perl and LaTeX, passing the pinned xerif-latex checkout.
set -euo pipefail

source_root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
runtime=$(realpath "${1:?Pass the pinned xerif-latex checkout}")
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

# Reproduce the release template merge for DocStrip. The Ruby build's
# macrocode line counts affect only documentation comments that DocStrip drops.
perl - "$source_root" > "$scratch/cocotex.dtx" <<'PERL'
use strict;
use warnings;

sub read_file {
    my ($path) = @_;
    open my $file, '<:raw', $path or die "$path: $!";
    local $/;
    return <$file>;
}

my ($root) = @ARGV;
my $template = read_file("$root/src/cocoTemplate.dtx");
my %version = read_file("$root/VERSION") =~ /^(\w+)="(\d+)"$/mg;
my $number = join '.', @version{qw(major minor patch)};
my $date = join '/', @version{qw(year month day)};
$template =~ s/\\def\\fileversion\{\Q$number\E\}// or die "Template and VERSION disagree";
$template =~ s!\\includeDTX\{([\w-]+)\}!read_file("$root/src/$1.dtx")!ge;
$template =~ s!%% INCLUDE-DOC!read_file("$root/src/cocoDTXPreface.dtx")!e;
$template =~ s/\\fileversion/$number/g;
$template =~ s/\\filedate/$date/g;
$template =~ s/\n%    \\begin\{macrocode\}[\n\s\t]*\n%    \\end\{macrocode\}\n/\n/g;
$template =~ s/\n{2,}/\n/g;
print $template;
PERL

cp "$source_root/lib/install/cocotex.ins" "$scratch/"
(
    cd "$scratch"
    latex -no-shell-escape -halt-on-error -interaction=nonstopmode cocotex.ins

    # The class digest records the installed class with the startup guard.
    echo '29ac17c9be114cec94af6d661d01eae0e4ea732ab8c1a106f36b909dbf17cfc2  cocotex.cls' | sha256sum --check

    outputs=(*.sty *.lua)
    test "${#outputs[@]}" -eq 12
    for output in "${outputs[@]}"; do
        cmp "$output" "$runtime/$output"
    done
    echo 'All twelve generated packages match the pinned xerif-latex runtime.'
)
