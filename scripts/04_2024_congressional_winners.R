suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

dir.create("outputs", showWarnings = FALSE)

redrawn_states <- c("AL", "CA", "FL", "LA", "MO", "NC", "OH", "TN", "TX", "UT")

results <- read_csv(
  "data/congressional/current_2024_president_and_house_by_district.csv",
  show_col_types = FALSE
) %>%
  filter(valid_pres_cong_data) %>%
  mutate(
    scope = if_else(state %in% redrawn_states, "10 redrawn states", "Other states"),
    split_ticket_type = case_when(
      cong_winner_party == "D" & pres_winner_party == "R" ~ "Democrat won Trump district",
      cong_winner_party == "R" & pres_winner_party == "D" ~ "Republican won Harris district",
      TRUE ~ "Same party won president and House"
    )
  )

district_table <- results %>%
  transmute(
    state,
    district_id,
    incumbent,
    incumbent_party,
    presidential_winner = pres_winner,
    house_winner_party = cong_winner_party,
    house_winner = cong_winner,
    split_ticket_type,
    in_redrawn_state = state %in% redrawn_states
  )

summary <- results %>%
  mutate(scope = "Nationwide") %>%
  bind_rows(results %>% filter(state %in% redrawn_states) %>% mutate(scope = "10 redrawn states")) %>%
  group_by(scope) %>%
  summarise(
    total_districts = n(),
    democratic_house_wins = sum(cong_winner_party == "D", na.rm = TRUE),
    republican_house_wins = sum(cong_winner_party == "R", na.rm = TRUE),
    harris_won_districts = sum(pres_winner_party == "D", na.rm = TRUE),
    trump_won_districts = sum(pres_winner_party == "R", na.rm = TRUE),
    democrats_who_won_trump_districts = sum(split_ticket_type == "Democrat won Trump district", na.rm = TRUE),
    republicans_who_won_harris_districts = sum(split_ticket_type == "Republican won Harris district", na.rm = TRUE),
    .groups = "drop"
  )

split_ticket <- district_table %>%
  filter(split_ticket_type != "Same party won president and House")

write_csv(district_table, "outputs/2024_house_winners_by_district.csv")
write_csv(summary, "outputs/2024_house_winners_summary.csv")
write_csv(split_ticket, "outputs/2024_split_ticket_districts.csv")

message("Wrote 2024 House winner and split-ticket outputs.")
