#' @export
statcast <- function(...) {
  # needs to sort and check
  sc <- data.table(...)
  class(sc) <- c('statcast',class(sc))
  statcastr:::.check_statcast(sc)
  sort_statcast(sc)
}

### |--------------------------| ###
### | Accessors/Replacers      | ###
### |--------------------------| ###

# Extract data
#' @export
setGeneric('d',function(object,...) standardGeneric('d'),valueClass='data.table')

#' @export
setMethod('d','data.table',function(object,...) {
  class(object) <- class(data.table::data.table())
  object
})

### |--------------------------| ###
### | Coercion                 | ###
### |--------------------------| ###

### |--------------------------| ###
### | show method              | ###
### |--------------------------| ###

#' @export
print.statcast <- function(object) {
  header <- paste0('statcast data.table object')
  cat(header,'\n')
  cat('--------------------------\n')
  if(nrow(object)==0) {
    cat('(empty)')
  } else {
    dates <- object$game_date
    cat(' ->',nrow(object),'pitches from',length(unique(object$player_name)),'pitchers\n')
    ### dates
    mn <- min(object$game_date)
    mx <- max(object$game_date)
    if(mn == mx) cat(' ->','data from',as.character(mn),'(1 day)\n') else {
      cat(' ->','data from',as.character(mn),'to',as.character(mx),'(',length(unique(object$game_date)),'days total )\n')
    }
    cat('--------------------------\n')
    cat('Access raw data with d() and individual metrics with `$`\n')
  }
}
