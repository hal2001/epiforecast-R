##' Make transparent colors according to weights in (0,1).
##' @import RColorBrewer plotrix
##' @param weights Numeric vector with elements in [0,1].
##' @return Character vector containing color codes.
make_sim_ys_colors = function(weights){
    stopifnot(all(weights <= 1 & weights >= 0))
    mycols = brewer.pal(3,"Set1")
    myrgbs = col2rgb(mycols[1])
    shades = round(weights/max(weights)*255)
    mycols = rgb(red = myrgbs[1],
                 green = myrgbs[2],
                 blue = myrgbs[3],
                 alpha = shades,
                 maxColorValue = 255)
    return(mycols)
}

##' Plotting function for "sim" class
##' @import hexbin
##' @export
plot.sim = function(mysim, ylab = "Disease Intensity", xlab = "Time", lty = 1,
                    nplot = min(100,ncol(mysim$ys)), type = c("lineplot","density", "hexagonal"), overlay=FALSE, ...){

    type = match.arg(type)
    ## Make some colors
    mycols = make_sim_ys_colors(mysim$weights[1:nplot])

    if(mysim$control.list$model=="Empirical Bayes") par(mfrow=c(2,1))

    ## Make line plot of ys
    if(type=="lineplot"){
        
        ## Make line plot
        matplot(mysim$ys[,1:nplot], type = 'l', ylab = ylab, xlab = xlab, col = mycols,
            lty = lty, axes = F, lwd=.5,...)
        axis(1); axis(2);

        ## Plot improvements
        time.of.forecast = get.latest.time(mysim$new.dat)
        ticks = c(1, 5, 10, 40, 150, 500, 1000)
        abline(v = time.of.forecast, lty=2, col = 'grey50')
        axis(side = 1, at = time.of.forecast, lty = 0, font = 2)
        mtext(side=3, cex=1.5, font=2, text = paste("Simulated trajectories for season:", mysim$new.season.label))
        mtext(side=3, cex=1.25, line=-1.25, text = mysim$control.list$model)
    } 


    ## Hexagonal plots (in progress)
    ## Easy way (wrong, since it plots /globally/; this is a problem of the line plots too!)
    if(type=="hexagonal"){
        nplot = 100
        xx= rep(1:nrow(mysim$ys), nplot )
        yy= do.call(c,lapply(1:nplot, function(ii){mysim$ys[,ii]}))
        hbin <- hexbin(x=xx,y=yy,xbins=nplot/3)
        plot(hbin)
    }

    ## Make density plot 
    if(type=="density"){
        mtext(side=3, cex=1.5, font=2, text = paste("Simulated trajectories for season:", mysim$new.season.label))
        mtext(side=3, cex=1.25, line=-1.25, text = mysim$control.list$model)
        mycols = brewer.pal(3,"Set1")
        myrgbs = col2rgb(mycols[1])
        pts.in.between = seq(from=1,to=52,by=2)
        pts.in.between = c(pts.in.between,52)
        intvls.in.between = sapply(1:(length(pts.in.between)-1), function(ii){pts.in.between[ii]:pts.in.between[(ii+1)]})
        means = sapply(1:52, function(ii) weighted.mean(mysim$ys[ii,],mysim$weights))
        ## plot(NA,xlim=c(0,52),ylim=c(0,3))
        plot(NA, xlim=c(0,52),ylim=range(mysim$ys)+c(-1,+4), ylab = ylab, xlab = xlab, col = mycols,
             lty = lty, axes = F, lwd=.5,...)
        for(jj in 1:length(intvls.in.between) ){
            this.intvl.means = means[intvls.in.between[[jj]]] 
            mydens = density(apply(mysim$ys[intvls.in.between[[jj]],],2,mean), weights = mysim$weights/sum(mysim$weights))
            weights = mydens$y 
            weights = weights-min(weights)
            shades = round(weights/max(weights)*255)
            mycols = rgb(red = myrgbs[1],
                         green = myrgbs[2],
                         blue = myrgbs[3],
                         alpha = shades,
                         maxColorValue = 255)
            centered.dens.x = mydens$x - mean(mydens$x)
            this.intvl.dens = list(y=sapply(1:length(this.intvl.means), function(ii){this.intvl.means[ii] + centered.dens.x}),
                                   x=intvls.in.between[[jj]],
                                   col=mycols)
            if(36 %in% intvls.in.between[[jj]]){
            sapply(1:3,function(ii)print(this.intvl.means[ii]))
            }
            abline(h=1.6)
            ## plot it
            for(ii in 1:length(this.intvl.means)){
                points(x=rep(this.intvl.dens$x[ii], nrow(this.intvl.dens$y)),
                       y=this.intvl.dens$y[,ii],
                       col=this.intvl.dens$col,
                       cex=2)
            }
        }

        ## plot actual mean
        lines(means, lwd=3)
        
        ## Overlay the lines
        if(overlay){
            mycols = make_sim_ys_colors(mysim$weights[1:nplot])
            matlines(mysim$ys[,1:nplot], col=mycols,type='l',lty=1)
        }
        axis(1);axis(2)
        mtext(side=3, cex=1.5, font=2, text = paste("Densities of trajectories for season:", mysim$new.season.label))
        mtext(side=3, cex=1.25, line=-1.25, text = mysim$control.list$model)
    }

    ## Make barplot
    if(mysim$control.list$model=="Empirical Bayes"){
        all.hist.seasons.in.sim = mysim$old.season.labels[mysim$sampled.row.major.parms$curve.i]
        all.hist.seasons.in.sim  =      as.factor(        all.hist.seasons.in.sim)
        levels(all.hist.seasons.in.sim) = mysim$old.season.labels
        mytable = table(all.hist.seasons.in.sim)/mysim$control.list$n.sims*100
        barplot(mytable,col=brewer.pal(3,"Set3")[1])
        title("Contribution of historical seasons to simulated curves (%)")
        ## pie(mytable, main="Historical seasons")
    }
} 




##' Printing function for "sim" class
##' @param mysim Output from running an OO.sim() function.
print.sim = function(mysim, verbose=TRUE,...){

    ctrlist = mysim[["control.list"]]
    ctrmodel = ctrlist$model
    ctrlist = ctrlist[which(names(ctrlist)!="model")]

    cat(fill=TRUE)
    cat(paste0(ctrlist$n.sims, " simulated trajectories with weights produced by ", ctrmodel, " model"), fill=T)
               ## ", to produce ", ctrlist$n.sims), fill=TRUE)
    cat(fill=TRUE)
    cat("====================",fill=TRUE)
    cat("Simulation settings:",fill=TRUE)
    cat("====================",fill=TRUE)

    print.each.control.list.item = function(x){
        stopifnot(is.list(x))
        if(!is.null(x[[1]])) { cat(names(x), "=", x[[1]], fill=T) }
    }
    
    if(ctrmodel %in% c("Empirical Bayes", "Basis Regression")){
        invisible(sapply(seq_along(ctrlist),
                         function(ii) print.each.control.list.item(ctrlist[ii])))
    } else {
        stop(paste("print not written for --", ctrmodel, " -- yet!"))
    } 

    cat("====================",fill=TRUE)
    if(verbose){
        cat(fill=TRUE)
        cat("The simulated trajectories look like this:",fill=T)
        cat(fill=TRUE)
        show.sample.trajectories(ys = mysim$ys, nshow = min(5,ncol(mysim$ys)))
    }
}


##' Showing sample trajectories of ys.
##' @param ys A matrix whose columns contain simulated curves.
##' @param nshow How many curves to show.
show.sample.trajectories = function(ys, nshow = 100){

    ## basic error checking
    if(!(class(ys) %in% c("matrix"))) stop("ys is not a matrix!")
    if(any(apply(ys,2,function(mycol){any(is.na(mycol))}))) stop("ys has missing entries!")

    ## format simulated trajectories
    ys = as.data.frame(round(ys[1:(nshow+1),1:(nshow+1)],2))
    ys[(nshow+1),] = ys[,(nshow+1)] =  rep("...",(nshow+1))
    colnames(ys) = Map(paste,rep("sim",(nshow+1)), 1:(nshow+1))
    rownames(ys) = Map(paste0,rep("time = ",(nshow+1)),1:(nshow+1))

    ## show it
    print(ys)
}

## Assign forecast to 'sim' class
forecast <- function(x,...) UseMethod("forecast",x)
##' Forecast a target (peak height, etc.) using a \code{sim} object
##'
##' @import rlist
##' @param mysim Output from running an OO.sim() function.
##' @export
forecast.sim = function(mysim,
                        target=c("pwk","pht","ons","dur"),
                        target.fun = NULL,
                        hist.bins = NULL,
                        plot.hist = FALSE,
                        add.to.plot = FALSE,
                        sig.digit = 2,
                        ...){

    par(mfrow=c(1,1))
    
    pwk = function(mysim){
        return( apply(mysim$ys, 2, which.max) )
    }

    pht = function(mysim){
        return( apply(mysim$ys, 2, max) )
    }

    if(length(target)>1) stop("must supply a target quantity! pwk, pht, ons, dur.")

    if(target == "pwk") targets = pwk(mysim)
    if(target == "pht") targets = pht(mysim)
    if(target == "ons") stop("onset not written yet") 
    if(target == "dur") stop("duration not written yet")


    ## Compute mean, median, two-sided 90% quantiles
    estimates = list(quantile = quantile(targets,c(0.05,0.95)),
                     quartile = quantile(targets,c(0.25,0.5,0.75)),
                     decile   = quantile(targets,1:9/10),
                     mean = mean(targets),
                     median = median(targets))

    ## Print a bunch of things
    cat("Summary for", target, ":",fill=TRUE)
    cat("====================", fill=TRUE)
    cat("The mean of", target, "is", round(estimates$mean,sig.digit), fill=TRUE)
    cat("The median of", target, "is", round(estimates$median,sig.digit), fill=TRUE)
    cat("And the 0.05, 0.95 quantiles are", round(estimates$quantile,sig.digit), fill=TRUE)
    cat("And the quartiles are", round(estimates$quartile,sig.digit), fill=TRUE)
    cat("And the deciles are", round(estimates$decile,sig.digit), fill=TRUE)

    ## Plot histogram if asked
    if(plot.hist){
        ## hist(targets, axes=FALSE, main="", xlab = target)
        hist(targets, axes=FALSE, main="", xlab = target, col="skyblue") ## todo: take Ryan's original wtd.hist
        mtext(paste("Forecasts for target:", target),3,cex=2,padj=-.5)
        axis(1); axis(2);
        abline(v=estimates$mean, col = 'red', lwd=3)
        abline(v=estimates$median, col = 'blue', lwd=2)
        abline(v=estimates$quantile, col = 'grey50', lwd=1, lty=2)
        legend("topright", col = c('red','blue','grey50'), lty=c(1,1,2), lwd = c(2,2,1), legend = c("Mean", "Median", "5%, 95% quantiles"))
    }

    ## add lines to original plot.sim output if necessary
    if(add.to.plot) stop("add.to.plot functionality not written yet")


    ## Return a list of things
    settings = list.remove(unclass(mysim),c("ys","weights"))
    return(list(settings = settings,
                target=list(pwk = targets),
                estimates=estimates))
}

## ##' constructor should take in the bare minimum to create forecasts
## ##' i.e. full.dat, n.sims, control.list, baseline, etc.
## sim <- function(...) {
##   structure(list(...), class = "sim")
## }


