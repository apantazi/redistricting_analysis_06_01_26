suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

dir.create("outputs", showWarnings = FALSE)

redrawn_states <- c("AL", "CA", "FL", "LA", "MO", "NC", "OH", "TN", "TX", "UT")

maps <- read_csv("outputs/presidential_map_scenarios.csv", show_col_types = FALSE)

house_2024 <- read_csv(
  "data/congressional/current_2024_president_and_house_by_district.csv",
  show_col_types = FALSE
)

redrawn_dem_wins_2024 <- house_2024 %>% 
  filter(state %in% redrawn_states) %>% 
  summarise(seats = sum(cong_winner_party == "D", na.rm = TRUE)) %>% 
  pull(seats)

national <- maps %>% 
  group_by(map) %>% 
  arrange(desc(harris_margin_pts),na.rm=TRUE,.by_group=TRUE)%>% 
  mutate(rank=row_number())%>% 
  filter(rank==218)%>% 
  ungroup()%>% 
  mutate(scope = "Nationwide House majority",
    seats_needed=218,
    tipping_district=district_id,
    tipping_harris_margin_pts=harris_margin_pts,
    dem_overperformance_needed_pts=pmax(0,-harris_margin_pts))%>% 
  select(map,seats_needed,tipping_district,tipping_harris_margin_pts,dem_overperformance_needed_pts,scope)

 redrawn_states_only <- maps |>
    filter(state %in% redrawn_states) |>
    group_by(map) |>
    arrange(desc(harris_margin_pts),na.rm=TRUE,.by_group=TRUE)%>% 
    mutate(rank=row_number())%>% 
    filter(rank==redrawn_dem_wins_2024)%>% 
    ungroup()%>% 
    mutate(scope = "Nationwide House majority",
    seats_needed=redrawn_dem_wins_2024,
    tipping_district=district_id,
    tipping_harris_margin_pts=harris_margin_pts,
    dem_overperformance_needed_pts=pmax(0,-harris_margin_pts))%>% 
    select(map,seats_needed,tipping_district,tipping_harris_margin_pts,dem_overperformance_needed_pts,scope)

summary <- bind_rows(national, redrawn_states_only) %>% 
  select(scope, everything()) %>% 
  arrange(scope, map)

write_csv(summary, "outputs/flipping_point_summary.csv")