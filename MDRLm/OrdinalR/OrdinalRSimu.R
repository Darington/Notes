REP=100
N=100
beta0=sort(c(-2,1)) #intercept
beta1=1 #genetic effect
betaC=1.5 #covariate
Yc=matrix(1, N, length(beta0)+1)
Y=array(N, 1)
X=matrix(0, N, 2)

SIMU=matrix(0,REP, 4)

for(rp in 1:REP) {
  for(i in 1:N) {
    et=array(0,length(beta0))
    X[i,1]=rbinom(1, 2, 0.5)  #freq=0.5
    X[i,2]=rnorm(1) #one covariate
    
    for(j in 1:length(beta0)) {
      et[j]=exp(beta0[j] + beta1*X[i,1]+betaC*X[i,2])
      Yc[i,j] = et[j]/(1+et[j])
    }
    s0=runif(1)
    Y[i] = length(which(s0 > Yc[i,]))
  }
  
  Yf=as.factor(Y) #as factor
  m <- polr(Yf ~ X, Hess=TRUE)
  summary(m)
  SIMU[rp, 1] = summary(m)$coefficient[3,1]  
  SIMU[rp, 2] = summary(m)$coefficient[4,1]  
  SIMU[rp, 3] = summary(m)$coefficient[1,1]
  SIMU[rp, 4] = summary(m)$coefficient[2,1]  
  
}
colnames(SIMU)= c("Intercept1", "Intercept2", "G", "Cov")
barplot(colMeans(SIMU), ylim=c(-3,3))
abline(h=c(beta0, -1*beta1, -1*betaC), col=c("red", "blue", "green", "black"))
legend("topleft", legend = c("Int1", "Int2", "G effect", "Cov effect"), col=c("red", "blue","green", "black"), lty=1)
