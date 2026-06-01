suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

dir.create("outputs", showWarnings = FALSE)

candidates <- read_csv(
  "data/candidates/ballotpedia_house_candidates_2026.csv",
  show_col_types = FALSE
)

incumbents <- candidates %>% 
  filter(incumbent)

steve_cohen <- candidates %>% 
  filter(
    state == "Tennessee",
    district == "District 9",
    candidate == "Steve Cohen"
  ) %>% 
  transmute(
    state,
    district,
    candidate,
    party,
    ballotpedia_status,
    election_phase,
    incumbent,
    source_url
  )

not_on_ballot_incumbents <- incumbents %>% 
  filter(ballotpedia_status == "did_not_make_ballot") %>% 
  transmute(
    state,
    district,
    candidate,
    party,
    ballotpedia_status,
    election_phase,
    source_url
  ) %>% 
  arrange(state, district, candidate)

write_csv(steve_cohen, "outputs/steve_cohen_candidate_status.csv")
write_csv(not_on_ballot_incumbents, "outputs/incumbents_not_on_ballot.csv")

message("Wrote candidate-status outputs.")
