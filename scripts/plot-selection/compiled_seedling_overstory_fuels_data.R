#### Purpose: Compile existing plot seedling/ EVT data from multiple data sources and add to compiled plots data; extract data for evaluating plots

library(tidyverse)
library(here)
library(sf)
library(readxl)



### Setup: define a function `datadir()` that points to your local data directory 
# The root of the data directory
data_dir = readLines(here("data_dir.txt"), n=1)
source(here("scripts/convenience_functions.R"))

#### Load seedling/ fuels/ overstory data-------------------------------

##FRD fire
FRD_regen_seed = read_excel(datadir("CSEs/richter-additional/freds/FredsCSE_DataEntryFinal_2012+2013.xlsx"), sheet = "Tree Regen")
FRD_regen_sap = read_excel(datadir("CSEs/richter-additional/freds/FredsCSE_DataEntryFinal_2012+2013.xlsx"), sheet = "Saplings")

##MNL fire
MNL_regen_seed = read_excel(datadir("CSEs/richter-additional/moonlight/All Moonlight CSE Data 2014.xlsx"), sheet = "Regen_Seedlings")
MNL_regen_sap = read_excel(datadir("CSEs/richter-additional/moonlight/All Moonlight CSE Data 2014.xlsx"), sheet = "Regen_Saplings")

##PWR fire
PWR_regen_seed = read_excel(datadir("CSEs/richter-additional/power/Seedlings Total.xlsx"))
PWR_regen_sap = read_excel(datadir("CSEs/richter-additional/power/Saplings Total.xlsx"))

#GON & SHR fires
GON_SHR_regen = read_excel(datadir("CSEs/showers-gondola/access-export/tree_regen.xlsx"))

#PND fire
PNTPNP_regen_seed = read_excel(datadir("non-CSEs/welch-db-export/tree_regen.xlsx"))


#### Load compiled plots data
plots_compiled = st_read(datadir("plot-data-compiled/plots_compiled.gpkg"))
plots_permanent = st_read(datadir("plot-data-compiled/plots_compiled_permanent.gpkg"))

#### Match the Plot ID from these worksheets to the Plot_ID from the compiled regen data
FRD_regen_seed_premerge = FRD_regen_seed %>%
  select(`Plot ID`, Count_total) %>%
  rename(Plot_ID = `Plot ID`) %>%
  group_by(Plot_ID) %>% 
  summarise(Count_total_allsp = sum(Count_total, na.rm=TRUE)) #sum regen seedlings for all species *ignore NAs!

MNL_regen_seed_premerge = MNL_regen_seed %>%
  select(Plot_ID, Count_total) %>%
  mutate(Plot_ID = replace(Plot_ID, Plot_ID == "S_3a", "S_3A")) %>% #rename plots to match compiled plot data
  mutate(Plot_ID = replace(Plot_ID, Plot_ID == "SE_6a", "SE_6A")) %>%
  group_by(Plot_ID) %>%
  summarise(Count_total_allsp = sum(Count_total, na.rm=TRUE))
  

PWR_regen_seed_premerge = PWR_regen_seed %>%
  #to match the plot ID from PWR tables to the Plot_ID column from the compiled regen data, prefix them with PWR1400[…]. You need to pad the number of zeros so there are 7 digits total. 
  #If the plot number has a suffix letter like A or B, this does not count in the 7 digits.
  mutate(PWR = "PWR14") %>% #add column with prefix for merging
  separate(Plot_ID, c("Plot_IDnum","Plot_IDletter"), "(?<=[0-9])(?=[A-Z])") %>% #separate letters from numbers
  mutate(Plot_IDletter = replace_na(Plot_IDletter, "")) %>% #replace NAs with blanks
  mutate(Plot_IDpad = str_pad(Plot_IDnum, 5, side = 'left', pad = '0')) %>% #pad with 0s to 5 digits
  unite("Plot_ID", c("PWR", "Plot_IDpad", "Plot_IDletter"), remove = TRUE, sep = "") %>% #create new Plot_ID column with PWR14[..] prefix
  group_by(Plot_ID) %>%
  summarise(Count_total_allsp = sum(Count_total, na.rm=TRUE))

GON_SHR_regen_premerge = GON_SHR_regen %>%
  select(Regen_Plot_Mast, Count_total) %>%
  rename(Plot_ID = Regen_Plot_Mast) %>%
  group_by(Plot_ID) %>%
  summarise(Count_total_allsp = sum(Count_total, na.rm=TRUE))

PNTPNP_regen_seed_premerge = PNTPNP_regen_seed %>%
  select(Regen_Plot, Count_total) %>%
  rename(Plot_ID = Regen_Plot) %>%
  group_by(Plot_ID) %>% 
  summarise(Count_total_allsp = sum(Count_total, na.rm=TRUE)) #sum regen seedlings for all species *ignore NAs!

##Combine regen dfs
compiled_regen = bind_rows(FRD_regen_seed_premerge, MNL_regen_seed_premerge, PWR_regen_seed_premerge, GON_SHR_regen_premerge, PNTPNP_regen_seed_premerge)

### Merge with compiled plot data---------------------------------------------
plots_with_regen = merge(plots_compiled, compiled_regen, all.x = TRUE) %>% #keep all permanent plots, even if they don't have regen recorded
  mutate(regen_present = Count_total_allsp > 0) %>% #add a column indicating if any regen is present
  mutate(regen_present = replace_na(as.character(regen_present), "NR"))


plots_permanent_with_regen_unmanaged = plots_with_regen %>% subset(facts_managed == "Unmanaged") %>%
  subset(permanent == "Permanent") %>%
  mutate(regen_present = Count_total_allsp > 0) %>%
  mutate(regen_present = replace_na(as.character(regen_present), "NR"))


summary(plots_permanent_with_regen_unmanaged) #31 out of 93 unmanaged permanent plots have no regen recorded (23 NAs, 8 zeros) 
# Includes NAs for 5 PNT/PNP plots - we did not pull regen data for this fire because it was heavy with poison oak and there were only a few permanent plots

## Prelim visualization------------------------------------------

ggplot(plots_with_regen %>% subset(permanent == "Permanent"), aes(x=precip,y=tmean, color=FIRE_ID, shape = regen_present)) +
  geom_point(size = 2.5) +
  scale_shape_manual(values = c(1,2,16))+
  facet_grid(permanent~facts_managed) +
  theme_bw(15)

ggplot(data = plots_with_regen, aes(x=precip,y=tmean, color=FIRE_ID, shape = regen_present)) +
  geom_point(size = 2.5) +
  scale_shape_manual(values = c(1,2,16))+
  facet_grid(permanent~facts_managed) +
  theme_bw(15)


ggplot(plots_with_regen %>% subset(permanent == "Permanent"), aes(x=yrs_to_first_survey, y=yrs_since_first_survey, color=FIRE_ID, shape = regen_present)) +
  geom_jitter(size = 2.5) +
  scale_shape_manual(values = c(1,2,16))+
  facet_grid(permanent~facts_managed) +
  theme_bw(15)



ggplot(plots_with_regen %>% subset(FIRE_ID == "FRD") %>% subset(permanent == "Permanent"), aes(x = facts_activity) )+
  geom_histogram(stat = "count") +
  scale_x_discrete(labels = scales::wrap_format(50)) +
  theme_bw(15) +
  theme(axis.text.x = element_text(angle = 90))
      
plots_permanent_with_regen_unmanaged %>%
  count(FIRE_ID)

# Extract Eveg data at plot locations--------------------------------

### Extract Eveg data at plot locations
#read in eveg data for N Sierra
eveg_saf = read_sf(datadir("Eveg/Eveg_NSshp/Eveg_NSierra.shp"), query = "SELECT SAF_COVER_ FROM Eveg_NSierra WHERE SAF_Cover_ != '000'")

#read in codes
eveg_saf_codes = read.csv(datadir("Eveg/SAF_COVER_CODES.csv")) %>% mutate(SAF_COVER_ = as.character(SAF_COVER_))

sf_use_s2(FALSE)
eveg_extr = st_join(plots_compiled %>% st_transform(st_crs(eveg_saf)), eveg_saf, left = TRUE) %>% data.frame()
#replace numbers with codes
eveg_extr = left_join(eveg_extr, eveg_saf_codes)


ggplot(eveg_extr %>% subset(permanent == "Permanent"), aes(x = SAF_COVER_TYPE, fill = FIRE_ID) )+
  geom_histogram(stat = "count") +
  scale_x_discrete(labels = scales::wrap_format(50)) +
  facet_grid(permanent~facts_managed) +
  theme_bw(15) +
  theme(axis.text.x = element_text(angle = 90))

eveg_extr %>% 
  subset(permanent == "Permanent") %>%
  subset(facts_managed = "Unmanaged") %>%
  group_by(FIRE_ID) %>% count(SAF_COVER_TYPE)
