suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

dir.create("outputs", showWarnings = FALSE)

redrawn_states <- c("AL", "CA", "FL", "LA", "MO", "NC", "OH", "TN", "TX", "UT")

state_lookup <- tibble(
  candidate_state = c(
    "Alabama", "California", "Florida", "Louisiana", "Missouri",
    "North Carolina", "Ohio", "Tennessee", "Texas", "Utah"
  ),
  state_abbrev = redrawn_states
)

house_2024 <- read_csv(
  "data/congressional/current_2024_president_and_house_by_district.csv",
  show_col_types = FALSE
) %>%
  filter(valid_pres_cong_data) %>%
  mutate(
    old_district = as.integer(district),
    old_harris_margin_pts = 100 * pres_dem_margin,
    old_cong_dem_margin_pts = 100 * cong_dem_margin,
    in_redrawn_state = state %in% redrawn_states,
    incumbent_key = tolower(gsub("[^a-z]", "", gsub("\\b(jr|sr|ii|iii|iv)\\b", "", tolower(incumbent)))),
    split_ticket_type = case_when(
      cong_winner_party == "D" & pres_winner_party == "R" ~ "Democrat won Trump district",
      cong_winner_party == "R" & pres_winner_party == "D" ~ "Republican won Harris district",
      TRUE ~ "Same party won president and House"
    )
  )

candidate_incumbents <- read_csv(
  "data/candidates/ballotpedia_house_candidates_2026.csv",
  show_col_types = FALSE
) %>%
  filter(incumbent) %>%
  left_join(state_lookup, by = c("state" = "candidate_state")) %>%
  filter(!is.na(state_abbrev)) %>%
  mutate(
    state = state_abbrev,
    incumbent_key = tolower(gsub("[^a-z]", "", gsub("\\b(jr|sr|ii|iii|iv)\\b", "", tolower(candidate)))),
    candidate_running_district = as.integer(district_number),
    status_rank = if_else(ballotpedia_status == "active", 1, 2),
    phase_rank = case_when(
      election_phase == "General election" ~ 1,
      grepl("primary", tolower(election_phase)) ~ 2,
      TRUE ~ 3
    )
  ) %>%
  arrange(state, incumbent_key, status_rank, phase_rank) %>%
  group_by(state, incumbent_key) %>%
  slice(1) %>%
  ungroup() %>%
  transmute(
    state,
    incumbent_key,
    candidate = candidate,
    candidate_party = party,
    ballotpedia_status,
    election_phase,
    candidate_running_district,
    candidate_running_district_id = paste0(state, "-", candidate_running_district),
    candidate_source_url = source_url
  )

current_split_ticket_summary <- house_2024 %>%
  filter(split_ticket_type != "Same party won president and House") %>%
  group_by(split_ticket_type, in_redrawn_state) %>%
  summarise(
    districts = n(),
    .groups = "drop"
  ) %>%
  arrange(split_ticket_type, desc(in_redrawn_state))

crosswalk <- read_csv(
  "outputs/district_population_matches.csv",
  show_col_types = FALSE
)

overlap_detail <- read_csv(
  "outputs/district_population_overlap_pairs.csv",
  show_col_types = FALSE
) %>%
  group_by(state, old_district) %>%
  mutate(
    old_district_total_pop = sum(matched_pop),
    old_district_share_in_new_district = matched_pop / old_district_total_pop
  ) %>%
  ungroup() %>%
  group_by(state, new_district) %>%
  mutate(
    new_district_total_pop = sum(matched_pop),
    new_district_share_from_old_district = matched_pop / new_district_total_pop
  ) %>%
  ungroup() %>%
  select(
    state,
    old_district,
    scenario_new_district = new_district,
    scenario_matched_pop = matched_pop,
    old_district_share_in_new_district,
    new_district_share_from_old_district
  )

post_presidential <- read_csv(
  "outputs/presidential_map_scenarios.csv",
  show_col_types = FALSE
) %>%
  filter(map != "Before redistricting") %>%
  transmute(
    map,
    state,
    new_district_id = district_id,
    new_harris_margin_pts = harris_margin_pts
  )

redrawn_members <- house_2024 %>%
  filter(state %in% redrawn_states) %>%
  left_join(candidate_incumbents, by = c("state", "incumbent_key")) %>%
  left_join(
    crosswalk %>%
      rename(
        matched_new_district = new_district,
        matched_pop_successor = matched_pop,
        matched_old_district_retained_share = old_district_retained_share,
        matched_new_district_from_old_share = new_district_from_old_share
      ),
    by = c("state", "old_district")
  ) %>%
  mutate(
    active_candidate_running = ballotpedia_status == "active" & !is.na(candidate_running_district),
    matched_new_district_id = paste0(state, "-", matched_new_district)
  )

with_alabama_change <- redrawn_members %>%
  mutate(
    map = "After redistricting, with Alabama change",
    scenario_new_district = if_else(
      active_candidate_running,
      candidate_running_district,
      matched_new_district
    ),
    new_district_id = paste0(state, "-", scenario_new_district)
  ) %>%
  left_join(overlap_detail, by = c("state", "old_district", "scenario_new_district"))

without_alabama_change <- redrawn_members %>%
  mutate(
    map = "After redistricting, without Alabama change",
    scenario_new_district = case_when(
      state == "AL" ~ old_district,
      active_candidate_running ~ candidate_running_district,
      TRUE ~ matched_new_district
    ),
    new_district_id = paste0(state, "-", scenario_new_district)
  ) %>%
  left_join(overlap_detail, by = c("state", "old_district", "scenario_new_district")) %>%
  mutate(
    old_district_share_in_new_district = if_else(state == "AL", 1, old_district_share_in_new_district),
    new_district_share_from_old_district = if_else(state == "AL", 1, new_district_share_from_old_district)
  )

member_exposure <- bind_rows(
  with_alabama_change,
  without_alabama_change
) %>%
  left_join(post_presidential, by = c("map", "state", "new_district_id")) %>%
  mutate(
    new_pres_winner_party = case_when(
      new_harris_margin_pts > 0 ~ "D",
      new_harris_margin_pts < 0 ~ "R",
      TRUE ~ "Tie"
    ),
    old_incumbent_party_margin_pts = if_else(
      cong_winner_party == "D",
      old_harris_margin_pts,
      -old_harris_margin_pts
    ),
    new_incumbent_party_margin_pts = if_else(
      cong_winner_party == "D",
      new_harris_margin_pts,
      -new_harris_margin_pts
    ),
    incumbent_party_margin_shift_pts = new_incumbent_party_margin_pts - old_incumbent_party_margin_pts,
    redistricting_made_seat_harder = incumbent_party_margin_shift_pts < 0,
    old_presidential_lean_against_house_winner = pres_winner_party != cong_winner_party,
    new_presidential_lean_against_house_winner = new_pres_winner_party != cong_winner_party,
    analysis_district_source = case_when(
      map == "After redistricting, without Alabama change" & state == "AL" ~ "Current Alabama district because Alabama change excluded",
      active_candidate_running ~ "Ballotpedia active incumbent running district",
      !is.na(ballotpedia_status) ~ paste0("Ballotpedia status is ", ballotpedia_status, "; using population-matched successor"),
      TRUE ~ "No Ballotpedia incumbent match; using population-matched successor"
    )
  ) %>%
  transmute(
    map,
    state,
    old_district_id = district_id,
    new_district_id,
    analysis_district_source,
    matched_new_district_id,
    candidate_running_district_id = if_else(active_candidate_running, candidate_running_district_id, NA_character_),
    ballotpedia_status,
    election_phase,
    candidate_source_url,
    house_winner = cong_winner_candidate,
    house_winner_party = cong_winner_party,
    incumbent,
    old_presidential_winner = pres_winner,
    new_presidential_winner = case_when(
      new_pres_winner_party == "D" ~ "Harris",
      new_pres_winner_party == "R" ~ "Trump",
      TRUE ~ "Tie"
    ),
    split_ticket_type,
    old_harris_margin_pts,
    new_harris_margin_pts,
    harris_margin_shift_pts = new_harris_margin_pts - old_harris_margin_pts,
    old_incumbent_party_margin_pts,
    new_incumbent_party_margin_pts,
    incumbent_party_margin_shift_pts,
    redistricting_made_seat_harder,
    old_presidential_lean_against_house_winner,
    new_presidential_lean_against_house_winner,
    old_district_retained_share = old_district_share_in_new_district,
    new_district_from_old_share = new_district_share_from_old_district
  ) %>%
  arrange(map, split_ticket_type, incumbent_party_margin_shift_pts)

split_ticket_exposure <- member_exposure %>%
  filter(split_ticket_type != "Same party won president and House")

split_ticket_summary <- split_ticket_exposure %>%
  group_by(map, split_ticket_type) %>%
  summarise(
    incumbents = n(),
    seats_made_harder = sum(redistricting_made_seat_harder, na.rm = TRUE),
    seats_made_easier = sum(!redistricting_made_seat_harder, na.rm = TRUE),
    still_presidentially_crosspressured = sum(new_presidential_lean_against_house_winner, na.rm = TRUE),
    median_incumbent_party_margin_shift_pts = median(incumbent_party_margin_shift_pts, na.rm = TRUE),
    worst_incumbent_party_margin_shift_pts = min(incumbent_party_margin_shift_pts, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(map, split_ticket_type)

write_csv(current_split_ticket_summary, "outputs/current_split_ticket_districts_by_redistricting_status.csv")
write_csv(member_exposure, "outputs/redrawn_state_incumbent_redistricting_exposure.csv")
write_csv(split_ticket_exposure, "outputs/split_ticket_redistricting_exposure_by_member.csv")
write_csv(split_ticket_summary, "outputs/split_ticket_redistricting_exposure_summary.csv")
