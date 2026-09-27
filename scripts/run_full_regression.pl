#!/usr/bin/env perl

use strict;
use warnings;
use File::Path qw(make_path);
use File::Spec;
use IO::Handle;
use POSIX qw(strftime);

# Number of simulator seeds and random write/read pairs per seed.
my $seed_count = shift @ARGV // 10;
my $pairs      = shift @ARGV // 100;
my $quiet      = @ARGV == 1 && $ARGV[0] eq '--quiet';

die "Usage: perl scripts/run_full_regression.pl SEEDS PAIRS [--quiet]\n"
  unless $seed_count =~ /^[1-9][0-9]*$/ && $pairs =~ /^[1-9][0-9]*$/
    && (@ARGV == 0 || $quiet);
die "Run from the repository root\n"
  unless -f 'rtl/design.sv' && -f 'tb/testbench.sv';
die "xrun is not available in PATH; load Xcelium first\n"
  unless grep { -x File::Spec->catfile($_, 'xrun') } File::Spec->path();

my $run_dir = 'results/full_' . strftime('%Y%m%d_%H%M%S', localtime) . "_$$";
my $cov_dir = "$run_dir/cov_work";
make_path($run_dir);

open my $summary, '>', "$run_dir/summary.csv"
  or die "Cannot create summary: $!\n";
print {$summary} "seed,result,writes,reads,skipped_bytes,commands_pct,write_data_pct,responses_pct,uvm_errors,uvm_fatals\n";
$summary->flush();
$| = 1; # show each seed result as soon as it finishes

# Save simulator output while keeping the terminal readable.
sub run_to_file {
  my ($command, $console_file) = @_;
  my $pid = fork();
  die "Cannot start simulator: $!\n" unless defined $pid;
  if ($pid == 0) {
    open STDIN, '<', File::Spec->devnull() or die "Cannot close simulator input: $!\n";
    open STDOUT, '>', $console_file or die "Cannot create $console_file: $!\n";
    open STDERR, '>&', \*STDOUT or die "Cannot redirect simulator errors: $!\n";
    exec @$command;
    die "Cannot run xrun: $!\n";
  }
  waitpid($pid, 0);
  return $?;
}

# Compile once; use the saved snapshot for every seed.
my @compile = (
  'xrun', '-64bit', '-sv', '-uvm', '-incdir', 'tb',
  'rtl/design.sv', 'tb/testbench.sv', '-top', 'tb_top',
  '-coverage', 'all', '-covdut', 'axi4_mem_slave',
  '-covworkdir', $cov_dir, '-elaborate', '-l', "$run_dir/compile.log",
);
print "Compiling...\n" unless $quiet;
die "Compile failed; see $run_dir/compile.log and compile_console.txt\n"
  if run_to_file(\@compile, "$run_dir/compile_console.txt") != 0;

my ($passed, $failed) = (0, 0);
for my $seed (1 .. $seed_count) {
  my $log = "$run_dir/seed${seed}.log";
  my @command = (
    'xrun', '-64bit', '-R', '+UVM_TESTNAME=axi_full_test',
    "+N_TXNS=$pairs", '-svseed', $seed,
    '-covworkdir', $cov_dir, '-covtest', "seed${seed}", '-l', $log,
  );
  my $status = run_to_file(\@command, "$run_dir/seed${seed}_console.txt");

  my $output = '';
  if (open my $fh, '<', $log) {
    local $/;
    $output = <$fh> // '';
    close $fh;
  }

  my ($writes, $reads, $skipped) =
    $output =~ /Writes=(\d+)\s+reads=(\d+)\s+skipped bytes=(\d+)/;
  my ($commands, $write_data, $responses) =
    $output =~ /Commands=(\d+\.\d+)%\s+write data=(\d+\.\d+)%\s+responses=(\d+\.\d+)%/;
  my ($errors) = $output =~ /^\s*UVM_ERROR\s*:\s*(\d+)\s*$/m;
  my ($fatals) = $output =~ /^\s*UVM_FATAL\s*:\s*(\d+)\s*$/m;

  my $ok = $status == 0
    && $output =~ /Running test axi_full_test/
    && $output =~ /Simulation complete via/
    && defined($writes) && defined($reads) && defined($skipped) && $skipped == 0
    && defined($commands) && $commands == 100
    && defined($write_data) && $write_data == 100
    && defined($responses) && $responses == 100
    && defined($errors) && $errors == 0
    && defined($fatals) && $fatals == 0;

  my $result = $ok ? 'PASS' : 'FAIL';
  $ok ? $passed++ : $failed++;
  print {$summary} join(',', $seed, $result,
    map { defined($_) ? $_ : '' }
      ($writes, $reads, $skipped, $commands, $write_data,
       $responses, $errors, $fatals)) . "\n";
  $summary->flush();
  print "Seed $seed: $result\n";
}

close $summary;
print "Finished: $passed passed, $failed failed\nResults: $run_dir\n"
  unless $quiet;
exit($failed ? 1 : 0);
