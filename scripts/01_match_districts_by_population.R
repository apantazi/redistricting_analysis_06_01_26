suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(redist)
  library(clue)
})

dir.create("outputs", showWarnings = FALSE)

plan_pairs <- read_csv("data/plan_pairs.csv", show_col_types = FALSE)

crosswalk_all <- tibble()
overlap_pairs_all <- tibble()
diagnostic_all <- tibble()

for (i in seq_len(nrow(plan_pairs))) {
  row <- plan_pairs[i, ]
  state <- row$state

  old_file <- file.path("data", "block_assignments", row$pre_file)
  new_file <- file.path("data", "block_assignments", row$post_file)
  pop_file <- file.path("data", "block_population", paste0("block_population_", state, ".rds"))

  old <- read_csv(
    old_file,
    col_types = cols(
      GEOID20 = col_character(),
      District = col_integer()
    )
  ) %>%
    rename(GEOID = GEOID20, old_district = District)

  new <- read_csv(
    new_file,
    col_types = cols(
      GEOID20 = col_character(),
      District = col_integer()
    )
  ) %>%
    rename(GEOID = GEOID20, new_district = District)

  pop <- readRDS(pop_file)

  blocks <- old %>%
    inner_join(new, by = "GEOID") %>%
    inner_join(pop, by = "GEOID") %>%
    filter(!is.na(old_district), !is.na(new_district), !is.na(pop))

  overlap_table <- blocks %>%
    group_by(old_district, new_district) %>%
    summarise(matched_pop = sum(pop), .groups = "drop")

  overlap_matrix <- xtabs(matched_pop ~ old_district + new_district, overlap_table)

  assignment <- solve_LSAP(max(overlap_matrix) - overlap_matrix)

  old_ids <- as.integer(rownames(overlap_matrix))
  new_ids <- as.integer(colnames(overlap_matrix))[as.integer(assignment)]
  matched_pop <- overlap_matrix[cbind(seq_along(old_ids), as.integer(assignment))]

  old_totals <- rowSums(overlap_matrix)
  new_totals <- colSums(overlap_matrix)

  crosswalk <- tibble(
    state = state,
    old_district = old_ids,
    new_district = new_ids,
    matched_pop = as.numeric(matched_pop),
    old_district_retained_share = matched_pop / old_totals,
    new_district_from_old_share = matched_pop / new_totals[as.character(new_ids)]
  )

  old_levels <- sort(unique(blocks$old_district))
  new_levels <- sort(unique(blocks$new_district))

  plan_matrix <- matrix(as.integer(factor(blocks$new_district, levels = new_levels)), ncol = 1)
  colnames(plan_matrix) <- "post"

  redist_plans_check <- tibble(
    draw = factor(rep("post", length(new_levels))),
    district = factor(seq_along(new_levels), ordered = TRUE)
  )

  attr(redist_plans_check, "plans") <- plan_matrix
  attr(redist_plans_check, "prec_pop") <- blocks$pop
  class(redist_plans_check) <- c("redist_plans", class(redist_plans_check))

  redist_matched <- match_numbers(
    redist_plans_check,
    plan = as.integer(factor(blocks$old_district, levels = old_levels)),
    total_pop = blocks$pop,
    col = "redist_pop_overlap"
  )

  diagnostic <- tibble(
    state = state,
    block_count = nrow(blocks),
    total_pop = sum(blocks$pop),
    matched_pop = sum(crosswalk$matched_pop),
    total_matched_pop_share = sum(crosswalk$matched_pop) / sum(blocks$pop),
    redist_match_numbers_pop_overlap = unique(redist_matched$redist_pop_overlap)
  )

  crosswalk_all <- bind_rows(crosswalk_all, crosswalk)
  overlap_pairs_all <- bind_rows(overlap_pairs_all, overlap_table %>% mutate(state = state, .before = 1))
  diagnostic_all <- bind_rows(diagnostic_all, diagnostic)
}

write_csv(crosswalk_all, "outputs/district_population_matches.csv")
write_csv(overlap_pairs_all, "outputs/district_population_overlap_pairs.csv")
write_csv(diagnostic_all, "outputs/district_population_match_diagnostics.csv")

member_examples <- tribble(
  ~member, ~state, ~old_district, ~running_new_district, ~note,
  "Cleo Fields", "LA", 6L, 6L, "Filed in Louisiana's new 6th District",
  "Debbie Wasserman Schultz", "FL", 25L, 20L, "Filed in Florida's new 20th District",
  "Steve Cohen", "TN", 9L, NA_integer_, "Marked did_not_make_ballot in Ballotpedia candidate data"
)

new_district_totals <- overlap_pairs_all %>%
  group_by(state, new_district) %>%
  summarise(new_district_total_pop = sum(matched_pop), .groups = "drop")

member_old_district_fragments <- overlap_pairs_all %>%
  inner_join(member_examples, by = c("state", "old_district")) %>%
  group_by(member, state, old_district) %>%
  mutate(
    old_district_total_pop = sum(matched_pop),
    old_district_share_in_new_district = matched_pop / old_district_total_pop,
    old_district_pct_in_new_district = 100 * old_district_share_in_new_district
  ) %>%
  ungroup() %>%
  left_join(new_district_totals, by = c("state", "new_district")) %>%
  mutate(
    new_district_share_from_old_district = matched_pop / new_district_total_pop,
    new_district_pct_from_old_district = 100 * new_district_share_from_old_district,
    is_running_district = !is.na(running_new_district) & new_district == running_new_district
  ) %>%
  arrange(member, desc(old_district_pct_in_new_district))

member_running_district_summary <- member_old_district_fragments %>%
  filter(is_running_district | is.na(running_new_district)) %>%
  group_by(member) %>%
  slice_max(old_district_pct_in_new_district, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(
    member,
    state,
    old_district,
    running_new_district,
    comparison_new_district = new_district,
    note,
    old_district_pct_in_comparison_district = old_district_pct_in_new_district,
    comparison_district_pct_from_old_district = new_district_pct_from_old_district
  )

write_csv(member_old_district_fragments, "outputs/member_old_district_population_fragments.csv")
write_csv(member_running_district_summary, "outputs/member_running_district_population_summary.csv")
