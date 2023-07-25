##' Save forecast and metadata to file, submit forecast to EFI
##' @param forecast dataframe
##' @param team_info list, see example
##' @param submit boolean, should forecast be submitted to EFI challenge
submit_forecast <- function(forecast,team_info,submit=FALSE){
  
  #Forecast output file name in standards requires for Challenge.  
  # csv.gz means that it will be compressed
  forecast_file <- paste0("aquatics","-",min(forecast$datetime),"-",team_info$team_name,".csv.gz")
  
  #Write csv to disk
  write_csv(forecast, forecast_file)
  
  #Confirm that output file meets standard for Challenge
  neon4cast::forecast_output_validator(forecast_file)
  
  # Generate metadata
  model_metadata = list(
    forecast = list(
      model_description = list(
        forecast_model_id =  system("git rev-parse HEAD", intern=TRUE), ## current git SHA
        name = "Air temperature to water temperature linear regression plus assume saturated oxygen", 
        type = "empirical",  
        repository = "https://github.com/eFellin/PairCoding"   ## repo added here
      initial_conditions = list(
        status = "absent"
      ),
      drivers = list(
        status = "propagates",
        complexity = 1, #Just air temperature
        propagation = list( 
          type = "ensemble", 
          size = 31) 
      ),
      parameters = list(
        status = "data_driven",
        complexity = 2 # slope and intercept (per site)
      ),
      random_effects = list(
        status = "absent"
      ),
      process_error = list(
        status = "absent"
      ),
      obs_error = list(
        status = "absent"
      )
    )
  )
  
  #  TODO: needs updating because this function has been depricated  
  #  metadata_file <- neon4cast:::generate_metadata(forecast_file, team_info$team_list, model_metadata)
  
  if(submit){
    neon4cast::submit(forecast_file = forecast_file, ask = FALSE)
  }
  
}
```
3. As before, add your new file under the Git tab, Commit the change, and push it back to Github

## Task 5: Collaborator adds the master script

The day-to-day workflow for the COLLABORATOR is similar, but not exactly the same as the OWNER. The biggest differences are that the COLLABORATOR needs to pull from the OWNER, not their own repository, and needs to do a pull request after the push.

### COLLABORATOR

1. Pull from OWNER. Unfortunately, there's not yet a RStudio button for pulling from someone else's repo. There are two options for how to pull from OWNER. 

The **first option** is to go to the collaborator's Github repo online, where there should now be a message near the top saying that your repo is behind the OWNER's. At the right side of that message there should be a "sync fork" option. After you've clicked on that and followed the instructions to update your fork, you should be able to use the Git > Pull button in RStudio to pull those changes down to your local computer.

The **second option** is to use git at the command line. In the RStudio "Terminal" tab type
```
git pull URL master
```
where URL is the address of the OWNER's Github repository. Because it is a pain to always remember and type in the OWNER's URL, it is common to define this as _upstream_
```
git remote add upstream URL
```
which is a one-time task, after which you can do the pull as
```
git pull upstream master
```
2. Open a new R file and add the code below. This code just flushes out the pseudocode outline we started with at the beginning of this activity.
```{r}
### Aquatic Forecast Workflow ###
# devtools::install_github("eco4cast/neon4cast")
#install.packages("rMR")
library(tidyverse)
library(neon4cast)
library(lubridate)
library(rMR)

forecast_date <- Sys.Date()
noaa_date <- Sys.Date() - days(1)  #Need to use yesterday's NOAA forecast because today's is not available yet

#Step 0: Define team name and team members 
team_info <- list(team_name = "air2waterSat_MCD",
                  team_list = list(list(individualName = list(givenName = "Mike", 
                                                              surName = "Dietze"),
                                        organizationName = "Boston University",
                                        electronicMailAddress = "dietze@bu.edu"))
                  )

## Load required functions
if(file.exists("01_download_data.R"))      source("01_download_data.R")
if(file.exists("02_calibrate_forecast.R")) source("02_calibrate_forecast.R")
if(file.exists("03_run_forecast.R"))       source("03_run_forecast.R")
if(file.exists("04_submit_forecast.R"))    source("04_submit_forecast.R")

### Step 1: Download Required Data
target     <- download_targets()       ## Y variables
site_data  <- download_site_meta()
target     <- merge_met_past(target)   ## append met data (X) into target file
met_future <- download_met_forecast(forecast_date) ## Weather forecast (future X)

## visual check of data
ggplot(target, aes(x = temperature, y = air_temperature)) +
  geom_point() +
  labs(x = "NEON water temperature (C)", y = "NOAA air temperature (C)") +
  facet_wrap(~site_id)

### Step 2: Calibrate forecast model
model <- calibrate_forecast(target)

### Step 3: Make a forecast into the future
forecast <- run_forecast(model,met_future,site_data)

#Visualize forecast.  Is it reasonable?
forecast %>% 
  ggplot(aes(x = datetime, y = prediction, group = parameter)) +
  geom_line() +
  facet_grid(variable~site_id, scale ="free")

### Step 4: Save and submit forecast and metadata
submit_forecast(forecast,team_info,submit=FALSE)
