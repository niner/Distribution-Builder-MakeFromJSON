use v6;
unit class Distribution::Builder::MakeFromJSON;

use System::Query;

has $.meta;
has $!collapsed-meta;

method collapsed-meta() {
    $!collapsed-meta //= system-collapse($!meta<build>);
}

method can-build(--> Bool) {
    self.collapsed-meta();
    return True;
    CATCH {
        default {
            note $_;
            return False;
        }
    }
}

method build() {
    my $destdir = '.';
    my $workdir = '.';

    my %vars = backend-values();
    %vars<DESTDIR> = $*CWD;
    my $meta = $.collapsed-meta;
    my %makefile-variables = $meta<makefile-variables>;
    for %makefile-variables.values -> $value is rw {
        next unless $value ~~ Map
            and $value<resource>:exists
            and $value<resource>.starts-with('libraries/');

        my $path = $value<resource>.substr(10); # strip off libraries/
        $value = $destdir.IO.child('resources').child('libraries')
            .child($*VM.platform-library-name($path.IO)).Str;
    }
    %vars.push: %makefile-variables;

    my $src-dir = ($meta<src-dir> || '.').IO;
    my $makefile = $src-dir.child('Makefile.in').slurp;
    for %vars.kv -> $k, $v {
        $makefile ~~ s:g/\%$k\%/$v/;
    }
    $src-dir.child('Makefile').spurt: $makefile;

    mkdir "$workdir/resources" unless "$workdir/resources".IO.e;
    mkdir "$workdir/resources/libraries" unless "$workdir/resources/libraries".IO.e;
    temp $*CWD = $src-dir;
    run 'make';
}

sub backend-values() {
    my %vars;

    # Code lifted from LibraryMake
    if $*VM.name eq 'moar' {
        %vars<O> = $*VM.config<obj>;
        my $so = $*VM.config<dll>;
        $so ~~ s/^.*\%s//;
        %vars<SO> = $so;
        %vars<CC> = $*VM.config<cc>;
        %vars<CCSHARED> = $*VM.config<ccshared>;
        %vars<CCOUT> = $*VM.config<ccout>;
        %vars<CCFLAGS> = $*VM.config<cflags>;

        %vars<LD> = $*VM.config<ld>;
        %vars<LDSHARED> = $*VM.config<ldshared>;
        %vars<LDFLAGS> = $*VM.config<ldflags>;
        %vars<LIBS> = $*VM.config<ldlibs>;
        %vars<LDOUT> = $*VM.config<ldout>;
        my $ldusr = $*VM.config<ldusr>;
        $ldusr ~~ s/\%s//;
        %vars<LDUSR> = $ldusr;

        %vars<MAKE> = $*VM.config<make>;

        %vars<EXE> = $*VM.config<exe>;
    }
    elsif $*VM.name eq 'jvm' {
        %vars<O> = $*VM.config<nativecall.o>;
        %vars<SO> = '.' ~ $*VM.config<nativecall.so>;
        %vars<CC> = $*VM.config<nativecall.cc>;
        %vars<CCSHARED> = $*VM.config<nativecall.ccdlflags>;
        %vars<CCOUT> = "-o"; # this looks wrong?
        %vars<CCFLAGS> = $*VM.config<nativecall.ccflags>;

        %vars<LD> = $*VM.config<nativecall.ld>;
        %vars<LDSHARED> = $*VM.config<nativecall.lddlflags>;
        %vars<LDFLAGS> = $*VM.config<nativecall.ldflags>;
        %vars<LIBS> = $*VM.config<nativecall.perllibs>;
        %vars<LDOUT> = $*VM.config<nativecall.ldout>;

        %vars<MAKE> = 'make';

        %vars<LDUSR> = '-l';
        # this is copied from moar - probably wrong
        #die "Don't know how to get platform independent '-l' (LDUSR) on JVM";
        #my $ldusr = $*VM.config<ldusr>;
        #$ldusr ~~ s/\%s//;
        #%vars<LDUSR> = $ldusr;

        %vars<EXE> = $*VM.config<exe>;
    }
    else {
        die "Unknown VM; don't know how to build";
    }

    return %vars;
}

=begin pod

=head1 NAME

Distribution::Builder::MakeFromJSON - blah blah blah

=head1 SYNOPSIS

  use Distribution::Builder::MakeFromJSON;

=head1 DESCRIPTION

Distribution::Builder::MakeFromJSON is ...

=head1 AUTHOR

Stefan Seifert <nine@detonation.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2017 Stefan Seifert

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
