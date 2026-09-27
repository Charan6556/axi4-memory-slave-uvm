#!/usr/bin/env perl

use strict;
use warnings;
use File::Path qw(make_path);
use File::Spec;
use POSIX qw(strftime);

my $seed_count = shift @ARGV // 10;
my $pairs      = shift @ARGV // 100;
my %options;
for my $option (@ARGV) {
  die "Usage: perl scripts/run_random_regression.pl SEEDS PAIRS [--no-coverage] [--quiet]\n"
    unless ($option eq '--no-coverage' || $option eq '--quiet')
      && !$options{$option}++;
}
my $no_coverage = $options{'--no-coverage'} // 0;
my $quiet       = $options{'--quiet'} // 0;

die "Usage: perl scripts/run_random_regression.pl SEEDS PAIRS [--no-coverage] [--quiet]\n"
  unless $seed_count =~ /^[1-9][0-9]*$/ && $pairs =~ /^[1-9][0-9]*$/;

die "Run this script from the repository root\n"
  unless -f 'rtl/design.sv' && -f 'tb/testbench.sv';
die "xrun is not available in PATH; run on a machine with Xcelium loaded\n"
  unless grep { -x File::Spec->catfile($_, 'xrun') } File::Spec->path();

my $run_dir = 'results/random_' . strftime('%Y%m%d_%H%M%S', localtime) . "_$$";
make_path($run_dir);

open my $summary, '>', "$run_dir/summary.csv"
  or die "Cannot create summary: $!\n";
print {$summary} "seed,result,writes,reads,skipped_bytes,uvm_errors,uvm_fatals\n";

my ($passed, $failed) = (0, 0);
my $expected_writes = $pairs + 16; # 16 memory-initialization bursts per seed
$| = 1; # show each result as soon as its seed finishes

for my $seed (1 .. $seed_count) {
  my $log = "$run_dir/seed${seed}.log";

  my @command = (
    'xrun', '-64bit', '-sv', '-uvm', '-incdir', 'tb',
    'rtl/design.sv', 'tb/testbench.sv', '-top', 'tb_top',
    '-access', '+rwc',
    '+UVM_TESTNAME=axi_random_test', "+N_TXNS=$pairs",
    '-svseed', $seed, '-l', $log,
  );
  push @command, ('-coverage', 'all', '-covtest', "random_seed${seed}_$$")
    unless $no_coverage;

  print "Running seed $seed...\n" unless $quiet;
  my $status;
  if ($quiet) {
    my $console = "$run_dir/seed${seed}_console.txt";
    my $pid = fork();
    die "Cannot start seed $seed: $!\n" unless defined $pid;
    if ($pid == 0) {
      open STDOUT, '>', $console or die "Cannot create $console: $!\n";
      open STDERR, '>&', \*STDOUT or die "Cannot redirect stderr: $!\n";
      exec @command;
      die "Cannot run xrun: $!\n";
    }
    waitpid($pid, 0);
    $status = $?;
  } else {
    $status = system(@command);
  }

  my $output = '';
  if (open my $fh, '<', $log) {
    local $/;
    $output = <$fh> // '';
    close $fh;
  }

  my ($writes, $reads, $skipped) =
    $output =~ /Writes=(\d+)\s+reads=(\d+)\s+skipped bytes=(\d+)/;
  my ($errors) = $output =~ /^\s*UVM_ERROR\s*:\s*(\d+)\s*$/m;
  my ($fatals) = $output =~ /^\s*UVM_FATAL\s*:\s*(\d+)\s*$/m;

  my $ok = $status == 0
    && defined($writes) && $writes == $expected_writes
    && defined($reads) && $reads == $pairs
    && defined($skipped) && $skipped == 0
    && defined($errors) && $errors == 0
    && defined($fatals) && $fatals == 0
    && $output =~ /Simulation complete via/;

  my $result = $ok ? 'PASS' : 'FAIL';
  $ok ? $passed++ : $failed++;
  print {$summary} join(',', $seed, $result,
    map { defined($_) ? $_ : '' }
      ($writes, $reads, $skipped, $errors, $fatals)) . "\n";
  print "Seed $seed: $result\n";
}

close $summary;
print "Finished: $passed passed, $failed failed\n" unless $quiet;
print "Results: $run_dir\n" unless $quiet;
exit($failed ? 1 : 0);
