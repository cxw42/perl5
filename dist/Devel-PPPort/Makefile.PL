################################################################################
#
#  Makefile.PL -- generate Makefile
#
################################################################################
#
#  Version 3.x, Copyright (C) 2004-2013, Marcus Holland-Moritz.
#  Version 2.x, Copyright (C) 2001, Paul Marquess.
#  Version 1.x, Copyright (C) 1999, Kenneth Albanowski.
#
#  This program is free software; you can redistribute it and/or
#  modify it under the same terms as Perl itself.
#
################################################################################

require 5.003;

use strict;
BEGIN { $^W = 1; }

use ExtUtils::MakeMaker;
use Config;

use vars '%opt';  # needs to be global, and we can't use 'our'

unless ($ENV{'PERL_CORE'}) {
  $ENV{'PERL_CORE'} = 1 if grep { $_ eq 'PERL_CORE=1' } @ARGV;
}

@ARGV = map { /^--with-(apicheck)$/ && ++$opt{$1} ? () : $_ } @ARGV;

my %mf = (
  NAME          => 'Devel::PPPort',
  VERSION_FROM  => 'PPPort_pm.PL',
  PM            => { 'PPPort.pm' => '$(INST_LIBDIR)/PPPort.pm' },
  H             => [ qw(ppport.h) ],
  OBJECT        => 'RealPPPort$(OBJ_EXT) $(O_FILES)',
  XSPROTOARG    => '-noprototypes',
  CONFIGURE     => \&configure,
);
WriteMakefile(%mf);

sub configure
{
  my @clean    = qw{ $(H_FILES) RealPPPort.xs RealPPPort.c PPPort.pm };
  my %depend   = (
    '$(OBJECT)' => '$(H_FILES)',
    'Makefile' => '$(VERSION_FROM)',
  );
  my @C_FILES  = qw{ module2.c module3.c },
  my %PL_FILES = (
    'ppport_h.PL'  => 'ppport.h',
    'PPPort_pm.PL' => 'PPPort.pm',
    'RealPPPort_xs.PL' => 'RealPPPort.xs',
    'mktests.PL' => 't/01_test.t',
  );
  my @moreopts;

  if (eval { ExtUtils::MakeMaker->VERSION(6) }) {
    push @moreopts, AUTHOR => 'Marcus Holland-Moritz <mhx@cpan.org>';
    push @moreopts, ABSTRACT_FROM => 'PPPort_pm.PL';
  }

  if (eval { ExtUtils::MakeMaker->VERSION(6.30_01) }) {
    print "Setting license tag...\n";
    push @moreopts, LICENSE => 'perl';
  }

  if (eval { ExtUtils::MakeMaker->VERSION (6.46) }) {
    open FH, '<PPPort_pm.PL' or die "cannot open PPPort_pm.PL for reading: $!";
    my $version;
    my $line;
    while ($line = <FH>) {
      ($version) = $line =~ /^\$VERSION = '([\d.]+)';$/ and last;
    };
    die 'failed to extract $VERSION from PPPort_pm.PL' if not $version;
    close FH;
    print "Adding META_MERGE...\n";
    push @moreopts, META_MERGE => {
      'meta-spec' => { version => 2 },
      provides => {
        'Devel::PPPort' => {
          file    => 'PPPort_pm.PL',
          version => $version,
        },
      },
      resources => {
        bugtracker => {
          web => 'https://rt.perl.org/rt3/',
        },
        repository => {
          type => 'git',
          url  => 'git://perl5.git.perl.org/perl.git',
          web  => 'https://perl5.git.perl.org/perl.git',
        },
      },
    };
  }

  if (not $ENV{'PERL_CORE'}) {
    # Devel::PPPort is in the core since 5.7.3
    # 5.11.0+ has site before perl
    push @moreopts, INSTALLDIRS => (
      ("$]" >= 5.007003 and "$]" < 5.011)
        ? 'perl'
        : 'site'
    );
  }

  if ($opt{'apicheck'}) {
    $PL_FILES{'apicheck_c.PL'} = 'apicheck.c';
    push @C_FILES, qw{ apicheck.c };
    push @clean,   qw{ apicheck.c apicheck.i };
    $depend{'apicheck.i'} = 'ppport.h';
  }

  if ($Config{gccversion}) {
    my $define = '-W -Wall';
    $define .= ' -Wdeclaration-after-statement' if $Config{gccversion} =~ /^(\d+\.\d+)\./ && $1 >= 3.4;
    push @moreopts, DEFINE => $define;
  }

  return {
    C        => \@C_FILES,
    XS       => { 'RealPPPort.xs' => 'RealPPPort.c' },
    PL_FILES => \%PL_FILES,
    depend   => \%depend,
    clean    => { FILES => "@clean" },
    @moreopts,
  };
}

sub MY::postamble
{
  package MY;
  my $post = shift->SUPER::postamble(@_);
  $post .= <<'POSTAMBLE';

purge_all: realclean
	@$(RM_F) PPPort.pm t/*.t

regen_pm:
	$(PERL) -I$(INST_ARCHLIB) -I$(INST_LIB) -I$(PERL_ARCHLIB) -I$(PERL_LIB) PPPort_pm.PL

regen_xs:
	$(PERL) -I$(INST_ARCHLIB) -I$(INST_LIB) -I$(PERL_ARCHLIB) -I$(PERL_LIB) RealPPPort_xs.PL

regen_tests:
	$(PERL) -I$(INST_ARCHLIB) -I$(INST_LIB) -I$(PERL_ARCHLIB) -I$(PERL_LIB) mktests.PL

regen_h:
	$(PERL) -I$(INST_ARCHLIB) -I$(INST_LIB) -I$(PERL_ARCHLIB) -I$(PERL_LIB) ppport_h.PL

regen: regen_pm regen_xs regen_tests regen_h

POSTAMBLE
  return $post;
}

sub MY::processPL
{
  package MY;
  my $original = shift->SUPER::processPL(@_);

  require "./parts/ppptools.pl";
  my $includes = join ' ', all_files_in_dir('parts/inc');

  my $updated = '';
  my @rules = split( m{^\s*$}m, $original );
  my $rule;
  foreach $rule ( @rules ) {
    if ( $rule =~ m{^\s*^PPPort\.pm\s+:}m ) {
      $rule =~ s{^(\s*^PPPort\.pm\s+:.*)}{$1 $includes}m; # PPPort.pm depends on all files from parts/inc
      $rule =~ s{pm_to_blib}{}m; # PPPort.pm must not depend on built PPPort.pm in blib/
    } elsif ( $rule =~ m{^\s*^ppport\.h\s+:}m ) {
      $rule =~ s{^(\s*^ppport\.h\s+:.*)}{$1 PPPort.pm}m; # ppport.h depends on PPPort.pm
      $rule =~ s{pm_to_blib}{}m; # ppport.h is used to build RealPPPort.xs so cannot depend on built PPPort in blib/
    } elsif ( $rule =~ m{^\s*^RealPPPort\.xs\s+:}m ) {
      $rule =~ s{^(\s*^RealPPPort\.xs\s+:.*)}{$1 ppport.h}m; # RealPPPort.xs depends on ppport.h
      $rule =~ s{pm_to_blib}{}m; # RealPPPort.xs is used to build PPPort binary, so it cannot depend on it
    } elsif ( $rule =~ m{^\s*\S+\b01_test\.t\s+:}m ) {
      $rule =~ s{^(\s*^\S+\b01_test\.t\s+:.*)}{$1 $includes}m; # all tests in t/ depends on all files from parts/inc
      $rule =~ s{pm_to_blib}{}m; # Generating test files does not depend on built PPPort in blib/
    }
    $updated .= $rule;
  }

  return $updated;
}

sub MY::dist_core
{
  package MY;
  my $dist = shift->SUPER::dist_core(@_);

  my $updated = '';
  my @rules = split( m{^\s*$}m, $dist );
  my $rule;
  foreach $rule ( @rules ) {
    if ( $rule =~ m{^\s*^dist\s+:}m ) {
        $rule =~ s{:}{: manifest}; # make sure we regenerate the manifest
        $rule .= qq[\t].q[$(NOECHO) $(ECHO) "Warning: Please check '__MAX_PERL__' value in PPPort_pm.PL"].qq[\n];
    }
    $updated .= $rule;
  }

  return $updated;
}


sub MY::c_o
{
  package MY;
  my $co = shift->SUPER::c_o(@_);

  if ($::opt{'apicheck'} && $co !~ /^\.c\.i:/m) {
    print "Adding custom rule for preprocessed apicheck file...\n";

    $co .= <<'CO'

.SUFFIXES: .i

.c.i:
	$(CCCMD) -E -I$(PERL_INC) $(DEFINE) $*.c > $*.i
CO
  }

  return $co;
}
