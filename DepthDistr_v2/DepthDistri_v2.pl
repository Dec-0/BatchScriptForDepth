#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
Getopt::Long::Configure qw(no_ignore_case);
use File::Basename;
use FindBin qw($Bin);
use lib "$Bin/.Modules";
use Parameter::BinList;

my ($HelpFlag,$BinList,$BeginTime);
my $ThisScriptName = basename $0;
my ($Dir,$Prefix,$AvgDistrFile,$AvgAccumFile,$Rscript,$Samtools,$MapScript,$Map,$SaveFlag);
my ($Bed,$DistrX,$DistrY,$AccumX,$AccumY);
my (@Bam,@DPrefix,@DepthFile,@DistrFile,@AccumFile,@Check);
my $HelpInfo = <<USAGE;

 $ThisScriptName
 Auther: zhangdong_xie\@foxmail.com

  This script was used to draw the distribution for a bunch of files.
  本脚本用于展示累积深度分布曲线，以及深度的分布范围。

 -i      ( Required ) Depth files (Multi Times);
                      The value of depth should be uniform like float(\%.4f) or int;
 -b      ( Required ) Bam files (Multi Times);
         '-i' and '-b' should at least specified one;
 -log    ( Required ) Directory for logging;
 
 -name   ( Optional ) Names for the depth files (Multi times);
                      假如指定的话，需要和-i、-b数量之和一致。
 -r      ( Optional ) Bed file for bam '-b';
 -prefix ( Optional ) Prefix of the logging file (default: 'DepthDistribution');
 -dx     ( Optional ) Maximal limit for labX of the distributing map;
 -dy     ( Optional ) Maximal limit for labY of the distributing map;
 -ax     ( Optional ) Maximal limit for labX of the accumulating map;
 -save   ( Optional ) Saving the intermediate info;
 
 -bin    List for searching of related bin or scripts;
 -h      Help infomation;

USAGE

GetOptions(
	'i=s' => \@DepthFile,
	'b=s' => \@Bam,
	'log=s' => \$Dir,
	'name:s' => \@DPrefix,
	'r:s' => \$Bed,
	'prefix:s' => \$Prefix,
	'dx:f' => \$DistrX,
	'dy:f' => \$DistrY,
	'ax:f' => \$AccumX,
	'save!' => \$SaveFlag,
	'bin:s' => \$BinList,
	'h!' => \$HelpFlag
) or die $HelpInfo;

if($HelpFlag || (!@DepthFile && !@Bam) || !$Dir || (@Bam && !$Bed))
{
	die $HelpInfo;
}
else
{
	$BeginTime = ScriptBegin(0,$ThisScriptName);
	IfFileExist(@DepthFile,@Bam);
	$Dir = IfDirExist($Dir);
	
	
	$BinList = BinListGet() if(!$BinList);
	$Prefix = BinSearch("DefaulPrefix",$BinList,1) unless($Prefix);
	$Samtools = BinSearch("Samtools",$BinList);
	$Rscript = BinSearch("Rscript",$BinList);
	$MapScript = BinSearch("MapScript",$BinList);
	for my $i (0 .. 98)
	{
		# only count 99%;
		push @Check, 0.01 * (100 - $i);
	}
	
	if(@DPrefix)
	{
		my $tNumA = @DPrefix;
		my $tNumB = @DepthFile;
		my $tNumC = @Bam;
		die "[ Error ] The number of names not consistent with -i and -b\n" unless($tNumA == $tNumB + $tNumC);
	}
}

if(1)
{
	# 假如指定了bam，那它们默认不含有对应的depth文件，需要重新生成;
	my $PreNum = @DepthFile;
	my @RMFlag = (0) x $PreNum;
	for my $i (0 .. $#Bam)
	{
		my $tPrefix = basename $Bam[$i];
		$tPrefix =~ s/bam$//;
		if(@DPrefix)
		{
			$tPrefix = $DPrefix[$PreNum + $i];
		}
		my $tDepth = $Dir . "/" . $tPrefix . "depth";
		`$Samtools depth -a -d 0 -q 0 -Q 0 -b $Bed $Bam[$i] > $tDepth`;
		
		push @DepthFile, $tDepth;
		push @RMFlag, 1;
	}
	
	# 确定相关文件名称;
	for my $i (0 .. $#DepthFile)
	{
		my $tPrefix = basename $DepthFile[$i];
		$tPrefix =~ s/\.gz$//;
		$tPrefix =~ s/\.depth$//;
		if(@DPrefix)
		{
			$tPrefix = $DPrefix[$i];
		}
		
		$DistrFile[$i] = $Dir . "/" . $tPrefix . ".distri.xls";
		$AccumFile[$i] = $Dir . "/" . $tPrefix . ".accum.xls";
	}
	$AvgDistrFile = $Dir . "/" . $Prefix . ".avg.distri.xls";
	$AvgAccumFile = $Dir . "/" . $Prefix . ".avg.accum.xls";
	$Map = $Dir . "/" . $Prefix . ".pdf";
	
	# distribution of depth;
	my ($MaxX,$MaxY) = (0,0);
	for my $i (0 .. $#DepthFile)
	{
		# each sample;
		my ($tX,$tY) = &DistrDepth($DepthFile[$i],$DistrFile[$i]);
		if($tX > $MaxX)
		{
			$MaxX = $tX;
		}
		if($tY > $MaxY)
		{
			$MaxY = $tY;
		}
	}
	if(!$DistrX)
	{
		$DistrX = $MaxX;
	}
	if(!$DistrY)
	{
		$DistrY = $MaxY;
	}
	&AvgDistr(\@DistrFile,$AvgDistrFile,$DistrX);
	
	
	# accumulation of depth;
	($MaxX,$MaxY) = (0,1);
	for my $i (0 .. $#DistrFile)
	{
		# each sample;
		my $tX = &AccumDepth($DistrFile[$i],$AccumFile[$i]);
		if($tX > $MaxX)
		{
			$MaxX = $tX;
		}
	}
	&AvgAccum(\@AccumFile,$AvgAccumFile);
	$AccumY = $MaxY;
	if(!$AccumX)
	{
		$AccumX = $MaxX;
	}
	
	# map drawing;
	my $RLine = $Map;
	for my $i (0 .. $#DepthFile)
	{
		$RLine .= " " . $AccumFile[$i] . " " . $DistrFile[$i];
	}
	#print "Rscript $MapScript $AccumX $AccumY $DistrX $DistrY $RLine $AvgAccumFile $AvgDistrFile\n";
	print "[ Info ] Boundary of accumulation : $AccumX,$AccumY\n";
	print "[ Info ] Boundary of distribution : $DistrX,$DistrY\n";
	print "[ CmdLine ] Rscript $MapScript $AccumX $AccumY $DistrX $DistrY $RLine $AvgAccumFile $AvgDistrFile\n";
	my $Return = `Rscript $MapScript $AccumX $AccumY $DistrX $DistrY $RLine $AvgAccumFile $AvgDistrFile`;
	chomp $Return;
	print "$Return\n";
	
	# removing flag;
	if(!$SaveFlag)
	{
		for my $i (0 .. $#DepthFile)
		{
			`rm $DistrFile[$i]`;
			`rm $AccumFile[$i]`;
		}
		`rm $AvgDistrFile`;
		`rm $AvgAccumFile`;
	}
	
	for my $i (0 .. $#DepthFile)
	{
		`rm $DepthFile[$i]` if($RMFlag[$i] && -e $DepthFile[$i]);
	}
}
printf "[ %s ] The end.\n",TimeString(time,$BeginTime);


######### Sub functions ##########
sub DistrDepth
{
	# calculate the distr items;
	my ($Depth,$Distr) = @_;
	my ($Multi,$MultiBit) = &MultiCheck($Depth);
	if($MultiBit)
	{
		$MultiBit = "%." . $MultiBit . "f";
	}
	my $BaseName = basename $Depth;
	print "[ Info ] Multi number $Multi for $BaseName\n";
	
	my @Num = ();
	open(DP,"cat $Depth | grep -v ^# |") or die $! unless($Depth =~ /\.gz$/);
	open(DP,"zcat $Depth | grep -v ^# |") or die $! if($Depth =~ /\.gz$/);
	while(my $Line = <DP>)
	{
		chomp $Line;
		my @Cols = split /\t/, $Line;
		$Cols[2] = $Cols[2] * $Multi;
		
		$Num[$Cols[2]] ++;
	}
	close DP;
	
	# all record but only show limit for x, and max for y;
	my $Total = 0;
	$Total = `cat $Depth | wc -l` unless($Depth =~ /\.gz$/);
	$Total = `zcat $Depth | wc -l` if($Depth =~ /\.gz$/);
	chomp $Total;
	my ($tA,$tX,$tY) = (0,0,0);
	my $Limit = 1 - $Check[-1];
	open(DIS,"> $Distr") or die $!;
	for my $i (0 .. $#Num)
	{
		my $tmpDp = $i / $Multi;
		$Num[$i] = 0 unless($Num[$i]);
		my $tmpPer = $Num[$i] / $Total;
		$tA += $tmpPer;
		
		$tmpPer = sprintf("%.5f",$tmpPer);
		if($tmpPer > 0)
		{
			if($MultiBit)
			{
				$tmpDp = sprintf("$MultiBit",$tmpDp);
			}
			print DIS "$tmpDp\t$tmpPer\n";
		}
		
		if($tA >= $Limit && $tX == 0)
		{
			$tX = $i;
		}
		if($tmpPer > $tY)
		{
			$tY = $tmpPer;
		}
	}
	close DIS;
	$tX = $tX / $Multi;
	print "[ Info ] Boundary ($tX,$tY)\n";
	
	return $tX,$tY;
}

sub MultiCheck
{
	my $File = $_[0];
	my ($Multi,$MultiBit) = (1,0);
	
	my $tmpDp = "";
	$tmpDp = `cat $File | head -n 5 | cut -f 3` unless($File =~ /\.gz$/);
	$tmpDp = `zcat $File | head -n 5 | cut -f 3` if($File =~ /\.gz$/);
	my @Dp = split /\n/, $tmpDp;
	for my $i (0 .. $#Dp)
	{
		if($Dp[$i] =~ /\./)
		{
			my ($tMulti,$tMultiBit) = (1,0);
			my $tmp = 0;
			my @Cols = split //, $Dp[$i];
			for my $j (0 .. $#Cols)
			{
				if($Cols[$j] eq ".")
				{
					$tmp = $j + 1;
					last;
				}
			}
			for my $j ($tmp .. $#Cols)
			{
				$tMulti *= 10;
				$tMultiBit ++;
			}
			if($tMulti > $Multi)
			{
				$Multi = $tMulti;
			}
			if($tMultiBit > $MultiBit)
			{
				$MultiBit = $tMultiBit;
			}
		}
	}
	
	return $Multi,$MultiBit;
}

sub MultiCheck2
{
	my $File = $_[0];
	my ($Multi,$MultiBit) = (1,0);
	
	my $tmpDp = "";
	$tmpDp = `cat $File | head -n 5 | cut -f 1` unless($File =~ /\.gz$/);
	$tmpDp = `zcat $File | head -n 5 | cut -f 1` if($File =~ /\.gz$/);
	my @Dp = split /\n/, $tmpDp;
	for my $i (0 .. $#Dp)
	{
		if($Dp[$i] =~ /\./)
		{
			my ($tMulti,$tMultiBit) = (1,0);
			my $tmp = 0;
			my @Cols = split //, $Dp[$i];
			for my $j (0 .. $#Cols)
			{
				if($Cols[$j] eq ".")
				{
					$tmp = $j + 1;
					last;
				}
			}
			for my $j ($tmp .. $#Cols)
			{
				$tMulti *= 10;
				$tMultiBit ++;
			}
			if($tMulti > $Multi)
			{
				$Multi = $tMulti;
			}
			if($tMultiBit > $MultiBit)
			{
				$MultiBit = $tMultiBit;
			}
		}
	}
	
	return $Multi,$MultiBit;
}

sub AvgDistr
{
	my @Distr = @{$_[0]};
	my $Avg = $_[1];
	my $MaxX = $_[2];
	
	my ($Multi,$MultiBit) = (1,0);
	for my $i (0 .. $#Distr)
	{
		my ($tMulti,$tMultiBit) = &MultiCheck2($Distr[$i]);
		if($tMulti > $Multi)
		{
			$Multi = $tMulti;
			$MultiBit = $tMultiBit;
		}
	}
	
	if($Multi == 1)
	{
		my @Num = ();
		for my $i (0 .. $#Distr)
		{
			open(DP,"< $Distr[$i]") or die $!;
			while(my $Line = <DP>)
			{
				chomp $Line;
				my @Cols = split /\t/, $Line;
				
				$Num[$Cols[0]] += $Cols[1];
			}
			close DP;
		}
		
		
		# all record but only show limit for x, and max for y;
		my $Total = @Distr;
		open(DIS,"> $Avg") or die $!;
		for my $i (0 .. $#Num)
		{
			my $tmpDp = $i;
			$Num[$i] = 0 unless($Num[$i]);
			my $tmpPer = sprintf("%.4f",$Num[$i] / $Total);
			next if($tmpPer == 0);
			print DIS "$tmpDp\t$tmpPer\n";
		}
		close DIS;
	}
	else
	{
		my @Div = ();
		my $SubDiv = $MaxX / 1000;
		for my $i (0 .. 1000)
		{
			push @Div, sprintf("%.4f",$i * $SubDiv);
		}
		
		my @DValue = ();
		for my $i (0 .. $#Distr)
		{
			my @tmpArray = &DivCheck($Distr[$i],\@Div);
			
			for my $j (0 .. $#Div)
			{
				push @{$DValue[$j]}, $tmpArray[$j];
			}
		}
		open(AVG,"> $Avg") or die $!;
		for my $i (0 .. $#Div)
		{
			my $tMean = &MeanCal(\@{$DValue[$i]});
			print AVG "$Div[$i]\t$tMean\n";
		}
		close AVG;
	}
	
	return 1;
}

sub DivCheck
{
	my $File = $_[0];
	my @Div = @{$_[1]};
	my @Value = ();
	
	my ($PreValue,$CurrValue) = (0,0);
	my $DivFlag = 0;
	open(DIS,"< $File") or die $!;
	while(my $Line = <DIS>)
	{
		chomp $Line;
		my @Cols = split /\t/, $Line;
		next if($Cols[1] == 0);
		$CurrValue = $Cols[1];
		
		last if($DivFlag > $#Div);
		if($Div[$DivFlag] <= $Cols[0])
		{
			for my $i ($DivFlag .. $#Div)
			{
				if($Div[$DivFlag] <= $Cols[0])
				{
					$Value[$DivFlag] = sprintf("%.5f",($PreValue + $CurrValue) / 2);
					$DivFlag ++;
				}
			}
		}
		
		$PreValue = $CurrValue;
	}
	close DIS;
	
	return @Value;
}

sub MeanCal
{
	my @Num = @{$_[0]};
	
	my ($Total,$Items,$Mean) = (0,0,0);
	for my $i (0 .. $#Num)
	{
		$Total += $Num[$i];
		$Items ++;
	}
	if($Items > 0)
	{
		$Mean = $Total / $Items;
		if($Mean =~ /\./)
		{
			$Mean = sprintf("%.5f",$Mean);
		}
	}
	
	return $Mean;
}

sub AccumDepth
{
	my ($Distr,$Accum) = @_;
	
	my $CheckFlag = 0;
	my $AccumPer = 0;
	my $tX = 0;
	open(DIS,"< $Distr") or die $!;
	open(ACC,"> $Accum") or die $!;
	while(my $Line = <DIS>)
	{
		chomp $Line;
		my @Cols = split /\t/, $Line;
		last if($CheckFlag > $#Check);
		$AccumPer += $Cols[1];
		if($AccumPer + $Check[$CheckFlag] >= 1)
		{
			for my $i ($CheckFlag .. $#Check)
			{
				if($AccumPer + $Check[$i] >= 1)
				{
					print ACC "$Check[$CheckFlag]\t$Cols[0]\n";
					$tX = $Cols[0];
					$CheckFlag ++;
				}
				else
				{
					last;
				}
			}
		}
	}
	close DIS;
	close ACC;
	
	return $tX;
}

sub AvgAccum
{
	my @Accum = @{$_[0]};
	my $Avg = $_[1];
	
	my @AccumH = ();
	for my $i (0 .. $#Accum)
	{
		open($AccumH[$i],"< $Accum[$i]") or die $!;
	}
	open(AVG,"> $Avg") or die $!;
	
	my $AccumNum = @Accum;
	my $ContinueFlag = 1;
	while($ContinueFlag)
	{
		my ($Per,$Dp) = (0,0);
		for my $i (0 .. $#Accum)
		{
			if(my $Line = readline($AccumH[$i]))
			{
				chomp $Line;
				my @Cols = split /\t/, $Line;
				$Per = $Cols[0];
				$Dp += $Cols[1];
			}
			else
			{
				$ContinueFlag = 0;
				last;
			}
		}
		last if($ContinueFlag == 0);
		
		$Dp = sprintf("%.4f",$Dp / $AccumNum);
		print AVG "$Per\t$Dp\n";
	}
	
	for my $i (0 .. $#Accum)
	{
		close $AccumH[$i];
	}
	close AVG;
	
	return 1;
}