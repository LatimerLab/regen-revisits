#### Purpose: Compile species data from initial survey to extract common invasive species to be on the look out for in resamples 

library(tidyverse)
library(here)
library(readxl)

### Setup: define a function `datadir()` that points to your local data directory 
# The root of the data directory
data_dir = readLines(here("data_dir.txt"), n=1)
source(here("scripts/convenience_functions.R"))

#### Load species composition data -------------------------------


FRD_sp = read_excel(datadir("CSEs/richter-additional/freds/FredsCSE_DataEntryFinal_2012+2013.xlsx"), sheet = "Species Comp and Cover")
PWR_sp = read_excel(datadir("CSEs/richter-additional/power/Species_Composition_2014.xlsx"))
MNL_sp = read_excel(datadir("CSEs/richter-additional/moonlight/Moonlight_Species_Composition.xlsx"), sheet = "Data")
# could not find species data from showers or gondola

### Get species list with max cover for each fire (from PWR first because we have species names)

PWR_sp_max = PWR_sp %>% mutate(`% Cover` = as.numeric(replace(`% Cover`, `% Cover` == "TR", 0.25))) %>%
  group_by(`Species...5`, `Species Name`) %>%
  rename(`Species Code` = `Species...5`) %>%
  summarise(max_cover = max(`% Cover`))

#read in extra species codes
extra_sp_names = read_excel(datadir("extra_species_codes_MNL_FRD.xlsx"))

sp_names = select(PWR_sp_max, c(`Species Code`, `Species Name`)) %>% rbind(., extra_sp_names)

### Convert codes to species names
FRD_sp = left_join(FRD_sp, sp_names)
MNL_sp = left_join(MNL_sp, sp_names)

# Get species list with max cover for FRD and MNL
FRD_sp_max = FRD_sp %>% group_by(`Species Code`, `Species Name`) %>%
  summarise(max_cover = max(`% Cover`))

MNL_sp_max = MNL_sp %>% mutate(`% Cover` = as.numeric(replace(`% Cover`, `% Cover` == "TR", 0.25))) %>%
  group_by(`Species Code`, `Species Name`) %>%
  summarise(max_cover = max(`% Cover`))


all_sp = rbind(PWR_sp_max, MNL_sp_max, FRD_sp_max)

all_sp_max = all_sp %>% group_by(`Species Name`, `Species Code`) %>%
  summarise(max_cover = max(max_cover))


## Pull out only the introduced species

#read in USDA plants list of introduced species for California
inv_sp = read_excel(datadir("USDA_introduced_sp_CA.xlsx"))

inv_in_plots = inner_join(inv_sp, all_sp_max)

# write.csv(inv_in_plots, "introduced species in plots.csv", row.names = F)
