suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

dir.create("outputs", showWarnings = FALSE)

redrawn_states <- c("AL", "CA", "FL", "LA", "MO", "NC", "OH", "TN", "TX", "UT")

current <- read_csv(
  "data/presidential/current_2024_presidential_by_district.csv",
  show_col_types = FALSE
) %>%
  transmute(
    map = "Before redistricting",
    state,
    district_id,
    harris_margin_pts = 100 * pres_dem_margin
  )

manifest <- read_csv("data/dra_district_manifest.csv", show_col_types = FALSE) %>%
  mutate(source_path = file.path("data", "dra_district_exports", post_file))

post_replacements <- tibble()

for (i in seq_len(nrow(manifest))) {
  one_map <- read_csv(
    manifest$source_path[i],
    col_select = any_of(c("Label", "E_24_PRES_Dem", "E_24_PRES_Rep", "E_24_PRES_Total")),
    show_col_types = FALSE,
    name_repair = "minimal"
  ) %>%
    transmute(
      state = manifest$state[i],
      district_id = paste0(state, "-", Label),
      dem = as.numeric(E_24_PRES_Dem),
      rep = as.numeric(E_24_PRES_Rep),
      total = as.numeric(E_24_PRES_Total),
      harris_margin_pts = 100 * (dem - rep) / total
    )

  post_replacements <- bind_rows(post_replacements, one_map)
}

with_alabama_change <- bind_rows(
  current %>%
    filter(!state %in% redrawn_states) %>%
    mutate(map = "After redistricting, with Alabama change"),
  post_replacements %>%
    mutate(map = "After redistricting, with Alabama change")
)

without_alabama_change <- bind_rows(
  current %>%
    filter(!state %in% redrawn_states | state == "AL") %>%
    mutate(map = "After redistricting, without Alabama change"),
  post_replacements %>%
    filter(state != "AL") %>%
    mutate(map = "After redistricting, without Alabama change")
)

all_maps <- bind_rows(
  current,
  with_alabama_change,
  without_alabama_change
)

summary <- bind_rows(
  all_maps %>% mutate(scope = "Nationwide"),
  all_maps %>% filter(state %in% redrawn_states) %>% mutate(scope = "10 redrawn states")
) %>%
  group_by(scope, map) %>%
  summarise(
    total_districts = n(),
    harris_won = sum(harris_margin_pts > 0, na.rm = TRUE),
    trump_won = sum(harris_margin_pts < 0, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(scope, map)

write_csv(all_maps, "outputs/presidential_map_scenarios.csv")
write_csv(summary, "outputs/harris_won_before_after.csv")