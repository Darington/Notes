library(randomForest)

datOrg=read.csv("~/git/Notes/Rpub/covid2/data2/covID2019_Mar16.csv", as.is = T, header = T)
rmNA=which(apply(is.na(datOrg), 1, any)) #remove
datWk=datOrg[-rmNA,]
cl=which(apply(datWk, 2, var)==0)
datWk=datWk[,-c(1,cl,37,39,40)]

covID2019.rs <- randomForest(diag~., data=datWk, proximity=TRUE)
varImpPlot(covID2019.rs)
abline(v=10, col="red")
covID.mds <- cmdscale(1-covID2019.rs$proximity, eig = T)
VarID=which(covID2019.rs$importance > 10)
pairs(cbind(datWk[,VarID], covID.mds$points), cex=0.6, gap=0,
      col=c("red", "blue")[as.numeric(datWk$diag)+1],
      main="CovID 2019")

#traing-test
tr_set=sample(nrow(datWk), ceiling(nrow(datWk)*0.8))
datWk_tr=datWk[tr_set,-ncol(datWk)]
datWk_trY=datWk[tr_set,ncol(datWk)]
datWk_test=datWk[-tr_set,-ncol(datWk)]
datWk_testY=datWk[-tr_set,ncol(datWk)]

covID2019.rs.tr <-randomForest(datWk_tr, datWk_trY, proximity=TRUE)
covPre=(predict(covID2019.rs.tr, datWk_test))
library(pROC)
aucObj=roc(datWk_testY, covPre)
plot(aucObj)

## Classification:
##data(iris)
set.seed(71)
iris.rf <- randomForest(Species ~ ., data=iris, importance=TRUE,
                        proximity=TRUE)
print(iris.rf)
## Look at variable importance:
varImpPlot(iris.rf)
round(importance(iris.rf), 2)
## Do MDS on 1 - proximity:
iris.mds <- cmdscale(1 - iris.rf$proximity, eig=TRUE)
op <- par(pty="s")
pairs(cbind(iris[,1:4], iris.mds$points), cex=0.6, gap=0,
      col=c("red", "green", "blue")[as.numeric(iris$Species)],
      main="Iris Data: Predictors and MDS of Proximity Based on RandomForest")
par(op)
print(iris.mds$GOF)

## The `unsupervised' case:
set.seed(17)
iris.urf <- randomForest(iris[, -5])
MDSplot(iris.urf, iris$Species)

## stratified sampling: draw 20, 30, and 20 of the species to grow each tree.
(iris.rf2 <- randomForest(iris[1:4], iris$Species, 
                          sampsize=c(20, 30, 20)))

## Regression:
## data(airquality)
set.seed(131)
ozone.rf <- randomForest(Ozone ~ ., data=airquality, mtry=3,
                         importance=TRUE, na.action=na.omit)
print(ozone.rf)
## Show "importance" of variables: higher value mean more important:
round(importance(ozone.rf), 2)

## "x" can be a matrix instead of a data frame:
set.seed(17)
x <- matrix(runif(5e2), 100)
y <- gl(2, 50)
(myrf <- randomForest(x, y))
(predict(myrf, x))

## "complicated" formula:
(swiss.rf <- randomForest(sqrt(Fertility) ~ . - Catholic + I(Catholic < 50),
                          data=swiss))
(predict(swiss.rf, swiss))
## Test use of 32-level factor as a predictor:
set.seed(1)
x <- data.frame(x1=gl(53, 10), x2=runif(530), y=rnorm(530))
(rf1 <- randomForest(x[-3], x[[3]], ntree=10))

## Grow no more than 4 nodes per tree:
(treesize(randomForest(Species ~ ., data=iris, maxnodes=4, ntree=30)))

## test proximity in regression
iris.rrf <- randomForest(iris[-1], iris[[1]], ntree=101, proximity=TRUE, oob.prox=FALSE)
str(iris.rrf$proximity)
