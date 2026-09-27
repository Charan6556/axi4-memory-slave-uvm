#!/usr/bin/env perl

use strict;
use warnings;
use POSIX qw(strftime);
use File::Path qw(make_path);

# getting seed count and transactions per seed

my $seed_count = shift @ARGV // 10;
my $pairs      = shift @ARGV // 100;

die "Use positive integers for seeds and pairs\n"
unless $seed_count =~ /^[1-9][0-9]*$/
&& $pairs =~ /^[1-9][0-9]*$/;

# DUT module name for code coverage

my $dut = "axi4_mem_slave";

# creating a separate directory for this regression

my $stamp   = strftime("%Y%m%d_%H%M%S", localtime);
my $run_dir = "perl_regression_${stamp}_$$";
my $cov_dir = "$run_dir/cov_work";

make_path($run_dir);

# creating result summary

open my $summary, ">", "$run_dir/summary.csv"
or die "Cannot create summary: $!\n";

print {$summary} "seed,result\n";

my $passed = 0;
my $failed = 0;

# including sixteen initialization write bursts

my $expected_writes = $pairs + 16;

# compiling and elaborating once before all seeds

print "\nCompiling design and testbench...\n";

my @compile = (
    "xrun",
    "-64bit", "-sv", "-uvm",
    "-incdir", ".",
    "design.sv", "testbench.sv",
    "-top", "tb_top",
    "-coverage", "all",
    "-covdut", $dut,
    "-covworkdir", $cov_dir,
    "-elaborate",
    "-l", "$run_dir/compile.log"
);

system(@compile) == 0
    or die "Compile failed, check $run_dir/compile.log\n";

# running each seed on the compiled snapshot

for my $seed (1 .. $seed_count) {

    my $log = "$run_dir/axi_random_seed${seed}.log";

    print "\nRunning seed $seed...\n";

    # building simulator command for this seed

    my @command = (
        "xrun",
        "-64bit", "-R",
        "+UVM_TESTNAME=axi_full_test",
        "+N_TXNS=$pairs",
        "-svseed", "$seed",
        "-covworkdir", $cov_dir,
        "-covtest", "seed${seed}",
        "-l", $log
    );

    # running simulation and getting exit status

    my $status = system(@command);

    # reading simulation log

    my $text = "";

    if (open my $log_file, "<", $log) {
        local $/;
        $text = <$log_file> // "";
        close $log_file;
    }

    # checking simulator completion and UVM results

    my $ok =
        ($status == 0)
        && ($text =~ /^\s*UVM_ERROR\s*:\s*0\s*$/m)
        && ($text =~ /^\s*UVM_FATAL\s*:\s*0\s*$/m)
        && ($text =~ /skipped bytes=0\b/)
&& ($text =~ /Commands=100\.00%\s+write data=100\.00%\s+responses=100\.00%/)
	&& ($text =~ /Simulation complete via/);

    # recording result for this seed

    my $result = $ok ? "PASS" : "FAIL";

    if ($ok) {
        $passed++;
    }
    else {
        $failed++;
    }

    print "Seed $seed: $result\n";
    print {$summary} "$seed,$result\n";
}

close $summary;

# merging coverage from all seeds

print "\nMerging coverage...\n";

my $imc = `which imc 2>/dev/null`;
chomp $imc;

if ($imc) {
    system("imc -execcmd \"merge $cov_dir/scope/seed* -out $cov_dir/scope/all_seeds -overwrite\"");
    system("imc -execcmd \"load -run $cov_dir/scope/all_seeds; report -summary -out $run_dir/coverage_summary.txt\"");
    print "Coverage report: $run_dir/coverage_summary.txt\n";
}
else {
    print "imc not found on PATH, skipping merge.\n";
    print "Per-seed coverage data is in $cov_dir/scope/\n";
}

# printing final regression result

print "\nFinished: $passed passed, $failed failed\n";
print "Logs and summary: $run_dir\n";

exit($failed ? 1 : 0);
