package GLPI::Agent::Task::Inventory::Linux::LliureXRunParts;

use strict;
use warnings;

use parent 'GLPI::Agent::Task::Inventory::Module';

use GLPI::Agent::Tools;

sub isEnabled {
    if (-d "/etc/lliurex-glpi-agent/run-parts/") {
	    return 1;
    }
    return 0;
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};
    my $logger    = $params{logger};

    my $command =
        'run-parts /etc/lliurex-glpi-agent/run-parts/softwares.d/' ;

    my $packages = _getPackagesList(
        logger => $logger, command => $command
    );
    return unless $packages;

    # mimic RPM inventory behaviour, as GLPI aggregates software
    # based on name and publisher
    my $publisher = getFirstMatch(
        logger  => $logger,
        pattern => qr/^Distributor ID:\s(.+)/,
        command => 'lsb_release -i',
    );

    foreach my $package (@$packages) {
        $package->{PUBLISHER} = $publisher;
        $inventory->addEntry(
            section => 'SOFTWARES',
            entry   => $package
        );
    }
}

sub _getPackagesList {
    my (%params) = @_;

    my @lines = getAllLines(%params)
        or return;

    my @packages;
    foreach my $line (@lines) {
        # skip descriptions
        next if $line =~ /^ /;
        my @infos = split("\t", $line);

        # Only keep as installed package if status matches
        if ($infos[5] && $infos[5] !~ / installed$/) {
            $params{logger}->debug(
                "Skipping $infos[0] package as not installed, status='$infos[5]'"
            ) if $params{logger};
            next;
        }

        push @packages, {
            NAME        => $infos[0],
            ARCH        => $infos[1],
            VERSION     => $infos[2],
            FILESIZE    => $infos[3] =~ /^\d+$/ ? $infos[3]*1024 : 0,
            FROM        => 'deb',
            SYSTEM_CATEGORY => $infos[4]
        };
    }

    return \@packages;
}

1;
