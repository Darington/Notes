library(Rcpp)
sourceCpp("~/git/Notes/R/RLib/Shotgun.cpp") #https://github.com/gc5k/Notes/blob/master/R/RLib/Shotgun.cpp
###############simulation setup
hl=0.2 #large effect
hs=0.3 #small effect
BLK=20 #number of blocks
BLK_snp=50 #LD block size

M=BLK_snp*BLK #loci
Bloci=seq(10, M, by=BLK) #big effect loci
Ml=length(Bloci) #one large effect in each block
Ms=M-Ml #number of small effect loci

ldInterval=BLK_snp*seq(0, BLK) #ld Tag
frq=runif(M, 0.1, 0.9) #allele frequency
Dp=runif(M-1, 0.8, 1)*sample(c(1,-1), M-1, replace = T) #ld
Dp[BLK_snp*seq(1,BLK-1)]=0 #set break
N=1000 #sample size
Nref=1000 #test

####################
#simulating effect
####################
snpEff=array(0, M)
snpEff[-Bloci]=rnorm(Ms, 0, sqrt(hs/Ms))
print(var(snpEff[-Bloci])*Ms)
snpEff[Bloci]=rnorm(Bloci, 0, sqrt(hl/Ml))
print(var(snpEff[Bloci])*Ml)

####################
#simulating genotype
####################
G=GenerateGenoDprimeRcpp(frq, Dp, N)
sG=scale(G) #scale genotype

#simulating additive effect
bv=sG%*%snpEff
ve=var(bv)/(hl+hs)*(1-hl-hs) #scale residual
y=bv+rnorm(N,0, sqrt(ve))

#simulating reference genome for ld block
Gref=GenerateGenoDprimeRcpp(frq, Dp, Nref)
sGref=scale(Gref)

#########################
#GWAS
#########################
SumStat=matrix(0, M, 4) #summary stats
for(i in 1:nrow(SumStat)) {
  mod=lm(y~sG[,i])
  SumStat[i,]=summary(mod)$coefficient[2,]
}

#####select big loci
BigLoci=Bloci #can be other procedure to pick up big effect loci




##########################################
##Henderson's MME, computational expensive
##########################################
TH_1=Sys.time()
h2_hat=hs+hl #can be estimated wiht other methods. Here we direct plug in the true h2
hs_hat=hs/Ms #h2 for each locus
sGl=sG[,-BigLoci] #matrix for small effect
lGl=sG[,BigLoci] #matrix for large effect

H=hs_hat*sGl%*%t(sGl)+diag(1,N) #Big V matrix
H_inv=solve(H) #inverse it

m1=t(lGl)%*%H_inv%*%lGl
m1_inv=solve(m1)
Bl_henderson=m1_inv%*%t(lGl)%*%H_inv%*%y #generalized estimation for fixed effect

y_res=y-lGl%*%Bl_henderson #residual
Bs_henderson=hs_hat*t(sGl)%*%H_inv%*%(y_res) #blup for random snp effects
TH_2=Sys.time()
print(TH_2-TH_1)

##plot results
layout(matrix(1:6,2,3, byrow = T))
plot(snpEff, SumStat[,1], col="red", pch=16, cex=0.5, xlab="B", ylab="LSE-B")
points(snpEff[BigLoci], SumStat[BigLoci,1], col="blue", pch=2)
abline(a=0, b=1, col="red")

plot(snpEff[-BigLoci], Bs_henderson, col="gold", pch=5, cex=0.5, xlab="Bsmall", ylab="BLUP-Bsmall")
abline(a=0, b=1, col="red")

plot(snpEff[BigLoci], Bl_henderson, col="green", pch=15, xlab="Blarge", ylab="Blarge-blup")
abline(a=0, b=1, col="red")

hist(snpEff[BigLoci], main="B")
hist(SumStat[BigLoci], main="Blup-Bsmall")
hist(Bs_henderson[BigLoci], main="Blup-Blarge")


########################################
#zxBLUP AJHG v106 p679-693
########################################
LDmatOrg=t(sG)%*%sG/(N-1)

ZH_1=Sys.time()
Ns=ceiling(Nref*1)
subS=sort(sample(Nref, Ns)) #subsampling technique
LDmat=t(sGref[subS,])%*%sGref[subS,]/(Ns-1)

#LDmat=LDmatOrg
ZH_1_1=Sys.time()

hMat=matrix(0, M-length(BigLoci), M-length(BigLoci)) #v matrix
lCnt=0
ldSS_size=matrix(0, BLK, 2)
for(i in 1:BLK) { #block-wise inversion for V using Zhou Xiang's trick
  ld_tag=seq(ldInterval[i]+1, ldInterval[i+1])
  rmLoci=intersect(ld_tag, Bloci)
  if(length(rmLoci)!=0) {
    ld_tag=setdiff(ld_tag, rmLoci)
  }
  ldss=LDmat[ld_tag, ld_tag]
  Ims_sub=diag(1/hs_hat/N, length(ld_tag))
  h=Ims_sub+ldss
  h_Inv=solve(h)
  hMat[(lCnt+1):(lCnt+length(ld_tag)), (lCnt+1):(lCnt+length(ld_tag))]=h_Inv
  ldSS_size[i,]=c(lCnt+1, lCnt+length(ld_tag))
  lCnt=lCnt+length(ld_tag)
}
LDll=LDmat[BigLoci, BigLoci]
LDls=LDmat[BigLoci, -BigLoci]
LDsl=LDmat[-BigLoci, BigLoci]
LDss=LDmat[-BigLoci, -BigLoci]
Zl=SumStat[BigLoci, 3]
Zs=SumStat[-BigLoci, 3]

P1=LDls%*%hMat #there is another trick here to reduce multiplication
C1=(LDll-P1%*%LDsl)
C1_inv=solve(C1)
C2=(Zl-P1%*%Zs)
beta_l_zx=1/sqrt(N)*C1_inv%*%C2

Ims=diag(1, M-length(BigLoci))

ZH_2_1=Sys.time()
P2=matrix(0, nrow(hMat), ncol(hMat))
for(i in 1:nrow(ldSS_size)) {
  l1=ldSS_size[i,1]
  l2=ldSS_size[i,2]
  P2[l1:l2, l1:l2] = LDss[l1:l2, l1:l2] %*% hMat[l1:l2, l1:l2]
}
#P2=LDss%*%hMat
ZH_2_2=Sys.time()

beta_s_zx=hs_hat*(Ims-P2)%*%(sqrt(N)*Zs-N*LDsl%*%beta_l_zx)
ZH_3=Sys.time()

##plot
layout(matrix(1:3, 1,3))
plot(snpEff[BigLoci], beta_l_zx, ylab="Quick Big Effect", xlab="True Big effect")
abline(a=0, b=c(1))
plot(snpEff[-BigLoci], beta_s_zx, ylab="Quick small effect", xlab="True small effect")
abline(a=0, b=c(1))
plot(Bs_henderson, beta_s_zx, xlab="Henderson BLUP", ylab="Quick BLUP")
abline(a=0, b=c(1))

#######################
##prediction accuracy
#######################
SIMU=30
Nt=1000
Gt=GenerateGenoDprimeRcpp(frq, Dp, Nt)
sGt=scale(Gt) #scale genotype

bvt=sGt%*%snpEff
vet=var(bvt)/(hl+hs)*(1-hl-hs) #scale residual

accuracy=matrix(0, SIMU, 3)
for(s in 1:SIMU) {
  yt=bvt+rnorm(Nt,0, sqrt(vet))

  yPre_zx=sGt[,BigLoci]%*%beta_l_zx+sGt[,-BigLoci]%*%beta_s_zx
  yPre_h=sGt[,BigLoci]%*%Bl_henderson+sGt[,-BigLoci]%*%Bs_henderson
  yPre_lse=sGt[,BigLoci]%*%SumStat[BigLoci,1]+sGt[,-BigLoci]%*%SumStat[-BigLoci,1]
  accuracy[s,1]=cor(yt, yPre_zx)
  accuracy[s,2]=cor(yt, yPre_h)
  accuracy[s,3]=cor(yt, yPre_lse)
}
barplot(colMeans(accuracy))
