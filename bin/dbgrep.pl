#!/usr/bin/perl

use strict;
use warnings;

use constant TRUNCATE_CHARS_THRESHOLD => 4096;

use DBI;
use Getopt::Std; $Getopt::Std::STANDARD_HELP_VERSION = 1;

run(process_args());

sub process_args
{
    my $args = { };
    getopts('u:h:pxavq', $args);
    
    $args->{u} = 'root' unless defined($args->{u});
    $args->{h} = 'localhost' unless defined($args->{h});
    $args->{expr} = shift(@ARGV); 
    $args->{db} = shift(@ARGV);

    foreach my $arg('expr', 'db')
    {
        if (!defined($args->{$arg}))
        {
            print STDERR "Missing required parameter: <$arg>, aborting!\n\n";
            VERSION_MESSAGE();
            HELP_MESSAGE();
            exit(1);
        }
    }
    
    my @tables = @ARGV;
    $args->{tables} = \@tables;
    return $args;
}

sub grep_table
{
    my $args = shift;
    my $dbh = shift;
    my $table = shift;
    
    my $regex = $args->{expr};
    $regex = quotemeta($regex) if (!$args->{x});
    
    my @fields = ();
    my $sth = $dbh->prepare("describe `$table`");
    my $pk;
    $sth->execute();
    while (my $rec = $sth->fetchrow_hashref())
    {
        push(@fields, $rec) if (
            $args->{a} || $rec->{Type} =~ m/(char|text|blob)/);

        $pk = $rec->{Field} if ($rec->{Key} eq 'PRI' && !defined($pk));
    }

    $sth = $dbh->prepare("select * from `$table`");
    $sth->execute();
    my $matching_attrs = { };
    while (my $rec = $sth->fetchrow_hashref())
    {
        foreach my $field(@fields)
        {
            my $attr = $field->{Field};
            if (defined($rec->{$attr}) && $rec->{$attr} =~ m/$regex/is)
            {
                my $val = '';                
                my $where = '';
                if ($args->{q})
                {
                    $matching_attrs->{$attr} = 1;
                }
                else
                {
                    if ($args->{v})
                    {
                        $val = $rec->{$attr};
                        my $truncated = '';
                        if (length($val) > TRUNCATE_CHARS_THRESHOLD)
                        {
                            $val = substr($val, 0, TRUNCATE_CHARS_THRESHOLD);
                            $truncated = " (truncated)";
                        }
                        $val = "\t{$val}";
                    }
                    if (defined($pk))
                    {
                        $where = "\t($pk = '" . $rec->{$pk} . "')";
                    }
                    print "$table.$attr$where$val\n";
                }
            }
        }
    }
    if ($args->{q})
    {
        my $attrs = join(', ', sort(keys %{$matching_attrs}));
        print "$table: $attrs\n" if ($attrs ne '');
    }
}

sub run
{
    my $args = shift;
    
    my $pass = $args->{p} ? read_pass() : undef;
    my $dbh = DBI->connect(
        "DBI:mysql:database=$args->{db};host=$args->{h}",
        $args->{u},
        $pass,
        { RaiseError => 1, AutoCommit => 0 },
        );

    my @tables = @{$args->{tables}};
    if (@tables == 0)
    {
        my $sth = $dbh->prepare('show tables');
        $sth->execute();
        while (my $rec = $sth->fetchrow_arrayref())
        {
            push(@tables, $$rec[0]);
        }
    }
    foreach my $table(@tables)
    {
        grep_table($args, $dbh, $table);
    }
    $dbh->disconnect();
}

sub HELP_MESSAGE
{
    print <<EOT;
Usage: dbgrep.pl [-u <db user>] [-h <db hostname>] [-p] [-x] [-a] [-v] [-q]
                 <expr> <db name> [<table name> ...]
Switches:
       -p a password is needed for authorization, read from console
       -x interpret <expr> as a Perl regular expression rather than string
       -a grep through all fields, not just text/(var)char/blob fields
       -v print matching values, not just table/field/primary key locations
       -q only print names of matching tables and fields
EOT
}

sub VERSION_MESSAGE
{
    print <<EOT;
This is dbgrep.pl, version 1.0, which scans for strings in a MySQL database.
Copyright (c) 2009 Jan Ploski (plosquare.com)
This software is licensed to you under Artistic License 2.0,
which is published at http://www.perlfoundation.org/artistic_license_2_0

EOT
}

sub read_pass
{
    use Term::ReadKey;

    ReadMode 'noecho';
    my $password = ReadLine 0;
    chomp $password;
    ReadMode 'normal';
    
    return $password;
}
