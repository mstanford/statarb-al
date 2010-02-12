## Trading simulation function
## input: signals object, prices df
###source("TradingLoopCPP/TradingLoopCPP.r")

##dyn.load("TradingLoopCPP/TradingLoop.so")
dyn.load("TradingLoopCPP/TradingLoop_printfs.so")

## the signals object here is assumed to be a list of dates
## positions matrix is a matrix of instruments / pairs
## rows ("P") indicate instruments for which signals are generated
## cols ("Q") indicate intruments acting as pairs (beta factors)
## NB: q should always also include the underlying p
## enforce pq.factor.list row names and first column identical
run.trading.simulation.cpp <- function(  signals.struct, prices
                                       , instr.p, instr.q, pq.factor.list
                                       , debug=FALSE, warn=FALSE, stop.on.wrn=FALSE
                                       , silent=FALSE, outfile="", debug.name=instr.p[1]
                                       , dbg.transactions=FALSE
                                       , init.cash=100000
                                       , pos.allocation="beta.neutral"){
  ## equity.blown.thr <- 10000
  if(outfile!="")
    if(file.exists(outfile)) { file.remove(outfile) }
  stopifnot(!is.unsorted(rev(names(signals.struct$sig.dates)))) ##o/w next line is wrong
  signals <- rev(signals.struct$sig.dates)
  tickers <- signals.struct$tickers
  dates <- names(signals)
  stopifnot(all(instr.p %in% tickers))
  tickers.instrp.idx <- match(instr.p,tickers)
   ## instr.p, tickers.instrp.idx form an aligned key/value set
  stopifnot(all(dates %in% row.names(prices))) ##prices dates range
                                        # must include all signals+more
  stopifnot(all(instr.p %in% instr.q))
  stopifnot(all(instr.q %in% names(prices)))
  stopifnot(!any(duplicated(names(prices))))
  prices <- prices[, instr.q] ## align instr.q (and also positions) and prices columns
  prices.instrpq.idx <- match(instr.q,names(prices))
   ## instr.q, price.instrpq.idx form an aligned key/value set

  stopifnot(all(row.names(pq.factor.list)==pq.factor.list$TIC))
  stopifnot(all(instr.p %in% pq.factor.list$TIC))
  pq.factor.list <- pq.factor.list[instr.p, ,drop=F] ##make sure it's aligned with instr.p
  stopifnot(!any(is.na(pq.factor.list$SEC_ETF))) ##sanity check against NAs
  
  prices <- prices[dates,] ## align the data frames
  stopifnot(all(row.names(prices)==dates))
  positions <-as.data.frame(matrix(0,length(instr.p),length(instr.q)))
  names(positions) <- instr.q;  row.names(positions) <- instr.p

  long.shr.amounts <- function(rat,tot,S,b){ #S is price of stock, b is price of pair
    if(pos.allocation=="beta.neutral"){       #tot is amount invested, rat = 1/beta
      rat.thr <- 0.1                         #(i.e. long/short ratio)
      if(abs(rat-1)<rat.thr){ if((rat-1)>0){ rat <- 1+rat.thr }else{rat <- 1-rat.thr} }
      c(s.shares=round(rat*tot/(S*(rat-1))), b.shares=round(tot/(b*(rat-1))))
    }else{ #"dollar neutral": long $tot S, short $tot b
      c(s.shares=round(tot/S),b.shares=round(tot/b))
    } }

  k <- 0
  lambda <- 0.01 #for single-instr debugging
  nav <- 0; cash <- init.cash; equity <- rep(0.,length(dates))

  ## get the number of signal array entries
  sig.arr.len <- dim(signals[[1]])[2]
  num.stks <- length(tickers)
  sig.mtx.2d <- matrix(get.signals.mtx(signals.struct),nrow=length(dates),ncol=num.stks*sig.arr.len,byrow=F)
  sig.actions <- matrix(as.integer(sig.mtx.2d[,seq(1,num.stks*sig.arr.len,by=sig.arr.len)]),nrow=length(dates),ncol=num.stks,byrow=F)

  ## sig.actions[1,1] <- NA
  ## sig.mtx.2d[1,2] <- NA
  .Call("backtest_loop",instr.p, tickers.instrp.idx, instr.q, prices.instrpq.idx
        , dates, as.matrix(pq.factor.list), as.matrix(prices)
        , as.matrix(positions), as.matrix(sig.mtx.2d), as.matrix(sig.actions)
        , list(debug=debug,debug.name=debug.name, silent=silent, pos.allocation=pos.allocation))

  #return(list(cash=cash,nav=nav,equity=equity,log=list(actions=s.action)))
}


test.cpp <- run.trading.simulation.cpp(  sig.f.bt, price.df.f
                                       , instr.p.all, c(instr.p.all,"XLF"), tc.xlf
                                       , debug=FALSE, debug.name="JPM", silent=FALSE
                                       , pos.allocation="beta.neutral")
