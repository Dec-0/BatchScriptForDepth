#!/usr/bin/Rscript

args = commandArgs(T)
Colors = c("#FFD700","#4F94CD","#FF8C00","#000000","#66CDAA","#8B658B")
TransColors = c("#FFD70010","#4F94CD10","#FF8C0010","#00000010","#66CDAA10","#8B658B10")

Limit = length(args)
if(Limit < 3)
{
	stop("\nNo arguments specified !\n\nThis script was used for depth counting.\n\n")
}
MapNum = Limit - 5
if(MapNum %% 2)
{
	stop("Numebr of data files is not even !\n")
}
SPNum = MapNum / 2
cat("Total number of samples: ",SPNum,"\n")

MaxAX = as.numeric(args[1])
MaxAY = as.numeric(args[2])
MaxDX = as.numeric(args[3])
MaxDY = as.numeric(args[4])

pdf(args[5],width=8,height=3.5 * (SPNum + 1))
par(mfrow=c(SPNum + 1,2),mgp=c(2.3,0.8,0),oma=c(1,1,1,1))
tLimit = Limit - 2
LineNum = 0
for(Id in c(6:tLimit))
{
	if(Id %% 2)
	{
		data = read.table(args[Id],sep="\t",header=F)
		LineNum = length(data[,1])
		if(LineNum < 300)
		{
			TransColors = c("#FFD700B0","#4F94CDB0","#FF8C00B0","#000000B0","#66CDAAB0","#8B658BB0")
		}
	}
}
for(Id in c(6:tLimit))
{
	if(Id %% 2)
	{
		next
	}
	
	ListOne = strsplit(args[Id],split="/")
	ListTwo = strsplit(ListOne[[1]][length(ListOne[[1]])],split="[.]")
	SampleName = ListTwo[[1]][1];
	
	data = read.table(args[Id],sep="\t",header=F)
	ColorId = floor(Id / 2) %% 6 + 1
	plot(x=data$V2,y=data$V1,type="l",col=Colors[ColorId],main=SampleName,xlim=c(0,MaxAX),ylim=c(0,MaxAY),xlab="Sequencing depth on one point",ylab="Accumulated percentage on all points")
	
	data = read.table(args[Id + 1],sep="\t",header=F)
	plot(data,type="h",col=Colors[ColorId],main=SampleName,xlim=c(0,MaxDX),ylim=c(0,MaxDY),xlab="Sequencing depth on one point",ylab="Percentage on all points")
	tdata1 = data$V1[which(data$V1 > 0.5)]
	tdata2 = data$V2[which(data$V1 > 0.5)]
	Peak = tdata1[which(tdata2 == max(tdata2))]
	PeakTxt = paste(" ","Peak depth =",Peak[1])
	legend("topright",legend=PeakTxt,text.col="red",bty="n")
	
	#lines(temp,col="#36363660",lwd=0.2)
}
Limit = Limit - 1
for(Id in c(Limit:Limit))
{
	if(Id %% 2)
	{
		next
	}
	
	ListOne = strsplit(args[Id],split="/")
	ListTwo = strsplit(ListOne[[1]][length(ListOne[[1]])],split="[.]")
	SampleName = ListTwo[[1]][1];
	
	data = read.table(args[Id],sep="\t",header=F)
	ColorId = floor(Id / 2) %% 6 + 1
	plot(x=data$V2,y=data$V1,type="l",col=Colors[ColorId],xlim=c(0,MaxAX),ylim=c(0,MaxAY),xlab="Sequencing depth on one point",ylab="Accumulated percentage on all points",main="Averaged Curve")
	
	data = read.table(args[Id + 1],sep="\t",header=F)
	plot(data,type="h",col=Colors[ColorId],xlim=c(0,MaxDX),ylim=c(0,MaxDY),xlab="Sequencing depth on one point",ylab="Percentage on all points",main="Averaged Distribution")
	tdata1 = data$V1[which(data$V1 > 0.5)]
	tdata2 = data$V2[which(data$V1 > 0.5)]
	Peak = tdata1[which(tdata2 == max(tdata2))]
	PeakTxt = paste(" ","Peak depth =",Peak[1])
	legend("topright",legend=PeakTxt,text.col="red",bty="n")
	
	#lines(temp,col="#36363660",lwd=0.2)
}

Limit = Limit - 1
data = read.table(args[6],sep="\t",header=F)
ColorId = 4
plot(x=data$V2,y=data$V1,type="l",lwd=0.2,col=Colors[ColorId],main="All Samples",xlim=c(0,MaxAX),ylim=c(0,MaxAY),xlab="Sequencing depth on one point",ylab="Accumulated percentage on all points")
for(Id in c(7:Limit))
{
	if(Id %% 2 == 0)
	{
		data = read.table(args[Id],sep="\t",header=F)
		ColorId = floor(Id / 2) %% 6 + 1
		lines(x=data$V2,y=data$V1,col=Colors[ColorId],lwd=0.2)
	}
}

data = read.table(args[7],sep="\t",header=F)
ColorId = 4
plot(data,type="h",col=TransColors[ColorId],main="All Samples",xlim=c(0,MaxDX),ylim=c(0,MaxDY),xlab="Sequencing depth on one point",ylab="Percentage on all points")
for(Id in c(8:Limit))
{
	if(Id %% 2)
	{
		data = read.table(args[Id],sep="\t",header=F)
		ColorId = floor(Id / 2) %% 6 + 1
		par(new=TRUE)
		plot(data,type="h",col=TransColors[ColorId],xlim=c(0,MaxDX),ylim=c(0,MaxDY),xlab="",ylab="")
	}
}

dev.off()