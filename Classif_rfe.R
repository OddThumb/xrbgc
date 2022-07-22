# Argument reading library (Python style)
if ( !require(optparse) ) {
  install.packages("optparse", repos="https://cran.seoul.go.kr/", quite=TRUE)
}
library(optparse)

# Input arguments ----
option_list = list(
  make_option(c("-p", "--primary"), type="character", default=NULL, 
              help="Primary dataset file name; one csv file or file list", metavar="character"),
  make_option(c("-e", "--eval"), type="character", default=NULL, 
              help="Evalulation dataset file name; one csv file or file list", metavar="character"),
  make_option(c("-c", "--label_column"), type="character", default="source_type",
              help="Label column name [default= %default]", metavar="character"),
  make_option(c("-l", "--label"), type="character", default=NULL,
              help="Class name for binary classification (e.g. CV)", metavar="character"),
  make_option(c("-o", "--out"), type="character", default="classifications",
              help="Output directory name [default= %default]", metavar="character"),
  make_option(c("-n", "--nproc"), type="numeric", default=8,
              help="Number of cores for parallel processing [default= %default]", metavar="numeric")
)

opt_parser = OptionParser(option_list=option_list)
opt = parse_args(opt_parser)

if (is.null(opt$primary)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file)", call.=FALSE)
}


# Set seed for reproducing
RNGkind(sample.kind = "Rejection")
set.seed(71263)


# Library loading
package.list <- c("rlist", "tools", "stringr", "dplyr", "abind", "reshape2",  # data handling
                  "caret", "caretEnsemble", 'randomForest', 'kernlab', 'nnet', 'kknn', 'klaR', 'rpart', 'fastAdaboost', # ensemble model
                  "plotly", "corrplot", "ggplot2", 'ggpubr', "pROC", "htmlwidgets",  # plot
                  "doParallel", 'doSNOW')  # parallel computing
installed <- unlist(lapply(package.list, require, character.only=TRUE))
if (!all(installed)) {
  lapply(package.list[!installed], install.packages, repos="https://cran.seoul.go.kr/", quite=TRUE)
}
lapply(package.list, require, character.only=TRUE)


# Define directory, target name, data version and data suffix
cat(">>> Making subdirectory and working directory...")
OutDirectory <- opt$out
dir.create(OutDirectory)

# Make sub-directory
target <- opt$label
suffix <- system("date +%y%m%d_%H%M%S", intern=TRUE)
WD <- paste(OutDirectory,paste(target,suffix,sep="_"),sep='/')
dir.create(WD)
cat("\n>>> Following directories are created: ",OutDirectory, WD)


# Options
SMOTE <- T
cv.method <- 'loocv'
norm.theta <- NULL #"PhyDist"
nproc <- opt$nproc


# ============================ Function Bin ====================================
# Searching for cross-validation parameter
cv.param <- function(cv.name, param) {
  param.list <- list('repcv'=list('method'='repeatedcv',
                                  'nfolds'=10,
                                  'nrepeats'=5),
                     'loocv'=list('method'='cv',
                                  'nfolds'=nrow(trainset),
                                  'nrepeats'=NULL))
  return(list('method'=param.list[[cv.name]][[param]]))
}

# Load data
data_load <- function(key, levels=sort(unique(data_raw[,opt[["label_column"]]]))) {
  if ( file_ext(opt[[key]])=="csv" ) {
    data.list <- list()
    
    # Naming
    name0 <- strsplit(opt[[key]], "\\_|\\.")[[1]][2]
    letters <- gsub(x = name0, pattern = "[[:digit:]]+", replacement = "")
    numbers <-  gsub(x = name0, pattern = "[^[:digit:]]+", replacement = "")
    letters_loc <- str_locate(name0, letters)
    numbers_loc <- str_locate(name0, numbers)
    name <- ifelse(numbers_loc[1] < letters_loc[1], paste(numbers,letters,sep=' '), paste(letters,numbers,sep=' '))
    
    data_raw <- read.csv(opt[[key]]) %>% mutate(GC=name)
    data_raw[,opt[["label_column"]]] <- factor(data_raw[,opt[["label_column"]]], levels=levels)
    data.list[[name]] <- data_raw
  } else {
    cat("\n!!! Input",key,"file is not a csv file, assuming a list of files...")
    data.list.file <- read.table(opt[[key]])$V1
    data.list <- list()
    for (l in data.list.file) {
      name0 <- strsplit(l, "\\_|\\.")[[1]][2]
      letters <- gsub(x = name0, pattern = "[[:digit:]]+", replacement = "")
      numbers <- gsub(x = name0, pattern = "[^[:digit:]]+", replacement = "")
      letters_loc <- str_locate(name0, letters)
      numbers_loc <- str_locate(name0, numbers)
      name <- ifelse(numbers_loc[1] < letters_loc[1], paste(numbers,letters,sep=' '), paste(letters,numbers,sep=' '))
      data.list[[name]] <- read.csv(l) %>% mutate(GC=name)
    }
    data_raw <- bind_rows(data.list)
    data_raw[,opt[["label_column"]]] <- factor(data_raw[,opt[["label_column"]]])
  }
  return(list('list'=data.list, 'data'=data_raw))
}

# ECDF plots
ecdf.plot <- function(data.list, orien="reverse") {
  # Combine given datasets
  plotData <- bind_rows(data.list)
  
  # Feature columns
  feature.names <- colnames(select(plotData,-c("GC", as.symbol(opt[["label_column"]]))))
  
  for (fn in feature.names) {
    # Empirical cumulative density fraction
    ggecdf(data = plotData, x = fn, color='GC', title = paste(fn," CDF",sep=''), orientation = orien) + 
      grids(linetype = "dashed") + 
      labs(y='Cumulative fraction', col=NULL, linetype=NULL) +
      theme(legend.position = "top") +
      font("title",       size = 12, color = "black", face = "bold") +
      font("legend.text", size = 8,  color = "black", face = "plain") +
      font("xy",          size = 8,  color = "black", face = "plain") +
      font("xy.text",     size = 8,  color = "black", face = "plain")
    ggsave(filename = paste(WD_DA,'/cdf_',fn,'.pdf',sep = ''), device = 'pdf', width = 6, height = 5)
  }
}

# Plotly, 2D or 3D plotting function
PlotPlotly <- function(plotdata, x.axis, y.axis, z.axis, sym, col, log.scale=c(), ...) {
  xdata <- if ('x' %in% log.scale) plotdata[,x.axis] %>% log10() else plotdata[,x.axis] %>% as.vector()
  ydata <- if ('y' %in% log.scale) plotdata[,y.axis] %>% log10() else plotdata[,y.axis] %>% as.vector()
  zdata <- if ('z' %in% log.scale) plotdata[,z.axis] %>% log10() else plotdata[,z.axis] %>% as.vector()
  if (!hasArg(z.axis)) {
    # Plot with Plotly!
    fig <- plot_ly(x = xdata,
                   y = ydata,
                   type = 'scatter',
                   mode = 'markers',
                   symbol = plotdata[,sym],
                   color = plotdata[,col],
                   colors=c('blue','green','black','orange','red'),
                   alpha = 0.5,
                   marker = list(size = 10), ...)
    
    fig <- fig %>% layout(xaxis = list(title = x.axis), yaxis = list(title = y.axis))
    
  } else {
    fig <- plot_ly(x = xdata,
                   y = ydata,
                   z = zdata,
                   symbol = plotdata[,sym],
                   color = plotdata[,col],
                   colors = c('blue','green','black','orange','red'),
                   marker = list(size=5),
                   mode ="markers", alpha = 0.5,
                   type = "scatter3d", ...)
    
    fig <- fig %>% layout(scene = list(xaxis = list(title = x.axis),
                                       yaxis = list(title = y.axis),
                                       zaxis = list(title = z.axis)))
    
  } 
  return(fig)
}

# Multi-variate gaussian
Neighbors <- function(cl.data, k, des) {
  
  n.feat <- ncol(cl.data)
  n.synth <- des*nrow(cl.data)
  
  # Calculate euclidean distance matrix
  dist.mat <- dist(cl.data, method = 'euclidean') %>% as.matrix()
  
  idcs.vec <- c()
  for (n in seq(n.synth)) {
    ref.idx  <- sample(nrow(cl.data), 1)      # randomly select 1 point from given input class data
    
    # Sort euclidean distances
    sorted.dists <- dist.mat[ref.idx,] %>% sort()
    knns.idx <- sample(names(sorted.dists[2:k+1]) %>% as.numeric(), 1)
    
    idx <- c(ref.idx, knns.idx)
    idcs.vec <- rbind(idcs.vec, idx) # collect them together
  }
  colnames(idcs.vec)  <- c('ref','nei')
  row.names(idcs.vec) <- seq(des*nrow(cl.data))
  
  # Random uniform numbers
  rndno <- runif(n=n.synth*n.feat) %>% matrix(nrow=n.synth, ncol=n.feat, byrow = T)
  synth <- cl.data[idcs.vec[,'ref'],] + rndno*(cl.data[idcs.vec[,'nei'],]-cl.data[idcs.vec[,'ref'],])
  
  return(synth)
}

# Data Augmentation and Balanced data (custom SMOTE)
smote <- function(data, k, desired.class.no=200, ...) {
  
  synth.data <- data.frame()
  classes <- levels(data$class)
  
  for (cl in classes) {
    cl.data <- data %>% filter(class == cl) %>% select(-class)
    
    # How many times does it augment
    des <- ceiling( desired.class.no / nrow(cl.data) ) - 1
    
    # The number of nearest neighbors
    if (!hasArg("k")) {
      # If k is not given as input, it will be calculated with desired.class.no
      k <- des
    }
    
    synth <- bind_cols(class = factor(cl,levels = classes), Neighbors(cl.data, k, des)) %>% as.data.frame()
    synth.data <- rbind(synth.data, synth)
  }
  
  return(synth.data)
}

# Data splitting into train set (70%) and test set (30%)
splitdata <- function(inputdata, target) {
  # Train(0.7) Test(0.3) Splitting
  test_list <- list()
  train_list <- list()
  for (l in levels(inputdata[,target])) {
    tmp <- filter(inputdata, inputdata[,target] == l)
    tr_idx <- sample(nrow(tmp))[1:round(0.7*nrow(tmp))]
    test_list[[l]]  <- tmp[-tr_idx,]
    train_list[[l]] <- tmp[ tr_idx,]
  }
  testset <-  bind_rows(test_list)
  trainset <- bind_rows(train_list)
  te_idx <- sample(nrow(testset))
  tr_idx <- sample(nrow(trainset))
  testset  <- testset[te_idx,]
  trainset <- trainset[tr_idx,]
  
  ret.list <- list()
  ret.list[['trainset']] <- trainset
  ret.list[['testset']]  <- testset
  
  return(ret.list)
}

# Binarize labels
binarize <- function(data) {
  output <- data %>% 
    mutate(class = ifelse(!!as.symbol(opt$label_column) == target, target, paste('non_',target,sep=''))) %>% 
    select(-as.symbol(opt$label_column))
  output[,"class"] <- factor(output[,"class"], levels = c(target, paste('non_',target,sep='')))
  output
}

# Shuffling
randomize <- function(data) {
  rownames(data) <- NULL
  rnd.idx <- sample(nrow(data))
  return(data[rnd.idx,])
}

# Training for several models, together
ens.training <- function(data, Control, methodList, iter, each.iter) {
  cat('\n For ', i, ' feature... (', iter, '/', each.iter, ')', sep='')
  
  cat('\n   Training for 5 models...')
  caretmodels <- caretList(class~., data=data, trControl=Control, methodList=methodList)
  
  return(caretmodels)
}

# Predicting for several models, together
ens.predict <- function(caretmodels, datalist) {
  ret.list <- list()
  for (i in seq_along(datalist)) {
    probs <- lapply(caretmodels, predict, newdata=datalist[[i]], type="prob")
    probs <- lapply(probs, function(x) x[,target]) %>% as.data.frame()
    
    ret.list[[i]] <- probs
  }
  names(ret.list) <- names(data.list)
  return(ret.list)
}

# Extracting accuracy from comfusion matrix
extract.acc <- function(pred.each, nm, data.list, target, accuracy.list, i) {
  onezeros <- sapply(pred.each[[nm]], as.character)
  confMat <- onezeros %>% 
    apply(2,
          function(x) {
            confusionMatrix(factor(x, levels=c(1,0)),
                            reference = factor(ifelse(data.list[[nm]]$class == target, 1, 0), levels = c(1,0)))
          })
  res.accuracy <- rbind(accuracy.list[[nm]],
                        confMat %>% lapply(function(x) x$overall[1]) %>%
                          bind_cols() %>% mutate(x=i))
  
  return(res.accuracy)
}

# Aggregating prediction results
aggregating.res <- function(prob.list, pred.list, eval.exist) {
  if ( eval.exist ) {
    prob.aggr <- list('train'=prob.list %>% lapply(function(x) x$train) %>% abind(along=3) %>% apply(c(1,2), mean),
                      'test' =prob.list %>% lapply(function(x) x$test ) %>% abind(along=3) %>% apply(c(1,2), mean),
                      'eval' =prob.list %>% lapply(function(x) x$eval ) %>% abind(along=3) %>% apply(c(1,2), mean))
  } else {
    prob.aggr <- list('train'=prob.list %>% lapply(function(x) x$train) %>% abind(along=3) %>% apply(c(1,2), mean),
                      'test' =prob.list %>% lapply(function(x) x$test ) %>% abind(along=3) %>% apply(c(1,2), mean))
  }
  
  pred.aggr <- lapply(prob.aggr, function(x) as.data.frame(cbind(apply(x, 2, function(y) ifelse(y >= 0.5, 1, 0)))) )
  
  return(list('prob.aggr'=prob.aggr, 'pred.aggr'=pred.aggr))
}

# Calculating Accuracy & Standard error 
acc.fun <- function(x) {
  c('acc'=100*mean(x), 'se'=sqrt((1/(length(x)-1))*100*mean(x)))
}

# Accuracy Curve plot
ggAccCurve <- function(data, col="id", linetype="id", height = 14, width = 14, suffix, method_name, eachModel=FALSE) {
  if ( eachModel ) {
    p <<- ggplot(data, aes_string(x="x", y="acc", col=col, linetype=linetype)) +
      geom_line() + 
      geom_point() + 
      geom_errorbar(aes(ymin = acc - se, ymax = acc + se), width=0.5) +
      ggtitle(paste("Accuracy curve for ", target, "(",method_name,")",sep='')) +
      facet_wrap(~id, ncol = 2, scales = 'free') +
      scale_x_continuous(breaks = seq(fno), labels = seq(fno)) +
      xlab('fset') + ylab('Accuracy (%)') +
      theme_pubr() + grids(linetype = "dashed") + expand_limits(y=100) +
      labs(col=NULL, linetype=NULL)
    ggsave(filename = paste(WD_ACC,"/AccCurve_",suffix,".pdf", sep = ""), plot = p,
           device = "pdf", height = height, width = width)
    p
  } else {
    p <<- ggplot(data, aes_string(x="x", y="acc", col=col, linetype=linetype)) +
      geom_line() + geom_point() + geom_errorbar(aes(ymin = acc - se, ymax = acc + se), width=0.5) +
      ggtitle(paste("Accuracy curve for ", target, "(",method_name,")",sep='')) +
      scale_x_continuous(breaks = seq(fno), labels = seq(fno)) +
      xlab('fset') + ylab('Accuracy (%)') +
      theme_pubr() + grids(linetype = "dashed") + expand_limits(y=100) +
      labs(col=NULL, linetype=NULL)
    ggsave(filename = paste(WD_ACC,"/AccCurve_",suffix,".pdf", sep = ""), plot = p,
           device = "pdf", height = height, width = width)
    p
  }
}


# ROC curve plot
PlotROC <- function(ref, pred, set, m=NULL, ...) {
  if ( is.null(m) ) {
    predictor=pred[[f]][[set]]
  } else {
    predictor=pred[[f]][[set]][,m]
  }
  plot.roc(x = ref,
           predictor = predictor,
           levels = c(1,0),
           print.auc = T, auc.polygon = T,
           max.auc.polygon = T, percent = T,
           print.thres = T, col = "1",
           main = paste(set, "ROC"),
           auc.polygon.col='skyblue')
}
# ==============================================================================


# ========================== Data Pre-processing ===============================
cat("\n>>> Data processing...")

# Loading data
eval.exist <- !is.null(opt[["eval"]])
prim <- data_load("primary")
if ( eval.exist ) {
  eval <- data_load("eval")
  data.list <- c(prim$list, eval)
}


# Split primary data into training and test data (0.7 / 0.3)
data.split <- splitdata(inputdata = prim$data, target = opt$label_column)
train.data <- data.split$trainset # Train data
test.data <- data.split$testset   # Test data
if ( eval.exist ) {
  eval.data  <- eval$data
}


# Normalization 
train.data.norm <- train.data
Norm_cols <- grep("L", colnames(train.data), value=TRUE, ignore.case = FALSE) # Columns to be normalized
#Norm_cols <- c(norm.theta, Norm_cols)

scaled_obj <- scale(as.data.frame.matrix(train.data.norm)[,Norm_cols], center=TRUE, scale=TRUE)
train.data.norm[,Norm_cols] <- scaled_obj

test.data.norm <- test.data
test.data.norm[,Norm_cols] <- scale(as.data.frame.matrix(test.data.norm)[,Norm_cols],
                                    center=attr(scaled_obj, "scaled:center"), # Same parameter as trianing data
                                    scale=attr(scaled_obj, "scaled:scale"))   # Same parameter as trianing data
if ( eval.exist ) {
  eval.data.norm <- eval.data
  eval.data.norm[,Norm_cols] <- scale(as.data.frame.matrix(eval.data.norm)[,Norm_cols],
                                      center=attr(scaled_obj, "scaled:center"), # Same parameter as trianing data
                                      scale=attr(scaled_obj, "scaled:scale"))   # Same parameter as trianing data
}


# Input data
trainset <- train.data.norm %>% select(-GC) %>% binarize() %>% randomize()
testset  <- test.data.norm  %>% select(-GC) %>% binarize() %>% randomize()
if ( eval.exist ) {
  evalset  <- eval.data.norm %>% select(-GC) %>% binarize() %>% randomize()
}


# Data analysis directory
WD_DA <- paste(WD,"1.DataAnalysis", sep='/')
dir.create(WD_DA)


# ecdf plotting for each feature
if ( eval.exist ) {
  ecdf.plot( data.list = list(train.data.norm, test.data.norm, eval.data.norm), orien = NULL)
} else {
  ecdf.plot( list(train.data.norm, test.data.norm), orien = NULL)
}


# Data augmentation by SMOTE --- (option)
if (SMOTE) {
  # SMOTE with 7 nearest neighbors, increasing size of each binary class about 300
  smote.data <- smote(data = trainset, k = 7, desired.class.no = 300)
  
  # Saving basic CMD as html file with plotly
  smote.train <- rbind(trainset %>% mutate(tag='real'),
                       smote.data %>% mutate(tag='synth'))
  p <- PlotPlotly(smote.train,
                  x.axis = 'color3', y.axis = 'L_3',   # color vs luminosity diagram
                  sym = 'tag', col = 'class',
                  symbols=c('circle', 'circle-open'))
  saveWidget(as_widget(p), paste(getwd(), '/', WD_DA, '/SMOTE_', target, '_vs_',
                                 paste('non_',target,sep=''), '.html', sep=''))
  cat("\n>>> CMD with the augmented data is saved in:", WD_DA)
  
  # Returning trainset
  trainset <- smote.train %>% select(-tag)
}


## =================== Searching ensemble models ===============================
#cat("\n>>> Model selecting for ensemble...")
## Data analysis directory
#WD_MS <- paste(WD, "2.ModelSelection", sep='/')
#dir.create(WD_MS)
#
#
## Available algorithm list in caret
#model.list <- c('rf', 'svmRadial', 'glm', 'svmLinear', 'nnet', 'kknn', 'nb', 'rpart', 'adaboost')
#cat("\n>>> Input model list is: ", model.list)
#
#
## Parallel computing
#cl <- makeCluster(nproc)
#registerDoParallel(cl)
#Control <- trainControl(method=cv.param(cv.method,'method'),
#                        number=cv.param(cv.method,'nfolds'),
#                        repeats=cv.param(cv.method,'nrepeats'),
#                        returnResamp = 'final', verboseIter = TRUE, classProbs=TRUE,
#                        allowParallel = TRUE)
#caretmodels <- caretList(class~., data=trainset, trControl=Control, methodList=model.list)
#results <- resamples(caretmodels, metric="Accuracy")
#summ <- summary(results)
#
#
## Dot plot of summary
#pdf(file=paste(WD_MS,"ModelResample.pdf",sep='/'), width=8, height=5)
#dotplot(results)
#dev.off()
#cat("\n>>> Model resampled performace plot is saved in ", WD_MS)
#
#
## Investigating correlations among model candidates
#cormat <- modelCor(results)    # correlation matrix
#col <- colorRampPalette(c("red", "white", "blue"))
#
#pdf(file=paste(WD_MS,"ModelCorplot.pdf",sep='/'), width=8, height=8)
#corrplot(cormat, method="color", col=col(200),  
#         type="upper", order="hclust", 
#         addCoef.col = "black",     # Add coefficient of correlation
#         tl.col="black", tl.srt=45, #Text label color and rotation
#         diag=FALSE                 # hide correlation coefficient on the principal diagonal
#)
#dev.off()
#cat("\n>>> Model correlation plot is saved in:", WD_MS)
#
#
### Model selection by accuracy and considering correation < 0.75
##model.no <- 5
##model.vec.acc.sorted <- names(sort( summ$statistics$Accuracy[,"Mean"], decreasing = T ))
##combinations <- combn(model.vec.acc.sorted, model.no)
##for (c in seq(dim(combinations)[2])) {
##  test.mat <- cormat[combinations[,c],combinations[,c]]
##  if (sum(test.mat > 0.75) == model.no) {
##    break
##  }
##}
##cat("\n>>> [ Selected models: ", colnames(test.mat), "]")
##selected.models <- colnames(test.mat)
#
#selected.models <- c("rf", "svmRadial", "glm", "kknn", "nb")
#
#pdf(file=paste(WD_MS,"SelectedCorplot.pdf",sep='/'), width=8, height=8)
#corrplot(cormat[selected.models,selected.models], method="color", col=col(200),  
#         type="upper", order="hclust", addCoef.col = "black", tl.col="black", tl.srt=45, diag=FALSE)
#dev.off()

selected.models <- c("rf", "svmRadial", "glm", "kknn", "nb")

# =============================  R F E  ==================================
cat("\n>>> Recursive feature elimination...")
# Data analysis directory
WD_FI <- paste(WD,"3.RFE", sep='/')
dir.create(WD_FI)

ctrl <- rfeControl(functions = rfFuncs,
                   method=cv.param(cv.method,'method'),
                   number=cv.param(cv.method,'nfolds'),
                   repeats=cv.param(cv.method,'nrepeats'),
                   returnResamp = "all",
                   verbose = TRUE)

cl <- makeCluster(nproc)
registerDoSNOW(cl)
rfProfile <- rfe(x = select(trainset, -class),
                 y = trainset$class,
                 sizes = seq(ncol(trainset)-1),
                 method = "rf", metric = 'RMSE',
                 rfeControl = ctrl)
trellis.par.set(caretTheme())

# save an ccuracy plot
pdf(file = paste(WD_FI,"/rfe_accuracy_plot.pdf",sep=""), width = 7, height = 7)
plot(rfProfile, type = c("g", "o"))
dev.off()

# Save a rfe result
save(rfProfile, file = paste(WD_FI,"/rfe_selected.Rdata",sep=""))

# Selected features
selected.features <- rfProfile$optVariables

# Plotting 3D plot with top3 features
x.axis <- selected.features[1]
y.axis <- selected.features[2]
z.axis <- selected.features[3]

if ( eval.exist ) {
  plotdata <- bind_rows(trainset %>% mutate(tag='train'),
                        testset  %>% mutate(tag='test'),
                        evalset  %>% mutate(tag='others'))
  plotdata$tag <- factor(plotdata$tag, levels = c('train','test','others'))
} else {
  plotdata <- bind_rows(trainset %>% mutate(tag='train'),
                        testset  %>% mutate(tag='test'))
  plotdata$tag <- factor(plotdata$tag, levels = c('train','test'))
}

p <- PlotPlotly(plotdata, x.axis, y.axis, z.axis, sym='tag', col='class', symbols=c('circle','circle-open'))
saveWidget(as_widget(p), paste(getwd(), '/', WD_FI, '/TOP3_', target, '_vs_',
                               paste('non_',target,sep=''), '.html', sep=''))
cat("\n>>> 3D plot with top 3 importance scores is saved in ",WD_FI)



# ========================= Accuracy Curve & ROC curve ===========================
cat("\n>>> Training and predicing...(", nproc, "process in parallel")
WD_ACC <- paste(WD, "4.AccCurve", sep='/')
dir.create(WD_ACC)
WD_ROC <- paste(WD, "5.ROCCurve", sep='/')
dir.create(WD_ROC)
WD_PRED <- paste(WD, "5.predictions", sep='/')
dir.create(WD_PRED)


# Prediction bins for results
prob.feat <- list()
pred.feat <- list()
if ( eval.exist ) {
  accuracy.list <- list('train'= data.frame(),
                        'test' = data.frame(),
                        'eval' = data.frame())
} else {
  accuracy.list <- list('train'= data.frame(),
                        'test' = data.frame())
}

# Operating ML
each.iter <- 20
fno <- length(selected.features)
cl <- makeCluster(nproc)
registerDoSNOW(cl)
for (i in seq(fno)) {
  feature_select <- selected.features[c(1:i)]
  
  train_x <- trainset %>% select(feature_select)
  train_y <- trainset[,'class'] %>% as.factor()
  traindata <- bind_cols(train_x, class = train_y) %>% as.data.frame()
  
  test_x <- testset %>% select(feature_select)
  test_y <- testset[,"class"] %>% as.factor()
  testdata <- bind_cols(test_x, class = test_y) %>% as.data.frame()
  
  # Try load evalset
  if ( eval.exist ) {
    eval_x <- evalset %>% select(feature_select)
    eval_y <- evalset[,'class'] %>% as.factor()
    evaldata <-  bind_cols(eval_x, class = eval_y) %>% as.data.frame()
    
    data.list <- list('train'=traindata,
                      'test' =testdata,
                      'eval' =evaldata)
  } else {
    data.list <- list('train'=traindata,
                      'test' =testdata)
  }
  
  Control <- trainControl(method=cv.param(cv.method,'method'),
                          number=cv.param(cv.method,'nfolds'),
                          repeats=cv.param(cv.method,'nrepeats'),
                          returnResamp = 'final', verboseIter = TRUE, classProbs=TRUE,
                          allowParallel = TRUE)
  
  prob.list <- list()
  pred.list <- list()
  for (iter in seq(each.iter)){
    ens.trained <- ens.training(data = traindata,
                                Control = Control,
                                methodList = selected.models,
                                iter = iter, each.iter = each.iter)
    
    prob.each <- ens.predict(caretmodels = ens.trained,
                             datalist = data.list)
    
    pred.each <- lapply(prob.each, function(x) as.data.frame(cbind(apply(x, 2, function(y) ifelse(y >= 0.5, 1, 0)))) )
    
    for (nm in names(pred.each)) {
      res.accuracy <- extract.acc(pred.each = pred.each, 
                                  nm = nm, i = i,
                                  data.list = data.list, 
                                  target = target, 
                                  accuracy.list = accuracy.list)
      accuracy.list[[nm]] <- res.accuracy
    }
    
    prob.list[[iter]] <- prob.each
    pred.list[[iter]] <- pred.each
  }
  
  res.aggr <- aggregating.res(prob.list = prob.list, pred.list = pred.list, eval.exist = eval.exist)
  
  prob.feat[[i]] <- res.aggr$prob.aggr
  pred.feat[[i]] <- res.aggr$pred.aggr
}
registerDoSEQ()
stopCluster(cl)

# Saving predictions
save(pred.feat, prob.feat, accuracy.list, file=paste(WD_PRED, "/prediction.Rdata", sep = ''))


# ====================== Drawing the Accuracy Curve ============================
# Add a column for majority voting ensemble prediction
accuracy.list2 <- lapply(accuracy.list, function(y) mutate(y, mjv = y %>% select(selected.models) %>% rowMeans()) )


# Melt down list into one data frame
acc.melt <- lapply(accuracy.list2, function(y) y %>% 
                     group_by(x) %>% 
                     summarise_all(acc.fun) %>% 
                     ungroup() %>% 
                     mutate(metric=rep(c('acc','se'), fno)) %>% 
                     melt(id=c('x','metric')) %>% 
                     dcast(x+variable~metric)) %>%
  bind_rows(.id='id')


# Summarize accuracy result by each models
eachModel.data <- acc.melt %>% filter(variable %in% selected.models)
major.data <- acc.melt %>% filter(variable == 'mjv')



# Plotting Accuracy curves
ggAccCurve(eachModel.data, suffix="eachModel", method_name='each model', col="variable", linetype="variable", height=30, width=30, eachModel=TRUE)
ggAccCurve(major.data, suffix="majority_voting", method_name='majority voting', col="id", linetype="id")


# save accuracy results
mjv.train.acc <- major.data %>% filter(id=='train')
mjv.test.acc  <- major.data %>% filter(id=='test')

write.table(mjv.train.acc, file = paste(WD_ACC,"train_acc_mjv.txt",sep='/'))
write.table(mjv.test.acc,  file = paste(WD_ACC,"test_acc_mjv.txt",sep='/'))

if ( eval.exist ) {
  mjv.eval.acc  <- major.data %>% filter(id=='eval')
  write.table(mjv.eval.acc, file = paste(WD_ACC,"eval_acc_mjv.txt",sep='/'))
}


# ==================== ROC curves for Each Feature Subset ======================
# Majority Voting
mjv.probs <- prob.feat %>% lapply(function(x) lapply(x, function(y) y %>% as.data.frame() %>% apply(1, mean)))

# References
Train_y <- ifelse(train_y == target, 1, 0)
Test_y <- ifelse(test_y == target, 1, 0)
if ( eval.exist ) {
  Eval_y <- ifelse(eval_y == target, 1, 0)
}


for (f in seq(fno)) {
  # Plot ROC curve
  if ( eval.exist ) {
    pdf(file = paste(WD_ROC,"/mjv_ROC_F",f,".pdf", sep = ""), height = 3, width = 8)
    par(mfrow=c(1,3))
    PlotROC(ref=Train_y, pred=mjv.probs, set='train')
    PlotROC(ref=Test_y,  pred=mjv.probs, set='test')
    PlotROC(ref=Eval_y,  pred=mjv.probs, set='eval')
    dev.off()
  } else {
    pdf(file = paste(WD_ROC,"/mjv_ROC_F",f,".pdf", sep = ""), height = 3, width = 6)
    par(mfrow=c(1,2))
    PlotROC(ref=Train_y, pred=mjv.probs, set='train')
    PlotROC(ref=Test_y,  pred=mjv.probs, set='test')
    dev.off()
  }
}

cat("\n>>> ROC cuves are saved in", WD_ROC)

cat("\n>>> All classification routine is done!")
