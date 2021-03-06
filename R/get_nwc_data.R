#' Get data from an NWC source.
#'
#' This function builds a request and returns the the data in question.
#'
#' @param huc The watershed of interest.
#' @param start_date A string representation of the start date in YYYY-MM-DD format.
#' @param end_date A string representation of the end date in YYYY-MM-DD format.
#' @param local TRUE/FALSE to request local watershed or total upstream watershed data.
#' @param return_var A character vector specifying which variables are of interest.
#' Choose from "all", "et", "prcp", "discharge", and "streamflow". Discharge is
#' the modeled discharge for the HUC. Streamflow, if available is monitored streamflow 
#' near the outlet of the HUC.
#' @return The data.
#' @author David Blodgett \email{dblodgett@usgs.gov}
#' @importFrom dataRetrieval readNWISdv
#' @export
#' @examples
#' NWCdata<-get_nwc_wb_data(huc="031601030306")
#'
get_nwc_wb_data<-function(huc, start_date="1980-09-30", end_date="2010-10-01", local=FALSE, return_var = "all") {
  urls<-list(huc12=list(et="https://cida.usgs.gov/nwc/thredds/sos/watersmart/HUC12_data/HUC12_eta.nc",
                        prcp="https://cida.usgs.gov/nwc/thredds/sos/watersmart/HUC12_data/HUC12_daymet.nc"),
             huc12agg=list(et="https://cida.usgs.gov/nwc/thredds/sos/watersmart/HUC12_data/HUC12_eta_agg.nc",
                        prcp="https://cida.usgs.gov/nwc/thredds/sos/watersmart/HUC12_data/HUC12_daymet_agg.nc",
                        MEAN_streamflow="https://cida.usgs.gov/nwc/thredds/sos/watersmart/HUC12_data/HUC12_Q.nc"),
             huc08=list(et="https://cida.usgs.gov/nwc/thredds/sos/watersmart/HUC08_data/HUC08_eta.nc",
                        prcp="https://cida.usgs.gov/nwc/thredds/sos/watersmart/HUC08_data/HUC08_daymet.nc"))
  
  if("discharge" %in% return_var) return_var[which(return_var == "discharge")] <- "MEAN_streamflow"
  
  nwisSite<-FALSE
  
  if(nchar(huc)==12 && local) {
    urlList<-urls['huc12'][[1]]
  } else if(nchar(huc)==12 && !local) {
    urlList<-urls['huc12agg'][[1]]
    nwisSite<-get_nwis_nwc_site(huc)
  } else if (nchar(huc)==8 && local) {
    urlList<-urls['huc08'][[1]]
  } else if (nchar(huc)==8 && !local) {
    stop('Total upstream HUC08 watersheds are not available yet.')
  } else { # Will implement huc08 here too.
    stop('must pass in an 8 or 12 digit HUC identifier')
  }
  
  dataOut<-list()
  
  for (var_name in names(urlList)) {
    if(grepl(pattern = 'nwc/thredds/sos', x = urlList[var_name]) && 
       (var_name %in% return_var || "all" %in% return_var)) {
      
      url<-paste0(urlList[var_name],'?request=GetObservation&service=SOS&version=1.0.0&observedProperty=',
                var_name,'&offering=',huc,'&eventTime=',start_date,'T00:00:00Z/', end_date,'T00:00:00Z')
      ts<-parse_swe_csv(url)
    
    if (is.data.frame(ts)) {dataOut[var_name]<-list(ts)}
    }
  }
  
  if(is.character(nwisSite) && 
     ("streamflow" %in% return_var || "all" %in% return_var)) {
    dataOut['streamflow']<-list(readNWISdv(nwisSite,'00060'))
    
    names(dataOut$streamflow)[4]<-'data_00060_00003'
    
    names(dataOut$streamflow)[5]<-'cd_00060_00003'
  }
  
  if("prcp" %in% return_var || "all" %in% return_var){
    dataOut$prcp$data[which(dataOut$prcp$data < 0)] <- NA
  }
  
  try(names(dataOut)[which(names(dataOut) %in% "MEAN_streamflow")]<-"discharge",silent = TRUE)
  
  return(dataOut)
}

#' Get WFS polygon for a watershed.
#'
#' This function builds a request and returns a spatial polygons data frame.
#'
#' @param huc The watershed of interest.
#' @param local TRUE/FALSE to request local watershed or total upstream watershed data.
#' @return The data.
#' @author David Blodgett \email{dblodgett@usgs.gov}
#' @importFrom jsonlite fromJSON
#' @export
#' @examples
#' NWCwatershed<-get_nwc_huc(huc="031601030306",local=TRUE)
#'
get_nwc_huc<-function(huc, local=FALSE) {
  
  baseURL<-"https://cida.usgs.gov/nwc/geoserver/ows"
  
  if (local) {
    layer<-"WBD:huc12"
  } else {
    layer<-"WBD:huc12agg"
  }
  
  hucRes<-'huc12'
  
  filter<-URLencode(paste0("<Filter><PropertyIsEqualTo><PropertyName>",
                           hucRes, "</PropertyName><Literal>",
                           huc, "</Literal></PropertyIsEqualTo></Filter>"))
  
  dataURL<-paste0(baseURL,"?service=WFS&version=1.0.0&request=GetFeature&typeName=",
                  layer,"&filter=",filter,"&outputFormat=application/json&srsName=EPSG:4326")
  
  geojson<-fromJSON(txt=readLines(dataURL, warn = FALSE),
                    collapse = "\n",simplifyVector = FALSE)
  
  return(geojson)
}

#' Get an NWIS site that matches the HUC in question.
#'
#' Given a HUC, this function checks if an NWIS site is available.
#'
#' @param huc The watershed of interest.
#' @return The NWIS site ID. NULL if none found.
#' @author David Blodgett \email{dblodgett@usgs.gov}
#' @importFrom jsonlite fromJSON
#' @importFrom utils URLencode
#' @examples
#' \dontrun{
#' data<-get_nwis_nwc_site(huc="031601030306")
#'}
get_nwis_nwc_site<-function(huc) {
  # Note that this file is available here: https://cida.usgs.gov/nwc/json/watershed_gages.json
  lookup<-fromJSON(txt=readLines(system.file('extdata','watershed_gages.json',package='NWCCompare')))
  returnval<-NULL
  for(l in 1:nrow(lookup)) {
    if (grepl(huc, lookup$hucId[l])) {
      if(nchar(huc)==12) {
        returnval<-lookup$gageId[l]
      }
    }
  }
  return(returnval)
}
