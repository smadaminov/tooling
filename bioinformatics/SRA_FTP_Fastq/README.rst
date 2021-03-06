SRA FTP Tools
*************

This folder contains tools to work with `SRA FTP server`_ hosted on ENA servers:

.. _SRA FTP SERVER:
    https://ena-docs.readthedocs.io/en/latest/retrieval/file-download/sra-ftp-structure.html

.. contents:: Table of Contents

Download Fastq Files
--------------------
``ena_fastq_download.pl`` is a Perl script to download paired-ended reads stored
on the ENA servers in the Fastq format. It takes a file name as its argument.
This files should contain a list of accession names to download.

To use this script you need to have ``perl`` installed, which is usually already
comes pre-installed in major Linux distributions. It was tested with a Perl
version ``v5.26.1``. Additionally, you need to have ``Net::FTP::AutoReconnect``
module installed, which should enable automatic reconnect in case the connection
was lost or dropped::

    sudo cpan App::cpanminus
    sudo cpanm Net::FTP::AutoReconnect

Usage example::

    $ cat accession_names.lst
    SRR9999671
    SRR999666
    SRR2443265
    $ perl ./ena_fastq_download.pl -f accession_names.lst

You can also generate man page for the script (or similarly, in other format)::

    $ pod2man ena_fastq_download.pl > ena_fastq_download.man
    $ man ./ena_fastq_download.man

TODO
----
- [sra_fastq_download.pl] add support for single-ended reads
- [sra_fastq_download.pl] add Windows version for the script
- [sra_fastq_download.pl] add support for other formats
- [sra_fastq_download.pl] some accessions follow a different folder structure, e.g., SRR13494420
