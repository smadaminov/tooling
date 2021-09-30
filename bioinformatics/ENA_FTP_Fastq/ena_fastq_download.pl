#!/usr/bin/perl
# SPDX-FileCopyrightText: 2021 Sergey Madaminov <sergey.madaminov@gmail.com>
# SPDX-License-Identifier: BSD-3-Clause

use strict;
use warnings;
use File::Path qw(make_path);
use Getopt::Long 'HelpMessage';
use Net::FTP::AutoReconnect;

GetOptions(
    'filename=s'    => \ my $accession_names_file,
    'help'          => sub { HelpMessage() },
) or HelpMessage();

HelpMessage() unless $accession_names_file;

my $failed_accessions = "failed_accessions.lst";
my $successful_accessions = "successful_accessions.lst";
my $scratch_dir = "./";

my $ftp = Net::FTP->new("ftp.sra.ebi.ac.uk", Debug => 0, Passive => 1)
    or die "Failed to connect to: $@";

$ftp->login("anonymous", '-anonymous@')
    or die "Failed to login: ", $ftp->message;

$ftp->cwd("/vol1/fastq/")
    or die "Failed to change working directory: ", $ftp->message;

$ftp->binary()
    or die "Failed to use binary transfer mode: ", $ftp->message;

open(FH, '<', $accession_names_file)
    or die "Failed to open file $accession_names_file: ", $!;

open(FF, '>', $failed_accessions)
    or die "Failed to open file $failed_accessions: ", $!;

open(FS, '>', $successful_accessions)
    or die "Failed to open file $successful_accessions: ", $!;

my $num_processed_accessions = 0;

while(my $accession_name = <FH>) {
    unless ($num_processed_accessions == 0) {
        print "Finished processing $num_processed_accessions accessions\n";
    }
    $accession_name = substr $accession_name, 0, -1;
    my $accession_path = substr $accession_name, 0, 6;
    my @fastq_files = ();
    $num_processed_accessions++;
    if (length($accession_name) == 9) {
        my $accession_path_1 = join("", $accession_path, "/", $accession_name, "/", $accession_name, "_1.fastq.gz");
        my @fastq_file_1 = $ftp->ls($accession_path_1);
        my $is_present_1 = @fastq_file_1;
        if ($is_present_1 == 0) {
            print STDERR "Cannot find accession '$accession_name' on ENA FTP server\n";
            print FF "$accession_name\n";
            next;
        }
        my $accession_path_2 = join("", $accession_path, "/", $accession_name, "/", $accession_name, "_2.fastq.gz");
        my @fastq_file_2 = $ftp->ls($accession_path_2);
        my $is_present_2 = @fastq_file_2;
        if ($is_present_2 == 0) {
            print STDERR "Cannot find accession '$accession_name' on ENA FTP server\n";
            print FF "$accession_name\n";
            next;
        }
        push @fastq_files, $accession_path_1;
        push @fastq_files, $accession_path_2;
    }
    elsif (length($accession_name) == 10) {
        my $prefix = substr $accession_name, -1;
        my $accession_path_1 = join("", $accession_path, "/00", $prefix, "/", $accession_name, "/", $accession_name, "_1.fastq.gz");
        my @fastq_file_1 = $ftp->ls($accession_path_1);
        my $is_present_1 = @fastq_file_1;
        if ($is_present_1 == 0) {
            print STDERR "Cannot find accession '$accession_name' on ENA FTP server\n";
            print FF "$accession_name\n";
            next;
        }
        my $accession_path_2 = join("", $accession_path, "/00", $prefix, "/", $accession_name, "/", $accession_name, "_2.fastq.gz");
        my @fastq_file_2 = $ftp->ls($accession_path_2);
        my $is_present_2 = @fastq_file_2;
        if ($is_present_2 == 0) {
            print STDERR "Cannot find accession '$accession_name' on ENA FTP server\n";
            print FF "$accession_name\n";
            next;
        }
        push @fastq_files, $accession_path_1;
        push @fastq_files, $accession_path_2;
    }
    else {
        printf("Unexpected accession length of %d for '$accession_name'\n", length($accession_name));
        print FF "$accession_name\n";
        next;
    }
    my $error_occurred = 0;
    my $dirname = $fastq_files[0];
    $dirname =~ s/[^\/]*$//;
    make_path($dirname)
        or $!{EEXIST}
        or do {
            print STDERR "Failed to create a folder '$dirname': ", $!;
            print FF "$accession_name\n";
            next;
    };
    for my $fastq_file (@fastq_files) {
        my $local_filename = $scratch_dir . $fastq_file;
        my $local_file = $ftp->get($fastq_file, $local_filename)
            or do {
                print STDERR "Failed to get $accession_name: ", $ftp->message;
                $error_occurred = 1;
                last;
        };
        my $local_file_size = -s $local_file;
        my $remote_file_size = $ftp->size($fastq_file)
            or do {
                print STDERR "Failed to get size of $accession_name: ", $ftp->message;
                $error_occurred = 1;
                last;
        };
        if ($local_file_size != $remote_file_size) {
            print STDERR "Potentially corrupted '$fastq_file': size does not match its remote counterpart\n";
            $error_occurred = 1;
            last;
        }
    }
    if ($error_occurred == 1) {
        print FF "$accession_name\n";
    }
    else {
        print "Successfully downloaded $accession_name\n";
        print FS "$accession_name\n";
    }
}
print "Finished processing $num_processed_accessions accessions\n";

$ftp->quit;

close(FH);
close(FF);
close(FS);

print "Done!\n";

__END__

=head1 NAME

ena_fastq_download.pl - Perl script to download accessions in the Fastq format
from ENA FTP server provided in the FTP server

=head1 SYNOPSIS

perl ena_fastq_download.pl [options] -f <filename>

 Options:
   -help            print this help message
   -filename        name of a file with the list of accessions to download

=head1 OPTIONS

=over 4

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Read accession names from an input file and download them.

=back

=head1 DESCRIPTION

B<This program> will read the accession names from an input file and download
them from ENA FTP server. Program also performs a simple check that accession
in question exists on the ENA FTP server. Fastq files should be for
paired-ended reads and split into two files with names *_1.fastq.gz and
*_2.fastq.gz.

After two fastq files will be downloaded, the script will check that their
sized match the sizes of the files on the ENA FTP server.

Successfully downloaded accession names are stored in the file, which name is
defined by the '$successful_accessions' variable (by default
'successful_accessions.lst') and failed downloads are stored in the file, which
is defined by the '$failed_accessions' (by default 'failed_accessions.lst')
variable. The variable '$scratch_dir' (by default the current directory)
specified the root directory where the downloaded Fastq files will be placed.

=cut
