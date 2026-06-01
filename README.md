# Redistricting analysis, June 1, 2026

## Scripts

-   `scripts/01_match_districts_by_population.R`\
    Matches old districts to new districts in the 10 redrawn states using Census block population as the weight. It reads block assignment files, joins block population, calculates old-new district overlap, and writes a population-weighted crosswalk. It also checks the plan-level overlap with `redist::match_numbers()`.

-   `scripts/02_harris_won_before_after.R`\
    Calculates how many districts Harris and Trump carried before redistricting and under the post-redistricting maps. It reports both nationwide counts and counts for the 10 redrawn states. Alabama is shown both ways: with the attempted GOP-backed map and without it.

-   `scripts/03_flipping_point.R`\
    Calculates the Democratic overperformance needed to win 218 House seats nationally and the overperformance needed in the 10 redrawn states for Democrats to hold the 80 seats they won there in 2024.

-   `scripts/04_2024_congressional_winners.R`\
    Summarizes actual 2024 House winners by district and identifies split-ticket districts, including Democrats who won Trump-carried districts and Republicans who won Harris-carried districts.

-   `scripts/05_black_vap_changes.R`\
    Calculates Black voting-age population shares before and after redistricting from DRA district exports.

-   `scripts/06_candidate_status_examples.R`\
    Pulls candidate status.

## Data folders

-   `data/block_assignments/`\
    Block assignment files for the old and new maps in the 10 redrawn states. Used for population-weighted district matching.

-   `data/block_population/`\
    Census block population weights. Used with the block assignment files to calculate how much population each old district shares with each new district.

-   `data/dra_district_exports/`\
    DRA district-level exports for old and new maps. Used for post-redistricting presidential results, compact district-level demographics, and Black VAP calculations.

-   `data/presidential/`\
    2024 presidential results by the congressional districts used in the 2024 election, from The Downballot.

-   `data/congressional/`\
    2024 presidential and House results by district. Used to compare presidential results with actual House winners.

-   `data/candidates/`\
    Candidate status. Used for examples of incumbents not on the ballot.

-   `data/plan_pairs.csv`\
    Lookup table pairing each old DRA map with its new DRA map.

-   `data/dra_district_manifest.csv`\
    Lookup table identifying the post-redistricting DRA district export for each redrawn state.

## Key Story Facts

-   **National majority threshold:** Democrats needed to run 3.1 points better than Harris' 2024 district margins to win 218 seats before redistricting. They now need 4.9 points if Alabama's attempted map is included, or 4.5 points if it is not.\
    Check: `scripts/03_flipping_point.R` -\> `outputs/flipping_point_summary.csv`

-   **Redrawn-state overperformance:** To hold the 80 seats they won in those 10 states, Democrats needed to outrun Harris by 5.4 points before redistricting. Under the new maps, they need to outrun Harris by 10.5 points.\
    Check: `scripts/03_flipping_point.R` -\> `outputs/flipping_point_summary.csv`

-   **Harris-won districts:** Harris carried 205 districts before the redistricting wave. Under the new maps, she would have carried 200 districts with Alabama's attempted map, or 201 without it.\
    Check: `scripts/02_harris_won_before_after.R` -\> `outputs/harris_won_before_after.csv`

-   **The 10 redrawn states:** In the 10 redrawn states, Democrats won 80 House seats and Republicans won 101 in 2024. Harris carried 74 of those districts; Trump carried 107.\
    Check: `scripts/04_2024_congressional_winners.R` -\> `outputs/2024_house_winners_summary.csv`

-   **Split-ticket Democratic targets:** Nationally, 13 Democrats won Trump-carried districts in 2024. In the 10 redrawn states, six Democrats won Trump-carried districts.\
    Check: `scripts/04_2024_congressional_winners.R` -\> `outputs/2024_split_ticket_districts.csv`

-   **Cleo Fields/Louisiana claim:** Cleo Fields won LA-6 in 2024, when the district was Black-majority by voting-age population. Under the new Louisiana map, LA-6 gave Trump 65.0% of the total presidential vote, or 66.2% of the two-party vote.\
    Check: `scripts/04_2024_congressional_winners.R` -\> `outputs/2024_house_winners_by_district.csv`; `scripts/05_black_vap_changes.R` -\> `outputs/black_vap_by_district.csv`; `scripts/02_harris_won_before_after.R` -\> `outputs/presidential_map_scenarios.csv`

-   **Steve Cohen/Tennessee Black VAP claim:** Tennessee's old 9th District was 60.3% Black voting-age population. After redistricting, the highest-Black-VAP Tennessee district is 31.7%.\
    Check: `scripts/05_black_vap_changes.R` -\> `outputs/steve_cohen_tennessee_black_vap_claim.csv`

## Notes

-   Presidential margins use Harris votes minus Trump votes as a share of each district's reported presidential total.