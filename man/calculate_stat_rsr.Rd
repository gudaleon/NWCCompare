% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utilities.R
\name{calculate_stat_rsr}
\alias{calculate_stat_rsr}
\title{Function to return the ratio of the root mean square error to the standard deviation}
\usage{
calculate_stat_rsr(estimate_timeseries, reference_timeseries)
}
\arguments{
\item{estimate_timeseries}{data frame containing value data for the modeled timeseries}

\item{reference_timeseries}{data frame containing value data for the observed timeseries}
}
\value{
rsr root mean square error/standard deviation for the two timeseries
}
\description{
This function accepts observed and modeled daily data series and returns the 
root mean square error/standard deviation of the reference timeseries
}
\examples{
estimate_timeseries<-mod_data$discharge
reference_timeseries<-obs_data$discharge
calculate_stat_rsr(estimate_timeseries, reference_timeseries)
}
