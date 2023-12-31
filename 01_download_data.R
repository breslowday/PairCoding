## Before getting started

#Note: This primer is based on the NEON-focused version of https://github.com/EcoForecast/EF_Activities Exercise_04. The most up-to-date version of this primer will be maintained there.

#Before beginning this exercise, you should have the following three packages installed, which you may not already have installed. If you don't have them installed, you should run the following commands **in your console** to install them. The reason for this is RMarkdown really doesn't like when you try to install packages while knitting a document. So, while you *can* run the code chunk by chunk in RMarkdown, if you go to knit it, you will receive an error.


##' Download Targets
##' @return data.frame in long format with days as rows, and time, site_id, variable, and observed as columns
download_targets <- function(){
  readr::read_csv("https://data.ecoforecast.org/neon4cast-targets/aquatics/aquatics-targets.csv.gz", guess_max = 1e6)
}

##' Download Site metadata
##' @return metadata dataframe
download_site_meta <- function(){
  site_data <- readr::read_csv("https://raw.githubusercontent.com/eco4cast/neon4cast-targets/main/NEON_Field_Site_Metadata_20220412.csv") 
  site_data %>% filter(as.integer(aquatics) == 1)
}


##' append historical meteorological data into target file
##' @param target targets dataframef
##' @return updated targets dataframe with added weather data
merge_met_past <- function(target){
  
  ## connect to data
  df_past <- neon4cast::noaa_stage3()
  
  ## filter for site and variable
  sites <- unique(target$site_id)
  noaa_past <- df_past |> 
    dplyr::filter(site_id %in% sites,
                  variable == "air_temperature") |> 
    dplyr::collect()
  
  noaa_past_mean = noaa_past |> 
    dplyr::select(datetime, site_id, prediction, parameter) |>
    dplyr::mutate(date = as_date(datetime)) |>
    dplyr::group_by(date, site_id) |>
    dplyr::summarize(air_temperature = mean(prediction, na.rm = TRUE),
                     .groups = "drop") |>
    dplyr::rename(datetime = date) |>
    dplyr::mutate(air_temperature = air_temperature - 273.15) 
  
  ## Aggregate (to day) and convert units of drivers
  target <- target %>% 
    group_by(datetime, site_id,variable) %>%
    summarize(obs2 = mean(observation, na.rm = TRUE), .groups = "drop") %>%
    mutate(obs3 = ifelse(is.nan(obs2),NA,obs2)) %>%
    select(datetime, site_id, variable, obs3) %>%
    rename(observed = obs3) %>%
    filter(variable %in% c("temperature", "oxygen")) %>% 
    tidyr::pivot_wider(names_from = "variable", values_from = "observed")
  
  ## Merge in past NOAA data into the targets file, matching by date.
  target <- left_join(target, noaa_past_mean, by = c("datetime","site_id"))
  
}

##' Download NOAA GEFS weather forecast
##' @param forecast_date start date of forecast
##' @return dataframe
download_met_forecast <- function(forecast_date){
  ## connect to data
  df_future <- neon4cast::noaa_stage2()
  
  noaa_date <- forecast_date - lubridate::days(1)  #Need to use yesterday's NOAA forecast because today's is not available yet
  
  ## filter available forecasts by date and variable
  met_future <- df_future |> 
    dplyr::filter(reference_datetime == lubridate::as_datetime(noaa_date),
                  datetime >= lubridate::as_datetime(forecast_date), 
                  variable == "air_temperature") |> 
    dplyr::collect()
  
  ## aggregate to daily
  met_future <- met_future %>% 
    mutate(date = lubridate::as_date(datetime)) %>% 
    group_by(date, site_id, parameter) |> 
    summarize(air_temperature = mean(prediction), .groups = "drop") |> 
    mutate(air_temperature = air_temperature - 273.15) |> 
    select(date, site_id, air_temperature, parameter)
  
  return(met_future)
}