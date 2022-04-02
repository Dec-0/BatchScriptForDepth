#!/usr/bin/perl
use strict;
use Getopt::Long;
Getopt::Long::Configure qw(no_ignore_case);
use File::Basename;
use FindBin qw($Bin);
use lib "$Bin/.Modules";
use Parameter::BinList;

my ($HelpFlag,$BinList,$BeginTime);
my $ThisScriptName = basename $0;
my ($BedFile,$LogPath,$BamSuffix);
my ($Samtools,$Rscript,$VisualScript,$ComFileName,$NComFileName,$MapName,$NMapName,$MergeFlag,$SaveFlag);
my ($BamSuffix,$DepthSuffix,$StatSuffix,$AccumFileName,$ZeroDepthArea,$HighDepthArea);
my ($NDepthSuffix,$NStatSuffix,$NAccumFileName,$NZeroDepthArea,$NHighDepthArea);
my ($UltraLowDp,$UltraHighDp,$CPoint);
my (@CheckPoint,@FilePath,@OriBam,@SPName,@BamFile,@StatFile,@NStatFile,@DepthFile,@NDepthFile);
my $HelpInfo = <<USAGE;

 $ThisScriptName
 Auther: zhangdong_xie\@foxmail.com

  This script was used to show the depth distribution of samples visually.

 -i      The file path for the batch of samples (Multi times);
         (If not standard solid-tumor directory, there should exist depth file under log path)
 -s      Bam file (Multi times);
         Careful: '-i' and '-s' should at least specify one;
         
 -b      ( Required ) The Bed file;
 -log    ( Required ) Log path;
 -suffix ( Optional ) The suffix of a bam file (default: .final.bam);
 -low    ( Optional ) ultra low depth (default: 100);
 -high   ( Optional ) ultra high depth (default: 10000);
 -check  ( Optional ) Check point (Only support like 0,10,20,30,50);
 -merge  ( Optional ) For the merge of bed areas with similar mean and similar sd (default: off);
         (It will only compare contining areas in same samples)
 -save   ( Optional ) If saving mean/sd statics file (with only -save);
         
 -bin    List for searching of related bin or scripts;
 -h      Help infomation;

USAGE

GetOptions(
	'i:s' => \@FilePath,
	's:s' => \@OriBam,
	'b=s' => \$BedFile,
	'log=s' => \$LogPath,
	'suffix:s' => \$BamSuffix,
	'low:i' => \$UltraLowDp,
	'high:i' => \$UltraHighDp,
	'check:s' => \$CPoint,
	'merge!' => \$MergeFlag,
	'save!' => \$SaveFlag,
	'bin:s' => \$BinList,
	'h!' => \$HelpFlag
) or die $HelpInfo;

if($HelpFlag || (!@FilePath && !@OriBam) || !$BedFile || !$LogPath)
{
	die $HelpInfo;
}
else
{
	$BeginTime = ScriptBegin(0,$ThisScriptName);
	
	$BinList = BinListGet() if(!$BinList);
	$Samtools = BinSearch("Samtools",$BinList);
	$Rscript = BinSearch("Rscript",$BinList);
	$VisualScript = BinSearch("DepthVisual_v1.R",$BinList);
	
	$BamSuffix = ".Final.bam" unless($BamSuffix);
	my $tmpMid = $BamSuffix;
	$tmpMid =~ s/.bam$//;
	$DepthSuffix = $tmpMid . ".depth";
	$NDepthSuffix = $tmpMid . ".normal.depth";
	$StatSuffix = $tmpMid . ".stat.xls";
	$NStatSuffix = $tmpMid . ".stat.normal.xls";
	$ComFileName = "CombinedStat" . $tmpMid . ".xls";
	$NComFileName = "CombinedStat" . $tmpMid . ".normal.xls";
	$MapName = "DepthCompare" . $tmpMid . ".pdf";
	$NMapName = "DepthCompare" . $tmpMid . ".normal.pdf";
	$AccumFileName = "DepthAccumCount" . $tmpMid . ".xls";
	$ZeroDepthArea = "UltraLowDepthArea" . $tmpMid . ".xls";
	$HighDepthArea = "UltraHighDepthArea" . $tmpMid . ".xls";
	$NAccumFileName = "DepthAccumCount" . $tmpMid . ".normal.xls";
	$NZeroDepthArea = "UltraLowDepthArea" . $tmpMid . ".normal.xls";
	$NHighDepthArea = "UltraHighDepthArea" . $tmpMid . ".normal.xls";
	
	
	@FilePath = IfDirExist(@FilePath) if(@FilePath);
	`mkdir -p $LogPath` unless(-d $LogPath);
	$LogPath = IfDirExist($LogPath);
	IfFileExist($BedFile);
	$UltraLowDp = 100 if(!$UltraLowDp);
	$UltraHighDp = 10000 if(!$UltraHighDp);
	if(!$CPoint)
	{
		@CheckPoint = (0,10,20,30,40,50,60,70,80,90,100,200,300,400,500,600,700,800,900,1000,1100,1200,1300,1400,1500);
	}
	else
	{
		@CheckPoint = split /,/, $CPoint;
		for my $i (0 .. $#CheckPoint)
		{
			die "Not pure number for $CheckPoint[$i].\n" if($CheckPoint[$i] =~ /\D/);
		}
	}
}

if(1)
{
	for my $i (0 .. $#FilePath)
	{
		my $SPlist = $FilePath[$i] . "/" . "samplelist.xls";
		IfFileExist($SPlist);
		
		# Get the sample path;
		open(SP,"< $SPlist") or die $!;
		while(my $Line = <SP>)
		{
			chomp $Line;
			my @Cols = split /\t/, $Line;
			if($Cols[0])
			{
				push @SPName, $Cols[0];
				my $tmpFile = $FilePath[$i] . "/" . $Cols[0] . "/Alignment/" . $Cols[0] . $BamSuffix;
				push @BamFile, $tmpFile;
				$tmpFile = $LogPath . "/" . $Cols[0] . $DepthSuffix;
				push @DepthFile, $tmpFile;
				$tmpFile = $LogPath . "/" . $Cols[0] . $NDepthSuffix;
				push @NDepthFile, $tmpFile;
				$tmpFile = $LogPath . "/" . $Cols[0] . $StatSuffix;
				push @StatFile, $tmpFile;
				$tmpFile = $LogPath . "/" . $Cols[0] . $NStatSuffix;
				push @NStatFile, $tmpFile;
			}
		}
		close SP;
	}
	
	for my $i (0 .. $#OriBam)
	{
		my $BaseName = basename $OriBam[$i];
		my @tCols = split /\./, $BaseName;
		my @Cols = split /_/, $tCols[0];
		
		push @SPName, $Cols[0];
		my $tmpFile = $OriBam[$i];
		push @BamFile, $tmpFile;
		$tmpFile = $LogPath . "/" . $Cols[0] . $DepthSuffix;
		push @DepthFile, $tmpFile;
		$tmpFile = $LogPath . "/" . $Cols[0] . $NDepthSuffix;
		push @NDepthFile, $tmpFile;
		$tmpFile = $LogPath . "/" . $Cols[0] . $StatSuffix;
		push @StatFile, $tmpFile;
		$tmpFile = $LogPath . "/" . $Cols[0] . $NStatSuffix;
		push @NStatFile, $tmpFile;
	}
	
	# get full depth;
	for my $i (0 .. $#SPName)
	{
		unless(-s $DepthFile[$i])
		{
			&DpAcquire($BedFile,$BamFile[$i],$DepthFile[$i]);
		}
	}
	printf "[ %s ] Depth acquiring done.\n",TimeString(time,$BeginTime);
	
	# depth normalization;
	for my $i (0 .. $#DepthFile)
	{
		unless(-e $NDepthFile[$i])
		{
			&DpNorm($DepthFile[$i],$NDepthFile[$i]);
		}
	}
	printf "[ %s ] Normalization of depth done.\n",TimeString(time,$BeginTime);
	
	# calculate mean and sd;
	if($MergeFlag)
	{
		my (@Dp,@SF);
		
		@Dp = ();
		@SF = ();
		for my $i (0 .. $#SPName)
		{
			push @Dp, $DepthFile[$i];
			push @SF, $StatFile[$i];
		}
		&MergeStatGen(\@Dp,\@SF);
		
		@Dp = ();
		@SF = ();
		for my $i (0 .. $#SPName)
		{
			push @Dp, $NDepthFile[$i];
			push @SF, $NStatFile[$i];
		}
		&MergeStatGen(\@Dp,\@SF);
	}
	else
	{
		for my $i (0 .. $#SPName)
		{
			&StatGen($DepthFile[$i],$StatFile[$i]);
			&StatGen($NDepthFile[$i],$NStatFile[$i]);
		}
	}
	printf "[ %s ] Statical calculation done.\n",TimeString(time,$BeginTime);
	
	# calculate the fluctuation;
	&DepthNorm(\@DepthFile,\@StatFile,$ComFileName);
	# visulization;
	&MapDraw(\@StatFile,$ComFileName,$MapName);
	# accumulting files & ultra low or high info;
	&StatRecord(\@DepthFile,\@StatFile,$AccumFileName,$ZeroDepthArea,$HighDepthArea);
	printf "[ %s ] Map drawing done.\n",TimeString(time,$BeginTime);
	&DepthNorm(\@NDepthFile,\@NStatFile,$NComFileName);
	&MapDraw(\@NStatFile,$NComFileName,$NMapName);
	&StatRecord(\@NDepthFile,\@NStatFile,$NAccumFileName,$NZeroDepthArea,$NHighDepthArea);
	printf "[ %s ] Map drawing of normalized file done.\n",TimeString(time,$BeginTime);
	
	
}
printf "[ %s ] The end.\n",TimeString(time,$BeginTime);


######### Sub functions ##########
sub DpAcquire
{
	my ($Bed,$Bam,$DpFile) = @_;
	
	`$Samtools depth -a -d 0 -q 0 -Q 0 -b $Bed $Bam > $DpFile`;
	
	return 1;
}

sub DpNorm
{
	my ($Dp,$DpNormal) = @_;
	
	my $FullDp = `awk 'BEGIN{SUM = 0}{SUM += \$3}END{print SUM}' $Dp`;
	chomp $FullDp;
	my $Points = `cat $Dp | wc -l`;
	chomp $Points;
	if($Points > 0)
	{
		my $Mean = $FullDp / $Points;
		open(ORI,"< $Dp") or die $!;
		open(NOR,"> $DpNormal") or die $!;
		while(my $Line = <ORI>)
		{
			chomp $Line;
			my @Cols = split /\t/, $Line;
			# Resolution: 1/50000 = 0.00002
			$Cols[2] = sprintf("%.5f",$Cols[2] / $Mean);
			print NOR join("\t",@Cols),"\n";
		}
		close ORI;
		close NOR;
	}
	
	return 1;
}

sub StatGen
{
	my $Depth = $_[0];
	my $Stat = $_[1];
	my ($BedStart,$BedEnd,$PreChr,$PrePos);
	my ($Mean,$MeanPlusSd);
	my @Items;
	
	# calculate the average depth for every targeted area;
	open(DEPTH,"< $Depth") or die "Cannnot open depth fie ($!) $Depth\n";
	open(STAT,"> $Stat") or die "Cannnot open stat fie ($!) $Stat\n";
	($PreChr,$PrePos,$BedStart) = (0,0,0);
	@Items = ();
	while(my $Line = <DEPTH>)
	{
		chomp $Line;
		my @Cols = split /\t/,$Line;
		my $CurrChr = $Cols[0];
		my $CurrPos = $Cols[1];
		if($PreChr ne $CurrChr || $PrePos + 1 != $CurrPos)
		{
			# save the old;
			if($PreChr)
			{
				$BedEnd = $PrePos;
				($Mean,$MeanPlusSd) = &DepthStat(\@Items);
				print STAT "$PreChr\t$BedStart\t$BedEnd\t$Mean\t$MeanPlusSd\n";
			}
			
			@Items = ();
			$BedStart = $CurrPos - 1;
		}
		
		$PreChr = $CurrChr;
		$PrePos = $CurrPos;
		push @Items, $Cols[2];
	}
	# save the old;
	if(@Items)
	{
		$BedEnd = $PrePos;
		($Mean,$MeanPlusSd) = &DepthStat(\@Items);
		print STAT "$PreChr\t$BedStart\t$BedEnd\t$Mean\t$MeanPlusSd\n";
	}
	close DEPTH;
	close STAT;
	
	return 1;
}

sub tmpStatGen
{
	# the different between this and StatGen is this function will add all intems in the end;
	
	my $Depth = $_[0];
	my $Stat = $_[1];
	my ($BedStart,$BedEnd,$PreChr,$PrePos);
	my ($Mean,$MeanPlusSd);
	my @Items;
	
	# calculate the average depth for every targeted area;
	open(DEPTH,"< $Depth") or die "Cannnot open depth fie ($!) $Depth\n";
	open(STAT,"> $Stat") or die "Cannnot open stat fie ($!) $Stat\n";
	($PreChr,$PrePos,$BedStart) = (0,0,0);
	@Items = ();
	while(my $Line = <DEPTH>)
	{
		chomp $Line;
		my @Cols = split /\t/,$Line;
		my $CurrChr = $Cols[0];
		my $CurrPos = $Cols[1];
		if($PreChr ne $CurrChr || $PrePos + 1 != $CurrPos)
		{
			# save the old;
			if($PreChr)
			{
				$BedEnd = $PrePos;
				($Mean,$MeanPlusSd) = &DepthStat(\@Items);
				print STAT "$PreChr\t$BedStart\t$BedEnd\t$Mean\t$MeanPlusSd\t",join(",",@Items),"\n";
			}
			
			@Items = ();
			$BedStart = $CurrPos - 1;
		}
		
		$PreChr = $CurrChr;
		$PrePos = $CurrPos;
		push @Items, $Cols[2];
	}
	# save the old;
	if(@Items)
	{
		$BedEnd = $PrePos;
		($Mean,$MeanPlusSd) = &DepthStat(\@Items);
		print STAT "$PreChr\t$BedStart\t$BedEnd\t$Mean\t$MeanPlusSd\t",join(",",@Items),"\n";
	}
	close DEPTH;
	close STAT;
	
	return 1;
}

sub MeanSdCompar
{
	my ($PreMean,$PreSd,$CurrMean,$CurrSd) = @_;
	
	if($PreMean == 0 || $CurrMean == 0)
	{
		if($PreMean > 5 || $CurrMean > 5)
		{
			if($PreMean < 20 && $CurrMean < 20)
			{
				return 1;
			}
			else
			{
				return 0;
			}
		}
		return 1;
	}
	
	if($PreMean / $CurrMean > 5 ||  $PreMean / $CurrMean < 0.2)
	{
		return -10000;
	}
	
	# if they were in the range of mean +/- 3*sd;
	if($PreMean >= $CurrMean)
	{
		if((3 * $CurrSd - 2 * $CurrMean) >= (4 * $PreMean - 3 *$PreSd))
		{
			return 1;
		}
	}
	else
	{
		if((3 * $PreSd - 2 * $CurrMean) >= (4 * $CurrMean - 3 * $CurrSd))
		{
			return 1;
		}
	}
	
	# if they were in 50% - 150%, in case the sd nearly zero;
	my $tV = $PreMean / $CurrMean;
	if($tV >= 0.4 && $tV <= 1.6)
	{
		return 1;
	}
	
	return 0;
}

sub MergeStatGen
{
	my @DepthFile = @{$_[0]};
	my @StatFile = @{$_[1]};
	my (@tmpStatFile,@FullDp,@tmpDp);
	my (@tmpStatH,@StatH);
	
	for my $i (0 .. $#StatFile)
	{
		$tmpStatFile[$i] = $StatFile[$i];
		$tmpStatFile[$i] =~ s/xls$/beforemerge.xls/;
		
		&tmpStatGen($DepthFile[$i],$tmpStatFile[$i]) unless(-e $tmpStatFile[$i]);
	}
	printf "[ %s ] Merging preparation done.\n",TimeString(time,$BeginTime);
	
	# real merging;
	for my $i (0 .. $#DepthFile)
	{
		open($tmpStatH[$i],"< $tmpStatFile[$i]") or die $!;
		open($StatH[$i],"> $StatFile[$i]") or die $!;
	}
	
	my (@PriMean,@PriSd,@CurrMean,@CurrSd);
	my ($BedChr,$BedStart,$BedEnd,$CurrChr,$CurrStart,$CurrEnd);
	my $TotalSP = @DepthFile;
	my $Threadhold = int(0.6 * $TotalSP);
	my $CFlag = 1;
	for my $i (0 .. $#DepthFile)
	{
		$PriMean[$i] = -1;
	}
	# if there is need to continue;
	while($CFlag)
	{
		my ($AccumFlag,$ComparFlag) = (0,0);
		for my $i (0 .. $#tmpStatFile)
		{
			if(my $Line = readline($tmpStatH[$i]))
			{
				chomp $Line;
				my @Cols = split /\t/, $Line;
				($CurrChr,$CurrStart,$CurrEnd,$CurrMean[$i],$CurrSd[$i]) = @Cols[0..4];
				@{$tmpDp[$i]} = split /,/, $Cols[-1];
				if($PriMean[$i] < 0)
				{
					($BedChr,$BedStart,$BedEnd,$PriMean[$i],$PriSd[$i]) = ($CurrChr,$CurrStart,$CurrEnd,$CurrMean[$i],$CurrSd[$i]);
				}
				else
				{
					$ComparFlag ++;
					if($CurrChr eq $BedChr)
					{
						$AccumFlag += &MeanSdCompar($PriMean[$i],$PriSd[$i],$CurrMean[$i],$CurrSd[$i]);
					}
					else
					{
						# if chr not same, then must re-start;
						$AccumFlag = -10000;
					}
				}
			}
			else
			{
				$CFlag = 0;
				last;
			}
		}
		last if($CFlag == 0);
		
		if($AccumFlag < $Threadhold && $ComparFlag == $TotalSP)
		{
			# saving if not consistency;
			for my $i (0 .. $#DepthFile)
			{
				($PriMean[$i],$PriSd[$i]) = &DepthStat(\@{$FullDp[$i]});
				my $tmp = $StatH[$i];
				print $tmp "$BedChr\t$BedStart\t$BedEnd\t$PriMean[$i]\t$PriSd[$i]\n";
				
				# if current not involved, then it must be the first of next round;
				($PriMean[$i],$PriSd[$i]) = ($CurrMean[$i],$CurrSd[$i]);
			}
			($BedChr,$BedStart,$BedEnd) = ($CurrChr,$CurrStart,$CurrEnd);
			@FullDp = ();
		}
		else
		{
			# extend the boundary;
			$BedEnd = $CurrEnd;
		}
		for my $i (0 .. $#DepthFile)
		{
			# adding for larger amount statics;
			push @{$FullDp[$i]}, @{$tmpDp[$i]};
		}
	}
	
	for my $i (0 .. $#DepthFile)
	{
		($PriMean[$i],$PriSd[$i]) = &DepthStat(\@{$FullDp[$i]});
		my $tmp = $StatH[$i];
		print $tmp "$BedChr\t$BedStart\t$BedEnd\t$PriMean[$i]\t$PriSd[$i]\n";
		
		close $tmpStatH[$i];
		close $StatH[$i];
		`rm $tmpStatFile[$i]`;
	}
	
	return 1;
}

sub DepthNorm
{
	my @Depth = @{$_[0]};
	my @Stat = @{$_[1]};
	my $Combine = $_[2];
	my (@Mean,@MultiIndex);
	
	# amplification index for normalization;
	my $Avg = 0;
	for my $i (0 .. $#Depth)
	{
		my $Total = `awk 'BEGIN{SUM = 0}{SUM += \$3}END{print SUM}' $Depth[$i]`;
		chomp $Total;
		my $Points = `cat $Depth[$i] | wc -l`;
		chomp $Points;
		
		if($Points > 0)
		{
			$Mean[$i] = $Total / $Points;
		}
		else
		{
			$Mean[$i] = 0;
		}
		
		$Avg += $Mean[$i];
	}
	my $SPNum = @Depth;
	if($SPNum)
	{
		$Avg = $Avg / $SPNum;
	}
	for my $i (0 .. $#Depth)
	{
		if($Mean[$i] > 0)
		{
			$MultiIndex[$i] = $Avg / $Mean[$i];
		}
		else
		{
			$MultiIndex[$i] = 10000;
		}
	}
	
	# percentage of division;
	if(@MultiIndex)
	{
		my @Value;
		
		for my $i (0 .. $#Stat)
		{
			open(DEPTH,"< $Stat[$i]") or die $!;
			while(my $Line = <DEPTH>)
			{
				chomp $Line;
				my @Cols = split /\t/,$Line;
				push @{$Value[$i]}, $Cols[3];
			}
			close DEPTH;
		}
		
		my $tmpFile = $LogPath . "/" . $Combine;
		open(STAT,"> $tmpFile") or die $!;
		for my $i (0 .. $#{$Value[0]})
		{
			my ($Mean,$tmp);
			
			$Mean = 0;
			for my $j (0 .. $#SPName)
			{
				$Value[$j][$i] = $Value[$j][$i] * $MultiIndex[$j];
				$Mean += $Value[$j][$i];
			}
			$tmp = @SPName;
			$Mean = $Mean / $tmp;
			
			for my $j (0 .. $#Stat)
			{
				if($Mean > 0)
				{
					if($Value[$j][$i] / $Mean > 1.2 || $Value[$j][$i] / $Mean < 0.8)
					{
						$Value[$j][$i] = sprintf("%.4f",$Value[$j][$i] / $Mean);
					}
					else
					{
						$Value[$j][$i] = 1;
					}
				}
				else
				{
					$Value[$j][$i] = 1;
				}
			}
			
			$tmp = ();
			for my $j (0 .. $#SPName)
			{
				$tmp .= $Value[$j][$i];
				if($j != $#Stat)
				{
					$tmp .= "\t";
				}
				else
				{
					$tmp .= "\n";
				}
			}
			print STAT $tmp;
		}
		close STAT;
	}
	
	return 1;
}

sub MapDraw
{
	my @Stat = @{$_[0]};
	my $Combine = $_[1];
	my $Map = $_[2];
	my ($MapFile,$RLine,$Lines,$Digits,$FirstDigit,$SecondDigit,$XAxisLimit,$YAxisLimit,$Return);
	
	my ($AvgFile,$NewBed);
	if($Stat[0] =~ /stat.xls$/)
	{
		$AvgFile = $LogPath . "/AvgDepthOfAllSamples.stat.xls";
		$YAxisLimit = 10000;
		$NewBed = $LogPath . "/RevisedBedArea.bed";
	}
	else
	{
		$AvgFile = $LogPath . "/AvgDepthOfAllSamples.stat.normal.xls";
		$YAxisLimit = 2.5;
		$NewBed = $LogPath . "/RevisedBedArea.normal.bed";
	}
	$XAxisLimit = `cat $Stat[0] | wc -l`;
	chomp $XAxisLimit;
	
	my @tmpH;
	for my $i (0 .. $#Stat)
	{
		open($tmpH[$i],"< $Stat[$i]") or die $!;
	}
	open(AVG,"> $AvgFile") or die $!;
	my $tmpFlag = 1;
	while($tmpFlag)
	{
		my @tmpArray = ();
		my ($BedChr,$BedStart,$BedEnd);
		for my $i (0 .. $#Stat)
		{
			if(my $Line = readline($tmpH[$i]))
			{
				chomp $Line;
				my @Cols = split /\t/, $Line;
				($BedChr,$BedStart,$BedEnd) = @Cols[0..2];
				push @tmpArray, $Cols[3];
			}
			else
			{
				$tmpFlag = 0;
			}
		}
		last if($tmpFlag == 0);
		
		my ($Mean,$PlusSd) = &DepthStat(\@tmpArray);
		print AVG join("\t",$BedChr,$BedStart,$BedEnd,$Mean,$PlusSd),"\n";
	}
	for my $i (0 .. $#Stat)
	{
		close $tmpH[$i];
	}
	close AVG;
	
	$MapFile = $LogPath . "/" . $Map;
	$RLine = join(" ",@Stat);
	$RLine .= " " . $AvgFile;
	$RLine .= " " . $LogPath . "/" . $Combine;
	# $Return = `$Rscript $VisualScript $MapFile $RLine $AxisLimit`;
	$Return = `Rscript $VisualScript $MapFile $RLine $XAxisLimit $YAxisLimit`;
	chomp $Return;
	print "$Return\n";
	$Return = `cut -f 1-3 $Stat[0] > $NewBed`;
	chomp $Return;
	print "$Return\n";
	$RLine = $LogPath . "/" . $Combine;
	`rm $RLine`;
	`rm $AvgFile`;
	
	printf "[ %s ] Map drawing ends.\n",TimeString(time,$BeginTime);
	
	return 1;
}

sub StatRecord
{
	my @Depth = @{$_[0]};
	my @Stat = @{$_[1]};
	my $Accum = $_[2];
	my $Zero = $_[3];
	my $High = $_[4];
	my $LogFile;
	my (@TotalBase,@DepthCount);
	
	# calculate the accumulated depth;
	for my $i (0 .. $#Depth)
	{
		$TotalBase[$i] = 0;
		for my $j (0 .. $#CheckPoint)
		{
			$DepthCount[$i][$CheckPoint[$j]] = 0;
		}
		open(DEPTH,"< $Depth[$i]") or die $!;
		while(my $Line = <DEPTH>)
		{
			chomp $Line;
			my @Cols = split /\t/,$Line;
			for my $j (0 .. $#CheckPoint)
			{
				if($Cols[2] > $CheckPoint[$j])
				{
					$DepthCount[$i][$CheckPoint[$j]] ++;
				}
			}
			
			$TotalBase[$i] ++;
		}
		close DEPTH;
	}
	
	$LogFile = $LogPath . "/" . $Accum;
	open(LOG,"> $LogFile") or die $!;
	print LOG "                           \t",join("\t",@SPName),"\n";
	print LOG "Total_Points_in_target     \t",join("\t",@TotalBase),"\n";
	for my $j (0 .. $#CheckPoint)
	{
		print LOG "Points_Depth_Above_$CheckPoint[$j]";
		for my $i (0 .. $#SPName)
		{
			printf LOG "\t%d(%.2f%)",$DepthCount[$i][$CheckPoint[$j]],100*($DepthCount[$i][$CheckPoint[$j]]/$TotalBase[$i]);
		}
		print LOG "\n";
	}
	close LOG;
	
	# filter out the nearly zero depth area;
	$LogFile = $LogPath . "/" . $Zero;
	open(LOG,"> $LogFile") or die $!;
	for my $i (0 .. $#SPName)
	{
		my ($tempLine,$Id);
		
		print LOG "#",$SPName[$i],"\n#NumberOfArea\tChromosome\tStart\tEnd\tMeanDepth\tMean+SE\n";
		open(STAT,"< $Stat[$i]") or die $!;
		$Id = 0;
		while($tempLine = <STAT>)
		{
			my @Cols;
			@Cols = split /\t/,$tempLine;
			
			$Id ++;
			if($Cols[3] < $UltraLowDp)
			{
				print LOG "$Id\t$tempLine";
			}
		}
		close STAT;
		print LOG "\n";
	}
	close LOG;
	
	# filter out the ultra high depth area;
	$LogFile = $LogPath . "/" . $High;
	open(LOG,"> $LogFile") or die $!;
	for my $i (0 .. $#SPName)
	{
		my ($tempLine,$Id);
		
		print LOG "#",$SPName[$i],"\n#NumberOfArea\tChromosome\tStart\tEnd\tMeanDepth\tMean+SE\n";
		open(STAT,"< $Stat[$i]") or die $!;
		$Id = 0;
		while($tempLine = <STAT>)
		{
			my @Cols;
			@Cols = split /\t/,$tempLine;
			
			$Id ++;
			if($Cols[3] > $UltraHighDp)
			{
				print LOG "$Id\t$tempLine";
			}
		}
		close STAT;
		print LOG "\n";
	}
	close LOG;
	
	for my $i (0 .. $#Stat)
	{
		`rm $Stat[$i]` unless($SaveFlag);
	}
	
	printf "[ %s ] Depth statistics ends.\n",TimeString(time,$BeginTime);
}

sub DepthStat
{
	my ($Mean,$Sd,$MeanPlusSd);
	my ($Points,$Sum,$i);
	my @Depth = @{$_[0]};
	
	$Sum = 0;
	for $i (0 .. $#Depth)
	{
		$Sum += $Depth[$i];
	}
	$Points = @Depth;
	$Mean = $Sum / $Points;
	
	$Sum = 0;
	for $i (0 .. $#Depth)
	{
		$Sum += ($Depth[$i] - $Mean) ** 2;
	}
	if($#Depth)
	{
		$Sum = $Sum / $#Depth;
	}
	$Sd = sqrt($Sum);
	$MeanPlusSd = sprintf("%.4f",$Mean + $Sd);
	$Mean = sprintf("%.4f",$Mean);
	
	return $Mean,$MeanPlusSd;
}