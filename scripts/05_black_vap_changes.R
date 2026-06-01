suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

dir.create("outputs", showWarnings = FALSE)

plan_pairs <- read_csv("data/plan_pairs.csv", show_col_types = FALSE)

all_districts <- tibble()

for (i in seq_len(nrow(plan_pairs))) {
  row <- plan_pairs[i, ]

  before_raw <- read_csv(
    file.path("data", "dra_district_exports", row$pre_file),
    col_select = c(1, any_of(c("Label", "V_20_VAP_Total", "V_20_VAP_Black"))),
    show_col_types = FALSE,
    name_repair = "minimal"
  )

  before_district_col <- names(before_raw)[1]

  before_districts <- before_raw %>%
    transmute(
      state = row$state,
      map_type = "Before redistricting",
      district = as.integer(.data[[before_district_col]]),
      district_id = paste0(state, "-", Label),
      vap_total = as.numeric(V_20_VAP_Total),
      black_vap = as.numeric(V_20_VAP_Black),
      black_vap_share = black_vap / vap_total
    ) %>%
    filter(!is.na(district), !is.na(black_vap_share))

  after_raw <- read_csv(
    file.path("data", "dra_district_exports", row$post_file),
    col_select = c(1, any_of(c("Label", "V_20_VAP_Total", "V_20_VAP_Black"))),
    show_col_types = FALSE,
    name_repair = "minimal"
  )

  after_district_col <- names(after_raw)[1]

  after_districts <- after_raw %>%
    transmute(
      state = row$state,
      map_type = "After redistricting",
      district = as.integer(.data[[after_district_col]]),
      district_id = paste0(state, "-", Label),
      vap_total = as.numeric(V_20_VAP_Total),
      black_vap = as.numeric(V_20_VAP_Black),
      black_vap_share = black_vap / vap_total
    ) %>%
    filter(!is.na(district), !is.na(black_vap_share))

  all_districts <- bind_rows(
    all_districts,
    before_districts,
    after_districts
  )
}

state_summary <- all_districts %>% 
  group_by(state, map_type) %>% 
  summarise(
    districts = n(),
    max_black_vap_share = max(black_vap_share, na.rm = TRUE),
    majority_black_vap_districts = sum(black_vap_share > 0.5, na.rm = TRUE),
    .groups = "drop"
  )

tn_after_max <- all_districts %>% 
  filter(state == "TN", map_type == "After redistricting") %>% 
  summarise(max_share = max(black_vap_share, na.rm = TRUE)) %>% 
  pull(max_share)

tennessee_claim <- all_districts %>% 
  filter(state == "TN") %>% 
  filter(
    (map_type == "Before redistricting" & district == 9) |
      (map_type == "After redistricting" & black_vap_share == tn_after_max)
  ) %>% 
  arrange(map_type) %>% 
  mutate(
    black_vap_share_pct = 100 * black_vap_share
  )

write_csv(all_districts, "outputs/black_vap_by_district.csv")
write_csv(state_summary, "outputs/black_vap_state_summary.csv")
write_csv(tennessee_claim, "outputs/steve_cohen_tennessee_black_vap_claim.csv")

message("Wrote Black VAP district outputs.")
