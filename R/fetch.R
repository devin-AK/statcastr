
.date_apply <- function(dates, FUN, ..., msg_base='', verbose=TRUE) {
  ldr <- length(dates)
  dat <- lapply(1:ldr,function(i) {
    if(verbose) {
      prog <- round((i-1) / ldr * 100,1)
      prog <- sprintf('% 4s',prog)
      message('\r',msg_base,' ',dates[i],'. ',prog,'% complete',appendLF=F)
      flush.console()
    }
    FUN(dates[i],...)
  })
  if(verbose) message('\r',msg_base,' ',dates[length(dates)],'.  100% complete',appendLF=T)
  flush.console()
  return(dat)
}

#' Save a statcast data object to disk
#'
#' @description This function saves a statcast data object (\code{sc}) to a specified location (\code{output})
#' @param sc A statcast data object
#' @param output A character string specifying PATH to which the object will be saved. The file extension determines how the file will be saved. Options include \code{.csv} for comma-separated values, and \code{.RDS} for RDS format. If output == NA, the file name will be automatically generated.
#' @param verbose TRUE or FALSE: Whether or not to report messages.
#' @return (nothing)
#' @details This function will write statcast data to disk, which can then be re-loaded into R with \code{load_statcast()}
#' @seealso [load_statcast()]
#' @examples
#' sc <- statcast()
#' save_statcast(sc,'empty')
#' @export
save_statcast <- function(sc, output=NA, verbose=TRUE) {
  # export a statcast data.table to file specified by output
  ## Format/ check input arguments
  .check_statcast(sc)
  if(is.na(output)) {
    rng <- range(sc$game_date)
    if(min(rng)==max(rng)) rng <- min(rng) else {
      rng <- paste(rng,collapse='--')
    }
    output <- paste0('statcast_export_',rng,'.RDS')
  }
  ft <- tolower(tools::file_ext(output))
  if(ft=='') {
    output <- paste0(output,'.RDS')
    ft <- 'rds'
  }
  if(!(ft %in% c('csv','rds'))) stop('"output" file type must be one of CSV or RDS')
  if(verbose) message('Exporting statcast data to "',output,'" ...',appendLF = F)
  if(ft=='csv') {
    write.csv(sc,file=output,quote=T,row.names=F)
  } else {
    saveRDS(sc,file=output)
  }
  if(verbose) message(' DONE.')
}

#' Load a statcast data object to disk
#'
#' @description This function load a statcast data object (\code{sc}) from the specified location (\code{input})
#' @param input PATH to .csv or .RDS file generated by \code{save_statcast()}
#' @return A statcast object
#' @details This function will load statcast data from disk (which was previously stored using \code{save_statcast()}). To get new statcast data, use \code{fetch_statcast()}
#' @seealso [save_statcast()], [fetch_statcast()]
#' @examples
#' sc <- load_statcast('sc_file.csv')
#' @export
load_statcast <- function(input) {
  arg <- deparse(substitute(input))
  if(!file.exists(input)) stop(arg,' not found. Please ensure the file exists at the indicated location.')
  ft <- tolower(tools::file_ext(input))
  if(!(ft %in% c('csv','rds'))) stop(arg,' must be one of CSV or RDS')
  if(ft=='csv') {
    sc <- data.table::fread(input=input, sep=',', header=T,na.strings=c('"null"'),verbose=F,showProgress=F,stringsAsFactors = F)
    sc <- sc[, game_date:=lubridate::ymd(game_date)]
    sc <- statcast(sc)
  }
  if(ft=='rds') {
    sc <- readRDS(input)
  }
  return(sc)
}

#' Update a statcast data object with additional and/or new data
#'
#' @description This function adds new statcast data to an existing statcast object.
#' @param sc A statcast data object
#' @param dates A flexible parameter for specifying dates (see [fetch_statcast()] for more details)
#' @param overwrite TRUE or FALSE: whether or not dates in \code{sc} will be overwritten with new data corresponding to \code{dates} argument. If TRUE the server will be queried with all dates listed in \code{dates}, even if some/all already exist in \code{sc}. If FALSE, only \code{dates} that don't already exist in \code{sc} will be queried.
#' @param verbose TRUE or FALSE: Whether or not to report messages.
#' @return A statcast object, with any new dates worth of data incorporated.
#' @details This function is useful for updating an existing statcast data object when new data becomes available.
#' @seealso [fetch_statcast()]
#' @examples
#' sc <- statcast()
#' update_statcast(sc,'2017 April 12')
#' @export
update_statcast <- function(sc, dates, overwrite=FALSE, verbose=TRUE) {
  # check arguments
  .check_statcast(sc)
  dates <- .parse_dates(dates)
  stopifnot(is.logical(overwrite))
  stopifnot(is.logical(verbose))
  if(verbose) message('Updating statcast data ...')

  # check if any dates in "dates" are already present in existing statcast data
  orig_dates <- lubridate::ymd(sc$game_date)
  overlapping_dates <- intersect(orig_dates,dates)
  if(length(overlapping_dates)!=0) {
    if(overwrite) {
      if(verbose) message('Re-downloading data corresponding to ',length(overlapping_dates),' dates')
      sc <- sc[!(orig_dates %in% overlapping_dates),] # remove rows from original sc
    } else {
      dates <- setdiff(dates,orig_dates)
    }
  }

  if(length(dates)!=0) {
    if(verbose) message('Downloading data corresponding to ',length(unique(dates)),' dates')
    # append new data
    sc.new <- fetch_statcast(dates, verbose=verbose)
    if(length(intersect(sc.new$game_date,sc$game_date))) stop('Internal error')
    sc <- data.table::rbindlist(list(sc,sc.new))
  }
  sc <- statcast(sc)
  return(sc)
}

# the column names that must be present in a data.table to be a valid statcast data.table
# cat(paste0(sQuote(colnames(dt),q=0x27),','))
.statcast_cn <- c('pitch_type', 'game_date', 'release_speed', 'release_pos_x', 'release_pos_z', 'player_name', 'batter', 'pitcher', 'events', 'description', 'spin_dir', 'spin_rate_deprecated', 'break_angle_deprecated', 'break_length_deprecated', 'zone', 'des', 'game_type', 'stand', 'p_throws', 'home_team', 'away_team', 'type', 'hit_location', 'bb_type', 'balls', 'strikes', 'game_year', 'pfx_x', 'pfx_z', 'plate_x', 'plate_z', 'on_3b', 'on_2b', 'on_1b', 'outs_when_up', 'inning', 'inning_topbot', 'hc_x', 'hc_y', 'tfs_deprecated', 'tfs_zulu_deprecated', 'fielder_2', 'umpire', 'sv_id', 'vx0', 'vy0', 'vz0', 'ax', 'ay', 'az', 'sz_top', 'sz_bot', 'hit_distance_sc', 'launch_speed', 'launch_angle', 'effective_speed', 'release_spin_rate', 'release_extension', 'game_pk', 'pitcher', 'fielder_2', 'fielder_3', 'fielder_4', 'fielder_5', 'fielder_6', 'fielder_7', 'fielder_8', 'fielder_9', 'release_pos_y', 'estimated_ba_using_speedangle', 'estimated_woba_using_speedangle', 'woba_value', 'woba_denom', 'babip_value', 'iso_value', 'launch_speed_angle', 'at_bat_number', 'pitch_number', 'pitch_name', 'home_score', 'away_score', 'bat_score', 'fld_score', 'post_away_score', 'post_home_score', 'post_bat_score', 'post_fld_score', 'if_fielding_alignment', 'of_fielding_alignment')

.check_statcast <- function(sc) {
  # ensure that "sc" inherits from data.table class and contains the columns in hidden variable .statcast_cn
  arg <- deparse(substitute(sc))
  if(!inherits(sc,'data.table')) stop(arg,' is not a valid statcast data.table')
  if(!identical(colnames(sc),.statcast_cn)) stop(arg,' is not a valid statcast data.table')
}

.parse_individual_date <- function(x) {
  stopifnot(length(x)==1)
  pd <- lubridate::ymd(x,quiet=T)
  if(is.na(pd)) {
    # consider x as single year
    if(.is_year(x)) {
      st <- lubridate::ymd(paste0(x,'0101'))
      en <- lubridate::ceiling_date(st,unit='year',change_on_boundary = TRUE) - lubridate::days(1)
      pd <- seq(st,en,by='days')
    } else {
      stop('Could not parse date "',deparse(substitute(x)),'". Try using yyyy-mm-dd format for dates.')
    }
  }
  return(lubridate::ymd(pd))
}

.is_year <- function(x) {
  suppressWarnings(nchar(x) == 4 & !is.na(as.numeric(x)))
}

.parse_dates <- function(dates,range_sep=' to ') {
  # First consider ranged dates
  is_ranged <- grepl(range_sep,dates,fixed=TRUE)
  if(any(is_ranged)) {
    ranged <- unlist(strsplit(dates[is_ranged],split=range_sep,fixed=TRUE))
    ranged <- do.call('c',lapply(ranged,.parse_individual_date))
    ranged <- seq(min(ranged),max(ranged),by='days')
  } else {
    ranged <- lubridate::ymd(NULL)
  }
  # Then consider individual dates
  if(any(!is_ranged)) {
    indiv <- dates[!is_ranged]
    indiv <- do.call('c',lapply(indiv,.parse_individual_date))
  } else {
    indiv <- lubridate::ymd(NULL)
  }
  # combine these
  result <- c(ranged,indiv)
  result <- unique(result)
  if(any(is.na(result))) stop('No valid dates were entered. Check the "dates" argument for errors, and use yyyy-mm-dd format for dates.')
  #if(any(is.na(result))) warning('One or more invalid dates were entered. Consider checking the "dates" argument for errors, and use yyyy-mm-dd format for specific dates, yyyy for a single year, or "yyyy-mm-dd to yyyy-mm-dd for a range of dates".')
  return(result)
}

#' Fetch MLB statcast data.
#'
#' @import data.table
#' @description This function queries Baseball Savant for statcast data on dates specified by \code{dates} and returns an R object with the results.
#' @param dates The dates from which to retrieve statcast data
#' @param verbose TRUE or FALSE: Whether or not to report messages.
#' @return A statcast data.table
#' @details The \code{dates} argument is intended to be as flexible as possible. A single date of the form yyyy-mm-dd may be used: \code{fetch_statcast("2017-03-20")}. To retrieve statcast data for an entire season, specify the year: \code{fetch_statcast(2017)}. To select a range of dates, use the separator " to " as follows: \code{fetch_statcast("2017 April 12 to 2017 April 20")}. To select specific dates, combine them in a character vector: \code{fetch_statcast(c('2017 Apr 12','2018 April 12'))}. All of these modes can be used in conjunction, as long as year is listed first (then month, then day) within each individual date.
#' @examples
#' fetch_statcast("2017 April 12")
#' fetch_statcast("2019 Sept 4 to 2020")
#' @export
fetch_statcast <- function(dates, verbose=TRUE) {
  ## example: fetch_statcast('2019 April 17')
  ## example: dat <- fetch_statcast(start='2019 March 15',end='2020 December 1',output=paste(start,end,sep=' - '))
  ## Format/check input arguments
  if(verbose) {
    st0 <- Sys.time()
    message('Fetching statcast data.')
  }
  dates <- .parse_dates(dates)
  stopifnot(is.logical(verbose))

  ## Step 1: counts pitches thrown on each day in dates
  pitches_thrown <- unlist(.date_apply(dates, FUN=.pitches_thrown_by_date, msg_base='Step 1 of 2: Counting pitches on',verbose=verbose))

  ## Step 2: fetch data from days with >0 pitches thrown
  idx <- pitches_thrown > 0
  if(all(idx==F)) {
      if(verbose) message('No pitches found on selected date(s)')
      sc <- statcast()
    } else {
      dates <- dates[idx]
      pitches_thrown <- pitches_thrown[idx]
      sc   <- .date_apply(dates, FUN=.statcast_data_by_date, msg_base='Step 2 of 2: Fetching data from ',verbose=verbose)

      ## Step 3: quality control
      if(verbose) message('Tidying up ... ',appendLF=F)
      pitches_fetched <- sapply(sc,nrow)
      if(any(test_idx <- pitches_fetched != pitches_thrown)) warning('There may have been an issue with downloading statcast data from the following dates: ',paste(date_range_final[test_idx],collapse=', '),'\nPlease try fetching again.')

      ## Step 4: data clean-up
      sc <- data.table::rbindlist(sc)
      sc[, game_date:=lubridate::ymd(game_date)]
      if(verbose) message('DONE.')
  }
  ## Step 5: export/return
  if(verbose) {
    tf <- Sys.time() - st0
    message('Elapsed time: ',format(round(tf,2)))
  }
  sc <- statcast(sc)
  return(sc)
}

#' Sort statcast data.
#'
#' @description Sort statcast data, first by date, then at_bat_number, and finally by pitch_number
#' @param sc A statcast data object
#' @return A sorted statcast data object
#' @details This function ensures that pitch data are sorted in chronological order.
#' @examples
#' sort_statcast()
#' @export
sort_statcast <- function(x) {
  #if(nrow(x)==0) return(x)
  scol <- c('game_date','at_bat_number','pitch_number')
  data.table::setorderv(x,scol) # make sure pitch data is ordered appropriately
  return(x)
}

.pad_dt <- function(dt, nrow=0) {
  dt <- rbind(rep(NA,nrow),dt,fill=T)
  dt[,-1]
}

.pitches_thrown_by_date <- function(date) {
  Sea <- lubridate::year(date)
  game_date_gt <- as.character(date)
  game_date_lt <- as.character(date)
  url_pitches_thrown <- paste0('https://baseballsavant.mlb.com/statcast_search/csv?hfPT=&hfAB=&hfGT=R%7C&hfPR=&hfZ=&stadium=&hfBBL=&hfNewZones=&hfPull=&hfC=&hfSea=',Sea,'%7C&hfSit=&player_type=pitcher&hfOuts=&opponent=&pitcher_throws=&batter_stands=&hfSA=&game_date_gt=',game_date_gt,'&game_date_lt=',game_date_lt,'&hfInfield=&team=&position=&hfOutfield=&hfRO=&home_road=&hfFlag=&hfBBT=&metric_1=&hfInn=&min_pitches=0&min_results=0&group_by=name&sort_col=pitches&player_event_sort=api_p_release_speed&sort_order=desc&min_pas=0&chk_stats_pa=on')
  tmpfile <- tempfile()
  download.file(url_pitches_thrown,tmpfile,quiet=TRUE)
  if(file.size(tmpfile)==0L) result <- 0 else {
    result <- sum(data.table::fread(input=tmpfile,sep=',',header=T,verbose=F,showProgress=F,select='pitches')$pitches)
  }
  unlink(tmpfile)
  Sys.sleep(runif(1,0.05,0.1))
  return(result)
}

.statcast_data_by_date <- function(date) {
  Sea <- lubridate::year(date)
  game_date_gt <- as.character(date)
  game_date_lt <- as.character(date)
  #https://baseballsavant.mlb.com/statcast_search?hfPT=&hfAB=&hfGT=R%7C&hfPR=&hfZ=&stadium=&hfBBL=&hfNewZones=&hfPull=&hfC=&hfSea=2020%7C&hfSit=&player_type=pitcher&hfOuts=&opponent=&pitcher_throws=&batter_stands=&hfSA=&game_date_gt=&game_date_lt=&hfInfield=&team=&position=&hfOutfield=&hfRO=&home_road=&hfFlag=&hfBBT=&metric_1=&hfInn=&min_pitches=0&min_results=0&group_by=name&sort_col=pitches&player_event_sort=api_p_release_speed&sort_order=desc&min_pas=0#results
  url <- paste0('https://baseballsavant.mlb.com/statcast_search/csv?all=true&hfPT=&hfAB=&hfGT=R%7C&hfPR=&hfZ=&stadium=&hfBBL=&hfNewZones=&hfPull=&hfC=&hfSea=',Sea,'%7C&hfSit=&player_type=pitcher&hfOuts=&opponent=&pitcher_throws=&batter_stands=&hfSA=&game_date_gt=',game_date_gt,'&game_date_lt=',game_date_lt,'&hfInfield=&team=&position=&hfOutfield=&hfRO=&home_road=&hfFlag=&hfBBT=&metric_1=&hfInn=&min_pitches=0&min_results=0&group_by=name&sort_col=pitches&player_event_sort=api_p_release_speed&sort_order=desc&min_pas=0&type=details&')
  tmpfile <- tempfile()
  download.file(url,tmpfile,quiet=T)
  result <- data.table::fread(input=tmpfile, sep=',', header=T,na.strings=c('"null"'),verbose=F,showProgress=F,stringsAsFactors = F)
  unlink(tmpfile)
  Sys.sleep(runif(1,0.05,0.1))
  invisible(gc())
  return(result)
}
# cc <- c('factor','character','numeric','numeric','numeric','character','integer','integer','factor','factor','numeric','numeric',
#         'numeric','numeric','integer','character',
#         'factor','factor','factor','factor','factor','factor','factor','factor','integer','integer','integer','numeric','numeric','numeric','numeric','integer','integer','integer',
#         'integer','integer','factor','numeric','numeric','factor','factor','integer','factor','character','numeric','numeric',
#         'numeric','numeric','numeric','numeric','numeric','numeric','numeric','numeric','numeric','numeric',
#         'numeric','numeric','integer','integer','integer','integer','integer','integer','integer','integer','integer','integer','numeric',
#         'numeric','numeric','numeric','numeric','numeric','numeric','numeric','integer','integer',
#         'factor','integer','integer','integer','integer','integer','integer','integer','integer','factor','factor')





#'https://baseballsavant.mlb.com/statcast_search/csv?hfPT=&hfAB=&hfGT=R%7C&hfPR=&hfZ=&stadium=&hfBBL=&hfNewZones=&hfPull=&hfC=&hfSea=2019%7C&hfSit=&player_type=pitcher&hfOuts=&opponent=&pitcher_throws=&batter_stands=&hfSA=&game_date_gt=&game_date_lt=&hfInfield=&team=&position=&hfOutfield=&hfRO=&home_road=&hfFlag=&hfBBT=&metric_1=&hfInn=&min_pitches=0&min_results=0&group_by=name&sort_col=pitches&player_event_sort=api_p_release_speed&sort_order=desc&min_pas=0&chk_stats_pa=on'

