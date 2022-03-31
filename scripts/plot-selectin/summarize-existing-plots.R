library(tidyverse)
library(here)
library(sf)
library(readxl)
library(terra)

# The root of the data directory
data_dir = readLines(here("data_dir.txt"), n=1)

source(here("scripts/convenience_functions.R"))

## Main CSE database compiled by Clark Richter
richter_plots = read_excel(datadir("CSEs/richter-db-export/Plot Data.xlsx"))

#### bring in the other plot locs

## for Pendola, need to make sure that regen & fuel data can be linked to plot IDs.
##!! NOTE that waiting to learn if Bassetts is rebarred (next need to ask Clark) -- only add it (from Richter spreadsheets) if it is

## note that there are also Rim and King from Shive if we want them
# To get Bassetts: from Richter tables merged with Welch DB for plot locs

# Pendola from Richter tables
pendola_plots = read_excel(datadir("CSEs/richter-additional/pendola/Plot_Data.xlsx"))

# gondola and showers from hugh. Fires burned 2002. Initial survey 08-09. Revisit 2019.
gond_show_plots = read_excel(datadir("CSEs/showers-gondola/access-export/Plot_data.xlsx"))


#### Non-rebarred (non-CSE) plots
## bring in Welch and Young data (box: plot_level_pub.csv)
welch_young_plots = read_csv(datadir("non-CSEs/young-welch-summarized/plot_level_pub.csv"))

## bring in Young/Latimer JFSP data
jfsp_plots = read_excel(datadir("non-CSEs/latimer-young-summarized/Data_template_DJNY-3.xlsx"),sheet = 3)



#### Merge the relevant plot sets:
## Richter DB
richter_premerge = richter_plots %>%
  mutate(survey_year = str_sub(Date,1,4)) %>%
  mutate(fire_sev = recode(FIRE_SEV, "Control" = "0", "Low" = "1", "Med" = "3", "High" = "5", "Unburned" = "0") %>% as.numeric) %>%
  select(FIRE_ID, Plot_ID = `Plot ID`, Sample_Year, Easting, Northing, fire_sev)

# Need to pull in the FRD 2013 surveys coords
frd_missing_coords = read_excel(datadir("CSEs/richter-additional/freds/CSE_Missing_Coordinates_CJR.xlsx")) %>%
  rename("Plot_ID" = `Plot ID`, "Easting_missing" = "Easting", "Northing_missing" = "Northing")

richter_premerge_2 =
  left_join(richter_premerge,frd_missing_coords,by="Plot_ID") %>%
  mutate(Easting = ifelse(is.na(Easting), Easting_missing, Easting),
         Northing = ifelse(is.na(Northing), Northing_missing, Northing)) %>%
  select(-Easting_missing, -Northing_missing) %>%
  mutate(CSE = "CSE", revisited = "Not-revisited")

richter_premerge_2[richter_premerge_2$FIRE_ID == "ANG", "revisited"] = "Revisited"


## Need to pull in the FRD 2012 fire sevs
# Fix the Frd 2012 plot IDs: FRD_12_395 -> FRD120395
richter_premerge_2 = richter_premerge_2 %>%
  mutate(Plot_ID = str_replace(Plot_ID,pattern = fixed("FRD_12_"),replacement = "FRD120"))

frd_missing_sevs = read_excel(datadir("CSEs/richter-additional/freds/FredsCSE_DataEntryFinal_2012+2013.xlsx")) %>%
  select(Plot_ID = "Plot ID", fire_sev_missing = FIRE_SEV)

richter_premerge_3 =
  left_join(richter_premerge_2,frd_missing_sevs,by="Plot_ID") %>%
  mutate(fire_sev = ifelse(is.na(fire_sev), fire_sev_missing, fire_sev) %>% as.numeric) %>%
  select(-fire_sev_missing)


##Pendola
pendola_premerge = pendola_plots %>%
  mutate(Sample_Year = str_sub(Date,1,4) %>% as.numeric,
         FIRE_ID = str_sub(Regen_Plot,1,3)) %>%
  select(FIRE_ID, Plot_ID = Regen_Plot, Sample_Year, Easting, Northing, fire_sev = FIRE_SEV) %>%
  mutate(CSE = "CSE", revisited = "Not-revisited")

###TODO !!!###!!! Filter to just those plots that are in the richter sheets "total Species Composition"



# Showers & Gondola
gond_show_premerge = gond_show_plots %>%
  mutate(FIRE_ID = str_sub(Regen_Plot_Mast,1,3)) %>%
  filter(Year <= 2009) %>% # keep only those plots sampled in 08 and 09 (bc DB also includes resampled)
  select(FIRE_ID, Plot_ID = Regen_Plot_Mast, Sample_Year = Year, Easting, Northing, fire_sev = FIRE_SEV)

# Pull in missing plots locs

show_missing_coords = read_excel(datadir("CSEs/showers-gondola/PlotLocations_Gondola&Showers.xlsx"),sheet=2) %>%
  select(Plot_ID = Object_ID, Northing_missing = Northing, Easting_missing = Easting)

gond_show_premerge_2 = gond_show_premerge %>%
  left_join(show_missing_coords, by="Plot_ID") %>%
  mutate(Easting = ifelse(is.na(Easting), Easting_missing, Easting) %>% as.numeric,
         Northing = ifelse(is.na(Northing), Northing_missing, Northing) %>% as.numeric) %>%
  select(-Easting_missing, -Northing_missing) %>%
  mutate(CSE = "CSE", revisited = "Revisited")


## Welch-Young (flag that non-CSE)

welch_young_premerge = welch_young_plots %>%
  mutate(FIRE_ID = str_sub(Regen_Plot,1,3)) %>%
  select(FIRE_ID,Plot_ID = Regen_Plot, Sample_Year = Year, Easting, Northing, fire_sev = FIRE_SEV, fire_year = Year.of.Fire) %>%
  mutate(CSE = "Non-CSE", revisited = "Not-revisited")

## Latimer-Young (flag that non-CSE)

jfsp_premerge = jfsp_plots %>%
  mutate(FIRE_ID = str_sub(plot_id,1,1)) %>%
  select(FIRE_ID, Plot_ID = plot_id, Sample_Year = sample_year, longitude, latitude, fire_year) %>%
  mutate(fire_sev = 5, CSE = "Non-CSE", revisited = "Not-revisited")


## Merge everything that's in UTMs and convert to lat-long

plots_merged_utm = bind_rows(richter_premerge_3, pendola_premerge, gond_show_premerge_2, welch_young_premerge)
plots_merged_utm = plots_merged_utm %>%
  filter(between(Easting,580000,1210000),
         between(Northing,1e06,10000000)) # this ends up throwing out some PWR 2015 plots with erroneously small NOrthings

# what is the UTM cutoff bt 10n and 11n?
hist(plots_merged_utm$Easting)
# looks like it's 10n > 1000000
hist(plots_merged_utm$Northing)

plots_merged_10n = plots_merged_utm %>%
  filter(Easting > 1000000)
plots_merged_11n = plots_merged_utm %>%
  filter(Easting < 1000000)

plots_10n_sf = st_as_sf(plots_merged_10n,coords = c("Easting","Northing"), crs = 26911)
plots_11n_sf = st_as_sf(plots_merged_11n,coords = c("Easting","Northing"), crs = 26910)

# OK all the UTM plots were in 11n
plots_sf_latlong = st_transform(plots_11n_sf, 4326)

coords = st_coordinates(plots_sf_latlong)

plots_sf_latlong$longitude = coords[,1]
plots_sf_latlong$latitude = coords[,2]

st_geometry(plots_sf_latlong) = NULL

plots = bind_rows(plots_sf_latlong, jfsp_premerge)

# what fire years need to be populated?
table(plots$FIRE_ID, plots$fire_year)

## Populate missing fire years
plots = plots %>%
  mutate(fire_year_missing = recode(FIRE_ID, ANG = 2007, GON = 2002, MNL = 2007, PNP = 1999, PNT = 1999, SHR = 2002, FRD = 2004, PWR = 2004, RCH = 2008, .default = 0)) %>%
  mutate(fire_year = ifelse(is.na(fire_year), fire_year_missing, fire_year))


### From Richter DB:
# want to keep Angora 2012 survey (it's 5 y old) but !!! DROP 2009 (too young)
# !!! drop RCH (reburned)
# keep Freds 2012-2013 (they're 8-9 y post)
# keep moonlight 2014 (it's 7 y post)
# keep power 2014-2015 (it's 10-11 y post)
# keep Star (it's 14 y)

plots = plots %>%
  filter(!(FIRE_ID == "RCH") & !((FIRE_ID == "ANG") & (Sample_Year == 2009)))


### Filter to moderate-high sev
plots = plots %>%
  filter(fire_sev >= 3)
  

### Filter out burned plots
fire_perims = vect(datadir("/fire-perims/fire20_1.gdb"))
fire_perims = fire_perims[fire_perims$YEAR_ > 1994,]
fire_perims$YEAR_ = as.numeric(fire_perims$YEAR_)


# rasterize it
r = rast(fire_perims,resolution=50,crs="+proj=aea +lat_1=34 +lat_2=40.5 +lat_0=0 +lon_0=-120 +x_0=0 +y_0=-4000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs ")
mostrecent_fire = rasterize(fire_perims,r, field="YEAR_", fun=max)



caldor = vect(datadir("fire-perims/ca3858612053820210815_20201011_20211016_ravg_data/ca3858612053820210815_20201011_20211016/CA3858612053820210815.kml"))
caldor = project(caldor,r)
caldor$year = 2021
caldor_rast = rasterize(caldor,r,field="year", fun=max)
dixie = vect(datadir("fire-perims/ca3987612137920210714_20201012_20211015_ravg_data/ca3987612137920210714_20201012_20211015/CA3987612137920210714.kml"))
dixie = project(dixie,r)
dixie$year = 2021
dixie_rast = rasterize(dixie,r,field="year", fun=max)

fire_hist = c(mostrecent_fire,caldor_rast,dixie_rast)
fire_hist = max(fire_hist, na.rm=TRUE)

writeRaster(fire_hist,datadir("temp/mostrecent_fire.tif"), overwrite=TRUE)

fire_hist = max(mostrecent_fire,caldor,dixie)

## extract most recent fire at each plot
plots_sf = st_as_sf(plots,coords = c("longitude","latitude"), crs = 4326) %>% st_transform(3310)
plots_vect = vect(plots_sf)

mostrecent_fire = extract(fire_hist,plots_vect)
plots_sf$mostrecent_fire = mostrecent_fire[,2]


# did the plot burn since focal fire?
plots_sf$reburned = plots_sf$fire_year < plots_sf$mostrecent_fire

##!! exclude 234 reburned plots
plots_sf = plots_sf %>%
  filter(reburned == FALSE)


st_write(plots_sf,datadir("temp/plots.gpkg"))







  
## Extract climate data
precip = rast(datadir("prism/PRISM_ppt_30yr_normal_800mM3_annual_bil/PRISM_ppt_30yr_normal_800mM3_annual_bil.bil"))
tmean = rast(datadir("prism/PRISM_tmean_30yr_normal_800mM3_annual_bil/PRISM_tmean_30yr_normal_800mM3_annual_bil.bil"))

plots_vect = vect(plots_sf %>% st_transform(crs(precip)))

precip_extr = extract(precip,plots_vect)
tmean_extr = extract(tmean,plots_vect)

plots_sf$precip = precip_extr[,2]
plots_sf$tmean = tmean_extr[,2]



### Compute # years since fire and since first survey

plots_sf = plots_sf %>%
  mutate(yrs_to_first_survey = Sample_Year - fire_year,
         yrs_since_first_survey = 2022 - Sample_Year)

ggplot(plots_sf, aes(x=precip,y=tmean,color=yrs_to_first_survey)) +
  geom_point() +
  facet_grid(CSE~revisited) +
  theme_bw(15)

ggplot(plots_sf, aes(x=precip,y=tmean,color=yrs_since_first_survey)) +
  geom_point() +
  facet_grid(CSE~revisited) +
  theme_bw(15)


# save separate CSE and non-CSE

plots_cse = plots_sf %>%
  filter(revisited == "Not-revisited",
         CSE == "CSE")

plots_noncse = plots_sf %>%
  filter(revisited == "Not-revisited",
         CSE == "Non-CSE")

st_write(plots_cse, datadir("temp/plots_cse.gpkg"))
st_write(plots_noncse, datadir("temp/plots_noncse.gpkg"))

## Remove those that are managed after the fire year















table(db_plots$FIRE_ID,db_plots$Sample_Year)

## See which ones have regen data



