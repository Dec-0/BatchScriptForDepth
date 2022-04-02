#!/usr/bin/Rscript

args = commandArgs(T)
TotalArgs = length(args)
XAxisLimit = as.numeric(args[TotalArgs - 1])
YAxisLimit = as.numeric(args[TotalArgs])
Limit = TotalArgs - 3
Colors = c("#000000","#66CDAA","#FFD700","#4F94CD","#FF8C00","#8B658B")
LineColors = c("#000000C0","#66CDAAC0","#FFD700C0","#4F94CDC0","#FF8C00C0","#8B658BC0");

data = read.table(args[2],sep="\t",header=F)
tmpNum = length(data$V1)
tmpWidth = ceiling(tmpNum / 400)
if(tmpWidth < 10)
{
	tmpWidth = 10
}
pdf(args[1],width=tmpWidth,height=2.5 * Limit)
par(mfrow=c(Limit,1))
for(id in c(2:Limit))
{
	ListOne = strsplit(args[id],split="/")
	ListTwo = strsplit(ListOne[[1]][length(ListOne[[1]])],split="[.]")
	SampleName = ListTwo[[1]][1];
	
	data = read.table(args[id],sep="\t",header=F)
	temp = as.vector(unlist(data[4]))
	ColorId = id %% 6 + 1
	if(YAxisLimit > 10)
	{
		plot(temp,type="h",col=Colors[ColorId],lwd=0.13,main=SampleName,xaxt="n",xlab="Id of targeted area",ylab="Average depth (+ SD)")
	} else {
		plot(temp,type="h",col=Colors[ColorId],lwd=0.13,main=SampleName,xaxt="n",xlab="Id of targeted area",ylab="Average depth (+ SD)",ylim=c(0,YAxisLimit))
	}
	axis(1,at=seq(0,XAxisLimit,20))
	legend("topright",legend=c("Mean","Mean+Sd"),col=c(Colors[ColorId],"#36363660"),pch=c(15,15),cex=0.8,pt.cex=1.8,text.col=c("#000000","#000000"),bty="n")
	temp = as.vector(unlist(data[5]))
	lines(temp,col="#36363660",lwd=0.2)
}

data = read.table(args[TotalArgs - 2],sep="\t",header=F)
temp = as.vector(unlist(data[1]))
plot(temp,type="l",col=LineColors[2],main="Division",xaxt="n",xlab="Id of targeted area",ylab="Division")
axis(1,at=seq(0,XAxisLimit,100))
Limit = length(data)
if(Limit > 1)
{
	for(id in c(2:Limit))
	{
		temp = as.vector(unlist(data[id]))
		ColorId = (id + 1) %% 6
		lines(temp,col=LineColors[ColorId],lwd=1.5)
	}
}
dev.off()
